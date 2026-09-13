#pragma once

#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/variant/color.hpp>
#include <vector>

namespace godot {

class VoxelOctreeDemo : public MeshInstance3D {
	GDCLASS(VoxelOctreeDemo, MeshInstance3D)

	struct Node {
		Vector3 center;
		float size;
		Color color;
		int children[8];
		bool solid;
	};

	std::vector<Node> nodes;
	float target_pixel_footprint = 1.5f;
	int internal_render_width = 320;
	Vector3 previous_camera_position;

	void build_octree();
	int make_node(const Vector3 &p_center, float p_size, int p_depth);
	bool terrain_contains(const Vector3 &p) const;
	void select_nodes(int p_index, const Vector3 &p_camera, std::vector<int> &r_selected) const;
	void rebuild_mesh(const std::vector<int> &p_selected);
	void append_cube(const Node &p_node, PackedVector3Array &r_vertices, PackedVector3Array &r_normals,
			PackedColorArray &r_colors, PackedInt32Array &r_indices) const;

protected:
	static void _bind_methods();

public:
	VoxelOctreeDemo();
	void _process(double p_delta) override;
	void set_target_pixel_footprint(float p_value);
	float get_target_pixel_footprint() const;
	void set_internal_render_width(int p_value);
	int get_internal_render_width() const;
};

} // namespace godot

