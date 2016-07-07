# Moon Run

The `moon-run` lib is a command-line utility for building and running Haxe projects.

Like how LESS/SASS provides a nested way to do CSS, `haxe.json` is a nested way to describe `build.hxml` where compiler flags within JSON objects can "inherit" from its parent.

It mainly provides an alternate way of compiling your Haxe projects using settings stored in a `haxe.json` file. It is useful for projects that has to compile to different targets with multiple different settings. You can organize your settings in a **nested** json structure.

It also supports retrieving settings from FlashDevelop's `.hxproj` files. I mainly use this with FlashDevelop (see Using With FlashDevelop section at the bottom).

## Quick Start

### Installation

```bash
haxelib install moon-run
haxelib run moon-run setup              # hx  => haxelib run moon-run
```

After setup, instead of running `haxelib run moon-run whatever`, you can instead use the shorter `hx whatever`. If you don't want the shortcut to be named `hx`, you can specify it like in the example below. You can also create shortcuts for other haxe libs.

```bash
haxelib run moon-run setup foo          # foo => haxelib run moon-run
haxelib run moon-run setup foo bar      # foo => haxelib run bar
haxelib run moon-run setup --remove     # removes instead of creating shortcut
```

### Example Usage

Requires haxe.json. See the sections below on how to use.
```bash
hx --help                               # shows command line help information
hx build foo                            # builds using `foo` configuration
hx build foo --debug                    # prints hxml output instead of building
hx run bar                              # run commands in `bar`
hx dev                                  # haxelib dev $name $path
```

For `hx dev`
- `$name` is implied based on current directory name, or if haxe.json exist, will use the information defined in `meta.name`.
- `$path` is the path of the current directory. 

## Sample haxe.json

Comments in JSON are invalid according to specifications. However, the `moon-run` lib allows comments and these are automatically stripped.

```javascript
{
    // Meta information about the project.
    // This can also be used to generate haxelib.json when pushing to
    // a haxelib repository. No need to add dependencies field here
    // as it can be inferred from the build settings.
    // If dependencies are listed here, then no inferrence is done.
    "meta":
    {
        "name": "my-project",
        "license": "2KILL",
        "tags": ["cross", "utility"],
        "description": "super cool project",
        "contributors": ["somebody"],
        "releasenote": "Update for haxe 3.2",
        "version": "1.0.0",
        "url": "https://github.com/somebody/my-project",
        "classPath": "src/"
        
        // leave out "dependencies" and moon-run will
        // automatically fill it in based on all the -lib
        // arguments in the build section below
    },
    
    // Build settings goes here.
    "build":
    {
        // These are the common settings that will be inherited
        // in all sub-settings.
        "-main": "Test",
        "-cp": ["src", "test"],
        "-lib": ["tink_core"],
        "-v": false,
        
        // This is a group of settings
        "release":
        {
            "-D": "hey"
        },
        
        "debug":
        {
            "-D": "yo"
        },
        
        // build with:
        // hx build js
        "js":
        {
            // This will override the parent -main setting.
            "-main": "Foo",
            
            // This will concatenate with the parent -lib resulting
            // in ["tink_core", "nodejs", "expressjs"].
            "-lib": ["nodejs", "expressjs"],
            "-js": "bin/foo.js"
        },
        
        // hx build neko
        "neko":
        {
            // This turns into a -main and the value is retrieved
            // from myfile.hxproj.
            "@hxproj-main": "run.hxproj",
            
            // Paths can have spaces, no problem.
            "-neko": "foo/bar baz/hey.n"
        },
        
        // hx build html
        "html":
        {
            // When multiple targets are listed together, args
            // --each and --next will be generated accordingly.
            "-js": "bin/html/app.js",
            "-as3": "bin/html/app_a.swf",
            
            // nested config. build with:
            // hx build html/as3
            "as3":
            {
                // This overrides the parent's -as3
                "-as3": "bin/html/app_c.swf",
                "-D": "abc"
            }
        },
        
        // hx build as3
        "as3":
        {
            "-as3": "bin/html/app_b.swf",
            "-D": "hi"
        },
        
        // hx build whatever
        "whatever":
        {
            "-js": "bin/js/app.js",
            
            // merges the settings in "release" and "debug"
            // into this current object
            "@merge": ["release", "debug"]
        },
        
        // used by run example below
        "hello":
        {
            "-main": "Foo",
            "-neko": "foo/bar baz/hello.n"
        },
        
        // hx build foo
        //   same as consecutive commands:
        //     hx build as3
        //     hx build whatever
        //   or in a single line:
        //     hx build as3 whatever
        //   and is also equivalent to:
        //     "foo": { "@multi": ["as3", "whatever"] }
        "foo": ["as3", "whatever"]
    },
    
    // Run settings goes here.
    "run":
    {
        // hx run message
        "message": "This is a string",
        
        // hx run greet something
        "greet":
        [
            // [0] is the first argument passed to the greet function
            ["println", "hello", [0], "!"],
            ["println", ["message"]]
        ],
        
        // hx run main
        // or simply, hx run
        "main":
        [
            ["hx", "build", "hello"],
            ["cd", "foo", "bar baz"],
            ["neko", "hello", "how", "are you"],
            ["greet", "world"]
        ]
    }
}
```

### Build Examples
The following examples are based on haxe.json above.

`hx build` generates the following hxml and runs it through haxe:
```
-main Test
-cp src
-cp test
-lib tink_core
```

----------

`hx build html` generates the following hxml and runs it through haxe:
```
-main Test
-cp src
-cp test
-lib tink_core
--each
-js bin/html/app.js
--next
-as3 bin/html/app_a.swf
```

----------

`hx build html as3` generates 2 hxml files and runs each of them through haxe:
```
-main Test
-cp src
-cp test
-lib tink_core
--each
-js bin/html/app.js
--next
-as3 bin/html/app_a.swf
```
```
-main Test
-cp src
-cp test
-lib tink_core
-D hi
-as3 bin/html/app_b.swf
```

----------

`hx build html/as3` builds the `as3` config within `html`, and not the other `as3` config within root of build config:
```
-main Test
-cp src
-cp test
-lib tink_core
-D abc
--each
-js bin/html/app.js
--next
-as3 bin/html/app_c.swf
```

----------

`hx build whatever` generates:
```
-main Test
-cp src
-cp test
-lib tink_core
-D hey
-D yo
-js bin/js/app.js
```

----------

`hx build foo` builds `as3` and `whatever` separately, and generates:
```
-main Test
-cp src
-cp test
-lib tink_core
-D hi
-as3 bin/html/app_b.swf
```
```
-main Test
-cp src
-cp test
-lib tink_core
-D hey
-D yo
-js bin/js/app.js
```


### Run Examples
The following examples are based on haxe.json above.

`hx run main`
```
Building... ok
Build completed with 1 successes and 0 failures.
Changed current directory to: C:\Path\To\MyProject\foo\bar baz/
Foo is running! The args are: [how,are you]
bye!
hello world !
This is a string
```

TODO: More examples.

## Build Argument Documentation

### Argument Types

There are 3 types of arguments in haxe compiler:
1. singular-type: arg/value pair that can only appear once (-main, -dce, etc...)
2. multi-type: arg/value pairs that can appear more than once (-lib, -D, etc...)
3. bool-type: arg flag that doesn't need a value (-debug, -v, etc...)

Singular-types are represented in JSON as `"-arg": "value"`.

Multi-types are represented in JSON as `"-arg": ["value1", "value2", ...]`. If an argument is a known multi-type, you can also write it as a string, e.g. `"-arg": "value"`. This lib will detect those and automatically wrap them in an Array.

Bool-types are represented in JSON as a Bool, e.g. `"-arg": true`. Valid values are `true` or `false`. If it is a known bool-type, any *truthy* value can be used, which will be coerced into a Bool. Truthy values includes the String "true", "false", "yes", and integers. If Int is given, 0 is false, everything else is true. Null is false. If an object or array is there where a truthy is expected, an exception will be thrown.

### Nested Build Settings

Build settings can be nested! Settings of a child-object inherits from all its parent-objects, all the way to the root build object.

Settings in a child-object will shadow its parent's settings if the argument is a single-type or bool-type, and will concatenate with its parent's settings if the argument is a multi-type.

If you want a multi-type value to shadow instead of concatenate, put a `null` as the first item in the array.

### Field Prefix

Fields that starts with `-` are Haxe's command line arguments.
Fields that starts with `@` are hx's special commands.
All other fields represents a group of settings.

List of special commands:
- `@merge: ["group1", "group2"]`  
  Merges all the settings from group1 object and group2 object into current
  object. This will replace or concatenate the values of current object when the
  field names match.
- `@multi: [{...}, {...}, ...]`  
  Builds each object in the array separately. If you have a
  `"groupX": ["groupA", "groupB"]`, and you build with `hx build groupX`, it
  will automatically transform into a multi command, and is the same as running
  `hx build groupA` followed by `hx build groupB`.
- `@hxproj-main: "myfile.hxproj"`  
  This will transform into a `-main` argument. It opens `myfile.hxproj` and read
  the `mainClass` setting for its value. I sometimes switch main class often
  from within FlashDevelop to test and run different classes, but I require
  custom build settings. So this comes in handy.
- `@hxproj: "myfile.hxproj"` (not implemented yet)  
  This is intended to read all the settings from `myfile.hxproj` and infer all
  the arguments. This might be useful to those using FlashDevelop as their Haxe
  IDE and wants to export their settings into a hxml file.

## Run Argument Documentation

Some projects may have a number of bash/batch scripts to run some common tasks. For most of my projects, it's simply to run the compiled program from the bin directory.

You can add those commands within the JSON file as `["command", "arg1", "arg2", ...]`. This lib will run them as `Sys.command()` calls.

Since they look like S-expressions, I couldn't resist and implemented a little simplified Lisp out of the JSON array syntax.

- All literals except arrays evaluates as themselves.
- Arrays become function calls. `env` is the current environment/scope.
  If `env` does not have variable `foo`, then do a Sys.command instead.
- You can override function definitions with your own definitions.
- If there's a conflict between user-defined function name, and a system call,
  you can prefix with a `#` to force a system call.
- User-defined functions are case-insensitive, by turning it to lowercase.

JSON                    |    Haxe
------------------------|------------
5                       | 5
true                    | true
"foo"                   | "foo"
{ "key": "value" }      | { "key": "value" }
["foo"]                 | env.foo() or Sys.command("foo")
["FoO"]                 | env.foo() or Sys.command("foo")
["foo", "bar", "baz"]   | env.foo("bar", "baz") or Sys.command("foo", ["bar", "baz"])
["array", "foo", "bar"] | ["foo", "bar"]
["&foo"]                | env["foo"]
["#foo", "bar"]         | Sys.command("foo", ["bar"])
[">foo", "bar"]         | new Process("foo", ["bar"])

Currently, you can't do much with Process. This will be updated in future versions.

List of implemented functions:
`begin`, `var`, `set`, `if`, `lambda`, `define`, `print`, `println`, `globals`,
`field`, `index`, `array`, `==`, `!=`, `<`, `>`, `<=`, `>=`, `&&`, `||`, `!`, `+`, `-`, `*`, `/`, `%`

## Using With FlashDevelop

### Basic Usage

1. Create `haxe.json` with the build and run settings for the desired platforms.
2. Set `Project > Properties... > Build > Pre-Build Command Line` to
   `haxelib run moon-run build "$(TargetPlatform)"`
3. Set `Project > Properties... > Output > Test Project` to run custom command
   `hx run "$(TargetPlatform)" --pause`

The `--pause` argument prevents the command prompt window from immediately
closing after your program has ended.

I'm not sure why, but `Pre-Build Command Line` does not seem to detect `hx`, but
`haxelib` works fine, even though they're on the same directory.

### Advanced Usage

By nesting your configs appropriately, your build command can be something like
`haxelib run moon-run build "$(TargetPlatform)/$(BuildConfig)"` or (TODO) merge them using
`haxelib run moon-run build "$(TargetPlatform)+$(BuildConfig)"`

## Contributions

Feel free to contribute.

## License

MIT