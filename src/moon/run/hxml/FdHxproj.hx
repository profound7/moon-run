package moon.run.hxml;

import haxe.xml.Parser;
import sys.io.File;

using moon.run.util.XmlTools;

/**
 * Used to retrieve the value of the mainClass
 * defined in a flash develop .hxproj file
 * 
 * @author Munir Hussin
 */
class FdHxproj
{
    public var file:String;
    public var doc:Xml;
    
    public function new(file:String)
    {
        this.file = file;
        
        try
        {
            var data = File.getContent(file);
            this.doc = Parser.parse(data);
        }
        catch (ex:Dynamic)
        {
            Sys.println(ex);
        }
    }
    
    public static function open(file:String):FdHxproj
    {
        return new FdHxproj(file);
    }
    
    public function getMainClass():String
    {
        return doc.findAttr("project/build/option:mainClass");
    }
    
    public function getOutputPath():String
    {
        return doc.findAttr("project/output/movie:path");
    }
    
    public function getOutputPlatform():String
    {
        return doc.findAttr("project/output/movie:platform");
    }
    
    public function getClassPaths():Array<String>
    {
        return doc.findAllAttr("project/classpaths/class:path");
    }
    
    public function getHaxeLibs():Array<String>
    {
        return doc.findAllAttr("project/haxelib/library:name");
    }
}