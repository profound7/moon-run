package moon.run.commands;

import haxe.CallStack;
import haxe.Json;
import haxe.xml.Parser;
import mcli.CommandLine;
import mcli.Decoder;
import moon.run.hxml.HxmlBuilder;
import moon.run.util.JsonTools;
import moon.run.util.Proto;
import sys.io.File;


/**
 * Usage:
 * 
 *   hx build <targets...> [--path jsonfile]
 * 
 *   <targets> is a user-definable key in the build object in the json file.
 *   [jsonfile] is a path to a valid .json file. If omitted, defaults to haxe.json.
 * 
 * Examples:
 * 
 *   hx build neko
 *   This will build using the "neko" entry in haxe.json
 * 
 *   hx build foo bar.json
 *   This will build using the "foo" entry in bar.json
 * 
 * Options:
 * @author Munir Hussin
 */
class BuildCommand extends CommandLine
{
    /**
     * The json settings file. Defaults to haxe.json
     */
    public var file:String = "haxe.json";
    
    /**
     * Don't build. Instead, display the hxml outputs.
     */
    public var debug:Bool = false;
    
    
    public function runDefault(varArgs:Array<String>):Void
    {
        var json:Proto = JsonTools.require(file);
        
        if (json.hasOwnField("build"))
        {
            var obj:Proto = json["build"];
            var builder = new HxmlBuilder(obj, debug);
            
            builder.build([for (a in varArgs) a.toLowerCase()]);
        }
        else
        {
            throw "No build settings found in json file.";
        }
        
        Sys.exit(0);
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
