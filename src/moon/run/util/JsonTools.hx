package moon.run.util;

import haxe.CallStack;
import haxe.Json;

#if sys
    import sys.io.File;
#end

using StringTools;

/**
 * Comments in JSON are invalid. In order to allow comments within
 * JSON configuration files, we need to strip them away before parsing.
 * 
 * Instead of removing comments, which will result in a shorter String,
 * the stripComments function actually replaces comments with spaces,
 * so the positions of all other characters are maintained.
 * 
 * This is helpful when there's Json parsing errors, and you need
 * the correct position of the parse error.
 * 
 * @author Munir Hussin
 */
class JsonTools
{
    //private static var space:Int = 219;
    private static var space:Int = 32;
    private static var rx = ~/Invalid char (\d+) at position (\d+)/;
    
    #if sys
    public static function load(file:String):Dynamic
    {
        var data:String = File.getContent(file);
        var json:Dynamic = parse(data, true);
        return json;
    }
    
    public static function require(file:String):Dynamic
    {
        var data:String = null;
        var json:Proto = null;
        
        try
        {
            data = File.getContent(file);
            json = parse(data, true);
            return json;
        }
        catch (ex:JsonException)
        {
            switch (ex)
            {
                case JsonParseError(msg):
                    Sys.println(msg);
                    
                case JsonUnexpectedError(ex):
                    Sys.println(ex);
            }
        }
        catch (ex:Dynamic)
        {
            Sys.println(ex);
            Sys.println(CallStack.exceptionStack().join("\n"));
        }
        
        Sys.exit(1);
        return null;
    }
    #end
    
    
    /**
     * Wraps Json.stringify.
     * 
     * Encodes given `value` and returns the resulting JSON string.
     * 
     * If `replacer` is given and is not null, it is used to retrieve
     * actual object to be encoded. The `replacer` function two parameters,
     * the key and the value being encoded. Initial key value is an empty string.
     * 
     * If `space` is given and is not null, the result will be pretty-printed.
     * Successive levels will be indented by this string.
     */
    public static inline function stringify(value:Dynamic, ?replacer:Dynamic->Dynamic->Dynamic, ?space:String):String
    {
        return Json.stringify(value, replacer, space);
    }
    
    /**
     * Parses json formatted string. However, unlike Json.parse,
     * this one has the option of allowing javascript comments
     * within the string.
     * 
     * Error messages are also slightly more helpful.
     */
    public static function parse(text:String, allowComments:Bool=false):Dynamic
    {
        try
        {
            var json = Json.parse(allowComments ? stripComments(text) : text);
            return json;
        }
        catch (ex:String)
        {
            // Json parser error messages still produces correct
            // character position of the original file, because
            // instead of removing comments, the comments are
            // actually replaced with spaces, so the positions
            // of all other characters are maintained.
            
            // give helpful error message if json parsing has errors
            if (rx.match(ex))
            {
                var char = String.fromCharCode(Std.parseInt(rx.matched(1)));
                var pos = Std.parseInt(rx.matched(2));
                var line = text.substr(0, pos).split("\n").length;
                var lines = text.split("\n");
                
                var prev = lines.slice(0, line - 1).join("\n") + "\n";
                var text0 = line - 2 >= 0 ? lines[line - 2] : null;
                var text1 = lines[line - 1];
                
                var col = pos - prev.length + 1;
                var arrow = [for (x in 0...col-1) "-"].join("") + "^";
                
                var err:StringBuf = new StringBuf();
                
                err.add('Error while parsing json at line $line, column $col near:\n');
                if (text0 != null) err.add('$text0\n');
                err.add('$text1\n');
                err.add('$arrow\n');
                err.add('Unexpected character $char\n');
                
                throw JsonParseError(err.toString());
            }
            else
            {
                throw JsonUnexpectedError(ex);
            }
        }
        catch (ex:Dynamic)
        {
            throw JsonUnexpectedError(ex);
        }
    }
    
    public static function stripComments(text:String):String
    {
        var sbuf:StringBuf = new StringBuf();
        var inString:Bool = false;
        var inInlineComments:Bool = false;
        var inBlockComments:Bool = false;
        
        var i:Int = 0;
        var n:Int = text.length;
        
        while (i < n)
        {
            var curr:Int = text.fastCodeAt(i);
            var next:Int = (i + 1 < n) ? text.fastCodeAt(i + 1) : -1;
            
            if (inString)
            {
                switch (curr)
                {
                    // end of string
                    case '"'.code:
                        inString = false;
                        sbuf.addChar(curr);
                        
                    // if there's an escape sequence, handle the next char as well
                    case '\\'.code:
                        sbuf.addChar(curr);
                        sbuf.addChar(next);
                        ++i;
                        
                    case _:
                        sbuf.addChar(curr);
                }
            }
            else if (inBlockComments)
            {
                // sequence of */ terminates the block comments
                if (curr == '*'.code && next == '/'.code)
                {
                    inBlockComments = false;
                    sbuf.addChar(space);
                    sbuf.addChar(space);
                    ++i;
                }
                else
                {
                    sbuf.addChar(space);
                }
            }
            else if (inInlineComments)
            {
                // either newline character terminates the inline comments
                if (curr == '\n'.code || curr == '\r'.code)
                {
                    inInlineComments = false;
                }
                
                sbuf.addChar(space);
            }
            else
            {
                switch (curr)
                {
                    // start of string
                    case '"'.code:
                        inString = true;
                        sbuf.addChar(curr);
                        
                    // possibly start of comments
                    case '/'.code:
                        
                        switch (next)
                        {
                            // start of inline comments
                            case '/'.code:
                                inInlineComments = true;
                                sbuf.addChar(space);
                                sbuf.addChar(space);
                                ++i;
                                
                            // start of block comments
                            case '*'.code:
                                inBlockComments = true;
                                sbuf.addChar(space);
                                sbuf.addChar(space);
                                ++i;
                                
                            case _:
                                sbuf.addChar(curr);
                        }
                        
                    case _:
                        sbuf.addChar(curr);
                }
            }
            
            ++i;
        }
        
        return sbuf.toString();
    }
}

enum JsonException
{
    JsonParseError(msg:String);
    JsonUnexpectedError(ex:Dynamic);
}