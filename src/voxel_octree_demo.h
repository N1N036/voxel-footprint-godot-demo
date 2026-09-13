#pragma once
#include <godot_cpp/classes/multi_mesh_instance3d.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/classes/shader.hpp>
#include <unordered_set>
#include <vector>
namespace godot {
class VoxelOctreeDemo : public MultiMeshInstance3D {
    GDCLASS(VoxelOctreeDemo, MultiMeshInstance3D)
    struct Node {
        Vector3 center, position, normal;
        Color color = Color(0,0,0,0);
        float size = 38.4f;
        int children[8] = {-1,-1,-1,-1,-1,-1,-1,-1};
        int count = 0;
        bool split = false;
        float surface_area = 0;
    };
    std::vector<Node> nodes;
    std::vector<int> previous_cut;
    std::unordered_set<uint64_t> occupied;
    Ref<MultiMesh> instances;
    Ref<ShaderMaterial> voxel_material;
    Ref<Shader> shadowed_shader, unshadowed_shader;
    int normal_mode = 0;
    float target = 1.5f;
    bool diagnostic = false, dirty = true, frozen = false;
    bool imported = false;
    int leaf_count = 0;
    double selection_ms = 0;
    void sample(Vector3 p, Color c, Vector3 normal = Vector3(0,1,0), float area = 0);
    void box(Vector3 p, Vector3 size, Color c);
    void ellipsoid(Vector3 p, Vector3 scale, Color c);
    void cylinder(Vector3 p, float radius, float top_radius, float height, Color c);
    void build_scene();
    void select(int index, const Transform3D &view, float focal, float near_plane, std::vector<int> &cut);
protected:
    static void _bind_methods();
public:
    void _ready() override;
    void _process(double delta) override;
    void set_target_pixel_footprint(float value);
    float get_target_pixel_footprint() const { return target; }
    void set_diagnostic(bool value) { diagnostic = value; dirty = true; }
    void set_frozen(bool value) { frozen = value; }
    int get_selected_count() const { return int(previous_cut.size()); }
    int get_leaf_count() const { return leaf_count; }
    double get_selection_ms() const { return selection_ms; }
    bool validate_cut() const;
    void load_mesh(const Ref<Mesh> &mesh);
    void set_hysteresis(bool enabled) { hysteresis = enabled; }
    double get_cut_churn() const { return cut_churn; }
    bool hysteresis = true;
    double cut_churn = 0;
    int sampling_depth = 9;
    float leaf_size = 0.075f;
    void set_sampling_depth(int depth);
    void reset_lod_history();
    void set_normal_mode(int mode);
    void set_voxel_shadows(bool enabled);
};
}
