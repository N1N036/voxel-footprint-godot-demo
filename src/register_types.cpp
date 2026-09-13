#include "register_types.h"
#include "voxel_octree_demo.h"
#include "probe_splat_demo.h"

#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_voxel_footprint_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
	ClassDB::register_class<VoxelOctreeDemo>();
	ClassDB::register_class<ProbeSplatDemo>();
}

void uninitialize_voxel_footprint_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
}

extern "C" GDExtensionBool GDE_EXPORT voxel_footprint_library_init(
		GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library,
		GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_voxel_footprint_module);
	init_obj.register_terminator(uninitialize_voxel_footprint_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
