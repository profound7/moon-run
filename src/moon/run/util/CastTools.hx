package moon.run.util;

import Type;

/**
 * ...
 * @author Munir Hussin
 */
class CastTools
{
    public static function isProto(val:Dynamic):Bool
    {
        return Type.typeof(val).equals(TObject);
    }
    
    public static function asProto(val:Dynamic):Proto
    {
        return isProto(val) ? val :
            throw 'Expected object, got $val';
    }
    
    public static function asStringArray(val:Dynamic):Array<String>
    {
        return Std.is(val, Array) ? val :
            (val == null ? [] : [Std.string(val)]);
    }
    
    public static function asDynamicArray(val:Dynamic):Array<Dynamic>
    {
        return Std.is(val, Array) ? val :
            (val == null ? [] : [val]);
    }
    
    public static function expectInt(val:Dynamic):Int
    {
        return Std.is(val, Int) ? val :
            throw 'Expected Int, got $val';
    }
    
    public static function expectString(val:Dynamic):String
    {
        return Std.is(val, String) ? val :
            throw 'Expected String, got $val';
    }
    
    public static function expectArray(val:Dynamic):Array<Dynamic>
    {
        return Std.is(val, Array) ? val :
            throw 'Expected Array, got $val';
    }
    
    public static function expectStringArray(val:Dynamic):Array<String>
    {
        if (Std.is(val, Array))
        {
            var arr:Array<Dynamic> = val;
            for (a in arr)
                if (!Std.is(a, String))
                    throw 'Expected String, got $a';
            return val;
        }
        else
        {
            throw 'Expected Array, got $val';
        }
    }
    
    /**
     * If val is a Bool, return val.
     * 
     * If val is an Int or Float, 0 is false,
     * everything else is True.
     * 
     * If val is a String, "true", "1" and "yes"
     * is true, everything else is false.
     * 
     * Null is false.
     * 
     * Since this is meant for json config, if you
     * put an object or array where a truthy value is
     * expected, it's most likely to be a mistake. So
     * everything else throws an error.
     */
    public static function truthy(val:Dynamic):Bool
    {
        return switch (Type.typeof(val))
        {
            case TClass(String):
                var s:String = val;
                s = s.toLowerCase();
                s == "true" || s == "1" || s == "yes";
                
            case TBool:
                val;
                
            case TInt | TFloat:
                val != 0;
                
            case TNull:
                false;
                
            case _:
                throw "Not a truthy value";
        }
    }
    
    public static function cmdEscape(s:String):String
    {
        if (s.indexOf('"') == -1)
            return '"$s"';
        else
            // works in windows. double quotes escaping untested in unix
            return '"' + s.split('"').join('""') + '"';
    }
    
    public static function stringify(val:Dynamic):String
    {
        var whiteSpace = ~/[ \n\r\t]+/;
        var s = Std.string(val);
        return whiteSpace.match(s) ? cmdEscape(s) : s;
    }
}