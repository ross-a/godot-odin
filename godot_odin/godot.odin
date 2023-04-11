package godot_odin

/*
 interface Godot 4.0 using GDExtension from Odin

 - Godot is written in C++, api bindings are C, and anything you can do in GDScript should be "doable" here
 - write stuff in Odin and have fun!
*/


import "core:fmt"
import "core:mem"
import "core:runtime"

@export
gde_interface : ^GDExtensionInterface

@export
library : GDExtensionClassLibraryPtr

@export
token : rawptr

// ------------------------------

// ------------------------------

ModuleInitializationLevel :: enum {
	MODULE_INITIALIZATION_LEVEL_CORE = cast(int)GDExtensionInitializationLevel.GDEXTENSION_INITIALIZATION_CORE,
	MODULE_INITIALIZATION_LEVEL_SERVERS = cast(int)GDExtensionInitializationLevel.GDEXTENSION_INITIALIZATION_SERVERS,
	MODULE_INITIALIZATION_LEVEL_SCENE = cast(int)GDExtensionInitializationLevel.GDEXTENSION_INITIALIZATION_SCENE,
	MODULE_INITIALIZATION_LEVEL_EDITOR = cast(int)GDExtensionInitializationLevel.GDEXTENSION_INITIALIZATION_EDITOR,
};

Callback :: proc(init_obj: ^InitObject, p_level: ModuleInitializationLevel)

InitObject :: struct {
	gde_interface : ^GDExtensionInterface,
	library : GDExtensionClassLibraryPtr,
	initialization : ^GDExtensionInitialization,

	initializer : Callback,
	terminator : Callback,
	minimum_library_initialization_level : ModuleInitializationLevel,

  ta : mem.Tracking_Allocator,

	classdb : map[typeid][2]rawptr,
}

initialize_level :: proc "c" (userdata: rawptr, p_level: GDExtensionInitializationLevel) {
	context = runtime.default_context()
	
	//ClassDB::current_level = p_level;
	init_obj := cast(^InitObject)userdata
	if init_obj.initializer != nil {
		init_obj.initializer(init_obj, cast(ModuleInitializationLevel)p_level)
	}
	//ClassDB::initialize(p_level);
}

deinitialize_level :: proc "c" (userdata: rawptr, p_level: GDExtensionInitializationLevel) {
	context = runtime.default_context()
	
	//ClassDB::current_level = p_level;
	init_obj := cast(^InitObject)userdata
	if init_obj.terminator != nil {
		init_obj.terminator(init_obj, cast(ModuleInitializationLevel)p_level)
	}
	//ClassDB::deinitialize(p_level);
}

init :: proc(init_obj: ^InitObject) -> GDExtensionBool {
	minimum_initialization_level :: GDExtensionInitializationLevel.GDEXTENSION_INITIALIZATION_CORE

	gde_interface = init_obj.gde_interface
	library = init_obj.library
	token = init_obj.library

	init_obj.initialization.userdata = init_obj
	init_obj.initialization.initialize = initialize_level
	init_obj.initialization.deinitialize = deinitialize_level
	init_obj.initialization.minimum_initialization_level = minimum_initialization_level

	//Variant::init_bindings();

	return 1 // true
}
