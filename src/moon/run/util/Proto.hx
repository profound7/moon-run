package moon.run.util;

import haxe.Json;
import sys.io.Process;
import Type;

using StringTools;
using moon.run.util.CastTools;

/**
 * ...
 * @author Munir Hussin
 */
typedef Struct = { };

abstract Proto(Struct) to Struct from Struct
{
    public static inline var parentField:String = "__parent";
    
    public var root(get, never):Proto;
    public var parent(get, set):Proto;
    public var isRoot(get, never):Bool;
    public var hasParent(get, never):Bool;
    
    
    public function new(?parentProto:Struct)
    {
        this = { };
        
        if (parentProto != null)
        {
            parent = parentProto;
        }
    }
    
    private function get_root():Proto
    {
        var obj:Proto = this;
        while (obj.hasParent)
            obj = obj.parent;
        return obj;
    }
    
    private function get_parent():Proto
    {
        return hasOwnField(parentField) ? getOwnField(parentField) : null;
    }
    
    private function set_parent(p:Proto):Proto
    {
        if (p == null)
            deleteOwnField(parentField);
        else
            setOwnField(parentField, p);
        return p;
    }
    
    private function get_isRoot():Bool
    {
        return parent == null;
    }
    
    private function get_hasParent():Bool
    {
        return parent != null;
    }
    
    public function hasOwnField(field:String):Bool
    {
        return Reflect.hasField(this, field);
    }
    
    public function hasField(field:String):Bool
    {
        return hasOwnField(field) || (hasParent && parent.hasField(field));
    }
    
    public function getOwnField(field:String):Dynamic
    {
        return Reflect.field(this, field);
    }
    
    @:arrayAccess public function getField(field:String):Dynamic
    {
        return hasOwnField(field) ? getOwnField(field):
            (hasParent ? parent.getField(field) : null);
    }
    
    public function setOwnField(field:String, value:Dynamic):Dynamic
    {
        Reflect.setField(this, field, value);
        return value;
    }
    
    @:arrayAccess public function setField(field:String, value:Dynamic):Dynamic
    {
        return hasOwnField(field) ? setOwnField(field, value):
            (hasParent ? parent.setField(field, value) : setOwnField(field, value));
    }
    
    public function deleteOwnField(field:String):Bool
    {
        return Reflect.deleteField(this, field);
    }
    
    public function deleteField(field:String):Bool
    {
        return hasOwnField(field) ? deleteOwnField(field):
            (hasParent ? parent.deleteField(field) : false);
    }
    
    public function listOwnFields():Array<String>
    {
        return Reflect.fields(this);
    }
    
    public function listFields():Array<String>
    {
        var pFields = hasParent ? parent.listFields() : [];
        var cFields = Reflect.fields(this);
        return pFields.concat(cFields);
    }
    
    public function copy(?dest:Proto):Proto
    {
        if (dest == null)
            return Reflect.copy(this);
        
        var src:Proto = this;
        
        for (key in listOwnFields())
            dest.setOwnField(key, src.getOwnField(key));
        
        return dest;
    }
    
    public static function orphanize(obj:Proto):Void
    {
        obj.parent = null;
        
        for (key in obj.listOwnFields())
        {
            var value:Dynamic = obj[key];
            
            if (value.isProto())
            {
                orphanize(value);
            }
        }
    }
    
    public static function parentize(obj:Proto):Void
    {
        for (key in obj.listOwnFields())
        {
            var value:Dynamic = obj[key];
            
            if (value.isProto())
            {
                var child:Proto = value;
                child.parent = obj;
                parentize(child);
            }
        }
    }
    
    public function collect(key:String, flatten:Bool=false):Array<Dynamic>
    {
        var ret:Array<Dynamic> = [];
        
        if (hasOwnField(key))
        {
            var val:Dynamic = getOwnField(key);
            
            if (flatten && Std.is(val, Array))
                ret = ret.concat(val);
            else
                ret.push(getOwnField(key));
        }
        
        for (f in listOwnFields())
        {
            var value:Dynamic = getOwnField(f);
            
            if (value.isProto())
            {
                var obj:Proto = value;
                ret = ret.concat(obj.collect(key, flatten));
            }
        }
        
        return ret;
    }
    
    
    public function syntax(name:String, fn:Proto->Array<Dynamic>->Dynamic):Proto->Array<Dynamic>->Dynamic
    {
        var self:Proto = this;
        self.setOwnField(name, new Syntax(fn));
        return fn;
    }
    
    public function lambda(vars:Array<String>, body:Dynamic):Array<Dynamic>->Dynamic
    {
        var self:Proto = this;
        var fn = function(args:Array<Dynamic>):Dynamic
        {
            if (args.length < vars.length)
                throw 'Insufficient arguments for function: $vars';
                
            var scope:Proto = new Proto(self);
            scope.setOwnField("arguments", args);
            
            // associate variable names with values
            for (i in 0...vars.length)
            {
                scope.setOwnField(vars[i], args[i]);
            }
            
            // arguments by index
            for (i in 0...args.length)
            {
                scope.setOwnField('%__$i', args[i]);
            }
            
            return scope.eval(body);
        }
        
        return fn;
    }
    
    public function define(name:String, vars:Array<String>, body:Dynamic):Array<Dynamic>->Dynamic
    {
        var fn = lambda(vars, body);
        setOwnField(name, fn);
        return fn;
    }
    
    
    // eval(5)                      ==> 5
    // eval(true)                   ==> true
    // eval("foo")                  ==> "foo"
    // eval(["foo"])                ==> env.foo() or Sys.command("foo")
    // eval(["foo", "bar", "baz"])  ==> env.foo("bar", "baz") or Sys.command("foo", ["bar", "baz"])
    // eval(["&foo"])               ==> env["foo"]
    // eval(["#foo", "bar"])        ==> Sys.command("foo", ["bar"])
    // eval([">foo", "bar"])        ==> new Process("foo", ["bar"])
    public function eval(expr:Dynamic):Dynamic
    {
        //Sys.println('eval: $expr');
        var self:Proto = this;
        
        switch (Type.typeof(expr))
        {
            case TClass(Array):
                var arr:Array<Dynamic> = expr;
                var args:Array<Dynamic> = arr.slice(1);
                var idAny:Dynamic = self.eval(arr[0]);
                
                var id:String = switch (Type.typeof(idAny))
                {
                    case TInt:
                        '&%__$idAny';
                        
                    case TClass(String):
                        idAny;
                        
                    case _:
                        throw 'Unexpected type for function';
                }
                
                var firstChar:String = id.substr(0, 1);
                
                // sys call
                if (firstChar == "#")
                {
                    id = id.substr(1);
                    return system(id, args);
                }
                // process
                else if (firstChar == ">")
                {
                    id = id.substr(1);
                    return process(id, args);
                }
                // get
                else if (firstChar == "&")
                {
                    id = id.substr(1);
                    return self[id];
                }
                // user-defined
                else if (self.hasField(id.toLowerCase()))
                {
                    var value:Dynamic = self[id.toLowerCase()];
                    
                    if (Std.is(value, Syntax))
                    {
                        value = value.fn(self, args);
                    }
                    else if (Reflect.isFunction(value))
                    {
                        args = [for (a in args) self.eval(a)];
                        value = value(args);
                    }
                    
                    return value;
                }
                // sys call fallback
                else
                {
                    //throw 'No such variable $id';
                    return system(id, args);
                }
                
                
            case _:
                return expr;
        }
    }
    
    public function system(cmd:String, args:Array<Dynamic>):Int
    {
        var sargs:Array<String> = [for (a in args) Std.string(eval(a))];
        var res                 = Sys.command(cmd, sargs);
        return res;
    }
    
    public function process(cmd:String, args:Array<Dynamic>):Dynamic
    {
        var sargs:Array<String> = [for (a in args) Std.string(eval(a))];
        
        try
        {
            var p:Process = new Process(cmd, sargs);
            
            var exitCode:Int = p.exitCode();
            var stdout:String = p.stdout.readAll().toString();
            p.close();
            return exitCode;
        }
        catch (ex:Dynamic)
        {
            return false;
        }
    }
}

class Syntax
{
    public var fn:Proto->Array<Dynamic>->Dynamic;
    
    public function new(fn:Proto->Array<Dynamic>->Dynamic)
    {
        this.fn = fn;
    }
}