//-*- compile-command: "~/dev/Odin/odin run binding-generator.odin -file" -*-

package bindgen

import "core:os"
import "core:fmt"
import "core:slice"
import "core:strings"
import "core:strconv"
import "core:unicode"
import "core:encoding/json"

Globals :: struct {
	builtin_classes : [dynamic]string,
	engine_classes : map[string]bool,	// Key is class name, value is boolean where True means the class is refcounted.
	native_structures : [dynamic]string, // Type names of native structures
	singletons : [dynamic]string,
	pck : string,
}

generate_global_constants :: proc(root: json.Object, target_dir: string, g: ^Globals) {
	file := strings.concatenate([]string{target_dir, "/global_constants.odin"})
	mode: int = 0
	when os.OS == .Linux || os.OS == .Darwin {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}

	os.remove(file) // remove old file first
	fd, err := os.open(file, os.O_WRONLY|os.O_CREATE, mode)
	defer os.close(fd)
	if err == os.ERROR_NONE {
		os.write_string(fd, "package godot\n\n")
		os.write_string(fd, "import \"core:fmt\"\n")
		os.write_string(fd, "import \"core:strings\"\n")		

		for constant in root["global_constants"].(json.Array) {
		}

		for enum_def in root["global_enums"].(json.Array) {
			name := fmt.tprintf("%s", enum_def.(json.Object)["name"])

			if strings.has_prefix(name, "Variant.") {
				continue // skip these
			}

			os.write_string(fd, fmt.tprintf("%s :: enum {{\n", name))
			for value in enum_def.(json.Object)["values"].(json.Array) {
				k := value.(json.Object)["name"]
				v := value.(json.Object)["value"]
				os.write_string(fd, fmt.tprintf("\t%s = %.0f,\n", k, v))
			}
			os.write_string(fd, "}\n\n")
		}

		prevent_redeclaration : [dynamic]string; defer delete(prevent_redeclaration)
		for class_api in root["classes"].(json.Array) { // putting class enums and constants here too
			class_name := fmt.tprintf("%s", class_api.(json.Object)["name"])
			if "enums" in class_api.(json.Object) {
				for enum_api in class_api.(json.Object)["enums"].(json.Array) {
					name := fmt.tprintf("%s_%s", class_name, enum_api.(json.Object)["name"])
					os.write_string(fd, fmt.tprintf("%s :: enum {{\n", name))
					if "values" in enum_api.(json.Object) {
						for value in enum_api.(json.Object)["values"].(json.Array) {
							vname := fmt.tprintf("%s", value.(json.Object)["name"])
							val   := fmt.tprintf("%.0f", value.(json.Object)["value"])
							os.write_string(fd, fmt.tprintf("  %s = %s,\n", vname, val))
						}
					}
					os.write_string(fd, "}\n")
				}
			}
			if "constants" in class_api.(json.Object) {
				for value in class_api.(json.Object)["constants"].(json.Array) {
					type := ""
					if !("type" in value.(json.Object)) {
						type = "int"
					} else {
						type = fmt.tprintf("%s", value.(json.Object)["type"])
					}
					vname := fmt.tprintf("%s", value.(json.Object)["name"])
					if slice.contains(prevent_redeclaration[:], vname) {
						continue
					}
					append(&prevent_redeclaration, vname)
					vtype := fmt.tprintf("%s", value.(json.Object)["type"])
					val   := fmt.tprintf("%.0f", value.(json.Object)["value"])
					vtype = correct_type(vtype, "", g)
					if len(vtype) > 0 do vtype = fmt.tprintf(" %s ", vtype)
					os.write_string(fd, fmt.tprintf("%s :%s: %s\n", vname, correct_type(vtype, "", g), val))
				}
			}
		}
		
		os.write_string(fd, `
VariantType :: enum {
	NIL,

	// atomic types
	BOOL,
	INT,
	FLOAT,
	STRING,
	
	// math types
	VECTOR2,
	VECTOR2I,
	RECT2,
	RECT2I,
	VECTOR3,
	VECTOR3I,
	TRANSFORM2D,
	VECTOR4,
	VECTOR4I,
	PLANE,
	QUATERNION,
	AABB,
	BASIS,
	TRANSFORM3D,
	PROJECTION,

	// misc types
	COLOR,
	STRING_NAME,
	NODE_PATH,
	RID,
	OBJECT,
	CALLABLE,
	SIGNAL,
	DICTIONARY,
	ARRAY,
	
	// typed arrays
	PACKED_BYTE_ARRAY,
	PACKED_INT32_ARRAY,
	PACKED_INT64_ARRAY,
	PACKED_FLOAT32_ARRAY,
	PACKED_FLOAT64_ARRAY,
	PACKED_STRING_ARRAY,
	PACKED_VECTOR2_ARRAY,
	PACKED_VECTOR3_ARRAY,
	PACKED_COLOR_ARRAY,
	
	VARIANT_MAX,
}

get_typestring_as_i32 :: proc(s: string, clean_up: bool = false) -> i32 {
  @static _types : map[string]VariantType
	if clean_up {
		delete(_types)
		return 0
	}

  if len(_types) == 0 {
    _types["nil"] = VariantType.NIL  // TODO auto-gen this
	// atomic types
    _types[	"bool"] = VariantType.BOOL
    _types[	"int"] = VariantType.INT
    _types[	"float"] = VariantType.FLOAT
    _types[	"string"] = VariantType.STRING
	
	// math types
    _types[	"vector2"] = VariantType.VECTOR2
    _types[	"vector2i"] = VariantType.VECTOR2I
    _types[	"rect2"] = VariantType.RECT2
    _types[	"rect2i"] = VariantType.RECT2I
    _types[	"vector3"] = VariantType.VECTOR3
    _types[	"vector3i"] = VariantType.VECTOR3I
    _types[	"transform2d"] = VariantType.TRANSFORM2D
    _types[	"vector4"] = VariantType.VECTOR4
    _types[	"vector4i"] = VariantType.VECTOR4I
    _types[	"plane"] = VariantType.PLANE
    _types[	"quaternion"] = VariantType.QUATERNION
    _types[	"aabb"] = VariantType.AABB
    _types[	"basis"] = VariantType.BASIS
    _types[	"transform3d"] = VariantType.TRANSFORM3D
    _types[	"projection"] = VariantType.PROJECTION

	// misc types
    _types[	"color"] = VariantType.COLOR
    _types[	"string_name"] = VariantType.STRING_NAME
    _types[	"node_path"] = VariantType.NODE_PATH
    _types[	"rid"] = VariantType.RID
    _types[	"object"] = VariantType.OBJECT
    _types[	"callable"] = VariantType.CALLABLE
    _types[	"signal"] = VariantType.SIGNAL
    _types[	"dictionary"] = VariantType.DICTIONARY
    _types[	"array"] = VariantType.ARRAY
	
	// typed arrays
    _types[	"packed_byte_array"] = VariantType.PACKED_BYTE_ARRAY
    _types[	"packed_int32_array"] = VariantType.PACKED_INT32_ARRAY
    _types[	"packed_int64_array"] = VariantType.PACKED_INT64_ARRAY
    _types[	"packed_float32_array"] = VariantType.PACKED_FLOAT32_ARRAY
    _types[	"packed_float64_array"] = VariantType.PACKED_FLOAT64_ARRAY
    _types[	"packed_string_array"] = VariantType.PACKED_STRING_ARRAY
    _types[	"packed_vector2_array"] = VariantType.PACKED_VECTOR2_ARRAY
    _types[	"packed_vector3_array"] = VariantType.PACKED_VECTOR3_ARRAY
    _types[	"packed_color_array"] = VariantType.PACKED_COLOR_ARRAY
  }

  str_tmp := strings.to_lower(s); defer delete(str_tmp)
  if str_tmp in _types {
    return cast(i32)_types[str_tmp]
  }
  return 0
}

get_type_as_i32 :: proc(t: typeid, clean_up: bool = false) -> i32 {
  @static _types : map[typeid]i32
  if clean_up {
    get_typestring_as_i32("", true)
    delete(_types)
    return 0
  }
  if t in _types {
    return _types[t]
  } else {
    _types[t] = get_typestring_as_i32(fmt.tprintf("%s", t))
    return _types[t]
  }
}

Operator :: enum {
	// comparison
	OP_EQUAL,
	OP_NOT_EQUAL,
	OP_LESS,
	OP_LESS_EQUAL,
	OP_GREATER,
	OP_GREATER_EQUAL,
	// mathematic
	OP_ADD,
	OP_SUBTRACT,
	OP_MULTIPLY,
	OP_DIVIDE,
	OP_NEGATE,
	OP_POSITIVE,
	OP_MODULE,
	// bitwise
	OP_SHIFT_LEFT,
	OP_SHIFT_RIGHT,
	OP_BIT_AND,
	OP_BIT_OR,
	OP_BIT_XOR,
	OP_BIT_NEGATE,
	// logic
	OP_AND,
	OP_OR,
	OP_XOR,
	OP_NOT,
	// containment
	OP_IN,
	OP_MAX,
}
`)
	}
}

camel_to_snake :: proc(name: string) -> string {
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

is_pod_type :: proc(type_name: string) -> bool {
  // These are types for which no class should be generated.
  @static pod_types := []string{"Nil"    ,        "void"    ,        "bool"    ,        "real_t" ,
                                "float"  ,        "double"  ,        "int"     ,        "int8_t" ,
                                "uint8_t",        "int16_t" ,        "uint16_t",        "int32_t",
                                "int64_t",        "uint32_t",        "uint64_t",
																"u8", "i8", "u16", "i16", "u32", "i32", "u64", "i64", "f32", "f64",
															 }
	for i in pod_types {
		if i == type_name do return true
	}
  return false
}

is_included_struct_type :: proc(type_name: string) -> bool {
	// Struct types which we already have implemented.
	//@static included_struct_types := []string{"AABB","Basis","Color","Plane","Projection",
	//																					"Quaternion","Rect2","Rect2i","Transform2D",
	//																					"Transform3D","Vector2","Vector2i","Vector3",
	//																					"Vector3i","Vector4","Vector4i"}
	@static included_struct_types := []string{}
	for i in included_struct_types {
		if i == type_name do return true
	}
	return false
}

is_included_type :: proc(type_name: string) -> bool {
	// Types which are already implemented.
  return is_included_struct_type(type_name) || type_name == "ObjectID"
}

is_bitfield :: proc(type_name: string) -> bool {
  return strings.has_prefix(type_name, "bitfield::")
}

get_enum_class :: proc(enum_name: string) -> string {
  if strings.contains(enum_name, ".") {
		if is_bitfield(enum_name) {
			str, _ := strings.replace_all(enum_name, "bitfield::", "")
			return strings.split(str, ".")[0]
		} else {
			str, _ := strings.replace_all(enum_name, "enum::", "")			
			return strings.split(str, ".")[0]
		}
	}
	return ""
}

is_enum :: proc(type_name: string) -> bool {
  return strings.has_prefix(type_name, "enum::") || strings.has_prefix(type_name, "bitfield::")
}

is_engine_class :: proc(type_name: string, g: ^Globals) -> bool {
	spl := strings.split(type_name, ".")
	tn := spl[len(spl)-1]
  return tn == "Object" || tn in g.engine_classes
}

is_variant :: proc(type_name: string, g: ^Globals) -> bool {
  return (
    type_name == "Variant"
			|| slice.contains(g.builtin_classes[:], type_name)
			|| type_name == "Nil"
			|| strings.has_prefix(type_name, "typedarray::")
  )
}

is_included :: proc(type_name: string, current_type: string, g: ^Globals) -> bool {
  // Check if a builtin type should be included.
  // This removes Variant and POD types from inclusion, and the current type.

	if strings.has_prefix(type_name, "typedarray::") do return true
  to_include := get_enum_class(type_name) if is_enum(type_name) else type_name
  if to_include == current_type || is_pod_type(to_include) do return false
  if to_include == "UtilityFunctions" do return true
  return is_engine_class(to_include, g) || is_variant(to_include, g)
}

get_operator_id_name :: proc(op: string) -> string {
  @static op_id_map : map[string]string
	if len(op_id_map) == 0 {		
    op_id_map["=="] = "equal"
    op_id_map["!="] = "not_equal"
    op_id_map["<"] = "less"
    op_id_map["<="] = "less_equal"
    op_id_map[">"] = "greater"
    op_id_map[">="] = "greater_equal"
    op_id_map["+"] = "add"
    op_id_map["-"] = "subtract"
    op_id_map["*"] = "multiply"
    op_id_map["/"] = "divide"
    op_id_map["unary-"] = "negate"
    op_id_map["unary+"] = "positive"
    op_id_map["%"] = "module"
    op_id_map["<<"] = "shift_left"
    op_id_map[">>"] = "shift_right"
    op_id_map["&"] = "bit_and"
    op_id_map["|"] = "bit_or"
    op_id_map["^"] = "bit_xor"
    op_id_map["~"] = "bit_negate"
    op_id_map["and"] = "and"
    op_id_map["or"] = "or"
    op_id_map["xor"] = "xor"
    op_id_map["not"] = "not"
    op_id_map["and"] = "and"
    op_id_map["in"] = "in"
  }
  return op_id_map[op]
}

get_enum_name :: proc(enum_name: string) -> string {
	str := ""
	if is_bitfield(enum_name) {
		str, _ = strings.replace_all(enum_name, "bitfield::", "")
	} else {
		str, _ = strings.replace_all(enum_name, "enum::", "")
	}
	tmp := strings.split(str, ".")
	return tmp[len(tmp)-1]
}

is_refcounted :: proc(type_name: string, g: ^Globals) -> bool {
	return type_name in g.engine_classes && g.engine_classes[type_name]
}

correct_type :: proc(type_name: string, meta: string, g: ^Globals) -> string {
	type_conversion : map[string]string
	type_conversion["float"] = "f32"
	type_conversion["double"] = "f64"
	type_conversion["nil"] = ""
	type_conversion["int"] = "int"
	type_conversion["uint"] = "uint"	
	type_conversion["int32"] = "i32"
	type_conversion["uint32"] = "u32"	
	type_conversion["int64"] = "i64"
	type_conversion["uint64"] = "u64"	
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

	type_conversion["int8_t"] = "i8"
	
  if meta != "" {
		if meta in type_conversion {
			return type_conversion[type_name]
		} else {
			return meta
		}
	}

	if type_name in type_conversion {
		return type_conversion[type_name]
	}

	if strings.has_prefix(type_name, "typedarray::") {
		str, _ := strings.replace_all(type_name, "typedarray::", "") // TODO?
		return fmt.tprintf("[^]%s%s", g.pck, str)
	}

	if is_enum(type_name) {
		base_class := get_enum_class(type_name)		
		if is_bitfield(type_name) {
			return fmt.tprintf("u64") //bit_set[%s%s_%s]", g.pck, base_class, get_enum_name(type_name))
		} else {
			if base_class != "" {
				return fmt.tprintf("%s%s_%s", g.pck, base_class, get_enum_name(type_name))
			} else {
				return fmt.tprintf("%s%s", g.pck, get_enum_name(type_name))
			}
		}
	}

	//if is_refcounted(type_name, g) {
	//	return fmt.tprintf("%sRef< %s >", g.pck, type_name)
	//}  // TODO

	if type_name == "Object" || is_engine_class(type_name, g) {
		return fmt.tprintf("%s%s", g.pck, type_name)
	}

	if strings.has_suffix(type_name, "*") {
		return fmt.tprintf("^%s%s", g.pck, type_name[:len(type_name)-1])
	}

	return fmt.tprintf("%s%s", g.pck, type_name)
}
	
type_for_parameter :: proc(type_name: string, meta: string, g: ^Globals) -> string {
	if is_pod_type(type_name) && type_name != "Nil" || is_enum(type_name) {
		return correct_type(type_name, meta, g)
	} else if is_variant(type_name, g) || is_refcounted(type_name, g) || type_name == "Object" {
		return fmt.tprintf("^%s", correct_type(type_name, "", g))
	} else {
		return correct_type(type_name, "", g)
	}
}

escape_identifier :: proc(id: string) -> string {
	@static cpp_keywords_map: map[string]string
	if len(cpp_keywords_map) == 0 {
    cpp_keywords_map["class"] = "_class"
    cpp_keywords_map["char"] = "_char"
    cpp_keywords_map["short"] = "_short"
    cpp_keywords_map["bool"] = "_bool"
    cpp_keywords_map["int"] = "_int"
    cpp_keywords_map["default"] = "_default"
    cpp_keywords_map["case"] = "_case"
    cpp_keywords_map["switch"] = "_switch"
    cpp_keywords_map["export"] = "_export"
    cpp_keywords_map["template"] = "_template"
    cpp_keywords_map["new"] = "new_"
    cpp_keywords_map["operator"] = "_operator"
    cpp_keywords_map["typeof"] = "type_of"
    cpp_keywords_map["typename"] = "type_name"
    cpp_keywords_map["context"] = "_context"		
  }
  if id in cpp_keywords_map {
		return cpp_keywords_map[id]
	}
	return id
}

correct_default_value :: proc(value: string, type_name: string, g: ^Globals) -> string {
	@static value_map : map[string]string
	if len(value_map) == 0 {
    value_map["null"] = "nil"
    //value_map["\"\""] = fmt.tprintf("%sString()", g.pck)
		//value_map["&\"\""] = fmt.tprintf("%sStringName()", g.pck)
    //value_map["[]"] = fmt.tprintf("%sArray()", g.pck)
    //value_map["{}"] = fmt.tprintf("%sDictionary()", g.pck)
	}
	_, ok := strconv.parse_int(value)
	if ok do return value
  if type_name == "bool" do return value

	is_real := (type_name == "float")
	if !is_real do return "nil"
	
	if value in value_map do return value_map[value]
	if value == "" do return fmt.tprintf("%s()", type_name)
	
	if strings.has_prefix(value, "Array[") do return "{}"
	return value
}

make_function_parameters :: proc(parameters: json.Array, g: ^Globals, include_default: bool=false, for_builtin: bool=false, is_vararg: bool=false) -> string {
	signature : [dynamic]string

	index := 0
	for par in parameters {
		type := fmt.tprintf("%s", par.(json.Object)["type"])
		meta := fmt.tprintf("%s", par.(json.Object)["meta"])
		name := fmt.tprintf("%s", par.(json.Object)["name"])		
		parameter := type_for_parameter(type, "meta" in par.(json.Object) ? meta : "", g)
		//snake_parameter := camel_to_snake(parameter)
		parameter_name := escape_identifier(name)

		if len(parameter_name) == 0 {
			parameter_name = fmt.tprintf("arg_%d", index+1)
		}
		parameter = fmt.tprintf("%s: %s", parameter_name, parameter)

		if include_default && "default_value" in par.(json.Object) && (!for_builtin || type != "Variant") {
			parameter = fmt.tprintf("%s = ", parameter)
			if is_enum(type) {
				parameter_type := correct_type(type, "", g)
				if parameter_type == "void" do parameter_type = "Variant"
				parameter = fmt.tprintf("%s%s", parameter, parameter_type)
			}
			default_value := fmt.tprintf("%s", par.(json.Object)["default_value"])
			parameter = fmt.tprintf("%s%s", parameter, correct_default_value(default_value, type, g))
		}

		append(&signature, parameter)

		if is_vararg {
			//append(&signature, "args: ..any") // TODO
		}
		
		index += 1
	}
	return strings.join(signature[:], ", ")
}

get_ptr_to_arg :: proc() -> (pta: map[string][2]string) {
	// for casting to needed type to interface with VariantTypes
	pta["int"]	= {"INT", "i64"} // an odin type = { GD..VariantType, some type to cast to (for interface reasons) }
	pta["uint"] = {"INT", "i64"}
	pta["bool"] = {"BOOL", "u8"} // most of these are from method_ptrcall.hpp in godot-cpp src, but with odin types
	pta["u8"]		= {"INT", "i64"}
	pta["i8"]		= {"INT", "i64"}
	pta["u16"]	= {"INT", "i64"}
	pta["i16"]	= {"INT", "i64"}
	pta["u32"]	= {"INT", "i64"}
	pta["i32"]	= {"INT", "i64"}
	pta["i64"]	= {"INT", "i64"}
	pta["u64"]	= {"INT", "i64"}
	pta["f32"]	= {"FLOAT", "f64"}
	pta["f64"]	= {"FLOAT", "f64"} // TODO: is this all int, bool and float types?

	pta["^godot.String"]	= {"STRING", "String"}
	pta["^godot.StringName"]	= {"STRING_NAME", "StringName"}
	
	pta["^godot.Vector2"]	= {"VECTOR2", "Vector2"}
	pta["^godot.Vector2i"]	= {"VECTOR2I", "Vector2i"}
	pta["^godot.Rect2"]	= {"RECT2", "Rect2"}
	pta["^godot.Rect2i"]	= {"RECT2I", "Rect2i"}
	pta["^godot.Vector3"]	= {"VECTOR3", "Vector3"}
	pta["^godot.Vector3i"]	= {"VECTOR3I", "Vector3i"}
	pta["^godot.Transform2D"]	= {"TRANSFORM2D", "Transform2D"}
	pta["^godot.Vector4"]	= {"VECTOR4", "Vector4"}
	pta["^godot.Vector4i"]	= {"VECTOR4I", "Vector4i"}
	pta["^godot.Plane"]	= {"QUATERNION", "Plane"}
	pta["^godot.Quaternion"]	= {"QUATERNION", "Quaternion"}
	pta["^godot.AABB"]	= {"AABB", "AABB"}
	pta["^godot.Basis"]	= {"BASIS", "Basis"}
	pta["^godot.Transform3D"]	= {"TRANSFORM3D", "Transform3D"}	
	pta["^godot.Projection"]	= {"PROJECTION", "Projection"}

	/* misc types */
	pta["^godot.Color"]	= {"COLOR", "Color"}
	pta["^godot.StringName"]	= {"STRING_NAME", "SringName"}
	pta["^godot.NodePath"]	= {"NODE_PATH", "NodePath"}
	pta["^godot.RID"]	= {"RID", "RID"}
	pta["^godot.Object"]	= {"OBJECT", "Object"}
	pta["^godot.Callable"]	= {"CALLABLE", "Callable"}
	pta["^godot.Signal"]	= {"SIGNAL", "Signal"}
	pta["^godot.Dictionary"]	= {"DICTIONARY", "Dictionary"}
	pta["^godot.Array"]	= {"ARRAY", "Array"}	

	/* typed arrays */
	pta["^godot.PackedByteArray"]	= {"PACKED_BYTE_ARRAY", "PackedByteArray"}		
	pta["^godot.PackedInt32Array"]	= {"PACKED_INT32_ARRAY", "PackedInt32Array"}
	pta["^godot.PackedInt64Array"]	= {"PACKED_INT64_ARRAY", "PackedInt64Array"}
	pta["^godot.PackedFloat32Array"]	= {"PACKED_FLOAT32_ARRAY", "PackedFloat32Array"}
	pta["^godot.PackedFloat64Array"]	= {"PACKED_FLOAT64_ARRAY", "PackedFloat64Array"}
	pta["^godot.PackedStringArray"]	= {"PACKED_STRING_ARRAY", "PackedStringArray"}
	pta["^godot.PackedVector2Array"]	= {"PACKED_VECTOR2_ARRAY", "PackedVector2Array"}
	pta["^godot.PackedVector3Array"]	= {"PACKED_VECTOR3_ARRAY", "PackedVector3Array"}
	pta["^godot.PackedColorArray"]	= {"PACKED_COLOR_ARRAY", "PackedColorArray"}
	
	return
}

generate_variant_class :: proc(target_dir: string, g: ^Globals) {
	class_name := "Variant"
	snake_class_name := camel_to_snake(class_name)	
	dir := fmt.tprintf("%s/%s", target_dir, snake_class_name)
	class_file := fmt.tprintf("%s/%s%s", dir, snake_class_name, ".odin")	

	os.make_directory(dir)
	mode: int = 0
	when os.OS == .Linux || os.OS == .Darwin {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}
	os.remove(class_file)

	fd, err := os.open(class_file, os.O_WRONLY|os.O_CREATE, mode)
	defer os.close(fd)
	if err == os.ERROR_NONE {
		os.write_string(fd, fmt.tprintf("package %s\n\n", snake_class_name))
		os.write_string(fd, "import \"core:fmt\"\n")		
		os.write_string(fd, "import \"core:strings\"\n")
		os.write_string(fd, "import godot \"../../gen\"\n")
		os.write_string(fd, "import gd \"../../../../godot_odin\"\n\n")

		os.write_string(fd, `
from_type_constructor :: proc(type: int) -> gd.GDExtensionVariantFromTypeConstructorFunc {
  @static from_type : [godot.VariantType.VARIANT_MAX]gd.GDExtensionVariantFromTypeConstructorFunc
  if from_type[1] == nil { // start from 1 to skip NIL
  	for i := 1; i < cast(int)godot.VariantType.VARIANT_MAX; i+=1 {
	  	from_type[i] = gd.gde_interface.get_variant_from_type_constructor(cast(gd.GDExtensionVariantType)i)
    }
  }
  return from_type[type]
}
to_type_constructor :: proc(type: int) -> gd.GDExtensionTypeFromVariantConstructorFunc {
  @static to_type : [godot.VariantType.VARIANT_MAX]gd.GDExtensionTypeFromVariantConstructorFunc
  if to_type[1] == nil { // start from 1 to skip NIL
  	for i := 1; i < cast(int)godot.VariantType.VARIANT_MAX; i+=1 {
	  	to_type[i] = gd.gde_interface.get_variant_to_type_constructor(cast(gd.GDExtensionVariantType)i)
    }
  }
  return to_type[type]
}
copy :: proc(me: ^godot.Variant, v: ^godot.Variant) {
  gd.gde_interface.variant_new_copy(cast(gd.GDExtensionVariantPtr)&me.opaque[0], cast(gd.GDExtensionConstVariantPtr)&v.opaque[0])
}
new_nil :: proc(me: ^godot.Variant) {
  gd.gde_interface.variant_new_nil(cast(gd.GDExtensionVariantPtr)&me.opaque[0])
}
destroy :: proc(me: ^godot.Variant) {
  gd.gde_interface.variant_destroy(cast(gd.GDExtensionVariantPtr)&me.opaque[0])
}
`)

		// ptr to arg stuff ------------------------------
		ptr_to_arg := get_ptr_to_arg()

		idx := 0
		for k, v in ptr_to_arg {
			if v[0] == "BOOL" || v[0] == "INT" || v[0] == "FLOAT" {
				os.write_string(fd, fmt.tprintf(`
constructor%d :: proc(me: ^godot.Variant, val: %s) {{
  lval : %s = cast(%s)val
  from_type_constructor(cast(int)godot.VariantType.%s)(cast(gd.GDExtensionVariantPtr)&me.opaque[0], cast(gd.GDExtensionTypePtr)&lval)
}}
to_type%d :: proc(me: ^godot.Variant, ret: ^%s) {{
  lval : %s
  to_type_constructor(cast(int)godot.VariantType.%s)(cast(gd.GDExtensionTypePtr)&lval, cast(gd.GDExtensionVariantPtr)&me.opaque[0])
  ret^ = lval
}}
`, idx, k, v[1], v[1], v[0], idx, k, k, v[0]))
				
			} else if v[0] == "OBJECT" {
				os.write_string(fd, fmt.tprintf(`
constructor%d :: proc(me: ^godot.Variant, val: %s) {{
  if val != nil {{
    from_type_constructor(cast(int)godot.VariantType.%s)(cast(gd.GDExtensionVariantPtr)&me.opaque[0], cast(gd.GDExtensionTypePtr)val)
  }} else {{
    nullobj : godot.GodotObject = nil
    from_type_constructor(cast(int)godot.VariantType.%s)(cast(gd.GDExtensionVariantPtr)&me.opaque[0], cast(gd.GDExtensionTypePtr)&nullobj)
  }}
}}
to_type%d :: proc(me: ^godot.Variant, ret: %s) {{
  to_type_constructor(cast(int)godot.VariantType.%s)(cast(gd.GDExtensionTypePtr)ret, cast(gd.GDExtensionVariantPtr)&me.opaque[0])
}}
`, idx, k, v[0], v[0], idx, k, v[0]))
				
			}else {
				os.write_string(fd, fmt.tprintf(`
constructor%d :: proc(me: ^godot.Variant, val: %s) {{
  from_type_constructor(cast(int)godot.VariantType.%s)(cast(gd.GDExtensionVariantPtr)&me.opaque[0], cast(gd.GDExtensionTypePtr)&val.opaque[0])
}}
to_type%d :: proc(me: ^godot.Variant, ret: %s) {{
  to_type_constructor(cast(int)godot.VariantType.%s)(cast(gd.GDExtensionTypePtr)&ret.opaque[0], cast(gd.GDExtensionVariantPtr)&me.opaque[0])
}}
`, idx, k, v[0], idx, k, v[0]))
				
			}
			idx += 1
		}

		// special string constructor ------------------------------
		os.write_string(fd, fmt.tprintf(`
constructor_string :: proc(me: ^godot.Variant, str: string) {{
  val := new(godot.String); defer free(val)
			
  str := strings.clone_to_cstring(str)
  gd.gde_interface.string_new_with_latin1_chars(cast(gd.GDExtensionStringPtr)&val.opaque[0], str)
  delete(str)

  from_type_constructor(cast(int)godot.VariantType.STRING)(cast(gd.GDExtensionVariantPtr)&me.opaque[0], cast(gd.GDExtensionTypePtr)&val.opaque[0])
}}
to_type_string :: proc(me: ^godot.Variant, ret: ^string) {{
	s := new(godot.String); defer free(s)
	to_type(me, s)
	length := gd.gde_interface.string_to_latin1_chars(cast(gd.GDExtensionConstStringPtr)s, nil, 0)
	cstr := make([]byte, length); defer delete(cstr)
	gd.gde_interface.string_to_latin1_chars(cast(gd.GDExtensionConstStringPtr)s, cstring(&cstr[0]), length)
	ret^ = string(cstr)
}}
`))
		// ------------------------------
		
		os.write_string(fd, "constructor :: proc{")
		idx = 0
		for _, _ in ptr_to_arg {
			os.write_string(fd, fmt.tprintf("constructor%d%s", idx, ", "))
			idx += 1
		}
		os.write_string(fd, fmt.tprintf("constructor_string"))
		os.write_string(fd, "}\n")
		os.write_string(fd, "to_type :: proc{")
		idx = 0
		for _, _ in ptr_to_arg {
			os.write_string(fd, fmt.tprintf("to_type%d%s", idx, idx!=len(ptr_to_arg)-1 ? ", " : ""))
			idx += 1
		}
		os.write_string(fd, "}\n")

		// special converting  any <-> Variant  stuff ---
		os.write_string(fd, "\n\n")
		os.write_string(fd, "convert_variant :: proc(v: ^godot.Variant) -> any {\n")
		os.write_string(fd, "  a : any\n")
		os.write_string(fd, "  vtype := gd.gde_interface.variant_get_type(cast(gd.GDExtensionConstVariantPtr)v)\n")

		os.write_string(fd, "  if vtype == gd.GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_STRING {\n")
		os.write_string(fd, "    str := new(string); defer free(str)\n")
		os.write_string(fd, "    to_type_string(v, str)\n")
		os.write_string(fd, "    a = str^\n")
		os.write_string(fd, "  }\n")
		vtoa : map[string]string
		for k, v in ptr_to_arg { // reverse map look up
			if !(v[0] in vtoa) {
				vtoa[v[0]] = k
			}
		}
		for k, v in vtoa {
			if k == "STRING" do continue
			os.write_string(fd, fmt.tprintf("  if vtype == gd.GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_%s {{\n", k))
			if strings.has_prefix(v, "^") {
				os.write_string(fd, fmt.tprintf("    to_type(v, a.(%s))\n", v))
			} else {
				os.write_string(fd, fmt.tprintf("    to_type(v, a.(^%s))\n", v))
			}
			os.write_string(fd, fmt.tprintf("  }}\n"))
		}
		os.write_string(fd, "  return a\n")
		os.write_string(fd, "}\n")
		
		os.write_string(fd, "convert_any :: proc(a: any) -> ^godot.Variant {\n")
		os.write_string(fd, "  arg := new(godot.Variant)\n")
		os.write_string(fd, "  if a.id == string {\n")
		os.write_string(fd, "    constructor(arg, a.(string))\n")
		os.write_string(fd, "  }\n")
		for k, _ in ptr_to_arg {
			os.write_string(fd, fmt.tprintf("  if a.id == %s {{\n", k))
			os.write_string(fd, fmt.tprintf("    constructor(arg, a.(%s))\n", k))
			os.write_string(fd, fmt.tprintf("  }}\n"))
		}
		os.write_string(fd, "  return arg\n")		
		os.write_string(fd, "}\n")
		// ------------------------------
		
	}
}

correct_operator :: proc(op: string) -> string {
	switch op {
		// comparison
	case "==":
		return "OP_EQUAL"
	case "!=":
		return "OP_NOT_EQUAL"
	case "<":
		return "OP_LESS"
	case "<=":
		return "OP_LESS_EQUAL"
	case ">":
		return "OP_GREATER"
	case ">=":
		return "OP_GREATER_EQUAL"
	// mathematic
	case "+":
		return "OP_ADD"
	case "-":
		return "OP_SUBTRACT"
	case "*":
		return "OP_MULTIPLY"
	case "/":
		return "OP_DIVIDE"
	case "unary-":
		return "OP_NEGATE"
	case "unary+":
		return "OP_POSITIVE"
	case "%":
		return "OP_MODULE"
	// bitwise
	case "<<":
		return "OP_SHIFT_LEFT"
	case ">>":
		return "OP_SHIFT_RIGHT"
	case "&":
		return "OP_BIT_AND"
	case "|":
		return "OP_BIT_OR"
	case "^":
		return "OP_BIT_XOR"
	case "~":
		return "OP_BIT_NEGATE"
	// logic
	case "&&":
		return "OP_AND"
	case "||":
		return "OP_OR"
	case "xor":
		return "OP_XOR"
	case "!":
		return "OP_NOT"
	// containment
	case "in":
		return "OP_IN"
	}	
	fmt.printf("Unhandled OPERATOR %s\n", op)
	return ""
}

generate_builtin_classes :: proc(builtin_api: json.Object, target_dir: string, size: int, used_classes: ^[dynamic]string, fully_used_classes: ^[dynamic]string, sfd: os.Handle, g: ^Globals) {
  generate_variant_class(target_dir, g)
	
	class_name := fmt.tprintf("%s", builtin_api["name"])
	snake_class_name := camel_to_snake(class_name)
	dir := fmt.tprintf("%s/%s", target_dir, snake_class_name)
	class_file := fmt.tprintf("%s/%s%s", dir, snake_class_name, ".odin")

  // instead of making an odin struct "fit" what a class should be
	// make a package of snake_class_name that contains NO member variables/data struct(class_name) but
	// does contain all member functions(as procs), constructors, destructor, operators, etc.. of the class
	// note1: packages are directory based, so all class procs will be packages/sub-directories of godot
	// note2: and all (:: structs) will be in "godot" package (structures.odin)
	os.make_directory(dir)
	
	mode: int = 0
	when os.OS == .Linux || os.OS == .Darwin {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}

	os.remove(class_file)

	fd, err := os.open(class_file, os.O_WRONLY|os.O_CREATE, mode)
	
	defer os.close(fd)
	if err == os.ERROR_NONE {
		os.write_string(fd, fmt.tprintf("package %s\n\n", snake_class_name))
		os.write_string(fd, "// builtin\n")
		os.write_string(fd, "import godot \"../../gen\"\n")
		os.write_string(fd, "import gd \"../../../../godot_odin\"\n\n")

		// Special cases.
		if class_name == "String" || class_name == "StringName" {
			os.write_string(fd, "import \"core:strings\"\n")
			os.write_string(fd, "import \"../variant\"\n")
			
			if class_name == "String" {
				os.write_string(fd, `// helper function
_to_string :: proc(sn: ^godot.String, s: string) {
	tmp := strings.clone_to_cstring(s); defer delete(tmp)
  gd.gde_interface.string_new_with_utf8_chars(cast(gd.GDExtensionStringPtr)sn, tmp)

  clean_string_names(sn)
}
_to_string_name :: proc(sn: ^godot.StringName, s: string) {
	str : godot.String
	tmp := strings.clone_to_cstring(s); defer delete(tmp)
  gd.gde_interface.string_new_with_utf8_chars(cast(gd.GDExtensionStringPtr)&str, tmp)
	p : gd.GDExtensionPtrConstructor
	call_args : [1]rawptr
	call_args[0] = &str
	p = gd.gde_interface.variant_get_ptr_constructor(gd.GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_STRING_NAME, 2)
	p(cast(gd.GDExtensionTypePtr)&sn.opaque[0], cast(gd.GDExtensionConstTypePtr)&call_args[0])

  clean_string_names(sn)
}
clean_string_names :: proc(ptr: rawptr = nil) {
  @static names : [dynamic]rawptr
  if ptr == nil {
    for p in names {
      free(p)
    }
		delete(names)
    return
  }
  append(&names, ptr)
}
`)
			}
		}
		if class_name != "String" {
			os.write_string(fd, "import gstring \"../string\"\n") // for _to_string_name
		}

		if class_name == "Vector2" || class_name == "Vector3" || class_name == "Vector4" {
			os.write_string(fd, "import \"core:math\"\n")
		}

		if class_name == "PackedStringArray" {
			os.write_string(fd, "import \"core:strings\"\n")
		}
		if class_name == "PackedColorArray" {
			os.write_string(fd, "import \"core:strings\"\n") // TODO color.hpp
		} // TODO ...

		if class_name == "Array" {
			os.write_string(fd, "import \"core:container/small_array\"\n")
		}

		if class_name == "Dictionary" {
			os.write_string(fd, "import \"../variant\"\n")
		}

		for include in fully_used_classes {
			if include == "TypedArray" {
				os.write_string(fd, "import \"core:fmt\"\n")
			} else {
				os.write_string(fd, "import \"core:fmt\"\n")
			}
		}
		if len(fully_used_classes) > 0 do os.write_string(fd, "\n")


		// Create struct in builtin_structures.odin
		os.write_string(sfd, fmt.tprintf("%s_SIZE :: %d\n", class_name, size))
		os.write_string(sfd, fmt.tprintf("%s :: struct {{\n", class_name))

    os.write_string(sfd, fmt.tprintf("  opaque : [%s_SIZE]u8,\n", class_name))
		if "members" in builtin_api {
			for member in builtin_api["members"].(json.Array) {
				name := fmt.tprintf("%s", member.(json.Object)["name"])
				type := fmt.tprintf("%s", member.(json.Object)["type"])
				//fmt.println(name, correct_type(type, "", g))
				os.write_string(sfd, fmt.tprintf("  %s : %s,\n", name, correct_type(type, "", g)))
			}
		}
		
		os.write_string(sfd, "}\n\n")
		os.write_string(fd, "// Constants ------------------------------\n")
		// ------------------------------

		g.pck = "godot."
		
		if "constants" in builtin_api {
			axis_constants_count := 0
			for constant in builtin_api["constants"].(json.Array) {
				// Special case: Vector3.Axis is the only enum in the bindings.
				// It's technically not supported by Variant but works for direct access.
				name := fmt.tprintf("%s", constant.(json.Object)["name"])
				type := fmt.tprintf("%s", constant.(json.Object)["type"])
				valu := fmt.tprintf("%s", constant.(json.Object)["value"])

				if class_name == "Vector3" && strings.has_prefix(name, "AXIS") {
					if axis_constants_count == 0 {
						os.write_string(fd, fmt.tprintf("\nAxis :: enum {{\n"))
					}
					os.write_string(fd, fmt.tprintf("  %s = %s,\n", name, valu))
					axis_constants_count += 1
					if axis_constants_count == 3 {
						os.write_string(fd, fmt.tprintf("}\n"))
					}
				} else {
					if strings.has_prefix(valu, "Vector2") { // opaque and 2 floats
						valu, _ = strings.replace_all(valu, "(", "{")
						valu, _ = strings.replace_all(valu, ")", "}")
						idx := strings.index(valu, "{")
						spl := strings.split(valu[idx+1:], ",")
						valu = fmt.tprintf("%s%s0, %s,%s", g.pck, valu[0:idx+1], spl[0], spl[1])
						valu, _ = strings.replace_all(valu, "inf", "math.inf_f32(1)")
					}

					if strings.has_prefix(valu, "Vector3") { // opaque and 3 floats
						valu, _ = strings.replace_all(valu, "(", "{")
						valu, _ = strings.replace_all(valu, ")", "}")
						idx := strings.index(valu, "{")
						spl := strings.split(valu[idx+1:], ",")
						valu = fmt.tprintf("%s%s0, %s,%s,%s", g.pck, valu[0:idx+1], spl[0], spl[1], spl[2])
						valu, _ = strings.replace_all(valu, "inf", "math.inf_f32(1)")
					}
					
					if strings.has_prefix(valu, "Vector4") { // opaque and 4 floats
						valu, _ = strings.replace_all(valu, "(", "{")
						valu, _ = strings.replace_all(valu, ")", "}")
						idx := strings.index(valu, "{")
						spl := strings.split(valu[idx+1:], ",")
						valu = fmt.tprintf("%s%s0, %s,%s,%s,%s", g.pck, valu[0:idx+1], spl[0], spl[1], spl[2], spl[3])
						valu, _ = strings.replace_all(valu, "inf", "math.inf_f32(1)")
					}

					if strings.has_prefix(valu, "Color") { // opaque, 4 floats(rgba), 4 ints(rgba_int), 3 float(hsv)
						valu, _ = strings.replace_all(valu, "(", "{")
						valu, _ = strings.replace_all(valu, ")", "}")
						idx := strings.index(valu, "{")
						spl := strings.split(valu[idx+1:], ",")
						spl[3], _ = strings.replace_all(spl[3], "}", "")
						valu = fmt.tprintf("%s%s0, %s,%s,%s,%s,0,0,0,0,0,0,0}", g.pck, valu[0:idx+1], spl[0], spl[1], spl[2], spl[3])
					}

					if strings.has_prefix(valu, "Transform2D") {  // opaque and 3 vector2's
						valu, _ = strings.replace_all(valu, "(", "{")
						valu, _ = strings.replace_all(valu, ")", "}")
						idx := strings.index(valu, "{")
						spl := strings.split(valu[idx+1:], ",")
						x := fmt.tprintf("0,%s,%s", spl[0], spl[1])
						y := fmt.tprintf("0,%s,%s", spl[2], spl[3])
						o := fmt.tprintf("0,%s,%s", spl[4], spl[5])
						valu = fmt.tprintf("%s%s0,{{%s}},{{%s}},{{%s}}", g.pck, valu[0:idx+1], x, y, o)
					}
					
					os.write_string(fd, fmt.tprintf("%s : %s = %s\n", name, correct_type(type, "", g), valu))
				}
			}
		}

		os.write_string(fd, "\n// Constructors Destructor ------------------------------\n")

		if "constructors" in builtin_api {
			for constructor in builtin_api["constructors"].(json.Array) {
				idx, _ := strconv.parse_int(fmt.tprintf("%f", constructor.(json.Object)["index"]))
				method_signature := fmt.tprintf("constructor%d :: proc(me: ^%s", idx, correct_type(class_name, "", g))
				arguments : [dynamic]string; defer delete(arguments)
				if "arguments" in constructor.(json.Object) {
					for argument, i in constructor.(json.Object)["arguments"].(json.Array) {
						name := fmt.tprintf("%s", argument.(json.Object)["name"])
						type := fmt.tprintf("%s", argument.(json.Object)["type"])
						tmp := ""
						if type == "bool" {
							tmp = fmt.tprintf("bval%d := %s ? 1 : 0\n  call_args[%d] = cast(gd.GDExtensionConstTypePtr)&bval%d", i, escape_identifier(name), i, i)
						} else if type == "int" {
							tmp = fmt.tprintf("val%d := %s; call_args[%d] = cast(gd.GDExtensionConstTypePtr)&val%d", i, escape_identifier(name), i, i)
						} else if type == "float" {
							tmp = fmt.tprintf("val%d := cast(f64)%s; call_args[%d] = cast(gd.GDExtensionConstTypePtr)&val%d", i, escape_identifier(name), i, i)
						} else {
							tmp = fmt.tprintf("call_args[%d] = cast(gd.GDExtensionConstTypePtr)%s", i, escape_identifier(name))
						}
						
						append(&arguments, strings.clone(tmp))
					}
				}
				
				if "arguments" in constructor.(json.Object) {
					args := constructor.(json.Object)["arguments"]
					arg_type := fmt.tprintf("%s", args.(json.Array)[0].(json.Object)["type"])
					
					method_signature = fmt.tprintf("%s, %s", method_signature,
																				 make_function_parameters(args.(json.Array), g, true, true))					
				}
				method_signature = fmt.tprintf("%s) {{\n", method_signature)
				os.write_string(fd, method_signature)
				os.write_string(fd, fmt.tprintf("  @static constructor_%d : gd.GDExtensionPtrConstructor\n", idx)) // TODO: assign to me's proc ptr instead?
				l := len(arguments) > 0 ? len(arguments) : 1
				os.write_string(fd, fmt.tprintf("  call_args : [%d]rawptr\n", l))
				for a in arguments {
					os.write_string(fd, fmt.tprintf("  %s\n", a))
				}
				os.write_string(fd, fmt.tprintf("  if constructor_%d == nil do constructor_%d = gd.gde_interface.variant_get_ptr_constructor(gd.GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_%s, %d)\n", idx, idx, strings.to_upper(snake_class_name), idx))
				os.write_string(fd, fmt.tprintf("  constructor_%d(cast(gd.GDExtensionTypePtr)&me.opaque[0], cast(gd.GDExtensionConstTypePtr)&call_args[0])\n", idx))
				os.write_string(fd, "}\n")
			}

			if class_name == "String" || class_name == "StringName" {
				// generate custom string proc constructors here
				if class_name == "String" {
					os.write_string(fd, fmt.tprintf("constructor_string :: proc(me: ^%s", correct_type(class_name, "", g)))
					os.write_string(fd, ", s: string) {\n")
					os.write_string(fd, "  str := strings.clone_to_cstring(s)\n")
					os.write_string(fd, "  gd.gde_interface.string_new_with_latin1_chars(cast(gd.GDExtensionStringPtr)&me.opaque[0], str)\n")
					os.write_string(fd, "  delete(str)\n")
					os.write_string(fd, "}\n")
					os.write_string(fd, fmt.tprintf("to_string :: proc(me: ^%s) -> string {{\n", correct_type(class_name, "", g)))
					os.write_string(fd, "  data_len := gd.gde_interface.string_to_latin1_chars(cast(gd.GDExtensionConstStringPtr)&me.opaque[0], nil, 0)\n")
					os.write_string(fd, "  data := make([]u8, data_len+1); defer delete(data)\n")
					os.write_string(fd, "  gd.gde_interface.string_to_latin1_chars(cast(gd.GDExtensionConstStringPtr)&me.opaque[0], cast(cstring)&data[0], data_len)\n")
					os.write_string(fd, "  data[data_len] = 0\n")
					os.write_string(fd, "  return string(data)\n")					
					os.write_string(fd, "}\n")
					
				} else {
					os.write_string(fd, fmt.tprintf("constructor_string :: proc(me: ^%s", correct_type(class_name, "", g)))
					os.write_string(fd, ", s: string) {\n")
					os.write_string(fd, "  str := new(godot.String)\n")
					os.write_string(fd, "  gstring.constructor_string(str, s)\n")
					os.write_string(fd, "  constructor2(me, str)\n")
					os.write_string(fd, "  free(str)\n")					
					os.write_string(fd, "}\n")
					
				}
			}
			
			os.write_string(fd, "constructor :: proc{")
			for constructor in builtin_api["constructors"].(json.Array) {
				idx, _ := strconv.parse_int(fmt.tprintf("%f", constructor.(json.Object)["index"]))
				s := idx > 0 ? ", " : ""
				os.write_string(fd, fmt.tprintf("%sconstructor%d", s, idx))
			}
			if class_name == "String" || class_name == "StringName" {
				os.write_string(fd, fmt.tprintf(", constructor_string"))
			}
			os.write_string(fd, "}\n")
		}
		
		if builtin_api["has_destructor"].(json.Boolean) {
			method_signature := fmt.tprintf("destructor :: proc(me: ^%s", correct_type(class_name, "", g))
			method_signature = fmt.tprintf("%s) {{\n", method_signature)
			os.write_string(fd, method_signature)
			os.write_string(fd, fmt.tprintf("  @static destructor : gd.GDExtensionPtrDestructor\n"))
			os.write_string(fd, fmt.tprintf("  if destructor == nil do destructor = gd.gde_interface.variant_get_ptr_destructor(gd.GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_%s)\n", strings.to_upper(snake_class_name)))
			os.write_string(fd, fmt.tprintf("  destructor(cast(gd.GDExtensionTypePtr)&me.opaque)\n"))
			os.write_string(fd, "}\n")
		}
		
		os.write_string(fd, "\n// Methods ------------------------------\n")
		
		method_list : [dynamic]string
		if "methods" in builtin_api {
			for method in builtin_api["methods"].(json.Array) {
				method_name := fmt.tprintf("%s", method.(json.Object)["name"])
        hash, _ := strconv.parse_int(fmt.tprintf("%f", method.(json.Object)["hash"]))
				enum_type_name := fmt.tprintf("GDEXTENSION_VARIANT_TYPE_%s", strings.to_upper(snake_class_name))
				if method_name == "map" do method_name = "_map"
				append(&method_list, method_name)
				
				method_signature := fmt.tprintf("%s :: proc(me: ^%s", method_name, correct_type(class_name, "", g))
				vararg := cast(bool) method.(json.Object)["is_vararg"].(json.Boolean)
				if "arguments" in method.(json.Object) {				
					method_signature = fmt.tprintf("%s, %s", method_signature,
																				 make_function_parameters(method.(json.Object)["arguments"].(json.Array), g, true, true, vararg))
				}
				method_signature = fmt.tprintf("%s)", method_signature)				
				if "is_static" in method.(json.Object) && method.(json.Object)["is_static"].(json.Boolean) {
					//method_signature = fmt.tprintf("%s", method_signature) // TODO??
				}
				if "return_type" in method.(json.Object) {
					return_type := fmt.tprintf("%s", method.(json.Object)["return_type"])
					pta := get_ptr_to_arg()
					crt := correct_type(return_type, "", g)
					ptr := "^"
					if crt in pta {
						ptr = ""
					}
					
					method_signature = fmt.tprintf("%s -> %s%s", method_signature, ptr, crt)
					
				}
				os.write_string(fd, method_signature)
				os.write_string(fd, fmt.tprintf(" {{\n"))

				os.write_string(fd, fmt.tprintf("  @static name : ^godot.StringName\n"))				
				os.write_string(fd, fmt.tprintf("  @static method : gd.GDExtensionPtrBuiltInMethod\n"))
				os.write_string(fd, fmt.tprintf("  if name == nil {{\n"))
				os.write_string(fd, fmt.tprintf("    name = new(godot.StringName); %s_to_string_name(name, \"%s\")\n", class_name!="String"?"gstring.":"", method_name))
				os.write_string(fd, fmt.tprintf("    method = gd.gde_interface.variant_get_ptr_builtin_method(gd.GDExtensionVariantType.%s, cast(gd.GDExtensionConstStringNamePtr)&name.opaque[0], %d)\n", enum_type_name, hash))
				os.write_string(fd, fmt.tprintf("  }}\n"))

				arguments : [dynamic]string; defer delete(arguments)
				if "arguments" in method.(json.Object) {
					for argument, i in method.(json.Object)["arguments"].(json.Array) {
						name := fmt.tprintf("%s", argument.(json.Object)["name"])
						type := fmt.tprintf("%s", argument.(json.Object)["type"])
						tmp : string
						if type == "bool" {
							tmp = fmt.tprintf("bval%d := %s ? 1 : 0\n  call_args[%d] = cast(gd.GDExtensionConstTypePtr)&bval%d", i, escape_identifier(name), i, i)
						} else {
							if strings.has_prefix(correct_type(type, "", g), "godot") {
								tmp = fmt.tprintf("val%d := %s; call_args[%d] = cast(gd.GDExtensionConstTypePtr)val%d", i, escape_identifier(name), i, i)
							} else {
								tmp = fmt.tprintf("val%d : %s; val%d = %s; call_args[%d] = cast(gd.GDExtensionConstTypePtr)&val%d", i, correct_type(type, "", g), i, escape_identifier(name), i, i)
							}
						}
						append(&arguments, strings.clone(tmp))
					}
				}
				l := len(arguments) > 0 ? len(arguments) : 1
				os.write_string(fd, fmt.tprintf("  call_args : [%d]rawptr\n", l))
				for a in arguments {
					os.write_string(fd, fmt.tprintf("  %s\n", a))
				}
				
        if "return_type" in method.(json.Object) {
					return_type := fmt.tprintf("%s", method.(json.Object)["return_type"])
					pta := get_ptr_to_arg()
					crt := correct_type(return_type, "", g)
					crt_with_ptr := fmt.tprintf("^%s", crt)
					ptr := ""
					if crt_with_ptr in pta || crt == "godot.Variant" {
						ptr = "^"
					}

					if ptr == "^" {
						os.write_string(fd, fmt.tprintf("  ret := new(%s)\n", crt))
						os.write_string(fd, fmt.tprintf("  method(cast(gd.GDExtensionTypePtr)&me.opaque[0], cast(gd.GDExtensionConstTypePtr)&call_args[0], cast(gd.GDExtensionTypePtr)ret, %d)\n", len(arguments)))
					} else {
						os.write_string(fd, fmt.tprintf("  ret : %s\n", crt))
						os.write_string(fd, fmt.tprintf("  method(cast(gd.GDExtensionTypePtr)&me.opaque[0], cast(gd.GDExtensionConstTypePtr)&call_args[0], cast(gd.GDExtensionTypePtr)&ret, %d)\n", len(arguments)))
					}
	        
					os.write_string(fd, fmt.tprintf("  return ret\n"))
				} else {
          os.write_string(fd, fmt.tprintf("  method(cast(gd.GDExtensionTypePtr)&me.opaque[0], cast(gd.GDExtensionConstTypePtr)&call_args[0], nil, %d)\n", len(arguments)))
				}
				os.write_string(fd, "}\n")
			}
		}

		if class_name == "String" {
			//os.write_string(fd, "utf8 :: proc(from: ^char, len: int=-1) -> string {}\n")
			//os.write_string(fd, "parse_utf8 :: proc(from: ^char, len: int=-1) {}\n")
			//os.write_string(fd, "utf16 :: proc(from: ^char, len: int=-1) -> string {}\n")
			//os.write_string(fd, "parse_utf16 :: proc(from: ^char, len: int=-1)\n")
			// more TODO
		}

		//if "members" in builtin_api {
		//	for member in builtin_api["members"].(json.Array) {
		//		getname := fmt.tprintf("get_%s", member.(json.Object)["name"])
		//		setname := fmt.tprintf("set_%s", member.(json.Object)["name"])				
		//		type := fmt.tprintf("%s", member.(json.Object)["type"])
		//		if !(slice.contains(method_list[:], getname)) {
		//			os.write_string(fd, fmt.tprintf("%s :: proc() -> %s\n", getname, correct_type(type, "", g)))
		//		}
		//		if !(slice.contains(method_list[:], setname)) {
		//			os.write_string(fd, fmt.tprintf("%s :: proc() -> %s\n", setname, correct_type(type, "", g)))
		//		}
		//	}
		//}

		if "indexing_return_type" in builtin_api {
			type := fmt.tprintf("%s", builtin_api["indexing_return_type"])
			cname := correct_type(class_name, "", g)
			ctype := correct_type(type, "", g)
			if strings.contains(cname, "Int32") do ctype = "i32"
			if strings.contains(cname, "Int64") do ctype = "i64"
			if strings.contains(cname, "Float32") do ctype = "f32"
			if strings.contains(cname, "Float64") do ctype = "f64"

			gdproc_map : map[string]string
			gdproc_map["Array"] = "array_operator_index"
			gdproc_map["PackedByteArray"] = "packed_byte_array_operator_index"
			gdproc_map["PackedColorArray"] = "packed_color_array_operator_index"
			gdproc_map["PackedFloat32Array"] = "packed_float32_array_operator_index"
			gdproc_map["PackedFloat64Array"] = "packed_float64_array_operator_index"
			gdproc_map["PackedInt32Array"] = "packed_int32_array_operator_index"
			gdproc_map["PackedInt64Array"] = "packed_int64_array_operator_index"
			gdproc_map["PackedStringArray"] = "packed_string_array_operator_index"
			gdproc_map["PackedVector2Array"] = "packed_vector2_array_operator_index"
			gdproc_map["PackedVector3Array"] = "packed_vector3_array_operator_index"

			if class_name in gdproc_map {
				os.write_string(fd, fmt.tprintf("set_idx :: proc(me: ^%s, #any_int idx: int, v: ^%s) {{\n", cname, ctype))
				os.write_string(fd, fmt.tprintf("  self := cast(gd.GDExtensionTypePtr)me\n"))
				os.write_string(fd, fmt.tprintf("  (cast(^%s)gd.gde_interface.%s(self, cast(gd.GDExtensionInt)idx))^ = v^\n", ctype, gdproc_map[class_name]))
				os.write_string(fd, fmt.tprintf("}}\n"))
				os.write_string(fd, fmt.tprintf("get_idx :: proc(me: ^%s, #any_int idx: int) -> ^%s {{\n", cname, ctype))
				os.write_string(fd, fmt.tprintf("  self := cast(gd.GDExtensionTypePtr)me\n"))			
				os.write_string(fd, fmt.tprintf("  return cast(^%s)gd.gde_interface.%s(self, cast(gd.GDExtensionInt)idx)\n", ctype, gdproc_map[class_name]))
				os.write_string(fd, fmt.tprintf("}}\n"))
				
			} else {
				os.write_string(fd, fmt.tprintf("set_idx :: proc(me: ^%s, idx: int, v: ^%s) {{\n", cname, ctype))
				os.write_string(fd, fmt.tprintf("  self := cast(gd.GDExtensionVariantPtr)me\n"))
				os.write_string(fd, fmt.tprintf("  valid : gd.GDExtensionBool\n"))
				os.write_string(fd, fmt.tprintf("  oob : gd.GDExtensionBool\n"))
				os.write_string(fd, fmt.tprintf("  gd.gde_interface.variant_set_indexed(self, cast(gd.GDExtensionInt)idx, cast(gd.GDExtensionConstVariantPtr)v, &valid, &oob)\n"))
				os.write_string(fd, fmt.tprintf("}}\n"))
				os.write_string(fd, fmt.tprintf("get_idx :: proc(me: ^%s, idx: int) -> ^%s {{\n", cname, ctype))
				os.write_string(fd, fmt.tprintf("  self := cast(gd.GDExtensionConstVariantPtr)me\n"))
				os.write_string(fd, fmt.tprintf("  valid : gd.GDExtensionBool\n"))
				os.write_string(fd, fmt.tprintf("  oob : gd.GDExtensionBool\n"))
				os.write_string(fd, fmt.tprintf("  ret := new(%s)\n", ctype))
				os.write_string(fd, fmt.tprintf("  gd.gde_interface.variant_get_indexed(self, cast(gd.GDExtensionInt)idx, cast(gd.GDExtensionVariantPtr)ret, &valid, &oob)\n"))
				os.write_string(fd, fmt.tprintf("  return ret"))
				os.write_string(fd, fmt.tprintf("}}\n"))
			}
		}
		
		if class_name == "Array" {
			// type should be OBJECT if class_name is something.. TODO: what is/does script do?
			os.write_string(fd, fmt.tprintf("set_typed :: proc(me: ^godot.Array, type: gd.GDExtensionVariantType, class_name: gd.GDExtensionConstStringNamePtr) {{\n"))
			os.write_string(fd, fmt.tprintf("  script := new(godot.Variant); defer free(script)\n")) // what is this?
			os.write_string(fd, fmt.tprintf("  gd.gde_interface.array_set_typed(cast(gd.GDExtensionTypePtr)me, type, class_name, cast(gd.GDExtensionConstVariantPtr)&script)\n"))
			os.write_string(fd, fmt.tprintf("}}\n"))
		}

		if "is_keyed" in builtin_api && builtin_api["is_keyed"].(json.Boolean) {
			// only Dictionary is keyed right.. for now
			//dictionary_operator_index : proc "c" (p_self: GDExtensionTypePtr, p_key: GDExtensionConstVariantPtr) -> GDExtensionVariantPtr, // p_self should be an Dictionary ptr
			// any variant can be key
			//pta["uint"] = {"INT", "i64"}
			pta := get_ptr_to_arg()
			vtoa : map[string]string
			for k, v in pta { // reverse map look up
				if !(v[0] in vtoa) {
					vtoa[v[0]] = k
				}
			}
			
			for k, v in vtoa {
				os.write_string(fd, fmt.tprintf("set_key_%s :: proc(me: ^godot.Dictionary, pk: %s, v: ^godot.Variant) {{\n", k, v))
				os.write_string(fd, fmt.tprintf("  self := cast(gd.GDExtensionTypePtr)me\n"))
				os.write_string(fd, fmt.tprintf("  k := new(godot.Variant)\n"))
				os.write_string(fd, fmt.tprintf("  variant.constructor(k, pk)\n"))
				os.write_string(fd, fmt.tprintf("  (cast(^godot.Variant)gd.gde_interface.dictionary_operator_index(self, cast(gd.GDExtensionConstVariantPtr)k))^ = v^\n"))
				os.write_string(fd, fmt.tprintf("}}\n"))
				os.write_string(fd, fmt.tprintf("get_key_%s :: proc(me: ^godot.Dictionary, pk: %s) -> ^godot.Variant {{\n", k, v))
				os.write_string(fd, fmt.tprintf("  self := cast(gd.GDExtensionTypePtr)me\n"))
				os.write_string(fd, fmt.tprintf("  k := new(godot.Variant)\n"))
				os.write_string(fd, fmt.tprintf("  variant.constructor(k, pk)\n"))
				os.write_string(fd, fmt.tprintf("  return cast(^godot.Variant)gd.gde_interface.dictionary_operator_index(self, cast(gd.GDExtensionConstVariantPtr)k)\n"))
				os.write_string(fd, fmt.tprintf("}}\n"))
			}
			os.write_string(fd, fmt.tprintf("set_key_str :: proc(me: ^godot.Dictionary, pk: string, pv: string) {{\n"))
			os.write_string(fd, fmt.tprintf("  self := cast(gd.GDExtensionTypePtr)me\n"))
			os.write_string(fd, fmt.tprintf("  k := new(godot.Variant); defer free(k)\n"))
			os.write_string(fd, fmt.tprintf("  variant.constructor(k, pk)\n"))
			os.write_string(fd, fmt.tprintf("  v := new(godot.Variant); defer free(v)\n"))
			os.write_string(fd, fmt.tprintf("  variant.constructor(v, pv)\n"))
			os.write_string(fd, fmt.tprintf("  (cast(^godot.Variant)gd.gde_interface.dictionary_operator_index(self, cast(gd.GDExtensionConstVariantPtr)k))^ = v^\n"))
			os.write_string(fd, fmt.tprintf("}}\n"))			
			os.write_string(fd, fmt.tprintf("get_key_str :: proc(me: ^godot.Dictionary, pk: string) -> ^godot.Variant {{\n"))
			os.write_string(fd, fmt.tprintf("  self := cast(gd.GDExtensionTypePtr)me\n"))
			os.write_string(fd, fmt.tprintf("  k := new(godot.Variant)\n"))
			os.write_string(fd, fmt.tprintf("  variant.constructor(k, pk)\n"))
			os.write_string(fd, fmt.tprintf("  return cast(^godot.Variant)gd.gde_interface.dictionary_operator_index(self, cast(gd.GDExtensionConstVariantPtr)k)\n"))
			os.write_string(fd, fmt.tprintf("}}\n"))			
			
			os.write_string(fd, fmt.tprintf("set_key :: proc{{\n"))
			for k, v in vtoa {
				os.write_string(fd, fmt.tprintf("set_key_%s,", k))
			}
			os.write_string(fd, fmt.tprintf("set_key_str"))
			os.write_string(fd, fmt.tprintf("}}\n"))
			os.write_string(fd, fmt.tprintf("get_key :: proc{{\n"))
			for k, v in vtoa {
				os.write_string(fd, fmt.tprintf("get_key_%s,", k))
			}
			os.write_string(fd, fmt.tprintf("get_key_str"))
			os.write_string(fd, fmt.tprintf("}}\n"))			
			//os.write_string(fd, fmt.tprintf("is_key :: proc{{}}\n")) // TODO
		}

		operators_map : map[string]int
		if "operators" in builtin_api {
			for operator in builtin_api["operators"].(json.Array) {
				operator_name := fmt.tprintf("%s", operator.(json.Object)["name"])
				right_type := fmt.tprintf("%s", operator.(json.Object)["right_type"])
				return_type := fmt.tprintf("%s", operator.(json.Object)["return_type"])
				is_unary := strings.contains(operator_name, "unary")
				non_unary_name, _ := strings.replace_all(operator_name, "unary", "")
				cop := correct_operator(operator_name)
				pta := get_ptr_to_arg()
				crt := correct_type(return_type, "", g)
				ptr := "^"
				if crt in pta {
					ptr = ""
				}
				
				if "right_type" in operator.(json.Object) {
					if !(cop in operators_map) {
						operators_map[cop] = 0
					}
					os.write_string(fd, fmt.tprintf("operator_%s%d :: proc(me: ^%s, other: %s) -> %s%s ", cop, operators_map[cop], correct_type(class_name, "", g), type_for_parameter(right_type, "", g), ptr, crt))
					operators_map[correct_operator(operator_name)] += 1
				} else {
					cop := correct_operator(non_unary_name)
					if !(cop in operators_map) {
						operators_map[cop] = 0
					}
					os.write_string(fd, fmt.tprintf("operator_%s :: proc(me: ^%s) -> %s%s ", cop, correct_type(class_name, "", g), ptr, crt))
				}

				os.write_string(fd, fmt.tprintf("{{\n"))
				enum_type_name := fmt.tprintf("GDEXTENSION_VARIANT_TYPE_%s", strings.to_upper(snake_class_name))
				os.write_string(fd, fmt.tprintf("  @static name : ^godot.String\n"))
				os.write_string(fd, fmt.tprintf("  @static operator : gd.GDExtensionPtrOperatorEvaluator\n"))
				os.write_string(fd, fmt.tprintf("  if name == nil {{\n"))
				os.write_string(fd, fmt.tprintf("    name = new(godot.String); %s_to_string(name, \"%s\")\n", class_name=="String" ? "" : "gstring.", operator_name))
				if right_type == "Variant" do right_type = "nil"
				snake_right_type := camel_to_snake(right_type)
				rt := fmt.tprintf("GDEXTENSION_VARIANT_TYPE_%s", strings.to_upper(snake_right_type))
				os.write_string(fd, fmt.tprintf("    operator = gd.gde_interface.variant_get_ptr_operator_evaluator(gd.GDExtensionVariantOperator.GDEXTENSION_VARIANT_%s, gd.GDExtensionVariantType.%s, gd.GDExtensionVariantType.%s)\n", cop, enum_type_name, rt))
				os.write_string(fd, fmt.tprintf("  }}\n"))

				if correct_type(return_type, "", g) == "bool" {
					os.write_string(fd, fmt.tprintf("  ret := new(int)\n"))
				} else {
					os.write_string(fd, fmt.tprintf("  ret := new(%s)\n", correct_type(return_type, "", g)))
				}
				if !is_unary {
					if type_for_parameter(right_type, "", g) == "bool" {
						os.write_string(fd, "  lother : int = other ? 1 : 0\n") // local other
					} else {
						os.write_string(fd, fmt.tprintf("  lother : %s = other\n", type_for_parameter(right_type, "", g)))
					}
					if strings.has_prefix(type_for_parameter(right_type, "", g), "^") {
						os.write_string(fd, fmt.tprintf("  operator(cast(gd.GDExtensionConstTypePtr)me, cast(gd.GDExtensionConstTypePtr)lother, cast(gd.GDExtensionTypePtr)ret)\n"))
					} else {
						os.write_string(fd, fmt.tprintf("  operator(cast(gd.GDExtensionConstTypePtr)me, cast(gd.GDExtensionConstTypePtr)&lother, cast(gd.GDExtensionTypePtr)ret)\n"))
					}
				} else {
					os.write_string(fd, fmt.tprintf("  operator(cast(gd.GDExtensionConstTypePtr)me, cast(gd.GDExtensionConstTypePtr)nil, cast(gd.GDExtensionTypePtr)ret)\n"))					
				}
				
				if correct_type(return_type, "", g) == "bool" {
					os.write_string(fd, "  return ret^ == 0 ? false : true")
				} else {
					os.write_string(fd, "  return ret")
				}
				os.write_string(fd, "\n}\n")
				
			}
		}
		for op_k, op_v in operators_map {
			os.write_string(fd, fmt.tprintf("%s :: proc{{", op_k))
			for i in 0..<op_v {
				os.write_string(fd, fmt.tprintf("%soperator_%s%d", i>0 ? ", " : "", op_k, i))
			}
			os.write_string(fd, "}\n")
		}

		g.pck = ""

	}

	// TODO: more "nice stuff" for builtin types
}

generate_builtin_bindings :: proc(root: json.Object, target_dir: string, build_config: string, g: ^Globals) {
	file := strings.concatenate([]string{target_dir, "/builtin_structures.odin"})
	mode: int = 0
	when os.OS == .Linux || os.OS == .Darwin {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}

	os.remove(file)
	fd, err := os.open(file, os.O_WRONLY|os.O_CREATE, mode)
	defer os.close(fd)
	if err == os.ERROR_NONE {
		os.write_string(fd, "package godot\n\n")
		os.write_string(fd, "import gd \"../../../godot_odin\"\n\n")
		g.pck = ""

    // Store types beforehand.
    for builtin_api in root["builtin_classes"].(json.Array) {
			name := fmt.tprintf("%s", builtin_api.(json.Object)["name"])
      if is_pod_type(name) do continue
      append(&g.builtin_classes, strings.clone(name))
		}

    builtin_sizes : map[string]int

		// Get sizes
    for size_list in root["builtin_class_sizes"].(json.Array) {
			bc := fmt.tprintf("%s", size_list.(json.Object)["build_configuration"])
      if bc == build_config {
        for size in size_list.(json.Object)["sizes"].(json.Array) {
					sname   := fmt.tprintf("%s", size.(json.Object)["name"])
					sval, _ := strconv.parse_int(fmt.tprintf("%f", size.(json.Object)["size"]))
					builtin_sizes[strings.clone(sname)] = sval
				}
				break
			}
		}

		// Variant, GodotObject, Wrapped, and Ref
		os.write_string(fd, fmt.tprintf("GODOT_ODIN_VARIANT_SIZE :: %d\n", builtin_sizes["Variant"]))
		os.write_string(fd, fmt.tprintf("Variant :: struct {{\n"))
		os.write_string(fd, fmt.tprintf("  opaque : [GODOT_ODIN_VARIANT_SIZE]u8,\n"))
		os.write_string(fd, fmt.tprintf("}}\n\n"))
		
		os.write_string(fd, fmt.tprintf("GodotObject :: distinct rawptr\n"))
		
		os.write_string(fd, fmt.tprintf("Wrapped :: struct {{\n"))
		//os.write_string(fd, fmt.tprintf("  plist_owned : [dynamic]gd.GDExtensionPropertyInfo,\n"))
		//os.write_string(fd, fmt.tprintf("  plist : ^gd.GDExtensionPropertyInfo,\n"))
		//os.write_string(fd, fmt.tprintf("  plist_size : u32,\n"))
		os.write_string(fd, fmt.tprintf("  _owner : rawptr, // GodotObject ptr\n"))
		os.write_string(fd, fmt.tprintf("}}\n\n"))

		os.write_string(fd, fmt.tprintf("Ref :: struct {{\n"))
		//os.write_string(fd, fmt.tprintf("  reference : rawptr,\n"))
		os.write_string(fd, fmt.tprintf("}}\n"))

		// Write something similar to class header/source files for odin
		for builtin_api in root["builtin_classes"].(json.Array) {
			name := fmt.tprintf("%s", builtin_api.(json.Object)["name"])
      if is_pod_type(name) { continue }
			if is_included_type(name) { continue }

			used_classes : [dynamic]string
			fully_used_classes : [dynamic]string
			defer delete(used_classes)
			defer delete(fully_used_classes)

			size := builtin_sizes[name]

			if "constructors" in builtin_api.(json.Object) {
				for constructor in builtin_api.(json.Object)["constructors"].(json.Array) {
					if "arguments" in constructor.(json.Object) {
						for argument in constructor.(json.Object)["arguments"].(json.Array) {
							type := fmt.tprintf("%s", argument.(json.Object)["type"])
							if is_included(type, name, g) {
								if "default_value" in argument.(json.Object) && type != "Variant" {
									append(&fully_used_classes, strings.clone(type))
								} else {
									append(&used_classes, strings.clone(type))
								}
							}
						}
					}
				}
			}

			if "methods" in builtin_api.(json.Object) {
				for method in builtin_api.(json.Object)["methods"].(json.Array) {
					if "arguments" in method.(json.Object) {
						for argument in method.(json.Object)["arguments"].(json.Array) {
							type := fmt.tprintf("%s", argument.(json.Object)["type"])
							if is_included(type, name, g) {
								if "default_value" in argument.(json.Object) && type != "Variant" {
									append(&fully_used_classes, strings.clone(type))
								} else {
									append(&used_classes, strings.clone(type))
								}
							}
						}
					}
					if "return_type" in method.(json.Object) {
						ret_type := fmt.tprintf("%s", method.(json.Object)["return_type"])
						if is_included(ret_type, name, g) {
							append(&used_classes, strings.clone(ret_type))
						}
					}
				}
			}

			if "members" in builtin_api.(json.Object) {
				for member in builtin_api.(json.Object)["members"].(json.Array) {
					type := fmt.tprintf("%s", member.(json.Object)["type"])
					if is_included(type, name, g) {
						append(&used_classes, strings.clone(type))
					}
				}
			}

			if "indexing_return_type" in builtin_api.(json.Object) {
				irtype := fmt.tprintf("%s", builtin_api.(json.Object)["indexing_return_type"])
				if is_included(irtype, name, g) {
					append(&used_classes, strings.clone(irtype))
				}
			}

			if "operators" in builtin_api.(json.Object) {
				for operator in builtin_api.(json.Object)["operators"].(json.Array) {
					if "right_type" in operator.(json.Object) {
						rtype := fmt.tprintf("%s", operator.(json.Object)["right_type"])
						if is_included(rtype, name, g) {
							append(&used_classes, strings.clone(rtype))
						}
					}
				}
			}

			for type_name in fully_used_classes {
				for i in 0..<len(used_classes) {
					if type_name == used_classes[i] {
						unordered_remove(&used_classes, i)
					}
				}
			}

			slice.sort(used_classes[:])
			slice.sort(fully_used_classes[:])
			slim_used_classes : [dynamic]string
			slim_fully_used_classes : [dynamic]string		
			prev := ""
			for i in 0..<len(used_classes) {
				if prev != used_classes[i] do append(&slim_used_classes, used_classes[i])
				prev = used_classes[i]
			}
			prev = ""
			for i in 0..<len(fully_used_classes) {
				if prev != fully_used_classes[i] do append(&slim_fully_used_classes, fully_used_classes[i])
				prev = fully_used_classes[i]
			}
			
			//fmt.println(name, "is using", slim_used_classes)		
			//fmt.println(name, "is fully using", slim_fully_used_classes)

			// below will create both a "class procs" file and add a struct to "structure.odin"
			generate_builtin_classes(builtin_api.(json.Object), target_dir, size, &slim_used_classes, &slim_fully_used_classes, fd, g)
		}
	}
}

is_struct_type :: proc(type_name: string, g: ^Globals) -> bool {
  return is_included_struct_type(type_name) || slice.contains(g.native_structures[:], type_name)
}

get_return_type :: proc(function_data: json.Object, g: ^Globals) -> string {
	return_type := ""
	return_meta := ""
	if "return_type" in function_data {   // TYPE
		rt := fmt.tprintf("%s", function_data["return_type"])
		return_type = rt
	} else if "return_value" in function_data {  // VALUE
		return_type = fmt.tprintf("%s", function_data["return_value"].(json.Object)["type"])
		if "meta" in function_data["return_value"].(json.Object) {
			return_meta = fmt.tprintf("%s", function_data["return_value"].(json.Object)["meta"])
		}
	}
	return return_type
}

make_signature :: proc(class_name: string, function_data: json.Object, g: ^Globals, use_template_get_node: bool = true, for_builtin: bool = false) -> string {
	func_signature := ""
	is_vararg := "is_vararg" in function_data && function_data["is_vararg"].(json.Boolean)
	is_static := "is_static" in function_data && function_data["is_static"].(json.Boolean)

	name := fmt.tprintf("%s", function_data["name"])
	function_signature_internal := ""
	if is_vararg || (!for_builtin && use_template_get_node && class_name == "Node" && name == "get_node") {
		function_signature_internal = "_internal"
	}

	func_signature = fmt.tprintf("%s%s%s :: proc(", func_signature, escape_identifier(name), function_signature_internal)

	if is_vararg {
		func_signature = fmt.tprintf("%sargs: ^^%sVariant, arg_count: int", func_signature, g.pck)
	} else {
		if "arguments" in function_data {
			func_signature = fmt.tprintf("%s%s", func_signature, make_function_parameters(function_data["arguments"].(json.Array), g, false, false, is_vararg))
		}
	}
	func_signature = fmt.tprintf("%s)", func_signature)

	return_type := get_return_type(function_data, g)
	
	rt := correct_type(return_type, "", g) // TODO return meta?
	if return_type != "" {

		if is_engine_class(return_type, g) {
			func_signature = fmt.tprintf("%s -> ^%s", func_signature, rt)
		} else {
			func_signature = fmt.tprintf("%s -> %s", func_signature, rt)
		}
	}
	return func_signature
}

generate_engine_classes :: proc(class_api: json.Object, target_dir: string, used_classes: ^[dynamic]string, fully_used_classes: ^[dynamic]string, sfd: os.Handle, g: ^Globals) {
  generate_variant_class(target_dir, g)
	
	class_name := fmt.tprintf("%s", class_api["name"])
	snake_class_name := camel_to_snake(class_name)
	dir := fmt.tprintf("%s/%s", target_dir, snake_class_name)
	class_file := fmt.tprintf("%s/%s%s", dir, snake_class_name, ".odin")

  // instead of making an odin struct "fit" what a class should be
	// make a package of snake_class_name that contains NO member variables/data struct(class_name) but
	// does contain all member functions(as procs), constructors, destructor, operators, etc.. of the class
	// note1: packages are directory based, so all class procs will be packages/sub-directories of godot
	// note2: and all (:: structs) will be in "godot" package (structures.odin)
	os.make_directory(dir)
	
	mode: int = 0
	when os.OS == .Linux || os.OS == .Darwin {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}

	os.remove(class_file)

	fd, err := os.open(class_file, os.O_WRONLY|os.O_CREATE, mode)
	
	defer os.close(fd)
	if err == os.ERROR_NONE {
		os.write_string(fd, fmt.tprintf("package %s\n\n", snake_class_name))
		os.write_string(fd, "// engine\n")		
		os.write_string(fd, "import godot \"../../gen\"\n")
		os.write_string(fd, "import gd \"../../../../godot_odin\"\n")
		os.write_string(fd, "import gstring \"../string\"\n")
		os.write_string(fd, "import \"../variant\"\n")

		for included in fully_used_classes {
			if included == "TypedArray" || included == "Variant" || included == "String" {
				//os.write_string(fd, "import \"../typed_array\"\n")
			} else {
				os.write_string(fd, fmt.tprintf("import \"../%s\"\n", camel_to_snake(included)))
			}
		}
		os.write_string(fd, "\n")

		if class_name != "Object" {
			//os.write_string(fd, "import \"<type_traits>\"\n")
			os.write_string(fd, "\n")			
		}

		parent := "Wrapped"
		if "inherits" in class_api {
			parent = fmt.tprintf("%s", class_api["inherits"])
		}

		os.write_string(sfd, fmt.tprintf("%s :: struct {{\n", class_name))
		os.write_string(sfd, fmt.tprintf("  using _ : %s,\n", parent))
		
		is_refcounted := class_name == "RefCounted"
		if is_refcounted {
			//os.write_string(sfd, "  reference : rawptr,\n")
		}

		
    is_singleton := slice.contains(g.singletons[:], class_name)
    if is_singleton {
			// this needs to change... something like a struct tag(then some "constructor"/proc logic) would work better here TODO
			// or just have a @static var in this proc ... idk
			// either way this should be moved out of the structures.odin and into this class methods/package file.. fd
			os.write_string(sfd, fmt.tprintf("  get_singleton : proc() -> ^%s,\n", class_name))
		}
		
		os.write_string(sfd, "}\n")

		if "methods" in class_api {
			for method in class_api["methods"].(json.Array) {
				if method.(json.Object)["is_virtual"].(json.Boolean) do continue // done later

				method_signature := make_signature(class_name, method.(json.Object), g)
				os.write_string(fd, fmt.tprintf("%s\n", method_signature))
				generate_engine_classes_method(method.(json.Object), class_name, fd, g)
			}
			for method in class_api["methods"].(json.Array) {
				if !method.(json.Object)["is_virtual"].(json.Boolean) do continue

				method_signature := make_signature(class_name, method.(json.Object), g)
				os.write_string(fd, fmt.tprintf("%s\n", method_signature))
			}
		}
	}
		
	// TODO: more "nice stuff" for engine classes
}

generate_engine_classes_method :: proc(method: json.Object, class_name: string, fd: os.Handle, g: ^Globals) {
	os.write_string(fd, "{\n")

	method_name := fmt.tprintf("%s", method["name"])
	hash := fmt.tprintf("%.0f", method["hash"])
	is_static := "is_static" in method && method["is_static"].(json.Boolean)
	is_vararg := "is_vararg" in method && method["is_vararg"].(json.Boolean)

	if !is_static {
		os.write_string(fd, fmt.tprintf("  inst := cast(gd.GDExtensionObjectPtr)(cast(^godot.Wrapped)context.user_ptr)._owner\n"))
	} else {
		os.write_string(fd, fmt.tprintf("  inst := cast(gd.GDExtensionObjectPtr)nil\n"))		
	}
	
	os.write_string(fd, fmt.tprintf("  @static class_name : ^godot.StringName\n"))
	os.write_string(fd, fmt.tprintf("  @static method_name : ^godot.StringName\n"))
	os.write_string(fd, fmt.tprintf("  @static method : gd.GDExtensionMethodBindPtr\n"))
	os.write_string(fd, fmt.tprintf("  if class_name == nil {{\n"))
	os.write_string(fd, fmt.tprintf("    class_name = new(godot.StringName); gstring._to_string_name(class_name, \"%s\")\n", class_name))
	os.write_string(fd, fmt.tprintf("    method_name = new(godot.StringName); gstring._to_string_name(method_name, \"%s\")\n", method_name))
	os.write_string(fd, fmt.tprintf("    method = gd.gde_interface.classdb_get_method_bind(cast(gd.GDExtensionConstStringNamePtr)&class_name.opaque[0], cast(gd.GDExtensionConstStringNamePtr)&method_name.opaque[0], %s)\n", hash))
	os.write_string(fd, fmt.tprintf("  }}\n"))
	
	arguments : [dynamic]string; defer delete(arguments)
	if "arguments" in method {
		for argument, i in method["arguments"].(json.Array) {

			name := fmt.tprintf("%s", argument.(json.Object)["name"])
			type := fmt.tprintf("%s", argument.(json.Object)["type"])
			meta := fmt.tprintf("%s", argument.(json.Object)["meta"])
			parameter := type_for_parameter(type, "meta" in argument.(json.Object) ? meta : "", g)
			
			tmp : string
			if type == "bool" {
				tmp = fmt.tprintf("bval%d := %s ? 1 : 0\n  call_args[%d] = cast(gd.GDExtensionConstTypePtr)&bval%d", i, escape_identifier(name), i, i)
			} if strings.has_prefix(parameter, "^") {
				tmp = fmt.tprintf("val%d := %s; call_args[%d] = cast(gd.GDExtensionConstTypePtr)val%d", i, escape_identifier(name), i, i)
			} else {
				tmp = fmt.tprintf("val%d := %s; call_args[%d] = cast(gd.GDExtensionConstTypePtr)&val%d", i, escape_identifier(name), i, i)
			}
			append(&arguments, strings.clone(tmp))
		}
	}

	return_type := get_return_type(method, g)
	rt := correct_type(return_type, "", g) // TODO return meta?
	has_return := return_type != ""
	
	if !is_vararg {
		l := len(arguments) > 0 ? len(arguments) : 1
		os.write_string(fd, fmt.tprintf("  call_args : [%d]rawptr\n", l))
		for a in arguments {
			os.write_string(fd, fmt.tprintf("  %s\n", a))
		}

		
		if has_return {   // _ptrcall doesn't need arg_count, since it's not vararg
			if is_engine_class(return_type, g) {
				os.write_string(fd, fmt.tprintf("  ret := new(%s)\n", rt))
				os.write_string(fd, fmt.tprintf("  gd.gde_interface.object_method_bind_ptrcall(method, inst, cast(^gd.GDExtensionConstTypePtr)&call_args[0], cast(gd.GDExtensionTypePtr)ret)\n"))
				os.write_string(fd, fmt.tprintf("  return ret\n"))
			} else {
				os.write_string(fd, fmt.tprintf("  ret : %s\n", rt))
				os.write_string(fd, fmt.tprintf("  gd.gde_interface.object_method_bind_ptrcall(method, inst, cast(^gd.GDExtensionConstTypePtr)&call_args[0], cast(gd.GDExtensionTypePtr)&ret)\n"))
				os.write_string(fd, fmt.tprintf("  return ret\n"))
			}
		} else {
			os.write_string(fd, fmt.tprintf("  gd.gde_interface.object_method_bind_ptrcall(method, inst, cast(^gd.GDExtensionConstTypePtr)&call_args[0], nil)\n"))
		}
	} else { // is_varg
		
		if has_return {
			if is_engine_class(return_type, g) {
				os.write_string(fd, fmt.tprintf("  ret := new(%s)\n", rt))
				os.write_string(fd, fmt.tprintf("  ret_error : gd.GDExtensionCallError\n"))
				os.write_string(fd, fmt.tprintf("  gd.gde_interface.object_method_bind_call(method, inst, cast(^gd.GDExtensionConstVariantPtr)args, cast(gd.GDExtensionInt)arg_count, cast(gd.GDExtensionVariantPtr)ret, &ret_error)\n"))
				os.write_string(fd, fmt.tprintf("  return ret\n"))
			} else {
				os.write_string(fd, fmt.tprintf("  ret : %s\n", rt))
				os.write_string(fd, fmt.tprintf("  ret_error : gd.GDExtensionCallError\n"))
				os.write_string(fd, fmt.tprintf("  gd.gde_interface.object_method_bind_call(method, inst, cast(^gd.GDExtensionConstVariantPtr)args, cast(gd.GDExtensionInt)arg_count, cast(gd.GDExtensionVariantPtr)&ret, &ret_error)\n"))
				os.write_string(fd, fmt.tprintf("  return ret\n"))
			}
		} else {
			os.write_string(fd, fmt.tprintf("  ret_error : gd.GDExtensionCallError\n"))
			os.write_string(fd, fmt.tprintf("  gd.gde_interface.object_method_bind_call(method, inst, cast(^gd.GDExtensionConstVariantPtr)args, cast(gd.GDExtensionInt)arg_count, nil, &ret_error)\n"))
		}

		os.write_string(fd, "}\n")
		// now write with ..any
		if has_return {
			os.write_string(fd, fmt.tprintf("%s :: proc(args: ..any) -> %s {{\n", method_name, correct_type(return_type, "", g)))
		} else {
			os.write_string(fd, fmt.tprintf("%s :: proc(args: ..any) {{\n", method_name))
		}
		os.write_string(fd, fmt.tprintf("  gargs := make([]^godot.Variant, len(args)); defer delete(gargs)\n"))
		os.write_string(fd, fmt.tprintf("  for a, idx in args {{\n"))
		os.write_string(fd, fmt.tprintf("    gargs[idx] = variant.convert_any(a)\n"))
		os.write_string(fd, fmt.tprintf("  }}\n"))
		os.write_string(fd, fmt.tprintf("  clean_up :: proc(gargs: []^godot.Variant) {{\n"))
		os.write_string(fd, fmt.tprintf("    for a in gargs {{\n"))
		os.write_string(fd, fmt.tprintf("      free(a)\n"))
		os.write_string(fd, fmt.tprintf("    }}\n"))
		os.write_string(fd, fmt.tprintf("  }}\n"))
		os.write_string(fd, fmt.tprintf("  defer clean_up(gargs)\n"))
		
		if has_return {
			os.write_string(fd, fmt.tprintf("  return %s(&gargs[0], len(gargs))\n", fmt.tprintf("%s_internal", method_name)))
		} else {
			os.write_string(fd, fmt.tprintf("  %s(&gargs[0], len(gargs))\n", fmt.tprintf("%s_internal", method_name)))
		}
		
	}
	os.write_string(fd, "}\n")
}

generate_engine_classes_bindings :: proc(root: json.Object, target_dir: string, use_template_get_node: bool, g: ^Globals) {
	file := strings.concatenate([]string{target_dir, "/engine_structures.odin"})
	mode: int = 0
	when os.OS == .Linux || os.OS == .Darwin {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}

	os.remove(file)
	sfd, err := os.open(file, os.O_WRONLY|os.O_CREATE, mode)
	defer os.close(sfd)
	if err != os.ERROR_NONE {
		fmt.println("ERROR: unable to open engine_structures.odin")
		return
	}
	os.write_string(sfd, "package godot\n\n")
	os.write_string(sfd, "import gd \"../../../godot_odin\"\n\n")
	g.pck = "godot."
	
	for class_api in root["classes"].(json.Array) {
		class_name := fmt.tprintf("%s", class_api.(json.Object)["name"])
		if class_name == "ClassDB" do continue

		used_classes : [dynamic]string
		fully_used_classes : [dynamic]string
		defer delete(used_classes)
		defer delete(fully_used_classes)
		
		if "methods" in class_api.(json.Object) {
			for method in class_api.(json.Object)["methods"].(json.Array) {
				if "arguments" in method.(json.Object) {
					for argument in method.(json.Object)["arguments"].(json.Array) {
						type_name := fmt.tprintf("%s", argument.(json.Object)["type"])
						if strings.has_prefix(type_name, "const ") {
							type_name = type_name[6:]
						}
						if strings.has_suffix(type_name, "*") {
							type_name = type_name[:len(type_name)-1]
						}

						if is_included(type_name, class_name, g) {
							if strings.has_prefix(type_name, "typedarray::") {
								append(&fully_used_classes, "TypedArray")
								array_type_name, _ := strings.replace_all(type_name, "typedarray::", "")
								if strings.has_prefix(array_type_name, "const ") {
									array_type_name = array_type_name[6:]
								}
								if strings.has_suffix(array_type_name, "*") {
									array_type_name = array_type_name[:len(array_type_name)-1]
								}

								if is_included(array_type_name, class_name, g) {
									if is_enum(array_type_name) {
										append(&fully_used_classes, get_enum_class(array_type_name))
									} else if "default_value" in argument.(json.Object) {
										append(&fully_used_classes, array_type_name)
									} else {
										append(&used_classes, array_type_name)
									}
								}
							} else if is_enum(type_name) {
								append(&fully_used_classes, get_enum_class(type_name))
							} else if "default_value" in argument.(json.Object) {
								append(&fully_used_classes, type_name)								
							} else {
								append(&used_classes, type_name)
							}
							//if is_refcounted(type_name, g) {
							//	append(&fully_used_classes, "Ref")
							//}  // TODO
						}
					}
				}
				
				// for method
				if "return_value" in method.(json.Object) {
					type_name := fmt.tprintf("%s", method.(json.Object)["return_value"].(json.Object)["type"])
					if strings.has_prefix(type_name, "const ") {
						type_name = type_name[6:]
					}
					if strings.has_suffix(type_name, "*") {
						type_name = type_name[:len(type_name)-1]
					}
					if is_included(type_name, class_name, g) {
						if strings.has_prefix(type_name, "typedarray::") {
							append(&fully_used_classes, "TypedArray")
							array_type_name, _ := strings.replace_all(type_name, "typedarray::", "")
							if strings.has_prefix(array_type_name, "const ") {
								array_type_name = array_type_name[6:]
							}
							if strings.has_suffix(array_type_name, "*") {
								array_type_name = array_type_name[:len(array_type_name)-1]
							}
							if is_included(array_type_name, class_name, g) {
								if is_enum(array_type_name) {
									append(&fully_used_classes, get_enum_class(array_type_name))
								} else if is_variant(array_type_name, g) {
									append(&fully_used_classes, array_type_name)
								} else {
									append(&used_classes, array_type_name)
								}
							}
						} else if is_enum(type_name) {
							append(&fully_used_classes, get_enum_class(type_name))
						} else if is_variant(type_name, g) {
							append(&fully_used_classes, type_name)
						} else {
							append(&used_classes, type_name)
						}
						//if is_refcounted(type_name, g) {
						//	append(&fully_used_classes, "Ref")
						//}  // TODO
					}
				}

				if "members" in class_api.(json.Object) {
					for member in class_api.(json.Object)["members"].(json.Array) {
						type := fmt.tprintf("%s", member.(json.Object)["type"])
						if is_included(type, class_name, g) {
							if is_enum(type) {
								append(&fully_used_classes, get_enum_class(type))
							} else {
								append(&used_classes, type)
							}
							//if is_refcounted(type, g) {
							//	append(&fully_used_classes, "Ref")
							//}  // TODO
						}
					}
				}

				if "inherits" in class_api.(json.Object) {
					name := fmt.tprintf("%s", class_api.(json.Object)["name"])
					inherits := fmt.tprintf("%s", class_api.(json.Object)["inherits"])
					if is_included(inherits, class_name, g) {
						append(&fully_used_classes, inherits)
					}
					//if is_refcounted(name, g) {
					//	append(&fully_used_classes, "Ref")
					//}  // TODO
				} else {
					//append(&fully_used_classes, "Wrapped")
				}
				
			}
		}

		// adjustments
		for type_name in fully_used_classes {
			for i in 0..<len(used_classes) {
				if type_name == used_classes[i] {
					unordered_remove(&used_classes, i)
				}
			}
		}
		
		slice.sort(used_classes[:])
		slice.sort(fully_used_classes[:])
		slim_used_classes : [dynamic]string
		slim_fully_used_classes : [dynamic]string		
		prev := ""
		for i in 0..<len(used_classes) {
			if prev != used_classes[i] do append(&slim_used_classes, used_classes[i])
			prev = used_classes[i]
		}
		prev = ""
		for i in 0..<len(fully_used_classes) {
			if prev != fully_used_classes[i] do append(&slim_fully_used_classes, fully_used_classes[i])
			prev = fully_used_classes[i]
		}
		
		//fmt.println(class_name, "is using", slim_used_classes)		
		//fmt.println(class_name, "is fully using", slim_fully_used_classes)

		generate_engine_classes(class_api.(json.Object), target_dir, &slim_used_classes, &slim_fully_used_classes, sfd, g)
	}
	
	g.pck = ""
}

get_gdextension_type :: proc(type_name: string) -> string {
  type_conversion_map : map[string]string
	type_conversion_map["bool"] = "i8"
  type_conversion_map["u8"] = "i64"
	type_conversion_map["i8"] = "i64"
	type_conversion_map["u16"] = "i64"
	type_conversion_map["i16"] = "i64"
	type_conversion_map["u32"] = "i64"
	type_conversion_map["i32"] = "i64"
	type_conversion_map["int"] = "i64"
	type_conversion_map["f32"] = "f64"

  if strings.has_prefix(type_name, "BitField<") do return "i64"

  if type_name in type_conversion_map {
    return type_conversion_map[type_name]
	}
  return type_name
}

get_encoded_arg :: proc(arg_name: string, type_name: string, type_meta: string, g: ^Globals) -> (result: string, name: string) {
  name = escape_identifier(arg_name)
  arg_type := correct_type(type_name, "", g)
	if is_pod_type(arg_type) {
		result = fmt.tprintf("%s_encoded := cast(%s)%s", name, get_gdextension_type(arg_type), name)
		name = fmt.tprintf("&%s_encoded", name)
	} else if is_engine_class(type_name, g) {
		name = fmt.tprintf("((%s != nil) ? %s : nil)", name, name)
	} else {
		name = fmt.tprintf("%s", name)
	}
	return
}

generate_utility_functions :: proc(root: json.Object, target_dir: string, g: ^Globals) {
	target_dir2 := fmt.tprintf("%s/utility_functions/", target_dir)
	file := strings.concatenate([]string{target_dir2, "utility_functions.odin"})
	mode: int = 0
	when os.OS == .Linux || os.OS == .Darwin {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}

	os.make_directory(target_dir)
	os.make_directory(target_dir2)
	
	os.remove(file)
	fd, err := os.open(file, os.O_WRONLY|os.O_CREATE, mode)
	defer os.close(fd)
	if err != os.ERROR_NONE {
		fmt.println("ERROR: unable to open utility_functions.odin")
		return
	}
	os.write_string(fd, "package utility_functions\n\n")
	os.write_string(fd, "import gd \"../../../../godot_odin\"\n")
	os.write_string(fd, "import godot \"../../gen\"\n")
	os.write_string(fd, "import \"../../gen/string_name\"\n")
	os.write_string(fd, "import \"../../gen/variant\"\n")	
	
	g.pck = "godot."

  for function in root["utility_functions"].(json.Array) {
		//fmt.println(function)
		func_name := function.(json.Object)["name"]
		hash := fmt.tprintf("%.0f", function.(json.Object)["hash"])
		
		vararg := "is_vararg" in function.(json.Object) && function.(json.Object)["is_vararg"].(json.Boolean)

		function_signature := make_signature("UtilityFunctions", function.(json.Object), g)
		os.write_string(fd, fmt.tprintf("%s {{\n", function_signature))
		// function body
		os.write_string(fd, fmt.tprintf("  @static __function_name : godot.StringName\n"))
		os.write_string(fd, fmt.tprintf("  @static __function : gd.GDExtensionPtrUtilityFunction\n"))		
		os.write_string(fd, fmt.tprintf("  if __function == nil {{\n"))
		os.write_string(fd, fmt.tprintf("    string_name.constructor(&__function_name, \"%s\")\n", func_name))
		os.write_string(fd, fmt.tprintf("    __function = gd.gde_interface.variant_get_ptr_utility_function(cast(gd.GDExtensionConstStringNamePtr)&__function_name, %s)\n", hash))
		os.write_string(fd, fmt.tprintf("  }}\n"))

		return_type := ""
		has_return := "return_type" in function.(json.Object)
		if has_return {
			return_type = fmt.tprintf("%s", function.(json.Object)["return_type"])
			has_return = (return_type != "void")
		}
		
		arguments : [dynamic]string
		if "arguments" in function.(json.Object) {
      for argument in function.(json.Object)["arguments"].(json.Array) {
				meta := ""
				if "meta" in argument.(json.Object) do meta = fmt.tprintf("%s", argument.(json.Object)["meta"])
        encode, arg_name := get_encoded_arg(
          fmt.tprintf("%s", argument.(json.Object)["name"]),
          fmt.tprintf("%s", argument.(json.Object)["type"]),
          meta, g)
        os.write_string(fd, fmt.tprintf("  %s\n", encode))
        append(&arguments, arg_name)
			}
		}
				
		if !vararg {
			os.write_string(fd, fmt.tprintf("  args := make([]gd.GDExtensionConstTypePtr, %d)\n", len(arguments)))
			for a, idx in arguments {
				os.write_string(fd, fmt.tprintf("  args[%d] = cast(gd.GDExtensionConstTypePtr)%s\n", idx, a))
			}

			if has_return {
				if return_type == "Object" {
					//fmt.printf("%s - %s\n", return_type, function_signature) TODO instance_from_id()
					os.write_string(fd, "  ret : rawptr = nil\n")
					os.write_string(fd, "  __function(cast(gd.GDExtensionTypePtr)&ret, &args[0], len(args))\n")
					//os.write_string(fd, "  return gd.gde_interface.object_get_instance_binding(ret, token, Object::__bindingcallbacks)\n") TODO
					os.write_string(fd, "  return nil\n")
				} else {
					os.write_string(fd, fmt.tprintf("  ret : %s\n", get_gdextension_type(correct_type(return_type, "", g))))
					os.write_string(fd, "  __function(cast(gd.GDExtensionTypePtr)&ret, &args[0], len(args))\n")
					os.write_string(fd, fmt.tprintf("  return cast(%s)ret\n", correct_type(return_type, "", g)))
				}
			} else {
				os.write_string(fd, "  __function(nil, &args[0], len(args))\n")
			}
			
		} else { // is_vararg
			os.write_string(fd, fmt.tprintf("  ret := new(godot.Variant)\n"))
			os.write_string(fd, "  __function(cast(gd.GDExtensionTypePtr)ret, cast(^gd.GDExtensionConstTypePtr)args, arg_count)\n")
			if has_return {
				os.write_string(fd, fmt.tprintf("  return (cast(^%s)ret)^\n", correct_type(return_type, "", g)))
			} else {
				os.write_string(fd, "  free(ret)\n")
			}
			os.write_string(fd, "}\n")
			// now write with ..any
			if has_return {
				os.write_string(fd, fmt.tprintf("%s :: proc(args: ..any) -> %s {{\n", func_name, correct_type(return_type, "", g)))
			} else {
				os.write_string(fd, fmt.tprintf("%s :: proc(args: ..any) {{\n", func_name))
			}
			os.write_string(fd, fmt.tprintf("  gargs := make([]^godot.Variant, len(args)); defer delete(gargs)\n"))
			os.write_string(fd, fmt.tprintf("  for a, idx in args {{\n"))
			os.write_string(fd, fmt.tprintf("    gargs[idx] = variant.convert_any(a)\n"))
			os.write_string(fd, fmt.tprintf("  }}\n"))
			os.write_string(fd, fmt.tprintf("  clean_up :: proc(gargs: []^godot.Variant) {{\n"))
			os.write_string(fd, fmt.tprintf("    for a in gargs {{\n"))
			os.write_string(fd, fmt.tprintf("      free(a)\n"))
			os.write_string(fd, fmt.tprintf("    }}\n"))
			os.write_string(fd, fmt.tprintf("  }}\n"))
			os.write_string(fd, fmt.tprintf("  defer clean_up(gargs)\n"))
			
			if has_return {
				os.write_string(fd, fmt.tprintf("  return %s(&gargs[0], len(gargs))\n", fmt.tprintf("%s_internal", func_name)))
			} else {
				os.write_string(fd, fmt.tprintf("  %s(&gargs[0], len(gargs))\n", fmt.tprintf("%s_internal", func_name)))
			}
		}
		
		os.write_string(fd, fmt.tprintf("}}\n"))
	}
	
}

generate_bindings :: proc(root: json.Object, use_template_get_node: bool, bits:string="64", precision:string="single", output_dir:string=".") {
  target_dir := strings.concatenate([]string{output_dir, "/gen"})

	os.remove_directory(target_dir)
  os.make_directory(target_dir)

	real_t := (precision == "double") ? "double" : "float" // TODO expose this to main() and add usage() user report
	fmt.println("Built-in type config:", real_t, bits)

	globals : Globals
	globals.pck = ""

	for class_api in root["classes"].(json.Array) {
		name := fmt.tprintf("%s", class_api.(json.Object)["name"])
		ref_counted := cast(bool)class_api.(json.Object)["is_refcounted"].(json.Boolean)
		globals.engine_classes[strings.clone(name)] = ref_counted
	}
	for native_struct in root["native_structures"].(json.Array) {
		//fmt.println(native_struct)
		name := fmt.tprintf("%s", native_struct.(json.Object)["name"])
		append(&globals.native_structures, strings.clone(name))
	}
	for singleton in root["singletons"].(json.Array) {
		name := fmt.tprintf("%s", singleton.(json.Object)["name"])		
		append(&globals.singletons, strings.clone(name))
	}

  generate_global_constants(root, target_dir, &globals)
  generate_builtin_bindings(root, target_dir, fmt.tprintf("%s_%s", real_t, bits), &globals)
  generate_engine_classes_bindings(root, target_dir, use_template_get_node, &globals)
  generate_utility_functions(root, target_dir, &globals)
}

main :: proc() {
	// Load in json file!
	data, ok := os.read_entire_file_from_filename("../extension_api.json")
	if !ok {
		fmt.eprintln("Failed to load extension_api.json!")
		return
	}
	defer delete(data)
	
	// Parse the json file.
	json_data, err := json.parse(data)
	if err != .None {
		fmt.eprintln("Failed to parse the json file.")
		fmt.eprintln("Error:", err)
		return
	}
	defer json.destroy_value(json_data)

	// Access the Root Level Object
	root := json_data.(json.Object)

	// Do generator stuff
	header := root["header"].(json.Object)
	fmt.println("Version", header["version_full_name"])

	generate_bindings(root, true)
}
