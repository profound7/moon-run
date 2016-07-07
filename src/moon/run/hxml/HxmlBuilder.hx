package moon.run.hxml;

import moon.run.util.Proto;
import sys.FileSystem;
import sys.io.File;
import Type;

using StringTools;
using moon.run.util.CastTools;

/**
 * Nested Json to Hxml converter
 * 
 * @author Munir Hussin
 */
class HxmlBuilder
{
    public static inline var MERGE_KEY = "@merge";
    public static inline var MULTI_KEY = "@multi";
    public static inline var HXPROJ_MAIN_KEY = "@hxproj-main";
    
    // { "-arg": "value" }
    // -arg output
    public static var targetArgs =
    [
        "-js", "-swf", "-as3", "-neko", "-php",
        "-cpp", "-cs", "-java", "-python"
    ];
    
    // { "-arg": true }
    // { "-arg": 1 }
    // -arg
    public static var boolArgs =
    [
        "--js-modern", "--flash-strict", "--flash-use-stage",
        "-debug", "--no-opt", "--no-traces", "--no-inline", "--no-output",
        "--gen-hx-classes", "--interp", "-v", "-prompt", "--times",
    ];
    
    // { "-arg": "value" }
    // -arg value
    public static var singleArgs =
    [
        "-main", "-xml", "-x", "-swf-version", "-swf-header",
        "--php-front", "-php-lib", "-php-prefix",
        "-dce", "-cmd"
    ];
    
    // { "-arg": ["value1", "value2", ...] }
    // -arg value1 -arg value2 ...
    public static var multiArgs =
    [
        "-cp", "-lib", "-D", "-resource", "--remap",
        "--macro", "-swf-lib", "-swf-lib-extern",
        "--display"
    ];
    
    
    public var obj:Proto;
    public var debug:Bool;
    public var okays:Int = 0;
    public var fails:Int = 0;
    
    
    public function new(obj:Proto, debug:Bool)
    {
        this.obj = obj;
        this.debug = debug;
        process(obj);
    }
    
    
    public static function merge(src:Proto, dest:Proto, ignoreObjects:Bool=false):Void
    {
        for (key in src.listOwnFields())
        {
            if (key == Proto.parentField ||
                (ignoreObjects && !key.startsWith("-") && !key.startsWith("@")))
                continue;
            
            var sval:Dynamic = src.getOwnField(key);
            var dval:Dynamic = dest.getOwnField(key);
            
            if (Std.is(sval, Array) && sval.length > 0 && sval[0] == null)
            {
                // if first item in source array is null, shadow instead of concat
                var sarr:Array<Dynamic> = sval;
                dest.setOwnField(key, sarr.slice(1));
            }
            else if (multiArgs.indexOf(key) != -1 || Std.is(sval, Array) || Std.is(dval, Array))
            {
                // if either is an array, or is a known multi-type, then concat
                var sarr:Array<Dynamic> = sval.asDynamicArray();
                var darr:Array<Dynamic> = dval.asDynamicArray();
                dest.setOwnField(key, darr.concat(sarr));
            }
            else
            {
                // everything else shadows
                dest.setOwnField(key, sval);
            }
        }
    }
    
    /**
     * Do some pre-processing on the json
     */
    public static function process(obj:Proto):Void
    {
        var keys:Array<String> = obj.listOwnFields();
        
        // -arg value
        for (key in singleArgs)
        {
            if (obj.hasOwnField(key))
            {
                obj[key].expectString();
                keys.remove(key);
            }
        }
        
        // -arg value1 -arg value2 ...
        for (key in multiArgs)
        {
            if (obj.hasOwnField(key))
            {
                obj[key] = obj[key].asStringArray();
                keys.remove(key);
            }
        }
        
        // -arg
        for (key in boolArgs)
        {
            if (obj.hasOwnField(key))
            {
                obj[key] = obj[key].truthy();
                keys.remove(key);
            }
        }
        
        // get the main class from FlashDevelop's .hxproj file
        if (obj.hasOwnField(HXPROJ_MAIN_KEY))
        {
            var file:String = obj[HXPROJ_MAIN_KEY].expectString();
            var mainClass:String = FdHxproj.open(file).getMainClass();
            obj.deleteField(HXPROJ_MAIN_KEY);
            obj.setOwnField("-main", mainClass);
            keys.remove(HXPROJ_MAIN_KEY);
        }
        
        if (obj.hasOwnField(MERGE_KEY))
        {
            if (obj.hasParent)
            {
                var parent:Proto = obj.parent;
                var refs:Array<String> = obj[MERGE_KEY].asStringArray();
                obj.deleteOwnField(MERGE_KEY);
                
                for (r in refs)
                {
                    merge(parent[r].asProto(), obj);
                }
                
                keys.remove(MERGE_KEY);
            }
            else
            {
                throw '$MERGE_KEY requires a parent object';
            }
        }
        
        // all other remaining keys
        for (key in keys)
        {
            var value:Dynamic = obj[key];
            
            if (key == Proto.parentField || key.startsWith("-"))
            {
                // do nothing
            }
            else
            {
                var type = Type.typeof(value);
                
                switch (type)
                {
                    case TObject:
                        var child:Proto = value;
                        child.parent = obj;
                        process(child);
                        
                    // "foo": "bar" ==> "foo": { /* bar data */ }
                    case TClass(String):
                        // do nothing
                        
                    // "foo": ["bar", "baz"] ==> ???
                    case TClass(Array):
                        // do nothing
                        var child:Proto = new Proto(obj);
                        child.setOwnField(MULTI_KEY, value);
                        obj.setOwnField(key, child);
                        
                    case _:
                }
            }
        }
    }
    
    /**
     * Returns the object referenced by target.
     * Target can be "foo" or with slashes "foo/bar/baz".
     */
    public static function pick(obj:Proto, target:String):Proto
    {
        var parts:Array<String> = target.split("/");
        obj = obj.root;
        
        for (p in parts)
        {
            if (p.length == 0)
                continue;
            else if (obj.hasOwnField(p))
                obj = obj.getOwnField(p);
            else
                throw 'Object does not have field $p in target $target.';
        }
        
        return obj;
    }
    
    public static function flatten(obj:Proto):Proto
    {
        var o:Proto = new Proto();
        var arr:Array<Proto> = [obj];
        
        while (obj.hasParent)
        {
            obj = obj.parent;
            arr.push(obj);
        }
        
        // start merging from root, so values get replaced by child values
        while (arr.length > 0)
        {
            obj = arr.pop();
            merge(obj, o, true);
        }
        
        return o;
    }
    
    
    /**
     * handles "@multi":["x", "y", ...] args
     */
    public static function handleMulti(obj:Proto, tobj:Proto, tasks:Array<Proto>):Void
    {
        if (tobj.hasOwnField(MULTI_KEY))
        {
            var keys:Array<String> = tobj.getOwnField(MULTI_KEY).asStringArray();
            tobj.deleteOwnField(MULTI_KEY);
            
            for (k in keys)
            {
                var kobj:Proto = pick(obj, k);
                kobj.parent = tobj;
                kobj = flatten(kobj);
                
                // there might be another multi from recently picked
                handleMulti(obj, kobj, tasks);
            }
        }
        else
        {
            tasks.push(tobj);
        }
    }
    
    
    
    public function build(targets:Array<String>):Void
    {
        var tasks:Array<Proto> = [];
        
        okays = 0;
        fails = 0;
        
        while (targets.length > 0)
        {
            var t:String = targets.shift();
            var tobj:Proto = flatten(pick(obj, t));
            
            handleMulti(obj, tobj, tasks);
        }
        
        //tasks = isolateTargets(tasks);
        
        if (tasks.length == 0)
        {
            var tobj:Proto = flatten(obj);
            handleMulti(obj, tobj, tasks);
        }
        
        for (t in tasks)
        {
            //Sys.println(Json.stringify(t, null, "    "));
            //Sys.println("\n-----------------------\n");
            
            buildHxml(t);
        }
        
        Sys.println('Build completed with $okays successes and $fails failures.');
        Sys.exit(fails == 0 ? 0 : 1);
    }
    
    public function buildHxml(obj:Proto):Void
    {
        var cmd = "haxe";
        var args:Array<String> = [];
        var keys:Array<String> = obj.listOwnFields();
        
        
        for (key in singleArgs)
        {
            keys.remove(key);
            
            if (obj.hasField(key))
            {
                args.push(key);
                args.push(obj[key].expectString());
            }
        }
        
        for (key in multiArgs)
        {
            keys.remove(key);
            
            if (obj.hasField(key))
            {
                var arr = obj[key].asStringArray();
                
                for (a in arr)
                {
                    args.push(key);
                    args.push(a);
                }
            }
        }
        
        for (key in boolArgs)
        {
            keys.remove(key);
            
            if (obj.hasField(key) && obj[key].truthy())
            {
                args.push(key);
            }
        }
        
        // get everything else that isn't target
        var others:Array<String> = [];
        var targets:Array<String> = [];
        
        // seperate the remaining args into targets and others
        for (k in keys)
        {
            if (targetArgs.indexOf(k) != -1)
                targets.push(k);
            else
                others.push(k);
        }
        
        // fallback, in case there are other newer haxe
        // command line args or other args I missed out.
        // it'll add the args appropriately based on
        // the value type
        for (key in others)
        {
            if (key.startsWith("-"))
            {
                var value:Dynamic = obj[key];
                
                switch (Type.typeof(value))
                {
                    // { "-arg": "value" }   ==> -arg value
                    // { "-arg": "foo bar" } ==> -arg "foo bar"
                    case TClass(String):
                        args.push(key);
                        args.push(value);
                        
                    // { "-arg": 1 }    ==> -arg
                    // { "-arg": true } ==> -arg
                    case TBool | TInt if (value.truthy()):
                        args.push(key);
                        
                    // { "-arg": ["x", "y"] } ==> -arg x -arg y
                    case TClass(Array):
                        var arr:Array<Dynamic> = value;
                        for (a in arr)
                        {
                            args.push(key);
                            args.push(a);
                        }
                        
                    case _:
                        throw "Illegal argument type";
                }
            }
            else
            {
                throw 'Invalid arg $key';
            }
        }
        
        
        
        // 2 or more targets require --each for common args above
        if (targets.length >= 2)
        {
            args.push("--each");
        }
        
        var it:Iterator<String> = targets.iterator();
        
        // now add in the targets, seperated by --next
        for (t in it)
        {
            args.push(t);
            args.push(obj[t]);
            
            if (it.hasNext())
            {
                args.push("--next");
            }
        }
        
        var hxml:String = toHxml(args);
        
        
        
        //Sys.println(cmd + " " + [for (x in a) stringify(x)].join(" ");
        
        if (debug)
        {
            Sys.println(hxml);
            Sys.println("\n-----------------------\n");
        }
        else
        {
            Sys.print('Building... ');
            
            // this works for -xml but does not work
            // for -neko, -js, etc... WHY????????!!!
            //var exitCode:Int = Sys.command(cmd, a);
            
            // WORKAROUND:
            // save the arguments to a hxml file and build
            // using that instead
            
            var tmpFile:String = makeTempFile("__tmp_", ".hxml");
            File.saveContent(tmpFile, hxml);
            
            // should we use Process instead?
            var exitCode:Int = Sys.command(cmd, [tmpFile]);
            FileSystem.deleteFile(tmpFile);
            
            if (exitCode == 0)
            {
                Sys.println("ok");
                ++okays;
            }
            else
            {
                Sys.println("failed");
                ++fails;
            }
        }
    }
    
    public static function toHxml(args:Array<String>):String
    {
        var sbuf:StringBuf = new StringBuf();
        var empty:Bool = true;
        
        for (a in args)
        {
            if (a.startsWith("-"))
            {
                if (empty)
                {
                    sbuf.add(a);
                    empty = false;
                }
                else
                {
                    sbuf.add("\n");
                    sbuf.add(a);
                }
            }
            else
            {
                sbuf.add(" ");
                sbuf.add(a);
            }
        }
        
        return sbuf.toString();
    }
    
    /**
     * generate a temporary file
     */
    public static function makeTempFile(prefix:String, ext:String):String
    {
        var name:String = null;
        var r:Int = 0;
        
        while (true)
        {
            r = Math.floor(Math.random() * 0x7fffffff);
            name = prefix + StringTools.hex(r, 8) + ext;
            
            if (!FileSystem.exists(name))
            {
                File.saveContent(name, ""); // create it!
                return name;
            }
        }
    }
}