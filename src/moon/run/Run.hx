package moon.run;

import mcli.CommandLine;
import mcli.Dispatch;
import moon.run.commands.BuildCommand;
import moon.run.commands.DevCommand;
import moon.run.commands.LibCommand;
import moon.run.commands.RunCommand;
import moon.run.commands.SetupCommand;


/**
 * moon-run - command line helper for haxe projects
 * 
 * @author Munir Hussin
 */
class Run extends CommandLine
{
    private var libDir:String;
    private var workDir:String;
    
    public function new(libDir:String, workDir:String)
    {
        super();
        this.libDir = libDir;
        this.workDir = workDir;
    }
    
    
    public function runDefault():Void
    {
        help();
        Sys.exit(0);
    }
    
    /**
     * Builds a haxe project using haxe.json settings.
     */
    public function build(d:Dispatch)
    {
        d.dispatch(new BuildCommand());
    }
    
    /**
     * Runs a haxe project using haxe.json settings.
     */
    public function run(d:Dispatch)
    {
        d.dispatch(new RunCommand());
    }
    
    /**
     * Creates shortcuts so you can type `hx` instead of `haxelib run moon-run`.
     * May need to run with "sudo".
     */
    public function setup(d:Dispatch)
    {
        d.dispatch(new SetupCommand());
    }
    
    /**
     * This is a shortcut to haxelib dev your-project /path/to/yourproject
     */
    public function dev(d:Dispatch)
    {
        d.dispatch(new DevCommand());
    }
    
    /**
     * Generates a haxelib.json from haxe.json.
     * Dependencies are automatically implied based on build options.
     */
    public function lib(d:Dispatch)
    {
        d.dispatch(new LibCommand());
    }
    
    /**
     * Shows help message
     */
    public function help()
    {
        Sys.println(this.showUsage());
        Sys.exit(0);
    }
    
    
    /**
     * Only run this program through haxelib run moon-run
     * and not neko run, or you may get errors due to
     * missing argument. haxelib run will append the current
     * directory as the last argument.
     */
    public static function main():Void
    {
        var args:Array<String> = Sys.args();
        var libDir:String = Sys.getCwd();
        var workDir:String = args.pop();
        
        Sys.setCwd(workDir);
        
        //Sys.println('Lib Dir:  $libDir');
        //Sys.println('Work Dir: $workDir');
        
        /*for (i in 0...args.length)
        {
            Sys.println('arg $i: ${args[i]}');
        }*/
        
        //Sys.exit(0);
        
        new Dispatch(args).dispatch(new Run(libDir, workDir));
    }
}