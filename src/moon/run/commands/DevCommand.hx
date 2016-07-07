package moon.run.commands;

import mcli.CommandLine;
import moon.run.util.JsonTools;
import moon.run.util.Proto;
import sys.FileSystem;
import sys.io.File;

using StringTools;
using moon.run.util.CastTools;

/**
 * Usage:
 * 
 *   hx dev
 * 
 * Creates a haxelib dev based on current directory.
 * Library name is inferred on current directory name.
 * 
 * If you are in: /path/to/myproj/
 * And you run:   hx dev
 * It will run:   haxelib dev myproj /path/to/myproj/
 * 
 * If there is a haxe.json file, the library name will
 * be retrieved from meta.name instead.
 * 
 * Examples:
 * 
 *   hx dev
 *   hx dev --remove
 * 
 * Options:
 * @author Munir Hussin
 */
class DevCommand extends CommandLine
{
    /**
     * Set this to remove instead of creating shortcut
     */
    public var remove:Bool = false;
    
    /**
     * The json settings file. Defaults to haxe.json
     */
    public var file:String = "haxe.json";
    
    
    public function runDefault():Void
    {
        try
        {
            var json:Proto = JsonTools.load(file);
            
            if (json.hasOwnField("meta"))
            {
                var obj:Proto = json["meta"];
                var name:String = obj.getOwnField("name").expectString();
                var path:String = Sys.getCwd();
                dev(name, path);
            }
            else
            {
                throw "No build settings found in json file.";
            }
        }
        catch (ex:Dynamic)
        {
            var path:String = Sys.getCwd();
            var name:String = inferName();
            dev(name, path);
        }
        
        Sys.exit(0);
    }
    
    @:skip public function inferName():String
    {
        var cwd:String = Sys.getCwd().replace("\\", "/");
        if (cwd.charAt(cwd.length - 1) == "/")
            cwd = cwd.substr(0, cwd.length - 1);
        return cwd.split("/").pop();
    }
    
    @:skip public function dev(name:String, ?path:String):Void
    {
        if (remove || path == null)
            Sys.command("haxelib", ["dev", name]);
        else
            Sys.command("haxelib", ["dev", name, path]);
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