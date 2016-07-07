package moon.run.commands;

import mcli.CommandLine;
import sys.FileSystem;
import sys.io.File;

/**
 * Usage:
 * 
 *   hx setup [name] [lib] [options]
 * 
 *   name defaults to `hx`
 *   lib defaults to `moon-run`
 * 
 * Examples:
 * 
 *   hx setup             hx  => haxelib run moon-run
 *   hx setup foo         foo => haxelib run moon-run
 *   hx setup foo bar     foo => haxelib run bar
 *   hx setup --remove    removes shortcut instead of creating
 * 
 * Options:
 * @author Munir Hussin
 */
class SetupCommand extends CommandLine
{
    /**
     * Set this to remove instead of creating shortcut
     */
    public var remove:Bool = false;
    
    
    public function runDefault(name:String="hx", lib:String="moon-run"):Void
    {
        if (remove)
            removeShortcut(name, lib);
        else
            createShortcut(name, lib);
    }
    
    @:skip public function createShortcut(name:String, lib:String):Void
    {
        switch (Sys.systemName())
        {
            case "Windows":
                var content = '@haxelib run $lib %*';
                
                try
                {
                    var path = Sys.getEnv("HAXEPATH");
                    
                    if (path == null || path.length == 0)
                    {
                        throw "HAXEPATH environment variable not found.";
                    }
                    
                    File.saveContent('$path/$name.bat', content);
                    Sys.println('Saved script to $path/$name.bat\n`$name` is now redirected to `haxelib run $lib`');
                }
                catch (e:Dynamic)
                {
                    Sys.println('Error: $e');
                    Sys.println("Failed to save to `%HAXEPATH%/$name.bat`.");
                    Sys.println("You can manually add $name.bat to any folder in your PATH");
                    Sys.println('  contents of the file: $content');
                    Sys.exit(1);
                }
                
            default:
                var content = '#!/bin/sh\n\nhaxelib run $lib $@';
                
                try
                {
                    File.saveContent('/usr/bin/$name', content);
                    var exitCode = Sys.command("chmod", '+x /usr/bin/$name'.split(" "));
                    Sys.println('Saved script to /usr/bin/$name to redirect to `haxelib run $lib`');
                    Sys.exit(exitCode);
                }
                catch (e:Dynamic)
                {
                    Sys.println('Failed to save to `/usr/bin/$name`. Perhaps you need to run with `sudo`?');
                    Sys.exit(1);
                }
        }
        
        Sys.exit(0);
    }
    
    @:skip public function removeShortcut(name:String, lib:String):Void
    {
        switch (Sys.systemName())
        {
            case "Windows":
                try
                {
                    var path = Sys.getEnv("HAXEPATH");
                    
                    if (path == null || path.length == 0)
                    {
                        throw "HAXEPATH environment variable not found.";
                    }
                    
                    var script = '$path/$name.bat';
                    
                    if (FileSystem.exists(script) && !FileSystem.isDirectory(script))
                    {
                        FileSystem.deleteFile(script);
                        Sys.println('Deleted script $script');
                    }
                    else
                    {
                        Sys.println('Script $script not found.');
                    }
                }
                catch (e:Dynamic)
                {
                    Sys.println('Error: $e');
                    Sys.println("Failed to delete `%HAXEPATH%/$name.bat`.");
                    Sys.exit(1);
                }
                
            default:
                var content = '#!/bin/sh\n\nhaxelib run $lib $@';
                
                try
                {
                    var script = '/usr/bin/$name';
                    
                    if (FileSystem.exists(script) && !FileSystem.isDirectory(script))
                    {
                        FileSystem.deleteFile(script);
                        Sys.println('Deleted script $script');
                    }
                    else
                    {
                        Sys.println('Script $script not found.');
                    }
                }
                catch (e:Dynamic)
                {
                    Sys.println('Failed to delete `/usr/bin/$name`. Perhaps you need to run with `sudo`?');
                    Sys.exit(1);
                }
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