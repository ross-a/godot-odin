//-*- compile-command: "./build.sh" -*-

package example

import "core:os"
import "core:fmt"
import "core:mem"
import "core:slice"
import "core:strings"
import "core:strconv"
import "core:reflect"
import "core:runtime"
import "core:testing"
import "core:intrinsics"

import gd "godot_odin"
import gdc "godot_odin/core"
import godot "godot_odin/bindgen/gen"

import "godot_odin/bindgen/gen/variant"
import gstring "godot_odin/bindgen/gen/string"
import "godot_odin/bindgen/gen/string_name"
import "godot_odin/bindgen/gen/utility_functions"
import "godot_odin/bindgen/gen/viewport"
import "godot_odin/bindgen/gen/ref_counted"
import "godot_odin/bindgen/gen/object"
import "godot_odin/bindgen/gen/vector2"
import "godot_odin/bindgen/gen/vector4"
import "godot_odin/bindgen/gen/array"
import "godot_odin/bindgen/gen/dictionary"
import "godot_odin/bindgen/gen/packed_int32_array"
import "godot_odin/bindgen/gen/callable"
import "godot_odin/bindgen/gen/node"
import "godot_odin/bindgen/gen/node_path"
import "godot_odin/bindgen/gen/label"

@test
make_into_class_file :: proc(t: ^testing.T) {
	// turn this file into a "fake" _class.odin file
  gdc.make_class_file(string(#file), []typeid{ExampleMin, ExampleRef, Example})
}
clean_up :: proc(ptr: rawptr = nil) {
	// for passing gdscript a pointer to something, then we can clean it up later
	@static ptrs : [dynamic]rawptr
	if ptr == nil {
		for p in ptrs {
			free(p)
		}
		delete(ptrs)
		return
	}
	append(&ptrs, ptr)
}

// structs and procs to turn into "fake" classes for Godot ------------------------------
ExampleMin :: struct {
	using _ : godot.Control,
}

ExampleRef :: struct {
	using _ : godot.RefCounted,
	id : int,
	get_id : proc() -> int,
}
ExampleRef_get_id :: proc() -> int {
	inst := cast(^ExampleRef)context.user_ptr
	return inst.id
}

Example :: struct {
	// parent
	using _ : godot.Control,

	// properties
  property_from_list : godot.Vector3 `property`,
	custom_position : godot.Vector2,
  dprop : [3]godot.Vector2 `property`,

	// static procs
	test_static : proc(p_a: int, p_b: int) -> int `static`,
	test_static2 : proc() `static`,

	// procs
	simple_func : proc(),
  simple_const_func : proc(),
  return_something : proc(base: ^godot.String) -> ^godot.String,
	return_something_const : proc() -> ^godot.Viewport,
	return_empty_ref : proc() -> ^ExampleRef,
	return_extended_ref : proc() -> ^ExampleRef,
	get_v4 : proc() -> ^godot.Vector4,
	test_node_argument : proc(p_node: ^Example) -> ^Example,
	extended_ref_checks : proc(p_ref: ^ExampleRef) -> ^ExampleRef,
	varargs_func : proc(args: ..any) -> ^godot.Variant,
	varargs_func_nv : proc(args: ..any) -> int,
	varargs_func_void : proc(args: ..any),
  def_args : proc(p_a: int, p_b: int) -> int,
	test_array : proc() -> ^godot.Array,
	test_tarray : proc() -> ^godot.Array,
	test_dictionary : proc() -> ^godot.Dictionary,
	test_tarray_arg : proc(p_array: ^godot.Array),
	test_string_ops : proc() -> ^godot.String,
	test_vector_ops : proc() -> int,
	
	// TODO: make bit_sets work without "; u8" size defining part (odin picks smallest size needed, automagically use that)
	test_bitfield : proc(flags: bit_set[Flags; u8]) -> bit_set[Flags; u8],

	// signal
	emit_custom_signal : proc(name: ^godot.String, value: int) `signal:"custom_signal"`,

	// property set/get
	set_custom_position : proc(pos: ^godot.Vector2),
	get_custom_position : proc() -> ^godot.Vector2,

	// virtual proc
	_has_point : proc(point: ^godot.Vector2) -> bool `virtual`,
}

// enums that will be included in the "class" with Example_init()
Constants :: enum {
	FIRST,
	ANSWER_TO_EVERYTHING = 42,
}
Flags :: enum {
	FLAG_ONE = 1,
	FLAG_TWO = 2,
}

Example_init :: proc(init_obj: ^gd.InitObject) {
	// any special properties and constants can be defined here
	// or anything that should happen after "class" registration
  gdc.add_group(init_obj.library, Example, "Group Name", "group_")
  gdc.add_subgroup(init_obj.library, Example, "Sub-Group Name", "group_subgroup_")
	
	info := new(gd.GDExtensionPropertyInfo) // TODO some sort of helper here
	info.type = gd.GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VECTOR2
	info.name = cast(gd.GDExtensionStringNamePtr)gdc.string_to_string_name("group_subgroup_custom_position")
	info.class_name = cast(gd.GDExtensionStringNamePtr)gdc.string_to_string_name("Example")
	info.hint = cast(u32)godot.PropertyHint.PROPERTY_HINT_NONE
	info.hint_string = cast(gd.GDExtensionStringPtr)gdc.string_to_string("")
	info.usage = cast(u32)(godot.PropertyUsageFlags.PROPERTY_USAGE_DEFAULT | godot.PropertyUsageFlags.PROPERTY_USAGE_NIL_IS_VARIANT)
	gdc.add_property(init_obj.library, Example, info, "set_custom_position", "get_custom_position") // add a property without `property` tag in struct
	free(info.name)
	free(info.class_name)
	free(info.hint_string)
	free(info)
	
	gdc.add_consts(init_obj.library, Example, Constants)
	gdc.add_const(init_obj.library, Example, nil, "CONSTANT_WITHOUT_ENUM", 314)
	gdc.add_consts(init_obj.library, Example, Flags)
}

Example_test_static :: proc(p_a: int, p_b: int) -> int {
	return p_a + p_b
}
Example_test_static2 :: proc() {
	utility_functions.print("  test_static2", " -odin ", 123)
}
Example_simple_func :: proc() {
	utility_functions.print("  Simple func called.")
}
Example_simple_const_func :: proc() {
	utility_functions.print("  Simple const func called.")
}
Example_return_something :: proc(base: ^godot.String) -> ^godot.String {
	utility_functions.print("  Return something called.")
	return base
}
Example_return_something_const :: proc() -> ^godot.Viewport {
	utility_functions.print("  Return something const called.")
	if node.is_inside_tree() {
		result := node.get_viewport(); clean_up(result)
		return result
	}
	return nil
}
Example_return_empty_ref :: proc() -> ^ExampleRef {
	r : ^ExampleRef = nil
	return r
}
Example_return_extended_ref :: proc() -> ^ExampleRef {
	userdata := gdc.make_class_user_data(ExampleRef)
	inst : ^ExampleRef

	// example of calling procs or using data that is only defined after rewriting / making_class_file
	//+owner := cast(^ExampleRef)ExampleRef_new(userdata)
	//+inst = cast(^ExampleRef)gdc.get_inst_from_owner(owner)
	
	inst.id = 1 // no static member variables like example.h/cpp
	return inst
}
Example_get_v4 :: proc() -> ^godot.Vector4 {
	v4 := new(godot.Vector4); clean_up(v4)
	vector4.constructor(v4, 1.2, 3.4, 5.6, 7.8)
	return v4
}
Example_test_node_argument :: proc(p_node: ^Example) -> ^Example {
	context.user_ptr = p_node
	str := "nil"
	if p_node != nil {
		str = fmt.tprintf("%d", object.get_instance_id())
  }
	
	utility_functions.print("  Test node argument called with ", str)
	return p_node
}
Example_extended_ref_checks :: proc(p_ref: ^ExampleRef) -> ^ExampleRef {
	userdata := gdc.make_class_user_data(ExampleRef)
	ref : ^ExampleRef

	//+owner := cast(^ExampleRef)ExampleRef_new(userdata)
	//+ref = cast(^ExampleRef)gdc.get_inst_from_owner(owner)

	context.user_ptr = p_ref
	p_ref_id := object.get_instance_id()
	context.user_ptr = ref
	ref_id := object.get_instance_id()
	utility_functions.print("  Example ref checks called with value: ", p_ref_id, ", returning value: ", ref_id);	

	return ref
}
Example_varargs_func :: proc(args: ..any) -> ^godot.Variant {
	str_args := fmt.tprint(args)
	utility_functions.print("  Varargs (Variant return) called with ", str_args, " arguments")
	ret := new(godot.Variant); clean_up(ret)
	variant.constructor(ret, len(args))
	return ret
}
Example_varargs_func_nv :: proc(args: ..any) -> int {
	str_args := fmt.tprint(args)
	utility_functions.print("  Varargs (int return) called with ", str_args, " arguments")
	return 42
}
Example_varargs_func_void :: proc(args: ..any) {
	str_args := fmt.tprint(..args)
	utility_functions.print("  Varargs (no return) called with ", str_args, " arguments")
}
Example_def_args :: proc(p_a: int = 100, p_b: int = 200) -> int {
	return p_a + p_b
}
Example_test_array :: proc() -> ^godot.Array {
	arr := new(godot.Array); clean_up(arr)
	array.constructor(arr)
	
	array.resize(arr, 2)
	one := new(godot.Variant); defer free(one)
	two := new(godot.Variant); defer free(two)
	variant.constructor(one, i32(1))
	variant.constructor(two, i32(2))
	
	array.set_idx(arr, 0, one)
	array.set_idx(arr, 1, two)
	
	return arr
}
Example_test_tarray :: proc() -> ^godot.Array {
	arr := new(godot.Array); clean_up(arr)
	array.constructor(arr)

	empty_str := cast(gd.GDExtensionConstStringNamePtr)new(godot.StringName); defer free(empty_str)
	array.set_typed(arr, gd.GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VECTOR2, empty_str)
	
	array.resize(arr, 2)
	one := new(godot.Variant); clean_up(one)
	two := new(godot.Variant); clean_up(two)
	vone := new(godot.Vector2); defer free(vone)
	vtwo := new(godot.Vector2); defer free(vtwo)
	vector2.constructor(vone, 1, 2)
	vector2.constructor(vtwo, 2, 3)	
	variant.constructor(one, vone)
	variant.constructor(two, vtwo)

	array.set_idx(arr, 0, one)
	array.set_idx(arr, 1, two)
	
	return arr
}
Example_test_dictionary :: proc() -> ^godot.Dictionary {
	dict := new(godot.Dictionary); clean_up(dict)
	dictionary.constructor(dict)

	dictionary.set_key(dict, "hello", "world")
	dictionary.set_key(dict, "foo", "bar")
	
	return dict
}
Example_test_tarray_arg :: proc(p_array: ^godot.Array) {
	for i := 0; i < array.size(p_array); i+=1 {
		val : int
		variant.to_type(array.get_idx(p_array, i), &val)
		utility_functions.print(val)
	}
}
Example_test_string_ops :: proc() -> ^godot.String {
	using gstring
	
	s := new(godot.String); defer free(s)
	constructor(s, "A")
	r_str := new(godot.String); defer free(r_str)
	constructor(r_str, "B")
	s1 := OP_ADD(s, r_str); defer free(s1)
	constructor(r_str, "C")
	s2 := OP_ADD(s1, r_str); defer free(s2)
	constructor(r_str, fmt.tprintf("%c", 0x010E))
	s3 := OP_ADD(s2, r_str); defer free(s3)
	constructor(r_str, "E")
	s4 := OP_ADD(s3, r_str); clean_up(s4)
	return s4
}
Example_test_vector_ops :: proc() -> int {
	using packed_int32_array
	arr := new(godot.PackedInt32Array); defer free(arr)
	constructor(arr)

	ret : i32 = 0
	push_back(arr, 10)
	push_back(arr, 20)
	push_back(arr, 30)
	push_back(arr, 45)

	for i:=0; i<size(arr); i+=1 {
		ret += get_idx(arr, i)^
	}
	return cast(int)ret
}
Example_test_bitfield :: proc(flags: bit_set[Flags; u8]) -> bit_set[Flags; u8] {
	f := new(godot.String); defer free(f)
	// odin bit_sets wrap all possible values (including zero!)
	// it can be confusing, but nil/{}/empty_set == 0, and yet
	// bit_set of Flags is { 0, FLAG_ONE, FLAG_TWO } so 3 bits are used... and FLAG_ONE is *not* first bit, 0 is

	// it's most likely best to use no equal something (ex: = 1) in enums if you are making them into bit_sets
	real_flags := (transmute(bit_set[Flags; u8]) ((transmute(u8)flags)<<1))
	
	gstring.constructor(f, fmt.tprint(real_flags))
	utility_functions.print("  Got BitField: ", f)
	return flags;
}

Example_emit_custom_signal :: proc(name: ^godot.String, value: int) {
	signal_name := new(godot.StringName)
	string_name.constructor(signal_name, "custom_signal")
	object.emit_signal(signal_name, name, value)
}

Example_set_custom_position :: proc(pos: ^godot.Vector2) {
	inst := cast(^Example)context.user_ptr
	inst.custom_position = pos^
}
Example_get_custom_position :: proc() -> ^godot.Vector2 {
	inst := cast(^Example)context.user_ptr
	return &inst.custom_position
}

Example__has_point :: proc(point: ^godot.Vector2) -> bool {
	inst := cast(^Example)context.user_ptr
	lbl := new(godot.String); defer free(lbl)
	gstring.constructor(lbl, "Label")
	np := new(godot.NodePath); defer free(np)
	node_path.constructor(np, lbl)
	if node.has_node(np) {
		label_node := node.get_node_internal(np); defer free(label_node)

		new_text := gdc.string_to_string("Got point: %s"); defer free(new_text)
		new_new_text := gstring.OP_MODULE(new_text, point); defer free(new_new_text)

		context.user_ptr = label_node
		label.set_text(new_new_text)
	}
	return false
}


// --------------------------------------------------------------------------------------

initialize_example_module :: proc(init_obj: ^gd.InitObject, p_level: gd.ModuleInitializationLevel) {
	context = runtime.default_context()

	if p_level != .MODULE_INITIALIZATION_LEVEL_SCENE {
		return
	}

  init_obj.ta = mem.Tracking_Allocator{}
  mem.tracking_allocator_init(&init_obj.ta, context.allocator)
  context.allocator = mem.tracking_allocator(&init_obj.ta)
	
	// ### auto-generated register_class is put here
	// *** end place to register classes
}

uninitialize_example_module :: proc(init_obj: ^gd.InitObject, p_level: gd.ModuleInitializationLevel) {
	context = runtime.default_context()	
	context.allocator = mem.tracking_allocator(&init_obj.ta)

	if p_level != .MODULE_INITIALIZATION_LEVEL_SCENE {
		return;
	}

	// ### auto-generated unregister_class is put here
	// *** end place to unregister classes
	clean_up()
	
  if len(init_obj.ta.allocation_map) > 0 {
    for _, v in init_obj.ta.allocation_map {
      fmt.printf("Leaked %v bytes @ %v\n", v.size, v.location)
    }
  }
  if len(init_obj.ta.bad_free_array) > 0 {
    fmt.println("Bad frees:")
    for v in init_obj.ta.bad_free_array {
      fmt.println(v)
    }
  }
	
}

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

	//fmt.println("***", init_obj.gde_interface.version_string, "***")

	return gd.init(init_obj)
}

