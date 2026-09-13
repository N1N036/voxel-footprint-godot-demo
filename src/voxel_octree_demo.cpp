#include "voxel_octree_demo.h"

#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/standard_material3d.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cmath>
#include <algorithm>

using namespace godot;

VoxelOctreeDemo::VoxelOctreeDemo() {
	build_octree();
	set_process(true);
}

void VoxelOctreeDemo::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_target_pixel_footprint", "value"), &VoxelOctreeDemo::set_target_pixel_footprint);
	ClassDB::bind_method(D_METHOD("get_target_pixel_footprint"), &VoxelOctreeDemo::get_target_pixel_footprint);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "target_pixel_footprint", PROPERTY_HINT_RANGE, "0.5,6,0.1"),
			"set_target_pixel_footprint", "get_target_pixel_footprint");
	ClassDB::bind_method(D_METHOD("set_internal_render_width", "value"), &VoxelOctreeDemo::set_internal_render_width);
	ClassDB::bind_method(D_METHOD("get_internal_render_width"), &VoxelOctreeDemo::get_internal_render_width);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "internal_render_width", PROPERTY_HINT_RANGE, "64,1024,1"),
			"set_internal_render_width", "get_internal_render_width");
}

bool VoxelOctreeDemo::terrain_contains(const Vector3 &p) const {
	if (p.y < -7.8f) return true; // Close the base of the small diorama.
	const float hill = 1.6f * std::sin(p.x * 0.48f) + 1.15f * std::cos(p.z * 0.42f)
		+ 0.75f * std::sin((p.x + p.z) * 0.7f);
	const float island = 3.2f - p.length() * 0.18f;
	return p.y < hill + island - 0.8f;
}

int VoxelOctreeDemo::make_node(const Vector3 &p_center, float p_size, int p_depth) {
	const float half = p_size * 0.5f;
	bool any_solid = false;
	bool any_empty = false;
	for (int x = -1; x <= 1; x += 2) {
		for (int y = -1; y <= 1; y += 2) {
			for (int z = -1; z <= 1; z += 2) {
				const bool solid = terrain_contains(p_center + Vector3(x * half, y * half, z * half));
				any_solid |= solid;
				any_empty |= !solid;
			}
		}
	}
	const bool center_solid = terrain_contains(p_center);
	any_solid |= center_solid;
	any_empty |= !center_solid;
	if (!any_solid) return -1;

	Node node {};
	node.center = p_center;
	node.size = p_size;
	node.color = Color(0.20f + (p_center.y + 8.0f) * 0.015f, 0.40f + (p_center.y + 8.0f) * 0.020f,
			0.25f + (std::sin(p_center.x) + 1.0f) * 0.035f);
	node.solid = !any_empty || p_depth == 0;
	for (int &child : node.children) child = -1;

	const int index = static_cast<int>(nodes.size());
	nodes.push_back(node);
	if (node.solid) return index;

	Color colour_sum(0, 0, 0, 0);
	int child_count = 0;
	const float child_size = p_size * 0.5f;
	const float child_offset = p_size * 0.25f;
	for (int x = -1; x <= 1; x += 2) {
		for (int y = -1; y <= 1; y += 2) {
			for (int z = -1; z <= 1; z += 2) {
				const int child_slot = ((x + 1) / 2) * 4 + ((y + 1) / 2) * 2 + ((z + 1) / 2);
				const int child = make_node(p_center + Vector3(x * child_offset, y * child_offset, z * child_offset), child_size, p_depth - 1);
				nodes[index].children[child_slot] = child;
				if (child >= 0) {
					colour_sum += nodes[child].color;
					++child_count;
				}
			}
		}
	}
	if (child_count == 0) return -1;
	nodes[index].color = colour_sum / static_cast<float>(child_count); // Filtered parent representation.
	return index;
}

void VoxelOctreeDemo::build_octree() {
	nodes.clear();
	make_node(Vector3(0, 0, 0), 16.0f, 4);
}

void VoxelOctreeDemo::select_nodes(int p_index, const Vector3 &p_camera, std::vector<int> &r_selected) const {
	const Node &node = nodes[p_index];
	const float distance = std::max(0.05f, p_camera.distance_to(node.center));
	// fov_factor is deliberately approximate: at a fixed low-res target, stability
	// and an intuitive artistic knob matter more than a physically exact bound.
	const float projected_pixels = node.size * static_cast<float>(internal_render_width) / (distance * 1.04f);
	bool has_children = false;
	for (const int child : node.children) has_children |= child >= 0;
	if (!has_children || projected_pixels <= target_pixel_footprint) {
		r_selected.push_back(p_index);
		return;
	}
	for (const int child : node.children) {
		if (child >= 0) select_nodes(child, p_camera, r_selected);
	}
}

void VoxelOctreeDemo::append_cube(const Node &p_node, PackedVector3Array &r_vertices, PackedVector3Array &r_normals,
		PackedColorArray &r_colors, PackedInt32Array &r_indices) const {
	static const Vector3 normals[] = { Vector3(1,0,0), Vector3(-1,0,0), Vector3(0,1,0), Vector3(0,-1,0), Vector3(0,0,1), Vector3(0,0,-1) };
	static const Vector3 corners[][4] = {
		{Vector3(1,-1,-1),Vector3(1,1,-1),Vector3(1,1,1),Vector3(1,-1,1)},
		{Vector3(-1,-1,1),Vector3(-1,1,1),Vector3(-1,1,-1),Vector3(-1,-1,-1)},
		{Vector3(-1,1,-1),Vector3(-1,1,1),Vector3(1,1,1),Vector3(1,1,-1)},
		{Vector3(-1,-1,1),Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,-1,1)},
		{Vector3(-1,-1,1),Vector3(1,-1,1),Vector3(1,1,1),Vector3(-1,1,1)},
		{Vector3(1,-1,-1),Vector3(-1,-1,-1),Vector3(-1,1,-1),Vector3(1,1,-1)} };
	const float half = p_node.size * 0.5f;
	for (int face = 0; face < 6; ++face) {
		const int base = r_vertices.size();
		for (int i = 0; i < 4; ++i) {
			r_vertices.push_back(p_node.center + corners[face][i] * half);
			r_normals.push_back(normals[face]);
			r_colors.push_back(p_node.color);
		}
		for (int i : {0, 1, 2, 0, 2, 3}) r_indices.push_back(base + i);
	}
}

void VoxelOctreeDemo::rebuild_mesh(const std::vector<int> &p_selected) {
	PackedVector3Array vertices, normals;
	PackedColorArray colors;
	PackedInt32Array indices;
	for (const int index : p_selected) append_cube(nodes[index], vertices, normals, colors, indices);
	Array arrays;
	arrays.resize(Mesh::ARRAY_MAX);
	arrays[Mesh::ARRAY_VERTEX] = vertices;
	arrays[Mesh::ARRAY_NORMAL] = normals;
	arrays[Mesh::ARRAY_COLOR] = colors;
	arrays[Mesh::ARRAY_INDEX] = indices;
	Ref<ArrayMesh> result;
	result.instantiate();
	result->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES, arrays);
	Ref<StandardMaterial3D> material;
	material.instantiate();
	// ArrayMesh vertex colors are consumed as the material albedo by the standard
	// material path; keeping the colours on the generated mesh also makes each
	// parent voxel's filtered representative colour explicit.
	material->set_roughness(1.0f);
	result->surface_set_material(0, material);
	set_mesh(result);
}

void VoxelOctreeDemo::_process(double) {
	Viewport *viewport = get_viewport();
	if (!viewport || nodes.empty()) return;
	Camera3D *camera = viewport->get_camera_3d();
	if (!camera) return;
	std::vector<int> selected;
	select_nodes(0, camera->get_global_position(), selected);
	rebuild_mesh(selected);
}

void VoxelOctreeDemo::set_target_pixel_footprint(float p_value) { target_pixel_footprint = std::clamp(p_value, 0.5f, 6.0f); }
float VoxelOctreeDemo::get_target_pixel_footprint() const { return target_pixel_footprint; }
void VoxelOctreeDemo::set_internal_render_width(int p_value) { internal_render_width = std::max(16, p_value); }
int VoxelOctreeDemo::get_internal_render_width() const { return internal_render_width; }
