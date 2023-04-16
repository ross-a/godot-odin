# godot-odin

> **Warning**
>
> This should be consider very experimental.
> This repository's `master` branch is only usable with Godot's ([GDExtension](https://godotengine.org/article/introducing-gd-extensions))
> API (Godot 4.0 and later).
>

This repository contains the  *Odin bindings* for the [**Godot Engine**](https://github.com/godotengine/godot)'s GDExtensions API.

- [**Compatibility**](#compatibility)
- [**Getting started**](#getting-started)
- [**Included example**](#included-example)

## Compatibility

**Warning:** The GDExtension API is brand new in Godot 4.0, and is still
considered in **beta** stage, despite Godot 4.0 itself being released.

This applies to both the GDExtension interface header, the API JSON, and this
first-party `godot-odin` extension.

## Getting started

Compiling this repository generates a static library to be linked with your shared lib.

To use the shared lib in your Godot project you'll need a `.gdextension`
file, which replaces what was the `.gdnlib` before.
Follow [the example](test/demo/example.gdextension):

```ini
[configuration]

entry_symbol = "example_library_init"

[libraries]

macos.debug = "bin/libgdexample.macos.debug.framework"
macos.release = "bin/libgdexample.macos.release.framework"
windows.debug.x86_64 = "bin/libgdexample.windows.debug.x86_64.dll"
windows.release.x86_64 = "bin/libgdexample.windows.release.x86_64.dll"
linux.debug.x86_64 = "bin/libgdexample.linux.debug.x86_64.so"
linux.release.x86_64 = "bin/libgdexample.linux.release.x86_64.so"
# Repeat for other architectures to support arm64, rv64, etc.
```

The `entry_symbol` is the name of the function that initializes
your library. It should be similar to following layout:

```odin
@export
// Initialization.
example_library_init :: proc "c" (p_interface: ^gd.GDExtensionInterface, p_library: gd.GDExtensionClassLibraryPtr, r_initialization: ^gd.GDExtensionInitialization) -> gd.GDExtensionBool {
  context = runtime.default_context()
  
  init_obj := new(gd.InitObject)
  init_obj.gde_interface = p_interface
  init_obj.library = p_library
  init_obj.initialization = r_initialization
  init_obj.initializer = initialize_example_module
  init_obj.terminator = uninitialize_example_module
  init_obj.minimum_library_initialization_level = gd.ModuleInitializationLevel.MODULE_INITIALIZATION_LEVEL_SCENE
  
  return gd.init(init_obj)
}
```

The `initialize_example_module()` should register the classes in ClassDB, very like a Godot module would do.

```odin
initialize_example_module :: proc(init_obj: ^gd.InitObject, p_level: gd.ModuleInitializationLevel) {
  context = runtime.default_context()

  if p_level != .MODULE_INITIALIZATION_LEVEL_SCENE {
    return
  }

  // ### auto-generated register_class is put here
  // *** end place to register classes
}
```

Also note that something like: `gdc.make_class_file(string(#file), []typeid{ExampleMin, ExampleRef, Example})` should be called, to auto-generate and register odin "classes"

And run: `odin run binding-generator.odin -file` in `bindgen` directory atleast once before hand.


## Included example

Check the project in the `demo` folder for an example on how to use and register different things.
