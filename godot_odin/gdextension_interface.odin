package godot_odin

import "core:c"

/*
 gdextension_interface.h - but as an odin file
 use with externsion_api.json
*/

/* VARIANT TYPES */

GDExtensionVariantType :: enum {
	GDEXTENSION_VARIANT_TYPE_NIL,

	/*  atomic types */
	GDEXTENSION_VARIANT_TYPE_BOOL,
	GDEXTENSION_VARIANT_TYPE_INT,
	GDEXTENSION_VARIANT_TYPE_FLOAT,
	GDEXTENSION_VARIANT_TYPE_STRING,

	/* math types */
	GDEXTENSION_VARIANT_TYPE_VECTOR2,
	GDEXTENSION_VARIANT_TYPE_VECTOR2I,
	GDEXTENSION_VARIANT_TYPE_RECT2,
	GDEXTENSION_VARIANT_TYPE_RECT2I,
	GDEXTENSION_VARIANT_TYPE_VECTOR3,
	GDEXTENSION_VARIANT_TYPE_VECTOR3I,
	GDEXTENSION_VARIANT_TYPE_TRANSFORM2D,
	GDEXTENSION_VARIANT_TYPE_VECTOR4,
	GDEXTENSION_VARIANT_TYPE_VECTOR4I,
	GDEXTENSION_VARIANT_TYPE_PLANE,
	GDEXTENSION_VARIANT_TYPE_QUATERNION,
	GDEXTENSION_VARIANT_TYPE_AABB,
	GDEXTENSION_VARIANT_TYPE_BASIS,
	GDEXTENSION_VARIANT_TYPE_TRANSFORM3D,
	GDEXTENSION_VARIANT_TYPE_PROJECTION,

	/* misc types */
	GDEXTENSION_VARIANT_TYPE_COLOR,
	GDEXTENSION_VARIANT_TYPE_STRING_NAME,
	GDEXTENSION_VARIANT_TYPE_NODE_PATH,
	GDEXTENSION_VARIANT_TYPE_RID,
	GDEXTENSION_VARIANT_TYPE_OBJECT,
	GDEXTENSION_VARIANT_TYPE_CALLABLE,
	GDEXTENSION_VARIANT_TYPE_SIGNAL,
	GDEXTENSION_VARIANT_TYPE_DICTIONARY,
	GDEXTENSION_VARIANT_TYPE_ARRAY,

	/* typed arrays */
	GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,
	GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY,
	GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY,
	GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,
	GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY,
	GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY,
	GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR2_ARRAY,
	GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY,
	GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY,

	GDEXTENSION_VARIANT_TYPE_VARIANT_MAX,
}

GDExtensionVariantOperator :: enum {
	/* comparison */
	GDEXTENSION_VARIANT_OP_EQUAL,
	GDEXTENSION_VARIANT_OP_NOT_EQUAL,
	GDEXTENSION_VARIANT_OP_LESS,
	GDEXTENSION_VARIANT_OP_LESS_EQUAL,
	GDEXTENSION_VARIANT_OP_GREATER,
	GDEXTENSION_VARIANT_OP_GREATER_EQUAL,

	/* mathematic */
	GDEXTENSION_VARIANT_OP_ADD,
	GDEXTENSION_VARIANT_OP_SUBTRACT,
	GDEXTENSION_VARIANT_OP_MULTIPLY,
	GDEXTENSION_VARIANT_OP_DIVIDE,
	GDEXTENSION_VARIANT_OP_NEGATE,
	GDEXTENSION_VARIANT_OP_POSITIVE,
	GDEXTENSION_VARIANT_OP_MODULE,
	GDEXTENSION_VARIANT_OP_POWER,

	/* bitwise */
	GDEXTENSION_VARIANT_OP_SHIFT_LEFT,
	GDEXTENSION_VARIANT_OP_SHIFT_RIGHT,
	GDEXTENSION_VARIANT_OP_BIT_AND,
	GDEXTENSION_VARIANT_OP_BIT_OR,
	GDEXTENSION_VARIANT_OP_BIT_XOR,
	GDEXTENSION_VARIANT_OP_BIT_NEGATE,

	/* logic */
	GDEXTENSION_VARIANT_OP_AND,
	GDEXTENSION_VARIANT_OP_OR,
	GDEXTENSION_VARIANT_OP_XOR,
	GDEXTENSION_VARIANT_OP_NOT,

	/* containment */
	GDEXTENSION_VARIANT_OP_IN,
	GDEXTENSION_VARIANT_OP_MAX,
}

GDExtensionVariantPtr :: distinct rawptr
GDExtensionConstVariantPtr :: distinct rawptr
GDExtensionStringNamePtr :: distinct rawptr
GDExtensionConstStringNamePtr :: distinct rawptr
GDExtensionStringPtr :: distinct rawptr
GDExtensionConstStringPtr :: distinct rawptr
GDExtensionObjectPtr :: distinct rawptr
GDExtensionConstObjectPtr :: distinct rawptr
GDExtensionTypePtr :: distinct rawptr
GDExtensionConstTypePtr :: distinct rawptr
GDExtensionMethodBindPtr :: distinct rawptr
GDExtensionInt :: distinct i64
GDExtensionBool :: distinct u8
GDObjectInstanceID :: distinct u64
GDExtensionRefPtr :: distinct rawptr
GDExtensionConstRefPtr :: distinct rawptr

/* VARIANT DATA I/O */

GDExtensionCallErrorType ::  enum i32 {
	GDEXTENSION_CALL_OK,
	GDEXTENSION_CALL_ERROR_INVALID_METHOD,
	GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT, // Expected a different variant type.
	GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS, // Expected lower number of arguments.
	GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS, // Expected higher number of arguments.
	GDEXTENSION_CALL_ERROR_INSTANCE_IS_NULL,
	GDEXTENSION_CALL_ERROR_METHOD_NOT_CONST, // Used for const call.
}

GDExtensionCallError :: struct {
	error : GDExtensionCallErrorType,
	argument : i32,
	expected : i32,
}

GDExtensionVariantFromTypeConstructorFunc :: proc "c" (GDExtensionVariantPtr, GDExtensionTypePtr)
GDExtensionTypeFromVariantConstructorFunc :: proc "c" (GDExtensionTypePtr, GDExtensionVariantPtr)
GDExtensionPtrOperatorEvaluator :: proc "c" (p_left: GDExtensionConstTypePtr, p_right: GDExtensionConstTypePtr, r_result: GDExtensionTypePtr)
GDExtensionPtrBuiltInMethod :: proc "c" (p_base: GDExtensionTypePtr, p_args: GDExtensionConstTypePtr, r_return: GDExtensionTypePtr, p_argument_count: int)
GDExtensionPtrConstructor :: proc "c" (p_base: GDExtensionTypePtr, p_args: GDExtensionConstTypePtr)
GDExtensionPtrDestructor :: proc "c" (p_base: GDExtensionTypePtr)
GDExtensionPtrSetter :: proc "c" (p_base: GDExtensionTypePtr, p_value: GDExtensionConstTypePtr)
GDExtensionPtrGetter :: proc "c" (p_base: GDExtensionConstTypePtr, r_value: GDExtensionTypePtr)
GDExtensionPtrIndexedSetter :: proc "c" (p_base: GDExtensionTypePtr, p_index: GDExtensionInt, p_value: GDExtensionConstTypePtr)
GDExtensionPtrIndexedGetter :: proc "c" (p_base: GDExtensionConstTypePtr, p_index: GDExtensionInt, r_value: GDExtensionTypePtr)
GDExtensionPtrKeyedSetter :: proc "c" (p_base: GDExtensionTypePtr, p_key: GDExtensionConstTypePtr, p_value: GDExtensionConstTypePtr)
GDExtensionPtrKeyedGetter :: proc "c" (p_base: GDExtensionConstTypePtr, p_key: GDExtensionConstTypePtr, r_value: GDExtensionTypePtr)
GDExtensionPtrKeyedChecker :: proc "c" (p_base: GDExtensionConstVariantPtr, p_key: GDExtensionConstVariantPtr) -> u32
GDExtensionPtrUtilityFunction :: proc "c" (r_return: GDExtensionTypePtr, p_args: ^GDExtensionConstTypePtr, p_argument_count: int)

GDExtensionClassConstructor :: proc "c" () -> GDExtensionObjectPtr

GDExtensionInstanceBindingCreateCallback :: proc "c" (p_token: rawptr, p_instance: rawptr) -> rawptr
GDExtensionInstanceBindingFreeCallback :: proc "c" (p_token: rawptr, p_instance: rawptr, p_binding: rawptr)
GDExtensionInstanceBindingReferenceCallback :: proc "c" (p_token: rawptr, p_binding: rawptr, p_reference: GDExtensionBool) -> GDExtensionBool

GDExtensionInstanceBindingCallbacks :: struct {
	create_callback : GDExtensionInstanceBindingCreateCallback,
	free_callback : GDExtensionInstanceBindingFreeCallback,
	reference_callback: GDExtensionInstanceBindingReferenceCallback,
}

/* EXTENSION CLASSES */

GDExtensionClassInstancePtr :: distinct rawptr

GDExtensionClassSet :: proc "c" (p_instance: GDExtensionClassInstancePtr, p_name: GDExtensionConstStringNamePtr, p_value: GDExtensionConstVariantPtr) -> GDExtensionBool
GDExtensionClassGet :: proc "c" (p_instance: GDExtensionClassInstancePtr, p_name: GDExtensionConstStringNamePtr, r_ret: GDExtensionVariantPtr) -> GDExtensionBool
GDExtensionClassGetRID :: proc "c" (p_instance: GDExtensionClassInstancePtr) -> u64

GDExtensionPropertyInfo :: struct {
	type : GDExtensionVariantType,
	name : GDExtensionStringNamePtr,
	class_name : GDExtensionStringNamePtr,
	hint : u32, // Bitfield of `PropertyHint` (defined in `extension_api.json`).
	hint_string : GDExtensionStringPtr,
	usage : u32, // Bitfield of `PropertyUsageFlags` (defined in `extension_api.json`).
}

GDExtensionMethodInfo :: struct {
	name : GDExtensionStringNamePtr,
	return_value : GDExtensionPropertyInfo,
	flags : u32, // Bitfield of `GDExtensionClassMethodFlags`.
	id : i32,
	
	/* Arguments: `default_arguments` is an array of size `argument_count`. */
	argument_count : u32,
	arguments : ^GDExtensionPropertyInfo,

	/* Default arguments: `default_arguments` is an array of size `default_argument_count`. */
	default_argument_count : u32,
	default_arguments : ^GDExtensionVariantPtr,
}

GDExtensionClassGetPropertyList :: proc "c" (p_instance: GDExtensionClassInstancePtr, r_count: ^u32) -> ^GDExtensionPropertyInfo
GDExtensionClassFreePropertyList :: proc "c" (p_instance: GDExtensionClassInstancePtr, p_list: ^GDExtensionPropertyInfo)
GDExtensionClassPropertyCanRevert :: proc "c" (p_instance: GDExtensionClassInstancePtr, p_name: GDExtensionConstStringNamePtr) -> GDExtensionBool
GDExtensionClassPropertyGetRevert :: proc "c" (p_instance: GDExtensionClassInstancePtr, p_name: GDExtensionConstStringNamePtr, r_ret: GDExtensionVariantPtr) -> GDExtensionBool
GDExtensionClassNotification :: proc "c" (p_instance: GDExtensionClassInstancePtr, p_what: i32)
GDExtensionClassToString :: proc "c" (p_instance: GDExtensionClassInstancePtr, r_is_valid: ^GDExtensionBool, p_out: GDExtensionStringPtr)
GDExtensionClassReference :: proc "c" (p_instance: GDExtensionClassInstancePtr)
GDExtensionClassUnreference :: proc "c" (p_instance: GDExtensionClassInstancePtr)
GDExtensionClassCallVirtual :: proc "c" (p_instance: GDExtensionClassInstancePtr, p_args: ^GDExtensionConstTypePtr, r_ret: GDExtensionTypePtr)
GDExtensionClassCreateInstance :: proc "c" (p_userdata: rawptr) -> GDExtensionObjectPtr
GDExtensionClassFreeInstance :: proc "c" (p_userdata: rawptr, p_instance: GDExtensionClassInstancePtr)
GDExtensionClassGetVirtual :: proc "c" (p_userdata: rawptr, p_name: GDExtensionConstStringNamePtr) -> GDExtensionClassCallVirtual

GDExtensionClassCreationInfo :: struct {
	is_virtual : GDExtensionBool,
	is_abstract : GDExtensionBool,
	set_func : GDExtensionClassSet,
	get_func : GDExtensionClassGet,
	get_property_list_func : GDExtensionClassGetPropertyList,
	free_property_list_func : GDExtensionClassFreePropertyList,
	property_can_revert_func : GDExtensionClassPropertyCanRevert,
	property_get_revert_func : GDExtensionClassPropertyGetRevert,
	notification_func : GDExtensionClassNotification,
	to_string_func : GDExtensionClassToString,
	reference_func : GDExtensionClassReference,
	unreference_func : GDExtensionClassUnreference,
	create_instance_func : GDExtensionClassCreateInstance, // (Default) constructor; mandatory. If the class is not instantiable, consider making it virtual or abstract.
	free_instance_func : GDExtensionClassFreeInstance, // Destructor; mandatory.
	get_virtual_func : GDExtensionClassGetVirtual, // Queries a virtual function by name and returns a callback to invoke the requested virtual function.
	get_rid_func : GDExtensionClassGetRID,
	class_userdata : rawptr, // Per-class user data, later accessible in instance bindings.
}

GDExtensionClassLibraryPtr :: distinct rawptr

/* Method */

GDExtensionClassMethodFlags :: enum i32 {
	GDEXTENSION_METHOD_FLAG_NORMAL = 1,
	GDEXTENSION_METHOD_FLAG_EDITOR = 2,
	GDEXTENSION_METHOD_FLAG_CONST = 4,
	GDEXTENSION_METHOD_FLAG_VIRTUAL = 8,
	GDEXTENSION_METHOD_FLAG_VARARG = 16,
	GDEXTENSION_METHOD_FLAG_STATIC = 32,
	GDEXTENSION_METHOD_FLAGS_DEFAULT = GDEXTENSION_METHOD_FLAG_NORMAL,
}

GDExtensionClassMethodArgumentMetadata :: enum i32 { // note: struct size needs this i32!
	GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
	GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT8,
	GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT16,
	GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT32,
	GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_INT64,
	GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_UINT8,
	GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_UINT16,
	GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_UINT32,
	GDEXTENSION_METHOD_ARGUMENT_METADATA_INT_IS_UINT64,
	GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_FLOAT,
	GDEXTENSION_METHOD_ARGUMENT_METADATA_REAL_IS_DOUBLE,
}

GDExtensionClassMethodCall :: proc "c" (method_userdata: rawptr, p_instance: GDExtensionClassInstancePtr, p_args: ^GDExtensionConstVariantPtr, p_argument_count: GDExtensionInt, r_return: GDExtensionVariantPtr, r_error: ^GDExtensionCallError)
GDExtensionClassMethodPtrCall :: proc "c" (method_userdata: rawptr, p_instance: GDExtensionClassInstancePtr, p_args: ^GDExtensionConstTypePtr, r_ret: GDExtensionTypePtr)

GDExtensionClassMethodInfo :: struct {
	name : GDExtensionStringNamePtr,
	method_userdata : rawptr,
	call_func : GDExtensionClassMethodCall,
	ptrcall_func : GDExtensionClassMethodPtrCall,
	method_flags : u32, // Bitfield of `GDExtensionClassMethodFlags`.

	/* If `has_return_value` is false, `return_value_info` and `return_value_metadata` are ignored. */
	has_return_value : GDExtensionBool,
	return_value_info : ^GDExtensionPropertyInfo,
	return_value_metadata : GDExtensionClassMethodArgumentMetadata,

	/* Arguments: `arguments_info` and `arguments_metadata` are array of size `argument_count`.
	 * Name and hint information for the argument can be omitted in release builds. Class name should always be present if it applies.
	 */
	argument_count : u32,
	arguments_info : ^GDExtensionPropertyInfo,
	arguments_metadata : ^GDExtensionClassMethodArgumentMetadata,

	/* Default arguments: `default_arguments` is an array of size `default_argument_count`. */
	default_argument_count : u32,
	default_arguments : ^GDExtensionVariantPtr,
}

/* SCRIPT INSTANCE EXTENSION */

GDExtensionScriptInstanceDataPtr :: distinct rawptr // Pointer to custom ScriptInstance native implementation.

GDExtensionScriptInstanceSet :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr, p_name: GDExtensionConstStringNamePtr, p_value: GDExtensionConstVariantPtr) -> GDExtensionBool
GDExtensionScriptInstanceGet :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr, p_name: GDExtensionConstStringNamePtr, r_ret: GDExtensionVariantPtr) -> GDExtensionBool
GDExtensionScriptInstanceGetPropertyList :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr, r_count: ^u32) -> ^GDExtensionPropertyInfo
GDExtensionScriptInstanceFreePropertyList :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr, p_list: ^GDExtensionPropertyInfo)
GDExtensionScriptInstanceGetPropertyType :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr, p_name: GDExtensionConstStringNamePtr, r_is_valid: ^GDExtensionBool) -> GDExtensionVariantType

GDExtensionScriptInstancePropertyCanRevert :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr, p_name: GDExtensionConstStringNamePtr) -> GDExtensionBool
GDExtensionScriptInstancePropertyGetRevert :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr, p_name: GDExtensionConstStringNamePtr, r_ret: GDExtensionVariantPtr) -> GDExtensionBool

GDExtensionScriptInstanceGetOwner :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr) -> GDExtensionObjectPtr
GDExtensionScriptInstancePropertyStateAdd :: proc "c" (p_name: GDExtensionConstStringNamePtr, p_value: GDExtensionConstVariantPtr, p_userdata: rawptr)
GDExtensionScriptInstanceGetPropertyState :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr, p_add_func: GDExtensionScriptInstancePropertyStateAdd, p_userdata: rawptr)

GDExtensionScriptInstanceGetMethodList :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr, r_count: ^u32) -> ^GDExtensionMethodInfo
GDExtensionScriptInstanceFreeMethodList :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr,  p_list: ^GDExtensionMethodInfo)

GDExtensionScriptInstanceHasMethod :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr, p_name: GDExtensionConstStringNamePtr) -> GDExtensionBool

GDExtensionScriptInstanceCall :: proc "c" (p_self: GDExtensionScriptInstanceDataPtr, p_method: GDExtensionConstStringNamePtr, p_args: ^GDExtensionConstVariantPtr, p_argument_count: GDExtensionInt, r_return: GDExtensionVariantPtr, r_error: ^GDExtensionCallError)
GDExtensionScriptInstanceNotification :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr, p_what: i32)
GDExtensionScriptInstanceToString :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr, r_is_valid: ^GDExtensionBool, r_out: GDExtensionStringPtr)

GDExtensionScriptInstanceRefCountIncremented :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr)
GDExtensionScriptInstanceRefCountDecremented :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr) -> GDExtensionBool

GDExtensionScriptInstanceGetScript :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr) -> GDExtensionObjectPtr
GDExtensionScriptInstanceIsPlaceholder :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr) -> GDExtensionBool

GDExtensionScriptLanguagePtr :: distinct rawptr

GDExtensionScriptInstanceGetLanguage :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr) -> GDExtensionScriptLanguagePtr

GDExtensionScriptInstanceFree :: proc "c" (p_instance: GDExtensionScriptInstanceDataPtr)

GDExtensionScriptInstancePtr :: distinct rawptr // Pointer to ScriptInstance.

GDExtensionScriptInstanceInfo ::  struct {
	set_func : GDExtensionScriptInstanceSet,
	get_func : GDExtensionScriptInstanceGet,
	get_property_list_func : GDExtensionScriptInstanceGetPropertyList,
	free_property_list_func : GDExtensionScriptInstanceFreePropertyList,

	property_can_revert_func : GDExtensionScriptInstancePropertyCanRevert,
	property_get_revert_func : GDExtensionScriptInstancePropertyGetRevert,

	get_owner_func : GDExtensionScriptInstanceGetOwner,
	get_property_state_func : GDExtensionScriptInstanceGetPropertyState,

	get_method_list_func : GDExtensionScriptInstanceGetMethodList,
	free_method_list_func : GDExtensionScriptInstanceFreeMethodList,
	get_property_type_func : GDExtensionScriptInstanceGetPropertyType,

	has_method_func : GDExtensionScriptInstanceHasMethod,

	call_func : GDExtensionScriptInstanceCall,
	notification_func : GDExtensionScriptInstanceNotification,

	to_string_func : GDExtensionScriptInstanceToString,

	refcount_incremented_func : GDExtensionScriptInstanceRefCountIncremented,
	refcount_decremented_func : GDExtensionScriptInstanceRefCountDecremented,

	get_script_func : GDExtensionScriptInstanceGetScript,

	is_placeholder_func : GDExtensionScriptInstanceIsPlaceholder,

	set_fallback_func : GDExtensionScriptInstanceSet,
	get_fallback_func : GDExtensionScriptInstanceGet,

	get_language_func : GDExtensionScriptInstanceGetLanguage,

	free_func : GDExtensionScriptInstanceFree,
}

/* INTERFACE */

GDExtensionInterface :: struct {
	version_major : u32,
	version_minor : u32,
	version_patch : u32,
	version_string : cstring,

	/* GODOT CORE */

	mem_alloc : proc "c" (p_bytes: c.size_t) -> rawptr,
	mem_realloc : proc "c" (p_ptr: rawptr, p_bytes: c.size_t) -> rawptr,
	mem_free : proc "c" (p_ptr: rawptr),

	print_error : proc "c" (p_description: cstring, p_function: cstring, p_file: cstring, p_line: i32, p_editor_notify: GDExtensionBool),
	print_error_with_message : proc "c" (p_description: cstring, p_message: cstring, p_function: cstring, p_file: cstring, p_line: i32, p_editor_notify: GDExtensionBool),
	print_warning : proc "c" (p_description: cstring, p_function: cstring, p_file: cstring, p_line: i32, p_editor_notify: GDExtensionBool),
	print_warning_with_message : proc "c" (p_description: cstring, p_message: cstring, p_function: cstring, p_file: cstring, p_line: i32, p_editor_notify: GDExtensionBool),
	print_script_error : proc "c" (p_description: cstring, p_function: cstring, p_file: cstring, p_line: i32, p_editor_notify: GDExtensionBool),
	print_script_error_with_message : proc "c" (p_description: cstring, p_message: cstring, p_function: cstring, p_file: cstring, p_line: i32, p_editor_notify: GDExtensionBool),

	get_native_struct_size : proc "c" (p_name: GDExtensionConstStringNamePtr) -> u64,

	/* GODOT VARIANT */

	/* variant general */
	variant_new_copy : proc "c" (r_dest: GDExtensionVariantPtr, p_src: GDExtensionConstVariantPtr),
	variant_new_nil : proc "c" (r_dest: GDExtensionVariantPtr),
  variant_destroy : proc "c" (p_self: GDExtensionVariantPtr),

	/* variant type */
	variant_call : proc "c" (p_self: GDExtensionVariantPtr, p_method: GDExtensionConstStringNamePtr, p_args: ^GDExtensionConstVariantPtr, p_argument_count: GDExtensionInt, r_return: GDExtensionVariantPtr, r_error: ^GDExtensionCallError),
	variant_call_static : proc "c" (p_type: GDExtensionVariantType, p_method: GDExtensionConstStringNamePtr, p_args: ^GDExtensionConstVariantPtr, p_argument_count: GDExtensionInt, r_return: GDExtensionVariantPtr, r_error: ^GDExtensionCallError),
	variant_evaluate : proc "c" (p_op: GDExtensionVariantOperator, p_a: GDExtensionConstVariantPtr, p_b: GDExtensionConstVariantPtr, r_return: GDExtensionVariantPtr, r_valid: ^GDExtensionBool),
	variant_set : proc "c" (p_self: GDExtensionVariantPtr, p_key: GDExtensionConstVariantPtr, p_value: GDExtensionConstVariantPtr, r_valid: ^GDExtensionBool),
	variant_set_named : proc "c" (p_self: GDExtensionVariantPtr, p_key: GDExtensionConstStringNamePtr, p_value: GDExtensionConstVariantPtr, r_valid: ^GDExtensionBool),
	variant_set_keyed : proc "c" (p_self: GDExtensionVariantPtr, p_key: GDExtensionConstVariantPtr, p_value: GDExtensionConstVariantPtr, r_valid: ^GDExtensionBool),
	variant_set_indexed : proc "c" (p_self: GDExtensionVariantPtr, p_index: GDExtensionInt, p_value: GDExtensionConstVariantPtr, r_valid: ^GDExtensionBool, r_oob: ^GDExtensionBool),
	variant_get : proc "c" (p_self: GDExtensionConstVariantPtr, p_key: GDExtensionConstVariantPtr, r_ret: GDExtensionVariantPtr, r_valid: ^GDExtensionBool),
	variant_get_named : proc "c" (p_self: GDExtensionConstVariantPtr, p_key: GDExtensionConstStringNamePtr, r_ret: GDExtensionVariantPtr, r_valid: ^GDExtensionBool),
	variant_get_keyed : proc "c" (p_self: GDExtensionConstVariantPtr, p_key: GDExtensionConstVariantPtr, r_ret: GDExtensionVariantPtr, r_valid: ^GDExtensionBool),
	variant_get_indexed : proc "c" (p_self: GDExtensionConstVariantPtr, p_index: GDExtensionInt, r_ret: GDExtensionVariantPtr, r_valid: ^GDExtensionBool, r_oob: ^GDExtensionBool),
	variant_iter_init : proc "c" (p_self: GDExtensionConstVariantPtr, r_iter: GDExtensionVariantPtr, r_valid: ^GDExtensionBool) -> GDExtensionBool,
	variant_iter_next : proc "c" (p_self: GDExtensionConstVariantPtr, r_iter: GDExtensionVariantPtr, r_valid: ^GDExtensionBool) -> GDExtensionBool,
	variant_iter_get : proc "c" (p_self: GDExtensionConstVariantPtr, r_iter: GDExtensionVariantPtr, r_ret: GDExtensionVariantPtr, r_valid: GDExtensionBool),
	variant_hash : proc "c" (p_self: GDExtensionConstVariantPtr) -> GDExtensionInt,
	variant_recursive_hash : proc "c" (p_self: GDExtensionConstVariantPtr, p_recursion_count: GDExtensionInt) -> GDExtensionInt,
	variant_hash_compare : proc "c" (p_self: GDExtensionConstVariantPtr, p_other: GDExtensionConstVariantPtr) -> GDExtensionBool,
	variant_booleanize : proc "c" (p_self: GDExtensionConstVariantPtr) -> GDExtensionBool,
	variant_duplicate : proc "c" (p_self: GDExtensionConstVariantPtr, r_ret: GDExtensionVariantPtr, p_deep: GDExtensionBool),
	variant_stringify : proc "c" (p_self: GDExtensionConstVariantPtr, r_ret: GDExtensionStringPtr),

	variant_get_type : proc "c" (p_self: GDExtensionConstVariantPtr) -> GDExtensionVariantType,
	variant_has_method : proc "c" (p_self: GDExtensionConstVariantPtr, p_method: GDExtensionConstStringNamePtr) -> GDExtensionBool,
	variant_has_member : proc "c" (p_type: GDExtensionVariantType, p_member: GDExtensionConstStringNamePtr) -> GDExtensionBool,
	variant_has_key : proc "c" (p_self: GDExtensionConstVariantPtr, p_key: GDExtensionConstVariantPtr, r_valid: ^GDExtensionBool) -> GDExtensionBool,
	variant_get_type_name : proc "c" (p_type: GDExtensionVariantType, r_name: GDExtensionStringPtr),
	variant_can_convert : proc "c" (p_from: GDExtensionVariantType, p_to: GDExtensionVariantType) -> GDExtensionBool,
	variant_can_convert_strict : proc "c" (p_from: GDExtensionVariantType, p_to: GDExtensionVariantType) -> GDExtensionBool,

	/* ptrcalls */
	get_variant_from_type_constructor : proc "c" (p_type: GDExtensionVariantType) -> GDExtensionVariantFromTypeConstructorFunc,
	get_variant_to_type_constructor : proc "c" (p_type: GDExtensionVariantType) -> GDExtensionTypeFromVariantConstructorFunc,
	variant_get_ptr_operator_evaluator: proc "c" (p_operator: GDExtensionVariantOperator, p_type_a: GDExtensionVariantType, p_type_b: GDExtensionVariantType) -> GDExtensionPtrOperatorEvaluator,
	variant_get_ptr_builtin_method : proc "c" (p_type: GDExtensionVariantType, p_method: GDExtensionConstStringNamePtr, p_hash: GDExtensionInt) -> GDExtensionPtrBuiltInMethod,
	variant_get_ptr_constructor : proc "c" (p_type: GDExtensionVariantType, p_constructor: i32) -> GDExtensionPtrConstructor,
	variant_get_ptr_destructor : proc "c" (p_type: GDExtensionVariantType) -> GDExtensionPtrDestructor,
	variant_construct : proc "c" (p_type: GDExtensionVariantType, p_base: GDExtensionVariantPtr, p_args: ^GDExtensionConstVariantPtr, p_argument_count: i32, r_error: ^GDExtensionCallError),
	variant_get_ptr_setter : proc "c" (p_type: GDExtensionVariantType, p_member: GDExtensionConstStringNamePtr) -> GDExtensionPtrSetter,
	variant_get_ptr_getter : proc "c" (p_type: GDExtensionVariantType, p_member: GDExtensionConstStringNamePtr) -> GDExtensionPtrGetter,
	variant_get_ptr_indexed_setter : proc "c" (p_type: GDExtensionVariantType) -> GDExtensionPtrIndexedSetter,
	variant_get_ptr_indexed_getter : proc "c" (p_type: GDExtensionVariantType) -> GDExtensionPtrIndexedGetter,
	variant_get_ptr_keyed_setter : proc "c" (p_type: GDExtensionVariantType) -> GDExtensionPtrKeyedSetter,
	variant_get_ptr_keyed_getter : proc "c" (p_type: GDExtensionVariantType) -> GDExtensionPtrKeyedGetter,
	variant_get_ptr_keyed_checker : proc "c" (p_type: GDExtensionVariantType) -> GDExtensionPtrKeyedChecker,
	variant_get_constant_value : proc "c" (p_type: GDExtensionVariantType, p_constant: GDExtensionConstStringNamePtr, r_ret: GDExtensionVariantPtr),
  variant_get_ptr_utility_function : proc "c" (p_function: GDExtensionConstStringNamePtr, p_hash: GDExtensionInt) -> GDExtensionPtrUtilityFunction,

	/*  extra utilities */
	string_new_with_latin1_chars : proc "c" (r_dest: GDExtensionStringPtr, p_contents: cstring),
	string_new_with_utf8_chars : proc "c" (r_dest: GDExtensionStringPtr, p_contents: cstring),
	string_new_with_utf16_chars : proc "c" (r_dest: GDExtensionStringPtr, p_contents: ^u16),
	string_new_with_utf32_chars : proc "c" (r_dest: GDExtensionStringPtr, p_contents: ^u32),
	string_new_with_wide_chars : proc "c" (r_dest: GDExtensionStringPtr, p_contents: ^u16),
	string_new_with_latin1_chars_and_len : proc "c" (r_dest: GDExtensionStringPtr, p_contents: cstring, p_size: GDExtensionInt),
	string_new_with_utf8_chars_and_len : proc "c" (r_dest: GDExtensionStringPtr, p_contents: cstring, p_size: GDExtensionInt),
	string_new_with_utf16_chars_and_len : proc "c" (r_dest: GDExtensionStringPtr, p_contents: ^u16, p_size: GDExtensionInt),
	string_new_with_utf32_chars_and_len : proc "c" (r_dest: GDExtensionStringPtr, p_contents: ^u32, p_size: GDExtensionInt),
	string_new_with_wide_chars_and_len : proc "c" (r_dest: GDExtensionStringPtr, _contents: ^u16, p_size: GDExtensionInt),
	
	/* Information about the following functions:
	 * - The return value is the resulting encoded string length.
	 * - The length returned is in characters, not in bytes. It also does not include a trailing zero.
	 * - These functions also do not write trailing zero, If you need it, write it yourself at the position indicated by the length (and make sure to allocate it).
	 * - Passing NULL in r_text means only the length is computed (again, without including trailing zero).
	 * - p_max_write_length argument is in characters, not bytes. It will be ignored if r_text is NULL.
	 * - p_max_write_length argument does not affect the return value, it's only to cap write length.
	 */
	string_to_latin1_chars : proc "c" (p_self: GDExtensionConstStringPtr, r_text: cstring, p_max_write_length: GDExtensionInt) -> GDExtensionInt,
	string_to_utf8_chars : proc "c" (p_self: GDExtensionConstStringPtr, r_text: cstring, p_max_write_length: GDExtensionInt) -> GDExtensionInt,
	string_to_utf16_chars : proc "c" (p_self: GDExtensionConstStringPtr, r_text: ^u16, p_max_write_length: GDExtensionInt) -> GDExtensionInt,
	string_to_utf32_chars : proc "c" (p_self: GDExtensionConstStringPtr, r_text: ^u32, p_max_write_length: GDExtensionInt) -> GDExtensionInt,
	string_to_wide_chars : proc "c" (p_self: GDExtensionConstStringPtr, r_text: ^u16, p_max_write_length: GDExtensionInt) -> GDExtensionInt,
	string_operator_index : proc "c" (p_self: GDExtensionStringPtr, p_index: GDExtensionInt) -> ^u32,
	string_operator_index_const : proc "c" (p_self: GDExtensionConstStringPtr, p_index: GDExtensionInt) -> ^u32,

	string_operator_plus_eq_string : proc "c" (p_self: GDExtensionStringPtr, p_b: GDExtensionConstStringPtr),
	string_operator_plus_eq_char : proc "c" (p_self: GDExtensionStringPtr, p_b: u32),
	string_operator_plus_eq_cstr : proc "c" (p_self: GDExtensionStringPtr, p_b: cstring),
	string_operator_plus_eq_wcstr : proc "c" (p_self: GDExtensionStringPtr, p_b: ^u16),
	string_operator_plus_eq_c32str : proc "c" (p_self: GDExtensionStringPtr, p_b: ^u32),

	/*  XMLParser extra utilities */

	xml_parser_open_buffer : proc "c" (p_instance: GDExtensionObjectPtr, p_buffer: ^u8, p_size: c.size_t) -> GDExtensionInt,

	/*  FileAccess extra utilities */

	file_access_store_buffer : proc "c" (p_instance: GDExtensionObjectPtr, p_src: ^u8, p_length: u64),
	file_access_get_buffer : proc "c" (p_instance: GDExtensionConstObjectPtr, p_dst: ^u8, p_length: u64) -> u64,

	/*  WorkerThreadPool extra utilities */

	worker_thread_pool_add_native_group_task : proc "c" (p_instance: GDExtensionObjectPtr, p_func: proc "c" (rawptr, u32), p_userdata: rawptr, p_elements: c.int, p_tasks: c.int, p_high_priority: GDExtensionBool, p_description: GDExtensionConstStringPtr) -> i64,
	worker_thread_pool_add_native_task : proc "c" (p_instance: GDExtensionObjectPtr, p_func: proc "c" (rawptr), p_userdata: rawptr, p_high_priority: GDExtensionBool, p_description: GDExtensionConstStringPtr) -> i64,

	/* Packed array functions */

	packed_byte_array_operator_index : proc "c" (p_self: GDExtensionTypePtr, p_index: GDExtensionInt) -> ^u8, // p_self should be a PackedByteArray
	packed_byte_array_operator_index_const : proc "c" (p_self: GDExtensionConstTypePtr, p_index: GDExtensionInt) -> ^u8, // p_self should be a PackedByteArray

	packed_color_array_operator_index : proc "c" (p_self: GDExtensionTypePtr, p_index: GDExtensionInt) -> GDExtensionTypePtr, // p_self should be a PackedColorArray, returns Color ptr
	packed_color_array_operator_index_const : proc "c" (p_self: GDExtensionConstTypePtr, p_index: GDExtensionInt) -> GDExtensionTypePtr, // p_self should be a PackedColorArray, returns Color ptr

	packed_float32_array_operator_index : proc "c" (p_self: GDExtensionTypePtr, p_index: GDExtensionInt) -> ^f32, // p_self should be a PackedFloat32Array
	packed_float32_array_operator_index_const : proc "c" (p_self: GDExtensionConstTypePtr, p_index: GDExtensionInt) -> ^f32, // p_self should be a PackedFloat32Array
	packed_float64_array_operator_index : proc "c" (p_self: GDExtensionTypePtr, p_index: GDExtensionInt) -> ^f64, // p_self should be a PackedFloat64Array
	packed_float64_array_operator_index_const : proc "c" (p_self: GDExtensionConstTypePtr, p_index: GDExtensionInt) -> ^f64, // p_self should be a PackedFloat64Array

	packed_int32_array_operator_index : proc "c" (p_self: GDExtensionTypePtr, p_index: GDExtensionInt) -> ^i32, // p_self should be a PackedInt32Array
	packed_int32_array_operator_index_const : proc "c" (p_self: GDExtensionConstTypePtr, p_index: GDExtensionInt) -> ^i32, // p_self should be a PackedInt32Array
	packed_int64_array_operator_index : proc "c" (p_self: GDExtensionTypePtr, p_index: GDExtensionInt) -> ^i64, // p_self should be a PackedInt32Array
	packed_int64_array_operator_index_const : proc "c" (p_self: GDExtensionConstTypePtr, p_index: GDExtensionInt) -> ^i64, // p_self should be a PackedInt32Array

	packed_string_array_operator_index : proc "c" (p_self: GDExtensionTypePtr, p_index: GDExtensionInt) -> GDExtensionStringPtr, // p_self should be a PackedStringArray
	packed_string_array_operator_index_const : proc "c" (p_self: GDExtensionConstTypePtr, p_index: GDExtensionInt) -> GDExtensionStringPtr, // p_self should be a PackedStringArray

	packed_vector2_array_operator_index : proc "c" (p_self: GDExtensionTypePtr, p_index: GDExtensionInt) -> GDExtensionTypePtr, // p_self should be a PackedVector2Array, returns Vector2 ptr
	packed_vector2_array_operator_index_const : proc "c" (p_self: GDExtensionConstTypePtr, p_index: GDExtensionInt) -> GDExtensionTypePtr, // p_self should be a PackedVector2Array, returns Vector2 ptr
	packed_vector3_array_operator_index : proc "c" (p_self: GDExtensionTypePtr, p_index: GDExtensionInt) -> GDExtensionTypePtr, // p_self should be a PackedVector3Array, returns Vector3 ptr
	packed_vector3_array_operator_index_const : proc "c" (p_self: GDExtensionConstTypePtr, p_index: GDExtensionInt) -> GDExtensionTypePtr, // p_self should be a PackedVector3Array, returns Vector3 ptr

	array_operator_index : proc "c" (p_self: GDExtensionTypePtr, p_index: GDExtensionInt) -> GDExtensionVariantPtr, // p_self should be an Array ptr
	array_operator_index_const : proc "c" (p_self: GDExtensionConstTypePtr, p_index: GDExtensionInt) -> GDExtensionVariantPtr, // p_self should be an Array ptr
	array_ref : proc "c" (p_self: GDExtensionTypePtr, p_from: GDExtensionConstTypePtr), // p_self should be an Array ptr
	array_set_typed : proc "c" (p_self: GDExtensionTypePtr, p_type: GDExtensionVariantType, p_class_name: GDExtensionConstStringNamePtr, p_script: GDExtensionConstVariantPtr), // p_self should be an Array ptr

	/* Dictionary functions */

	dictionary_operator_index : proc "c" (p_self: GDExtensionTypePtr, p_key: GDExtensionConstVariantPtr) -> GDExtensionVariantPtr, // p_self should be an Dictionary ptr
	dictionary_operator_index_const : proc "c" (p_self: GDExtensionConstTypePtr, p_key: GDExtensionConstVariantPtr) -> GDExtensionVariantPtr, // p_self should be an Dictionary ptr

	/* OBJECT */

	object_method_bind_call : proc "c" (p_method_bind: GDExtensionMethodBindPtr, p_instance: GDExtensionObjectPtr, p_args: ^GDExtensionConstVariantPtr, p_arg_count: GDExtensionInt, r_ret: GDExtensionVariantPtr, r_error: ^GDExtensionCallError),
	object_method_bind_ptrcall : proc "c" (p_method_bind: GDExtensionMethodBindPtr, p_instance: GDExtensionObjectPtr, p_args: ^GDExtensionConstTypePtr, r_ret: GDExtensionTypePtr),
	object_destroy : proc "c" (p_o: GDExtensionObjectPtr),
	global_get_singleton : proc "c" (p_name: GDExtensionConstStringNamePtr) -> GDExtensionObjectPtr,

	object_get_instance_binding : proc "c" (p_o: GDExtensionObjectPtr, p_token: rawptr, p_callbacks: ^GDExtensionInstanceBindingCallbacks) -> rawptr,
	object_set_instance_binding : proc "c" (p_o: GDExtensionObjectPtr, p_token: rawptr, p_binding: rawptr, p_callbacks: ^GDExtensionInstanceBindingCallbacks),

	object_set_instance : proc "c" (p_o: GDExtensionObjectPtr, p_classname: GDExtensionConstStringNamePtr, p_instance: GDExtensionClassInstancePtr), /* p_classname should be a registered extension class and should extend the p_o object's class. */

	object_cast_to : proc "c" (p_object: GDExtensionConstObjectPtr, p_class_tag: rawptr) -> GDExtensionObjectPtr,
	object_get_instance_from_id : proc "c" (p_instance_id: GDObjectInstanceID) -> GDExtensionObjectPtr,
	object_get_instance_id : proc "c" (p_object: GDExtensionConstObjectPtr) -> GDObjectInstanceID,

	/* REFERENCE */

	ref_get_object : proc "c" (p_ref: GDExtensionConstRefPtr) -> GDExtensionObjectPtr,
	ref_set_object : proc "c" (p_ref: GDExtensionRefPtr, p_object: GDExtensionObjectPtr),

	/* SCRIPT INSTANCE */

	script_instance_create : proc "c" (p_info: ^GDExtensionScriptInstanceInfo, p_instance_data: GDExtensionScriptInstanceDataPtr) -> GDExtensionScriptInstancePtr,

	/* CLASSDB */

	classdb_construct_object : proc "c" (p_classname: GDExtensionConstStringNamePtr) -> GDExtensionObjectPtr, /* The passed class must be a built-in godot class, or an already-registered extension class. In both case, object_set_instance should be called to fully initialize the object. */
	classdb_get_method_bind : proc "c" (p_classname: GDExtensionConstStringNamePtr, p_methodname: GDExtensionConstStringNamePtr, p_hash: GDExtensionInt) -> GDExtensionMethodBindPtr,
	classdb_get_class_tag : proc "c" (p_classname: GDExtensionConstStringNamePtr) -> rawptr,

	/* CLASSDB EXTENSION */

	/* Provided parameters for `classdb_register_extension_*` can be safely freed once the function returns. */
	classdb_register_extension_class : proc "c" (p_library: GDExtensionClassLibraryPtr, p_class_name: GDExtensionConstStringNamePtr, p_parent_class_name: GDExtensionConstStringNamePtr, p_extension_funcs: ^GDExtensionClassCreationInfo),
	classdb_register_extension_class_method : proc "c" (p_library: GDExtensionClassLibraryPtr, p_class_name: GDExtensionConstStringNamePtr, p_method_info: ^GDExtensionClassMethodInfo),
	classdb_register_extension_class_integer_constant : proc "c" (p_library: GDExtensionClassLibraryPtr, p_class_name: GDExtensionConstStringNamePtr, p_enum_name: GDExtensionConstStringNamePtr, p_constant_name: GDExtensionConstStringNamePtr, p_constant_value: GDExtensionInt, p_is_bitfield: GDExtensionBool),
	classdb_register_extension_class_property : proc "c" (p_library: GDExtensionClassLibraryPtr, p_class_name: GDExtensionConstStringNamePtr, p_info: ^GDExtensionPropertyInfo, p_setter: GDExtensionConstStringNamePtr, p_getter: GDExtensionConstStringNamePtr),
	classdb_register_extension_class_property_group : proc "c" (p_library: GDExtensionClassLibraryPtr, p_class_name: GDExtensionConstStringNamePtr, p_group_name: GDExtensionConstStringPtr, p_prefix: GDExtensionConstStringPtr),
	classdb_register_extension_class_property_subgroup : proc "c" (p_library: GDExtensionClassLibraryPtr, p_class_name: GDExtensionConstStringNamePtr, p_subgroup_name: GDExtensionConstStringPtr, p_prefix: GDExtensionConstStringPtr),
	classdb_register_extension_class_signal : proc "c" (p_library: GDExtensionClassLibraryPtr, p_class_name: GDExtensionConstStringNamePtr, p_signal_name: GDExtensionConstStringNamePtr, p_argument_info: ^GDExtensionPropertyInfo, p_argument_count: GDExtensionInt),
	classdb_unregister_extension_class : proc "c" (p_library: GDExtensionClassLibraryPtr, p_class_name: GDExtensionConstStringNamePtr), /* Unregistering a parent class before a class that inherits it will result in failure. Inheritors must be unregistered first. */

	get_library_path : proc "c" (p_library: GDExtensionClassLibraryPtr, r_path: GDExtensionStringPtr),

}

/* INITIALIZATION */

GDExtensionInitializationLevel :: enum i32 {
	GDEXTENSION_INITIALIZATION_CORE,
	GDEXTENSION_INITIALIZATION_SERVERS,
	GDEXTENSION_INITIALIZATION_SCENE,
	GDEXTENSION_INITIALIZATION_EDITOR,
	GDEXTENSION_MAX_INITIALIZATION_LEVEL,
}

GDExtensionInitialization ::  struct {
	/* Minimum initialization level required.
	 * If Core or Servers, the extension needs editor or game restart to take effect */
	minimum_initialization_level : GDExtensionInitializationLevel,
	/* Up to the user to supply when initializing */
	userdata : rawptr,
	/* This function will be called multiple times for each initialization level. */
	initialize : proc "c" (userdata: rawptr, p_level: GDExtensionInitializationLevel),
	deinitialize : proc "c" (userdata: rawptr, p_level: GDExtensionInitializationLevel),
}

/* Define a C function prototype that implements the function below and expose it to dlopen() (or similar).
 * This is the entry point of the GDExtension library and will be called on initialization.
 * It can be used to set up different init levels, which are called during various stages of initialization/shutdown.
 * The function name must be a unique one specified in the .gdextension config file.
 */
GDExtensionInitializationFunction :: proc "c" (p_interface: ^GDExtensionInterface, p_library: GDExtensionClassLibraryPtr, r_initialization: ^GDExtensionInitialization) -> GDExtensionBool



