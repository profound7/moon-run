package moon.run.commands;

import haxe.CallStack;
import mcli.CommandLine;
import moon.run.hxml.HxmlBuilder;
import moon.run.util.JsonTools;
import moon.run.util.Proto;
import sys.FileSystem;
import sys.io.File;

/**
 * Usage:
 * 
 *   hx lib
 * 
 * Generates haxelib.json
 * 
 * Options:
 * @author Munir Hussin
 */
class LibCommand extends CommandLine
{
    /**
     * The json settings file. Defaults to haxe.json
     */
    public var file:String = "haxe.json";
    
    /**
     * The output json file. Defaults to haxelib.json
     */
    public var out:String = "haxelib.json";
    
    public function runDefault():Void
    {
        var json:Proto = JsonTools.require(file);
        
        if (json.hasOwnField("build") && json.hasOwnField("meta"))
        {
            var build:Proto = json["build"];
            var libs:Array<Dynamic> = build.collect("-lib", true);
            var meta:Proto = json["meta"];
            
            // only infer dependencies if you leave that field out
            if (!meta.hasOwnField("dependencies"))
            {
                var dependencies:Proto = { };
                
                for (lib in libs)
                {
                    var libInfo = Std.string(lib).split(":");
                    var libName = libInfo[0];
                    var libVer = libInfo.length >= 2 ? libInfo[1] : "";
                    dependencies[libName] = libVer;
                }
                
                meta["dependencies"] = dependencies;
            }
            
            File.saveContent(out, JsonTools.stringify(meta, null, "    "));
            Sys.println('$out file successfully created.');
        }
        else
        {
            throw "Both build and meta sections are required in json file.";
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