package gdc // core

import "core:os"
import "core:fmt"
import "core:slice"
import "core:strings"
import "core:reflect"
import "core:runtime"
import "core:unicode"
import gd "../../godot_odin"
import godot "../../godot_odin/bindgen/gen"

import gstring "../bindgen/gen/string"
import "../bindgen/gen/string_name"
import "../bindgen/gen/variant"
import "../bindgen/gen/utility_functions"
import "../bindgen/gen/ref_counted"

/*
 note: run make_class_file() on some file you want to "classerize" then build .dll/.so with that _class.odin file
*/

get_init_obj :: proc(init_obj: ^gd.InitObject = nil) -> ^gd.InitObject {
	@static ptr : ^gd.InitObject
	if init_obj != nil {
		ptr = init_obj
	}
	return ptr
}

ClassUserData :: struct {
	class_type : typeid,
	parent_type : typeid,
	class_string_name : ^godot.StringName,
	parent_string_name : ^godot.StringName,

	db : ^map[rawptr]typeid, // instance ptr to typeid
}

get_db :: proc() -> ^map[rawptr]typeid {
	@static db : ^map[rawptr]typeid
	if db == nil {
		db = new(map[rawptr]typeid)  // class instance ptr -> typeid map
	}
	return db
}

get_signals :: proc() -> ^map[string]bool {
	@static sigs : ^map[string]bool
	if sigs == nil {
		sigs = new(map[string]bool)
	}
	return sigs
}

get_callables :: proc() -> ^[dynamic]^godot.Callable {
	@static callables : ^[dynamic]^godot.Callable
	if callables == nil {
		callables = new([dynamic]^godot.Callable)
	}
	return callables
}

get_vtable :: proc() -> ^map[string]gd.GDExtensionClassCallVirtual {
	@static vtbl : ^map[string]gd.GDExtensionClassCallVirtual
	if vtbl == nil {
		vtbl = new(map[string]gd.GDExtensionClassCallVirtual)
	}
	return vtbl
}

get_inst_from_owner :: proc(owner: rawptr) -> rawptr {
	db := get_db()
	for k, _ in db {
		if (cast(^godot.Object)k)._owner == owner do return k
	}
	return nil
}

make_class_user_data :: proc(T: typeid, cleanup: bool = false) -> ^ClassUserData {
	@static class_map : map[typeid]^ClassUserData

	if cleanup {
		delete(class_map)
		return nil
	}
	
	names := reflect.struct_field_names(T)
	types := reflect.struct_field_types(T)

	idx := 0
	for ; idx < len(names); idx+=1 {
		sf : reflect.Struct_Field = reflect.struct_field_by_name(T, names[idx])
		if names[idx] == "_" && sf.is_using == true {
			break // pick first unnamed field ("_") as parent "class"
		}
	}
	parent_type := idx < len(names) ? fmt.tprintf("%s", types[idx]) : ""

	if !(T in class_map) {
		class_types := new(ClassUserData) // free'd after unregister
		class_types.class_type = T
		class_types.parent_type = types[idx].id
		class_types.class_string_name = new(godot.StringName)
		class_types.parent_string_name = new(godot.StringName)	
		string_name.constructor(class_types.class_string_name, fmt.tprintf("%s", T))
		string_name.constructor(class_types.parent_string_name, parent_type)
		class_types.db = get_db()
		class_map[T] = class_types
	}
	return class_map[T]
}

register_class :: proc(init_obj: ^gd.InitObject, T: typeid, bind_func: proc(^gd.GDExtensionClassCreationInfo, bool)) {
	get_init_obj(init_obj) // assumes register_class happens before other things
	
  class_types := make_class_user_data(T)
	
	funcs := new(gd.GDExtensionClassCreationInfo)
	funcs.is_virtual = 0
	funcs.is_abstract = 0
	funcs.class_userdata = cast(rawptr)class_types

	init_obj.classdb[T] = {class_types, funcs}

	bind_func(funcs, true)
	init_obj.gde_interface.classdb_register_extension_class(init_obj.library,
																													cast(gd.GDExtensionConstStringNamePtr)class_types.class_string_name,
																													cast(gd.GDExtensionConstStringNamePtr)class_types.parent_string_name,
																													funcs)
	bind_func(funcs, false)
}

unregister_class :: proc(init_obj: ^gd.InitObject, T: typeid) {
	class_string_name := new(godot.StringName); defer free(class_string_name)
	string_name.constructor(class_string_name, fmt.tprintf("%s", T))
	init_obj.gde_interface.classdb_unregister_extension_class(init_obj.library, cast(gd.GDExtensionConstStringNamePtr)class_string_name)

	free((cast(^ClassUserData)init_obj.classdb[T][0]).class_string_name)
	free((cast(^ClassUserData)init_obj.classdb[T][0]).parent_string_name)	
	free(init_obj.classdb[T][0])
	free(init_obj.classdb[T][1])
}

get_parent :: proc(T: typeid) -> (string, typeid) {
	names := reflect.struct_field_names(T)
	for name in names {
		sf : reflect.Struct_Field = reflect.struct_field_by_name(T, name)
		if !reflect.is_procedure(sf.type) && name == "_" {
			return name, sf.type.id
		}
	}
	return "", nil
}

// ------------------------------

classdb_create_instance :: proc(inst: gd.GDExtensionClassInstancePtr, p_userdata: rawptr) -> gd.GDExtensionObjectPtr {
	userdata := (cast(^ClassUserData)p_userdata)^
	class_name := userdata.class_string_name
	parent_class_name := userdata.parent_string_name

	//fmt.printf("class: %s  parent: %s  inst: %x\n", userdata.class_type, userdata.parent_type, inst)
	
  // track class instance for look up later... TODO remove??? or use for something?
	//userdata.db[inst] = userdata.class_type

	p_owner := gd.gde_interface.classdb_construct_object(cast(gd.GDExtensionConstStringNamePtr)parent_class_name)
	gd.gde_interface.object_set_instance(cast(gd.GDExtensionObjectPtr)p_owner, cast(gd.GDExtensionConstStringNamePtr)class_name, inst)

	//fmt.printf("owner: %x  inst: %x\n", p_owner, inst)

	return cast(gd.GDExtensionObjectPtr)p_owner
}

// ------------------------------

is_variant :: proc(s: string) -> bool {
	return godot.get_typestring_as_i32(s) != 0
}

make_class_file :: proc(file: string, struct_list: []typeid) {
	new_free_bind_string := `			
###_new :: proc "c" (p_userdata: rawptr) -> gd.GDExtensionObjectPtr {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
	inst := new(###)
  context.user_ptr = inst
	inst._owner = gdc.classdb_create_instance(cast(gd.GDExtensionClassInstancePtr)inst, p_userdata)

  db := gdc.get_db()
  db[inst]=###
  ###_instance_bind(inst)

  return cast(gd.GDExtensionObjectPtr)inst._owner
}
###_free :: proc "c" (p_userdata: rawptr, p_instance: gd.GDExtensionClassInstancePtr) {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
	inst := cast(^###)p_instance
	free(inst)
}
###_bind :: proc(funcs: ^gd.GDExtensionClassCreationInfo, bind_methods: bool) {
  context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
	@static initialized := false
  if !bind_methods {
    if initialized do return
    initialized = true
  } else {
    funcs.create_instance_func = ###_new
    funcs.free_instance_func = ###_free
`
	non_mandatory_funcs := `
###_set_func :: proc "c" (p_instance: gd.GDExtensionClassInstancePtr, p_name: gd.GDExtensionConstStringNamePtr, p_value: gd.GDExtensionConstVariantPtr) -> gd.GDExtensionBool {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
  inst  := cast(^###)p_instance
  subs  := string_name.substr(cast(^godot.StringName)p_name, 0); defer free(subs)
	name  := gstring.to_string(subs); defer free(strings.ptr_from_string(name))
 	names := reflect.struct_field_names(###)
  name = name[0:len(name)-1] // no terminator
  //fmt.println(#procedure, name)
  if p_instance != nil && slice.contains(names, name) {
    sf := reflect.struct_field_by_name(###, name)
    tmp := cast(^godot.Variant)p_value
    a := reflect.struct_field_value_by_name(inst^, name, true)
    a_bytes := mem.any_to_bytes(a)
    data_start :: 8
    if fmt.tprintf("%s", sf.type) == "string" {
      str := new(godot.String); defer free(str)
      variant.to_type(tmp, str)
      delete((cast(^string)&a_bytes[0])^)
      ostr := gstring.to_string(str) // don't delete me right away! this will leak like 1 byte at end... FIXME!
      mem.copy(&a_bytes[0], &ostr, len(a_bytes))
  	  return cast(gd.GDExtensionBool)1
    }
    mem.copy(&a_bytes[0], &tmp.opaque[data_start], len(a_bytes))
  	return cast(gd.GDExtensionBool)1
  }
	return cast(gd.GDExtensionBool)0
}
###_get_func :: proc "c" (p_instance: gd.GDExtensionClassInstancePtr, p_name: gd.GDExtensionConstStringNamePtr, r_ret: gd.GDExtensionVariantPtr) -> gd.GDExtensionBool {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
  inst := cast(^###)p_instance
  subs  := string_name.substr(cast(^godot.StringName)p_name, 0); defer free(subs)
	name  := gstring.to_string(subs); defer free(strings.ptr_from_string(name))
 	names := reflect.struct_field_names(###)
  name = name[0:len(name)-1] // no terminator
  //fmt.println(#procedure, name)
  if p_instance != nil && slice.contains(names, name) {
    sf := reflect.struct_field_by_name(###, name)
    tag := fmt.tprintf("%s", sf.tag)
		is_signal := strings.contains(tag, "signal")
		signal := ""
		if is_signal {
			sidx := strings.index(tag, "signal:\"") + 8
			eidx := strings.index(tag[sidx:], "\"")
			signal = tag[sidx:sidx+eidx]
		}

    tmp := transmute(^godot.Variant)r_ret
    a := reflect.struct_field_value_by_name(inst^, name, true)
    a_bytes := mem.any_to_bytes(a)
    data_start :: 8
    type : i32 =  godot.get_type_as_i32(sf.type.id)
    sigs := gdc.get_signals()

    if is_signal && signal in sigs && sigs[signal] {
      type = cast(i32)gd.GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_CALLABLE
      call := new(godot.Callable)
      callables := gdc.get_callables()
      append(callables, call)
      callable.constructor(call, cast(^godot.Object)inst._owner, cast(^godot.StringName)p_name)
      a_bytes = call.opaque[:]
    }
    if fmt.tprintf("%s", sf.type) == "string" {
      str := new(godot.String); defer free(str)
      gstring.constructor(str, fmt.tprintf("%v", a))
      a_bytes = str.opaque[:]
    }

    mem.copy(&tmp.opaque[0], &type, size_of(type)) // need to set Variant type too!
    mem.copy(&tmp.opaque[data_start], &a_bytes[0], int(godot.get_size_of_type(type)))
  	return cast(gd.GDExtensionBool)1
  }
	return cast(gd.GDExtensionBool)0
}
###_get_property_list_func :: proc "c" (p_instance: gd.GDExtensionClassInstancePtr, r_count: ^u32) -> ^gd.GDExtensionPropertyInfo {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
	//fmt.println(#procedure, "###")
  names := reflect.struct_field_names(###)
  types := reflect.struct_field_types(###)
  tags  := reflect.struct_field_tags(###)
  props : [dynamic]gd.GDExtensionPropertyInfo
  for n, idx in names {
    type := fmt.tprintf("%s", types[idx])
    if strings.has_prefix(fmt.tprintf("%s", tags[idx]), "property") {
      if strings.has_prefix(type, "[") {
        arr_len, _ := strconv.parse_int(type[1:])
        tidx := strings.index(type, "]")
        type = type[tidx+1:]
        if arr_len > 0 {
          for i:=0; i<arr_len; i+=1 {
        	  info : gd.GDExtensionPropertyInfo
        	  info.type = cast(gd.GDExtensionVariantType)godot.get_typestring_as_i32(type)
        	  info.name = cast(gd.GDExtensionStringNamePtr)gdc.string_to_string_name(fmt.tprintf("%s%d", n, i))
        	  info.class_name = cast(gd.GDExtensionStringNamePtr)gdc.string_to_string_name("###")
        	  info.hint = cast(u32)godot.PropertyHint.PROPERTY_HINT_NONE
        	  info.hint_string = cast(gd.GDExtensionStringPtr)gdc.string_to_string("")
        	  info.usage = cast(u32)(godot.PropertyUsageFlags.PROPERTY_USAGE_DEFAULT | godot.PropertyUsageFlags.PROPERTY_USAGE_NIL_IS_VARIANT)
            append(&props, info)
          }
        }
      } else {
    	  info : gd.GDExtensionPropertyInfo
    	  info.type = cast(gd.GDExtensionVariantType)godot.get_type_as_i32(types[idx].id)
    	  info.name = cast(gd.GDExtensionStringNamePtr)gdc.string_to_string_name(n)
    	  info.class_name = cast(gd.GDExtensionStringNamePtr)gdc.string_to_string_name("###")
    	  info.hint = cast(u32)godot.PropertyHint.PROPERTY_HINT_NONE
    	  info.hint_string = cast(gd.GDExtensionStringPtr)gdc.string_to_string("")
    	  info.usage = cast(u32)(godot.PropertyUsageFlags.PROPERTY_USAGE_DEFAULT | godot.PropertyUsageFlags.PROPERTY_USAGE_NIL_IS_VARIANT)
        append(&props, info)
      }
    }
  }
	r_count^ = cast(u32)len(props)
  if r_count^ > 0 {
  	return &props[0]
  }
  return nil
}
###_free_property_list_func :: proc "c" (p_instance: gd.GDExtensionClassInstancePtr, p_list: ^gd.GDExtensionPropertyInfo) {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
	//fmt.println(#procedure, "###")
  if p_list == nil do return
  props := cast([^]gd.GDExtensionPropertyInfo)p_list
  for i:=0; ; i+=1 {
    if props[i].name == nil do break
    free(props[i].name)
    free(props[i].class_name)
    free(props[i].hint_string)
  }
  free(p_list)
}
###_property_can_revert_func :: proc "c" (p_instance: gd.GDExtensionClassInstancePtr, p_name: gd.GDExtensionConstStringNamePtr) -> gd.GDExtensionBool {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
	fmt.println(#procedure, "###")
	return cast(gd.GDExtensionBool)0
}
###_property_get_revert_func :: proc "c" (p_instance: gd.GDExtensionClassInstancePtr, p_name: gd.GDExtensionConstStringNamePtr, r_ret: gd.GDExtensionVariantPtr) -> gd.GDExtensionBool {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
	fmt.println(#procedure, "###")
	return cast(gd.GDExtensionBool)0
}
###_notification_func :: proc "c" (p_instance: gd.GDExtensionClassInstancePtr, p_what: i32) {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
	//fmt.println(#procedure, "###")
}
###_to_string_func :: proc "c" (p_instance: gd.GDExtensionClassInstancePtr, r_is_valid: ^gd.GDExtensionBool, p_out: gd.GDExtensionStringPtr) {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
	//fmt.println(#procedure, "###")
  context.user_ptr = p_instance
	gstring.constructor(cast(^godot.String)p_out, fmt.tprintf("[ %d ]", object.get_instance_id(cast(^###)p_instance)))
	r_is_valid^ = 1
}
###_reference_func :: proc "c" (p_instance: gd.GDExtensionClassInstancePtr) {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
	//fmt.println(#procedure, "###", p_instance)
  context.user_ptr = p_instance
  inst := cast(^###)p_instance
}
###_unreference_func :: proc "c" (p_instance: gd.GDExtensionClassInstancePtr) {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
	//fmt.println(#procedure, "###", p_instance)
  context.user_ptr = p_instance
  inst := cast(^###)p_instance
}
###_get_virtual_func :: proc "c" (p_userdata: rawptr, p_name: gd.GDExtensionConstStringNamePtr) -> gd.GDExtensionClassCallVirtual {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
  subs  := string_name.substr(cast(^godot.StringName)p_name, 0); defer free(subs)
	name  := gstring.to_string(subs); defer free(strings.ptr_from_string(name))
 	names := reflect.struct_field_names(###)
  name = name[0:len(name)-1] // no terminator
  //fmt.println(#procedure, name)
  if slice.contains(names, name) {
    sf := reflect.struct_field_by_name(###, name)
    tag := fmt.tprintf("%s", sf.tag)
		is_virtual := strings.contains(tag, "virtual")
    name1 := fmt.tprintf("###_%s", name) // vtable contains class as prefix
    if is_virtual {
      vtbl := gdc.get_vtable()
      if name1 in vtbl {
        return vtbl[name1]
      }
    }
  }

	return cast(gd.GDExtensionClassCallVirtual)nil
}
###_get_rid_func :: proc "c" (p_instance: gd.GDExtensionClassInstancePtr) -> u64 {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
	//fmt.println(#procedure, "###")
	return 0
}
`
	instance_bind := `
###_instance_bind :: proc(inst: ^###) {
`
	virtual_bind := `
###_virtual_@@@_bind :: proc "c" (p_instance: gd.GDExtensionClassInstancePtr, p_args: ^gd.GDExtensionConstTypePtr, r_ret: gd.GDExtensionTypePtr) {
	context = runtime.default_context()
	context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))
  context.user_ptr = p_instance
`
	// This does some magic "class like" creation from struct and similar named procs
	// It rewrites a file to xxx_class.odin, but with new(), free(), bind()
	// procs.. for each struct/"class" we want to link up with Godot (in struct_list)
	
	s := file
	idx := strings.last_index_byte(s, '/')
	idx = (idx != -1) ? idx + 1 : strings.last_index_byte(s, '\\') + 1
	in_file := s[idx:]
	out_file := fmt.tprintf("%s_class.odin", s[idx:len(s)-5])
	os.remove(out_file)

	in_fd, err1 := os.open(in_file, os.O_RDONLY); defer os.close(in_fd)
	mode: int = 0
	when os.OS == .Linux || os.OS == .Darwin {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}
	out_fd, err2 := os.open(out_file, os.O_WRONLY|os.O_CREATE, mode); defer os.close(out_fd)
	if err1 != os.ERROR_NONE || err2 != os.ERROR_NONE {
		fmt.println("Error: unable to open files!")
	}
	in_data, ok := os.read_entire_file(in_fd)
	
	struct_flag := make([]bool, len(struct_list))
	lines := strings.split_lines(string(in_data)); defer delete(lines)

	proc_sigs : [dynamic]string; defer delete(proc_sigs)
  enum_sigs : [dynamic]string; defer delete(enum_sigs)
	
	if ok { // file was read... get global func proc signatures.. 1st pass
		procs : [dynamic]string; defer delete(procs)  // contains only procs in struct
		for s, idx in struct_list {
			names := reflect.struct_field_names(struct_list[idx])
			for name, i in names {
				sf : reflect.Struct_Field = reflect.struct_field_by_name(struct_list[idx], name)
				if reflect.is_procedure(sf.type) && name != "_" {				
					proc_name := fmt.tprintf("%s_%s", s, name)
					append(&procs, proc_name)
				}
			}
		}
		for line in lines {
			if strings.contains(line, ":: proc") {
				append(&proc_sigs, line)
			}
			if strings.contains(line, ":: enum") {
				append(&enum_sigs, line)
			}
		}
	}
	if ok { // file was read... 2nd pass
		for line in lines {
			if strings.contains(line, "//+") {
				str, _ := strings.replace_all(line, "//+", "")
				os.write_string(out_fd, fmt.tprintf("%s\n", str))
			} else {
				os.write_string(out_fd, fmt.tprintf("%s\n", line))
			}

			// after the "___ :: struct {" line start looking for line that ends this struct with "}"
			for s, idx in struct_list {
				if strings.has_prefix(line, fmt.tprintf("%s :: struct", s)) {
					struct_flag[idx] = true
				}
			}
			if strings.has_prefix(line, "}") {
				for b, idx in struct_flag {
					if b {
						struct_flag[idx] = false
						// start throwing in new, free, and bind procs
						new_code, _ := strings.replace_all(new_free_bind_string, "###", fmt.tprintf("%s", struct_list[idx]))
						os.write_string(out_fd, new_code)

						funcs := []string{"set_func",  // non-mandatory funcs
															"get_func",
															"get_property_list_func",
															"free_property_list_func",
															"property_can_revert_func",
															"property_get_revert_func",
															"notification_func",
															"to_string_func",
															"reference_func",
															"unreference_func",
															"get_virtual_func",
															"get_rid_func"}
						for f in funcs {
							os.write_string(out_fd, fmt.tprintf("    funcs.%s = %s_%s\n", f, struct_list[idx], f))
						}
						os.write_string(out_fd, "    return\n  }\n")

						new_code, _ = strings.replace_all(non_mandatory_funcs, "###", fmt.tprintf("%s", struct_list[idx]))
						os.write_string(out_fd, new_code)

						inst_bind_lines : [dynamic]string // store bindings to skip 2 passes
						
						{
							names := reflect.struct_field_names(struct_list[idx])
							for name, i in names {
								sf : reflect.Struct_Field = reflect.struct_field_by_name(struct_list[idx], name)
								if reflect.is_procedure(sf.type) && name != "_" {
									if !strings.contains(fmt.tprintf("%s", sf.type), "proc") {
										fmt.printf("Warning: consider changing %s to the \"proc(x) -> x\" type definition", sf.type) // warning for type'd proc sigs
									}

									// instead of passing sf.type to make_method_bind()
									// we can pass entire line from global proc that is in same file (hopefully)
									// that line will have arg names and default values (again hopefully)
									proc_sig : string = fmt.tprintf("%s", sf.type)
									for s in proc_sigs {
										if strings.has_prefix(s, fmt.tprintf("%s_%s", struct_list[idx], name)) {
											proc_sig, _ = strings.replace_all(s, "\"", "\\\"") // escape (") for stuff like.... proc "c"
											break
										}
									}

									is_const := false
									is_vararg := false
									is_static := strings.contains(fmt.tprintf("%s", sf.tag), "static")

									// ------------------------------
									// CALL
									// ------------------------------
									
									// this will be a method that is called by Godot which will in turn call the actual method ex: Example_test_static()
									os.write_string(out_fd, fmt.tprintf(`
  %s_%s_method_call :: proc "c" (method_userdata: rawptr, 
                                 p_instance: gd.GDExtensionClassInstancePtr, 
                                 p_args: ^gd.GDExtensionConstVariantPtr, 
                                 p_argument_count: gd.GDExtensionInt, 
                                 r_return: gd.GDExtensionVariantPtr, 
                                 r_error: ^gd.GDExtensionCallError) {{
`, struct_list[idx], name))
									{
										os.write_string(out_fd, "    context = runtime.default_context()\n")
										os.write_string(out_fd, "    context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))\n")
										//os.write_string(out_fd, "    fmt.println(#procedure)\n")
										
										// now the secret sauce! - put class instance in context.user_ptr
										os.write_string(out_fd, "    context.user_ptr = p_instance\n")
										
										sig := fmt.tprintf("%s", sf.type)
										ret_type := ""
										if strings.contains(sig, "->") {
											spl := strings.split(sig, "->"); defer delete(spl)
											ret_type = strings.trim_space(spl[len(spl)-1])
											if strings.has_prefix(ret_type, "^") do ret_type = ret_type[1:]
										}
										
										args := get_args(fmt.tprintf("%s", proc_sig)); defer delete(args)
										arg_len := len(args)
										if args[0] == "" do arg_len = 0
										if arg_len != 0 { // TODO: making too many args here, fix?
											os.write_string(out_fd, fmt.tprintf("    args := make([]^godot.Variant, %d+p_argument_count); defer delete(args)\n", arg_len))
											for s, idx in args {
												os.write_string(out_fd, fmt.tprintf("    args[%d] = (cast([^]^godot.Variant)p_args)[%d]\n", idx, idx))
											}
											for s, idx in args {
												_, type, def_val := get_name_type_default(strings.trim_space(s))
												arg_type, vararg := correct_type(type, "", struct_list)
												
												if vararg {
													is_vararg = true

													os.write_string(out_fd, fmt.tprintf("    arg%d := make([]any, p_argument_count-%d); defer delete(arg%d)\n", idx, idx, idx))
													// now add the rest of the args to this vararg/[]any.. the variants can decide their own type here
													os.write_string(out_fd, fmt.tprintf("    for anyidx in 0..<(p_argument_count-%d) {{\n", idx))
													os.write_string(out_fd, fmt.tprintf("      arg%d[anyidx] = variant.convert_variant((cast([^]^godot.Variant)p_args)[anyidx+%d])\n", idx, idx))
													os.write_string(out_fd, fmt.tprintf("    }}\n"))
													break
													
												} else {
													is_ptr := strings.has_prefix(type, "^")
													type_is_bitset := strings.contains(type, "bit_set")
													if is_ptr {
														clean := fmt.tprintf(";defer free(arg%d)", idx)
														os.write_string(out_fd, fmt.tprintf("    arg%d := new(%s)%s\n", idx, type[1:], clean))
													} else if type_is_bitset {
														os.write_string(out_fd, fmt.tprintf("    arg%d : u64\n", idx)) // 128 won't work
													} else {
														os.write_string(out_fd, fmt.tprintf("    arg%d : %s\n", idx, type))
													}
													if def_val != "" {
														os.write_string(out_fd, fmt.tprintf("    if %d >= p_argument_count {{\n", idx))
														os.write_string(out_fd, fmt.tprintf("      arg%d = %s\n", idx, def_val))
														os.write_string(out_fd, fmt.tprintf("    }} else {{\n"))
														os.write_string(out_fd, fmt.tprintf("      variant.to_type(args[%d], %sarg%d)\n", idx, is_ptr ? "" : "&", idx))
														os.write_string(out_fd, fmt.tprintf("    }}\n"))
													} else {
														os.write_string(out_fd, fmt.tprintf("    variant.to_type(args[%d], %sarg%d)\n", idx, is_ptr ? "" : "&", idx))
													}
													
												}
											}
										}
										
										if ret_type != "" {

											ret_is_bitset := strings.contains(ret_type, "bit_set")
											ret_bit_set_size := ""
											if strings.contains(ret_type, "u8") || strings.contains(ret_type, "i8") do ret_bit_set_size = "u8"
											if strings.contains(ret_type, "u16") || strings.contains(ret_type, "i16") do ret_bit_set_size = "u16"
											if strings.contains(ret_type, "u32") || strings.contains(ret_type, "i32") do ret_bit_set_size = "u32"
											if strings.contains(ret_type, "u64") || strings.contains(ret_type, "i64") do ret_bit_set_size = "u64"
											if strings.contains(ret_type, "u128") || strings.contains(ret_type, "i128") do ret_bit_set_size = "u128" // won't work
											
											if ret_type == "Variant" {
												os.write_string(out_fd, fmt.tprintf("    ret := %s_%s(", struct_list[idx], name))
											} else if ret_is_bitset {
												os.write_string(out_fd, "    ret := new(godot.Variant); defer free(ret)\n")
												os.write_string(out_fd, fmt.tprintf("    variant.constructor(ret, cast(u64)transmute(%s)%s_%s(", ret_bit_set_size, struct_list[idx], name))
											} else {
												os.write_string(out_fd, "    ret := new(godot.Variant); defer free(ret)\n")
												os.write_string(out_fd, fmt.tprintf("    variant.constructor(ret, %s_%s(", struct_list[idx], name))
											}
											for idx in 0..<arg_len {
												s := args[idx]
												is_ptr := strings.has_prefix(s, "^")
												type_is_bitset := strings.contains(s, "bit_set")  // TODO: shift << 1 the bit_set???
												bit_set_size := "" // there is a odin builtin proc "card" cardinality to get # or elem's in set TODO use that?
												if strings.contains(s, "u8") || strings.contains(s, "i8") do bit_set_size = "u8"
												if strings.contains(s, "u16") || strings.contains(s, "i16") do bit_set_size = "u16"
												if strings.contains(s, "u32") || strings.contains(s, "i32") do bit_set_size = "u32"
												if strings.contains(s, "u64") || strings.contains(s, "i64") do bit_set_size = "u64"
												if strings.contains(s, "u128") || strings.contains(s, "i128") do bit_set_size = "u128" // won't work!
												
												arg_type, vararg := correct_type(strings.trim_space(s), "", struct_list)
												arg_prefix := is_ptr ? "&" : (vararg ? ".." : "")
												if type_is_bitset {
													bit_set_type := (s[strings.index(s, ":")+1:])
													os.write_string(out_fd, fmt.tprintf("transmute(%s )(cast(%s)%sarg%d%s)", bit_set_type, bit_set_size, arg_prefix, idx, idx==len(args)-1 ? "" : ", "))
												} else {
													os.write_string(out_fd, fmt.tprintf("%sarg%d%s", arg_prefix, idx, idx==len(args)-1 ? "" : ", "))
												}
											}
											if ret_type != "Variant" do os.write_string(out_fd, ")")
											os.write_string(out_fd, ")\n") // end args to proc call and end variant.constructor()
											os.write_string(out_fd, "    if ret != nil {\n")
											os.write_string(out_fd, "      (cast(^godot.Variant)r_return)^ = ret^\n")
											os.write_string(out_fd, "    }\n")
											
										} else { // no return
											os.write_string(out_fd, fmt.tprintf("    %s_%s(", struct_list[idx], name))
											for idx in 0..<arg_len {
												os.write_string(out_fd, fmt.tprintf("arg%d%s", idx, idx==len(args)-1 ? "" : ", "))
											}
											os.write_string(out_fd, ")\n") // end args to proc call and end variant.constructor()
											
										}

										if arg_len != 0 { // clean up of args
											for s, idx in args {
												_, type, def_val := get_name_type_default(strings.trim_space(s))
												arg_type, vararg := correct_type(type, "", struct_list)
												
												if vararg {
													os.write_string(out_fd, fmt.tprintf("    for anyidx in 0..<(p_argument_count-%d) {{\n", idx))
													os.write_string(out_fd, fmt.tprintf("      switch v in arg%d[anyidx] {{\n", idx))
													os.write_string(out_fd, fmt.tprintf("    	 case string:\n"))
													os.write_string(out_fd, fmt.tprintf("		     free(strings.ptr_from_string(v))\n"))
													os.write_string(out_fd, fmt.tprintf("		     free(&arg%d[anyidx].(string))\n", idx))
													os.write_string(out_fd, fmt.tprintf("      }}\n"))
													os.write_string(out_fd, fmt.tprintf("    }}\n"))
													break
												}
											}
										}
																		
										os.write_string(out_fd, "  }\n")
									}

									// ------------------------------
									// PTRCALL
									// ------------------------------
									
									os.write_string(out_fd, fmt.tprintf(`
  %s_%s_method_ptrcall :: proc "c" (method_userdata: rawptr, 
                                    p_instance: gd.GDExtensionClassInstancePtr, 
                                    p_args: ^gd.GDExtensionConstTypePtr, 
                                    r_ret: gd.GDExtensionTypePtr) {{
`, struct_list[idx], name))
									{
										os.write_string(out_fd, "    context = runtime.default_context()\n")
										os.write_string(out_fd, "    context.allocator = mem.tracking_allocator(&(gdc.get_init_obj().ta))\n")
										//os.write_string(out_fd, "    fmt.println(#procedure)\n")										
	
										// now the secret sauce! - put class instance in context.user_ptr
										os.write_string(out_fd, "    context.user_ptr = p_instance\n")
										
										sig := fmt.tprintf("%s", sf.type)
										ret_type := ""
										if strings.contains(sig, "->") {
											spl := strings.split(sig, "->"); defer delete(spl)
											ret_type = strings.trim_space(spl[len(spl)-1])
											if strings.has_prefix(ret_type, "^") do ret_type = ret_type[1:]
										}

										args := get_args(fmt.tprintf("%s", sf.type)); defer delete(args)
										arg_len := len(args)
										if args[0] == "" do arg_len = 0
										if arg_len != 0 {
											for s, idx in args {
												is_ptr := strings.has_prefix(args[idx], "^")
												ptr_str := is_ptr ? "^" : ""
												arg_type, vararg := correct_type(strings.trim_space(s), "", struct_list)
												if vararg { // TODO: vararg are unsupported with ptrcall right?
													is_vararg = true
													break
												}
												if strings.contains(arg_type, "bit_set") {
													os.write_string(out_fd, fmt.tprintf("    arg%d : %s\n", idx, arg_type))
												} else {
													os.write_string(out_fd, fmt.tprintf("    arg%d := transmute(%s%s)((cast([^]uintptr)p_args)[%d])\n", idx, ptr_str, arg_type, idx))
												}
											}
										}

										if !is_vararg {
											if ret_type != "" {
												os.write_string(out_fd, fmt.tprintf("    ret := %s_%s(", struct_list[idx], name))
												for idx in 0..<arg_len {
													os.write_string(out_fd, fmt.tprintf("arg%d%s", idx, idx==len(args)-1 ? "" : ", "))
												}
												os.write_string(out_fd, ")\n") // end args to proc call and end variant.constructor()
												//os.write_string(out_fd, "    (cast(^godot.Object)r_ret)^ = ret^\n")
												
											} else { // no return
												os.write_string(out_fd, fmt.tprintf("    %s_%s(", struct_list[idx], name))
												for idx in 0..<arg_len {
													os.write_string(out_fd, fmt.tprintf("arg%d%s", idx, idx==len(args)-1 ? "" : ", "))
												}
												os.write_string(out_fd, ")\n") // end args to proc call and end variant.constructor()
												
											}
										}
																		
										os.write_string(out_fd, "  }\n")
									}

									// bindf the method
									tag := fmt.tprintf("%s", sf.tag)
									is_signal := strings.contains(tag, "signal")
									is_virtual := strings.contains(tag, "virtual")
									signal := "\"\""
									if is_signal {
										sidx := strings.index(tag, "signal:\"") + 8
										eidx := strings.index(tag[sidx:], "\"")
										signal = fmt.tprintf("\"%s\"", tag[sidx:sidx+eidx])
									}
									os.write_string(out_fd,
												fmt.tprintf("  %s_method_bind : gdc.MethodBind = gdc.make_method_bind(%s, \"%s\", \"%s\", %s_%s_method_call, %s_%s_method_ptrcall, %v, %v, %v, %v, %v, %s)\n",
																		name, struct_list[idx], name, proc_sig, struct_list[idx], name, struct_list[idx], name, is_const, is_vararg, is_static, is_virtual, is_signal, signal))
									os.write_string(out_fd, fmt.tprintf("  gdc.classdb_bind_method(\"%s\", &%s_method_bind)\n", struct_list[idx], name))

									inst_bind_line := fmt.tprintf("  inst.%s = %s_%s\n", name, struct_list[idx], name)
									append(&inst_bind_lines, inst_bind_line)
								}
							}
						}
						os.write_string(out_fd, "}\n") // finish ###_bind :: proc()

						new_code, _ = strings.replace_all(instance_bind, "###", fmt.tprintf("%s", struct_list[idx]))
						os.write_string(out_fd, new_code)
						{
							for l in inst_bind_lines {
								os.write_string(out_fd, l)
							}
							
							// setup all struct proc pointers in type hierarchy
							curr_struct := struct_list[idx]
							for ;; {
								field := reflect.struct_field_by_name(curr_struct, "_")
								names := reflect.struct_field_names(field.type.id)
								types := reflect.struct_field_types(field.type.id)
								ftype := fmt.tprintf("%s", field.type)
								if ftype == "Wrapped" do break
								for name, idx in names {
									if strings.has_prefix(name, "_") do continue
									if name == "_owner" do break
									os.write_string(out_fd, fmt.tprintf("  inst.%s = %s.%s\n", name, camel_to_snake(ftype), name))
								}
								curr_struct = field.type.id
							}
						}
						os.write_string(out_fd, "}\n") // finish ###_instance_bind :: proc()

						names := reflect.struct_field_names(struct_list[idx])
						types := reflect.struct_field_types(struct_list[idx])
						tags  := reflect.struct_field_tags(struct_list[idx])
						for n, i in names {
							type := fmt.tprintf("%s", types[i])
							tag  := fmt.tprintf("%s", tags[i])
							if strings.contains(tag, "virtual") {
								new_code, _ = strings.replace_all(virtual_bind, "###", fmt.tprintf("%s", struct_list[idx]))
								new_code, _ = strings.replace_all(new_code, "@@@", n)
								os.write_string(out_fd, new_code)
								args := get_args(type); defer delete(args)
								os.write_string(out_fd, fmt.tprintf("  %s_%s(", struct_list[idx], n))
								for a, ai in args {
									ct, _ := correct_type(a, "", struct_list)
									os.write_string(out_fd, fmt.tprintf("cast(^%s)(cast([^]gd.GDExtensionConstTypePtr)p_args)[%d]", ct, ai))
								}
								os.write_string(out_fd, ")\n")
								
								os.write_string(out_fd, "}\n") // finish ###_virtual_@@@_bind :: proc()
							}
						}

					}
				}
			}

			if strings.has_prefix(strings.trim_left_space(line), "// ### auto-generated register_class is put here") {
				os.write_string(out_fd, "  vtbl := gdc.get_vtable()\n")
				for s in struct_list {
					os.write_string(out_fd, fmt.tprintf("  gdc.register_class(init_obj, %s, %s_bind)\n", s, s))
					has_init := false
					for n in proc_sigs[:] {
						if strings.has_prefix(n, fmt.tprintf("%s_init", s)) {
							has_init = true
						}
					}
					if has_init {
						os.write_string(out_fd, fmt.tprintf("  %s_init(init_obj)\n", s))
					}

					names := reflect.struct_field_names(s)
					tags  := reflect.struct_field_tags(s)
					for n, i in names {
						tag  := fmt.tprintf("%s", tags[i])
						if strings.contains(tag, "virtual") {
							os.write_string(out_fd, fmt.tprintf("  vtbl[\"%s_%s\"] = %s_virtual_%s_bind\n", s, n, s, n))
						}
					}

				}
			}
			if strings.has_prefix(strings.trim_left_space(line), "// ### auto-generated unregister_class is put here") {
				for s in struct_list { // TODO unregister children of parent classes FIRST!
					os.write_string(out_fd, fmt.tprintf("  gdc.unregister_class(init_obj, %s)\n", s))
				}
				os.write_string(out_fd, "  gdc.make_class_user_data(nil, true) // cleanup\n")
				os.write_string(out_fd, "  delete(init_obj.classdb)\n")
				
				os.write_string(out_fd, "  db := gdc.get_db()\n") 
				os.write_string(out_fd, "  delete(db^)\n")
				os.write_string(out_fd, "  free(db)\n")
				
				os.write_string(out_fd, "  sigs := gdc.get_signals()\n")
				os.write_string(out_fd, "  delete(sigs^)\n")
				os.write_string(out_fd, "  free(sigs)\n")

				os.write_string(out_fd, "  callables := gdc.get_callables()\n")
				os.write_string(out_fd, "  for c in callables {\n")
				os.write_string(out_fd, "    free(c)\n")
				os.write_string(out_fd, "  }\n")
				os.write_string(out_fd, "  delete(callables^)\n")
				os.write_string(out_fd, "  free(callables)\n")
				
				os.write_string(out_fd, "  vtbl := gdc.get_vtable()\n")
				os.write_string(out_fd, "  delete(vtbl^)\n")
				os.write_string(out_fd, "  free(vtbl)\n")
				
				os.write_string(out_fd, "  gstring.clean_string_names()\n")
				os.write_string(out_fd, "  godot.get_type_as_i32(nil, true)\n")
			}
		}
	}
}

MethodBind :: struct {
	name : godot.StringName,
	instance_class : godot.StringName,
	proc_signature : string,

	method_call : gd.GDExtensionClassMethodCall,
	method_ptrcall : gd.GDExtensionClassMethodPtrCall,
	
	_const : bool,
	_varargs : bool,
	_static : bool,
	_virtual : bool,

	_signal : bool,
	signal_name : string,
}

camel_to_snake :: proc(name: string) -> string {
	if len(name) == 0 do return ""
	if name == "AABB" do return "aabb"
	if name == "RID" do return "rid"
	if name == "AESContext" do return "aes_context"

	one_letter := false
	result := ""

	r := rune(name[0])
	prev_letter := r
	if unicode.is_letter(r) do one_letter = true
	result = fmt.tprintf("%s%c", result, unicode.to_lower(rune(name[0])))
	
	for i in 1..<len(name) {
		r = rune(name[i])
		next_letter := rune('_')
		if i+1 < len(name) do next_letter = rune(name[i+1])
		if unicode.is_upper(r) {
			if one_letter && (unicode.is_lower(prev_letter) || unicode.is_lower(next_letter)) {
				result = fmt.tprintf("%s%c%c", result, '_', unicode.to_lower(r))
			} else {
				result = fmt.tprintf("%s%c", result, unicode.to_lower(r))
			}
		} else {
			result = fmt.tprintf("%s%c", result, r)
		}
		if unicode.is_letter(r) do one_letter = true
		prev_letter = r
	}
  if strings.contains(result, "1_d") {
		result, _ = strings.replace_all(result, "1_d", "1d")
	}
  if strings.contains(result, "2_d") {
		result, _ = strings.replace_all(result, "2_d", "2d")
	}
  if strings.contains(result, "3_d") {
		result, _ = strings.replace_all(result, "3_d", "3d")
	}
	
	return result
}

get_name_type_default :: proc(str: string) -> (name: string, type: string, def: string) {
	_str := strings.trim_space(str)
  _str = strings.trim(_str, "()")
	strs := strings.split(_str, ":"); defer delete(strs)  // get type from strings like "(name: type)"
	name = strings.trim_space(strs[0])

	type = strings.trim_space(strs[len(strs)-1])
	tdef := strings.split(type, "="); defer delete(tdef)
	type = strings.trim_space(tdef[0])

	def = ""
	if len(tdef) > 1 {
		def = strings.trim_space(tdef[len(tdef)-1])
	}

	return
}

string_to_variant_type :: proc(str: string) -> gd.GDExtensionVariantType {
	name, type, def := get_name_type_default(str)
	ctos := camel_to_snake(type)
	_str := strings.to_upper(ctos)
	defer delete(_str)
													
	for i in 0..<cast(int)gd.GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX {
		s := fmt.tprintf("%s\n", cast(gd.GDExtensionVariantType) i)
		if strings.contains(s, _str) {
			return cast(gd.GDExtensionVariantType)i
		}
	}
	return cast(gd.GDExtensionVariantType)0
}

get_ret :: proc(s: string) -> string {
	if strings.contains(s, "->") {
		str := strings.split(s, "->"); defer delete(str)
		return str[len(str)-1]
	}
	return ""
}

get_name :: proc(s: string) -> string {
	_str := strings.trim_space(s)
	col := strings.index(_str, ":")
	_str = _str[0:col]
	_str = strings.trim_space(_str)
	return _str
}

get_args :: proc(s: string) -> (strs: []string) {
	_str := strings.trim_space(s)
	arg_start := strings.index(_str, "(") + 1
	arg_end := strings.index(_str, ")")	
	args := _str[arg_start:arg_end]
	strs = strings.split(args, ",") // remember to clean this up!
	return
}

make_method_bind :: proc(class: typeid, method_name: string, proc_sig: string, method_call: gd.GDExtensionClassMethodCall, method_ptrcall: gd.GDExtensionClassMethodPtrCall, is_const, is_vararg, is_static: bool, is_virtual: bool, is_signal: bool, sig_name: string) -> (mb: MethodBind) {
	string_name.constructor(&mb.name, method_name)
	string_name.constructor(&mb.instance_class, fmt.tprintf("%s", class))
	
	mb.proc_signature = proc_sig

	mb.method_call = method_call
	mb.method_ptrcall = method_ptrcall

	mb._const = is_const
	mb._varargs = is_vararg
	mb._static = is_static
	mb._virtual = is_virtual

	mb._signal = is_signal
	mb.signal_name = sig_name
	return
}

string_to_string_name :: proc(s: string) -> ^godot.StringName {
	tmp := new(godot.StringName)
	string_name.constructor(tmp, s)
	return tmp
}

string_to_string :: proc(s: string) -> ^godot.String {
	tmp := new(godot.String)
	gstring.constructor(tmp, s)
	return tmp
}

get_metadata :: proc(type: string) -> gd.GDExtensionClassMethodArgumentMetadata {
	switch type {
	case "int":
		intsize := size_of(int)
		if intsize == 8 {
			return gd.GDExtensionClassMethodArgumentMetadata.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64
		} else {
			return gd.GDExtensionClassMethodArgumentMetadata.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT32
		}
	case "i8":
		return gd.GDExtensionClassMethodArgumentMetadata.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT8
	case "i16":
		return gd.GDExtensionClassMethodArgumentMetadata.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT16
	case "i32":
		return gd.GDExtensionClassMethodArgumentMetadata.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT32
	case "i64":
		return gd.GDExtensionClassMethodArgumentMetadata.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64
	case "u8":
		return gd.GDExtensionClassMethodArgumentMetadata.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_UINT8
	case "u16":
		return gd.GDExtensionClassMethodArgumentMetadata.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_UINT16
	case "u32":
		return gd.GDExtensionClassMethodArgumentMetadata.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_UINT32
	case "u64":
		return gd.GDExtensionClassMethodArgumentMetadata.GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_UINT64
	case "f32":
		return gd.GDExtensionClassMethodArgumentMetadata.GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_FLOAT
	case "f64":
		return gd.GDExtensionClassMethodArgumentMetadata.GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_DOUBLE
	}
	return gd.GDExtensionClassMethodArgumentMetadata.GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE
}

// ------------------------------

classdb_bind_method :: proc(class_name: string, mb: ^MethodBind) {
	class_name_string_name := cast(gd.GDExtensionStringNamePtr)string_to_string_name(class_name)
	defer free(class_name_string_name)

	hint := godot.PropertyHint.PROPERTY_HINT_NONE
  usage := godot.PropertyUsageFlags.PROPERTY_USAGE_DEFAULT | godot.PropertyUsageFlags.PROPERTY_USAGE_NIL_IS_VARIANT
	
	ret := get_ret(mb.proc_signature)
	n, t, d := get_name_type_default(ret)

	rv_info  := new(gd.GDExtensionPropertyInfo); defer free(rv_info)
	rv_info.type = string_to_variant_type(t)
	rv_info.name = cast(gd.GDExtensionStringNamePtr)string_to_string_name(n)
	defer free(rv_info.name)
	rv_info.class_name = class_name_string_name
	rv_info.hint = cast(u32)hint // TODO
	rv_info.hint_string = cast(gd.GDExtensionStringPtr)string_to_string("TODO"); defer free(rv_info.hint_string)
	rv_info.usage = cast(u32)usage
	rv_meta := get_metadata(t)

	args := get_args(mb.proc_signature); defer delete(args)
	args_len := 0
	if args[0] != "" do args_len = len(args)
	args_info := make([]gd.GDExtensionPropertyInfo, args_len); defer delete(args_info)
	args_meta := make([]gd.GDExtensionClassMethodArgumentMetadata, args_len); defer delete(args_meta)
	defs := make([]gd.GDExtensionVariantPtr, args_len); defer delete(defs)

	if args_len > 0 {
		for arg, i in args {
			n, t, d = get_name_type_default(arg)
			args_info[i].type = string_to_variant_type(t)
			args_info[i].name = cast(gd.GDExtensionStringNamePtr)string_to_string_name(n)
			args_info[i].class_name = cast(gd.GDExtensionStringNamePtr)string_to_string_name(t)
			args_info[i].hint = cast(u32)hint // TODO
			args_info[i].hint_string = cast(gd.GDExtensionStringPtr)string_to_string("TODO")
			args_info[i].usage = cast(u32)usage
			args_meta[i] = get_metadata(t)
			//v := new(godot.Variant)
			//variant.new_nil(v) // TODO?
			//defs[i] = cast(gd.GDExtensionVariantPtr)v
		}
	}

	method_info : gd.GDExtensionClassMethodInfo
	
	method_info.name = cast(gd.GDExtensionStringNamePtr)&mb.name // GDExtensionStringNamePtr
	method_info.method_userdata = nil // rawptr
	method_info.call_func = mb.method_call // GDExtensionClassMethodCall
	method_info.ptrcall_func = mb.method_ptrcall // GDExtensionClassMethodPtrCall

	get_hint_flags :: proc(mb: ^MethodBind) -> u32 {
		return (mb._const ? cast(u32)gd.GDExtensionClassMethodFlags.GDEXTENSION_METHOD_FLAG_CONST : 0) |
			(mb._varargs ? cast(u32)gd.GDExtensionClassMethodFlags.GDEXTENSION_METHOD_FLAG_VARARG : 0) |
			(mb._static ? cast(u32)gd.GDExtensionClassMethodFlags.GDEXTENSION_METHOD_FLAG_STATIC : 0) |
			(mb._virtual ? cast(u32)gd.GDExtensionClassMethodFlags.GDEXTENSION_METHOD_FLAG_VIRTUAL : 0)
	}
	method_info.method_flags = get_hint_flags(mb) // Bitfield of `GDExtensionClassMethodFlags`.

	method_info.has_return_value = ret == "" ? 0 : 1 // GDExtensionBool
	method_info.return_value_info = rv_info // ^GDExtensionPropertyInfo,
	method_info.return_value_metadata = rv_meta // GDExtensionClassMethodArgumentMetadata,

	method_info.argument_count = cast(u32)len(args_info)
	if method_info.argument_count > 0 {
		method_info.arguments_info = cast(^gd.GDExtensionPropertyInfo)&args_info[0]
		method_info.arguments_metadata = cast(^gd.GDExtensionClassMethodArgumentMetadata)&args_meta[0]
	}

	method_info.default_argument_count = 0 //cast(u32)len(args_info) // u32
	if method_info.default_argument_count > 0 {
		method_info.default_arguments = &defs[0] // ^GDExtensionVariantPtr, TODO
	}

	gd.gde_interface.classdb_register_extension_class_method(gd.library, cast(gd.GDExtensionConstStringNamePtr)class_name_string_name, &method_info)

	// SIGNAL -
	if mb._signal {
		add_signal(gd.library, class_name, mb.signal_name, mb.proc_signature)
	}

	if args_len > 0 {
		for _, i in args {
			free(args_info[i].name)
			free(args_info[i].class_name)
			free(args_info[i].hint_string)
		}
	}
	
}

correct_type :: proc(type_name: string, meta: string, struct_list: []typeid) -> (string, bool) {
	type_conversion : map[string]string
	type_conversion["nil"] = ""
	type_conversion["int"] = "int"
	type_conversion["uint"] = "uint"	
	type_conversion["bool"] = "bool"
	type_conversion["u8"] = "u8"
	type_conversion["i8"] = "i8"
	type_conversion["u16"] = "u16"
	type_conversion["i16"] = "i16"
	type_conversion["u32"] = "u32"
	type_conversion["i32"] = "i32"	
	type_conversion["u64"] = "u64"
	type_conversion["i64"] = "i64"	
	type_conversion["f32"] = "f32"
	type_conversion["f64"] = "f64"

	if type_name in type_conversion {
		return type_conversion[type_name], false
	}

	type_n := type_name
	if strings.has_prefix(type_name, "^") {
		type_n = type_name[1:]
	}
	is_vararg := false
	if strings.contains(type_name, "any") {
		is_vararg = true
	}
	if strings.contains(type_name, "bit_set") {
		return type_n, false
	}

	pck := "godot."
	if strings.has_prefix(type_n, "godot.") {
		pck = ""
	}
	else if is_vararg {
		pck = ""
	} else {
		for s in struct_list {
			str := fmt.tprintf("%s", s)
			if type_n == str {
				pck = ""
			}
		}
	}
	if type_n == "Object" {
		return fmt.tprintf("^%s%s", pck, type_n), is_vararg
	}

	return fmt.tprintf("%s%s", pck, type_n), is_vararg
}

add_signal :: proc(library: gd.GDExtensionClassLibraryPtr, class_name: string, signal_name: string, signal_sig: string) {
	cl_name := cast(gd.GDExtensionConstStringNamePtr)string_to_string_name(class_name); defer free(cl_name)
	
	sig_name := new(godot.StringName); defer free(sig_name)
	string_name.constructor(sig_name, signal_name)
	sigs := get_signals()
	sigs[signal_name] = true

	hint := godot.PropertyHint.PROPERTY_HINT_NONE
  usage := godot.PropertyUsageFlags.PROPERTY_USAGE_DEFAULT | godot.PropertyUsageFlags.PROPERTY_USAGE_NIL_IS_VARIANT
	
	args := get_args(signal_sig); defer delete(args)
	args_len := 0
	if args[0] != "" do args_len = len(args)
	args_info := make([]gd.GDExtensionPropertyInfo, args_len); defer delete(args_info)
	if args_len > 0 {
		for arg, i in args {
			n, t, _ := get_name_type_default(arg)
			args_info[i].type = string_to_variant_type(t)
			args_info[i].name = cast(gd.GDExtensionStringNamePtr)string_to_string_name(n)
			args_info[i].class_name = cast(gd.GDExtensionStringNamePtr)string_to_string_name(t)
			args_info[i].hint = cast(u32)hint
			args_info[i].hint_string = cast(gd.GDExtensionStringPtr)string_to_string("TODO")
			args_info[i].usage = cast(u32)usage
		}
	}

	gd.gde_interface.classdb_register_extension_class_signal(library,
																													 cl_name,
																													 cast(gd.GDExtensionConstStringNamePtr)&sig_name.opaque[0],
																													 cast(^gd.GDExtensionPropertyInfo)&args_info[0],
																													 cast(gd.GDExtensionInt)args_len)
	if args_len > 0 {
		for _, i in args {
			free(args_info[i].name)
			free(args_info[i].class_name)
			free(args_info[i].hint_string)
		}
	}
}

add_group :: proc(library: gd.GDExtensionClassLibraryPtr, cl: typeid, group_name: string, prefix: string) {
	// prefix is the string prefixing/in-front-of any struct field that will be part of this group.. group_name will show in godot
	cl_name := cast(gd.GDExtensionConstStringNamePtr)string_to_string_name(fmt.tprintf("%s", cl))
	gr_name := cast(gd.GDExtensionConstStringPtr)string_to_string(group_name)
	pref := cast(gd.GDExtensionConstStringPtr)string_to_string(prefix)
	gd.gde_interface.classdb_register_extension_class_property_group(library,
																																	 cl_name,
																																	 gr_name,
																																	 pref)
	free(cl_name)
	free(gr_name)
	free(pref)
}

add_subgroup :: proc(library: gd.GDExtensionClassLibraryPtr, cl: typeid, sub_group_name: string, prefix: string) {
	cl_name := cast(gd.GDExtensionConstStringNamePtr)string_to_string_name(fmt.tprintf("%s", cl))
	gr_name := cast(gd.GDExtensionConstStringPtr)string_to_string(sub_group_name)
	pref := cast(gd.GDExtensionConstStringPtr)string_to_string(prefix)
	gd.gde_interface.classdb_register_extension_class_property_subgroup(library,
																																			cl_name,
																																			gr_name,
																																			pref)
	free(cl_name)
	free(gr_name)
	free(pref)
}

add_property :: proc(library: gd.GDExtensionClassLibraryPtr, cl: typeid, info: ^gd.GDExtensionPropertyInfo, p_setter: string, p_getter: string) {
	cl_name := cast(gd.GDExtensionConstStringNamePtr)string_to_string_name(fmt.tprintf("%s", cl))
	setter := cast(gd.GDExtensionConstStringNamePtr)string_to_string_name(p_setter)
	getter := cast(gd.GDExtensionConstStringNamePtr)string_to_string_name(p_getter)
	gd.gde_interface.classdb_register_extension_class_property(library, cl_name, info, setter, getter)
	free(cl_name)
	free(setter)
	free(getter)
}

add_consts :: proc(library: gd.GDExtensionClassLibraryPtr, cl: typeid, e: typeid) {
	names  := reflect.enum_field_names(e)
	values := reflect.enum_field_values(e)
	for n, idx in names {
		add_const(library, cl, e, n, values[idx])
	}
}

add_const :: proc(library: gd.GDExtensionClassLibraryPtr, cl: typeid, e: typeid, s: string, c: reflect.Type_Info_Enum_Value) {
	cl_name := cast(gd.GDExtensionConstStringNamePtr)string_to_string_name(fmt.tprintf("%s", cl))
	enum_name := cast(gd.GDExtensionConstStringNamePtr)string_to_string_name(fmt.tprintf("%s", e))
	const_name := cast(gd.GDExtensionConstStringNamePtr)string_to_string_name(s)
	const_val := cast(gd.GDExtensionInt)c
	is_bitfield := cast(gd.GDExtensionBool)0
	gd.gde_interface.classdb_register_extension_class_integer_constant(library, cl_name, enum_name, const_name, const_val, is_bitfield)
	free(cl_name)
	free(enum_name)
	free(const_name)
}

