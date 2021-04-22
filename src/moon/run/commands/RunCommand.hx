package moon.run.commands;

import mcli.CommandLine;
import moon.run.util.JsonTools;
import moon.run.util.Proto;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import Type;

using StringTools;
using moon.run.util.CastTools;

/**
 * Usage:
 * 
 *   hx run [section] [args ...]
 * 
 * Runs commands from a haxe.json file.
 * If no section is specified, `main` is assumed.
 * 
 * Examples:
 * 
 *   hx run
 *   hx run foo
 * 
 * Options:
 * @author Munir Hussin
 */
class RunCommand extends CommandLine
{
    /**
     * The json settings file. Defaults to haxe.json
     */
    public var file:String = "haxe.json";
    public var pause:Bool = false;
    
    public function runDefault(varArgs:Array<String>):Void
    {
        var res        = 0;
        var json:Proto = JsonTools.require(file);
        
        if (json.hasOwnField("run"))
        {
            var run:Proto = json["run"];
            var globals:Proto = process(run);
            initGlobals(globals);
            
            if (varArgs.length == 0)
            {
                varArgs = ["main"];
            }
            
            globals.eval(varArgs);
            
            if (pause)
                globals.eval(["pause"]);
        }
        else
        {
            throw "No build settings found in json file.";
        }
        
        Sys.exit(0);
    }
    
    @:skip public static function process(obj:Proto):Proto
    {
        var globals:Proto = new Proto();
        
        for (key in obj.listOwnFields())
        {
            var value:Dynamic = obj[key];
            
            switch (Type.typeof(value))
            {
                case TClass(Array):
                    var arr:Array<Dynamic> = value;
                    var body = [("begin":Dynamic)].concat(arr);
                    globals.define(key, [], body);
                    
                case _:
                    globals[key] = value;
            }
        }
        
        return globals;
    }
    
    @:skip public static function initGlobals(globals:Proto):Void
    {
        globals.syntax("begin", function(env:Proto, args:Array<Dynamic>):Dynamic
        {
            var scope:Proto = new Proto(env);
            var value:Dynamic = null;
            
            for (a in args)
            {
                value = scope.eval(a);
            }
            
            return value;
        });
        
        globals.syntax("globals", function(env:Proto, args:Array<Dynamic>):Dynamic
        {
            return globals;
        });
        
        globals.syntax("var", function(env:Proto, args:Array<Dynamic>):Dynamic
        {
            var name:String = args[0].expectString();
            var value:Dynamic = args.length == 1 ? null : args[1];
            env.setOwnField(name, value);
            return null;
        });
        
        // (set variable "value")
        // (set (field object "key") "value")
        // (set (index array index) "value")
        globals.syntax("set", function(env:Proto, args:Array<Dynamic>):Dynamic
        {
            var name:Dynamic = args[0];
            var value:Dynamic = env.eval(args[1]);
            
            if (Std.is(name, Array))
            {
                var arr:Array<Dynamic> = name;
                switch (arr)
                {
                    case ["field", o, k]:
                        var obj:Proto = env.eval(o);
                        var field:String = k.expectString();
                        Reflect.setField(obj, field, value);
                        
                    case ["index", o, i]:
                        var obj:Array<Dynamic> = env.eval(o).expectArray();
                        var index:Int = env.eval(i).expectInt();
                        o[i] = value;
                        
                    case _:
                        throw "Unexpected Array";
                }
            }
            else if (Std.is(name, String))
            {
                env[(name:String)] = value;
            }
            
            return value;
        });
        
        globals.syntax("if", function(env:Proto, args:Array<Dynamic>):Dynamic
        {
            if (env.eval(args[0]))
                return env.eval(args[1]);
            else
                return env.eval(args[2]);
        });
        
        globals.syntax("lambda", function(env:Proto, args:Array<Dynamic>):Dynamic
        {
            var sig:Array<String> = args[0].expectStringArray();
            var body:Dynamic = args[1];
            return env.lambda(sig, body);
        });
        
        globals.syntax("define", function(env:Proto, args:Array<Dynamic>):Dynamic
        {
            var name:String = args[0].expectString();
            var sig:Array<String> = args[1].expectStringArray();
            var body:Dynamic = args[2];
            return env.define(name, sig, body);
        });
        
        globals.syntax("println", function(env:Proto, args:Array<Dynamic>):Dynamic
        {
            Sys.println([for (a in args) env.eval(a)].join(" "));
            return null;
        });
        
        globals.syntax("print", function(env:Proto, args:Array<Dynamic>):Dynamic
        {
            Sys.print([for (a in args) env.eval(a)].join(" "));
            return null;
        });
        
        globals.syntax("pause", function(env:Proto, args:Array<Dynamic>):Dynamic
        {
            if (Sys.systemName() == "Windows")
            {
                Sys.command("pause");
            }
            else
            {
                Sys.command("read", ["-rsp", "$'Press any key to continue...\n'", "-n1", "key"]);
            }
            return null;
        });
        
        globals.syntax("array", function(env:Proto, args:Array<Dynamic>):Dynamic
        {
            return [for (a in args) env.eval(a)];
        });
        
        globals.syntax("field", function(env:Proto, args:Array<Dynamic>):Dynamic
        {
            var obj:Proto = env.eval(args[0]);
            var field:String = args[0].expectString();
            return Reflect.field(obj, field);
        });
        
        globals.syntax("index", function(env:Proto, args:Array<Dynamic>):Dynamic
        {
            var obj:Array<Dynamic> = env.eval(args[0]).expectArray();
            var index:Int = env.eval(args[0]).expectInt();
            return obj[index];
        });
        
        var comparisons =
        [
            "==" => function(a:Dynamic, b:Dynamic) { return a == b; },
            "!=" => function(a:Dynamic, b:Dynamic) { return a != b; },
            "<"  => function(a:Dynamic, b:Dynamic) { return a < b; },
            ">"  => function(a:Dynamic, b:Dynamic) { return a > b; },
            "<=" => function(a:Dynamic, b:Dynamic) { return a <= b; },
            ">=" => function(a:Dynamic, b:Dynamic) { return a >= b; },
            "&&" => function(a:Dynamic, b:Dynamic) { return a && b; },
            "||" => function(a:Dynamic, b:Dynamic) { return a || b; },
        ];
        
        for (key in comparisons.keys())
        {
            globals.syntax(key, function(env:Proto, args:Array<Dynamic>):Dynamic
            {
                var prev:Dynamic = env.eval(args[0]);
                var curr:Dynamic = null;
                var cmp:Dynamic->Dynamic->Bool = comparisons[key];
                
                for (i in 1...args.length)
                {
                    curr = env.eval(args[i]);
                    
                    if (!cmp(prev, curr))
                        return false;
                    
                    prev = curr;
                }
                
                return true;
            });
        }
        
        // all of these can be used as "unary" also when there's only 1 arg
        var arithmetic:Map<String, Array<Dynamic>> =
        [
            //     [init value of fold, if true then init value is first argument, the function]
            "+" => [0, false, function(a:Dynamic, b:Dynamic) { return a + b; }],
            "-" => [0, true, function(a:Dynamic, b:Dynamic) { return a - b; }],
            "*" => [1, false, function(a:Dynamic, b:Dynamic) { return a * b; }],
            "/" => [1, true, function(a:Dynamic, b:Dynamic) { return a / b; }],
            "%" => [1, true, function(a:Dynamic, b:Dynamic) { return a % b; }],
            
            // true if there's even number of true
            "!" => [true, false, function(a:Dynamic, b:Dynamic) { return a && !b || !a && b; }],
        ];
        
        // [10]      ==> -10    0 - 10
        // [10 1]    ==> 9      0 + 10 - 1
        // [10 1 2]  ==> 7      0 + 10 - 1 - 2
        for (key in arithmetic.keys())
        {
            globals.syntax(key, function(env:Proto, args:Array<Dynamic>):Dynamic
            {
                var total:Dynamic = arithmetic[key][0];
                var curr:Dynamic = null;
                var op:Dynamic->Dynamic->Bool = arithmetic[key][2];
                var s:Int = 0;
                
                if (args.length > 1 && arithmetic[key][1] == true)
                {
                    total = env.eval(args[0]);
                    ++s;
                }
                
                for (i in s...args.length)
                {
                    curr = env.eval(args[i]);
                    total = op(total, curr);
                }
                
                return total;
            });
        }
        
        globals.syntax("cd", function(env:Proto, args:Array<Dynamic>):Dynamic
        {
            for (a in args)
                Sys.setCwd(env.eval(a));
            Sys.println("Changed current directory to: " + Sys.getCwd());
            return true;
        });
    }
    
    /**
     * Shows this message.
     */
    public function help()
    {
        Sys.println(this.showUsage());
        Sys.exit(0);
    }
}