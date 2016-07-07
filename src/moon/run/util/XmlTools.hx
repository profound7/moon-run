package moon.run.util;

/**
 * XmlTools static extensions for finding/filtering tags.
 * I'm not going to put this in moon-core because it's
 * kind of non-standard. Perhaps if I were to write
 * an xpath version, I might add it to moon-core.
 * 
 * @author Munir Hussin
 */
class XmlTools
{
    /**
     * Returns a list of xml nodes that conforms to the
     * specified path. It's something like xpath, but
     * very simple and basic.
     * 
     * // returns an array of option tags that are within
     * // build tags that are within project tag.
     * 
     * xml.find("project/build/option");
     * 
     * // same as above, but only option tags that
     * // have the mainClass attribute
     * xml.find("project/build/option:mainClass");
     */
    public static function find(xml:Xml, path:String):Array<Xml>
    {
        var names = path.split("/");
        var tmp:Array<Xml> = [xml];
        var result:Array<Xml> = null;
        var i:Int = 0;
        
        for (i in 0...names.length)
        {
            result = [];
            
            while (tmp.length > 0)
            {
                var xml = tmp.pop();
                var nodes = filter(xml, names[i]);
                result = result.concat(nodes);
            }
            
            tmp = result;
            //debug(result);
            //trace("");
        }
        
        //debug(result);
        return result;
    }
    
    /**
     * Finds the first xml node matching the path given, and returns
     * the value of the attribute given.
     * 
     * Usage: doc.findAttr("project/build/option:mainClass")
     */
    public static function findAttr(xml:Xml, path:String):String
    {
        var pos:Int = path.lastIndexOf(":");
        if (pos == -1) throw "No attribute given in the path";
        
        var attrName:String = path.substr(pos + 1);
        var results = find(xml, path);
        
        if (results.length > 0)
        {
            var optNode = results.shift();
            return optNode.get(attrName);
        }
        
        return null;
    }
    
    /**
     * Finds all xml node matching the path given, and returns
     * all the values of the attribute given.
     * 
     * Usage: doc.findAttrs("project/classpaths/class:path")
     */
    public static function findAllAttr(xml:Xml, path:String):Array<String>
    {
        var pos:Int = path.lastIndexOf(":");
        if (pos == -1) throw "No attribute given in the path";
        
        var attrName:String = path.substr(pos + 1);
        var results = find(xml, path);
        var ret:Array<String> = [];
        
        for (node in results)
        {
            ret.push(node.get(attrName));
        }
        
        return ret;
    }
    
    @:noUsing private static function debug(nodes:Array<Xml>):Void
    {
        for (n in nodes)
        {
            trace(n.nodeName);
        }
    }
    
    /**
     * Filters the immediate children of the xml node
     * where the node matches `nodeName`.
     * 
     * // returns all item tags immediately within sales
     * sales.filter("item");
     * 
     * // returns all item tags that has a color attribute
     * sales.filter("item:color");
     * 
     * This is a very simple filter without other xpath-like
     * functionality, which I wrote just to find certain
     * values in FlashDevelop's hxproj file.
     * 
     * I don't think I'll write a more sophisticated or
     * complete one. There's probably a haxelib that already
     * does that.
     */
    public static function filter(xml:Xml, nodeName:String):Array<Xml>
    {
        var nodeAttr:String = null;
        var nodes:Array<Xml> = [];
        
        if (nodeName.indexOf(":") != -1)
        {
            var n = nodeName.split(":");
            nodeName = n[0];
            nodeAttr = n[1];
        }
        
        for (node in xml.elements())
        {
            if (node.nodeName == nodeName)
            {
                if (nodeAttr == null)
                {
                    nodes.push(node);
                }
                else for (attr in node.attributes())
                {
                    if (attr == nodeAttr)
                        nodes.push(node);
                }
            }
        }
        
        return nodes;
    }
}