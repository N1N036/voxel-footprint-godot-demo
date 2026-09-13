#pragma once
#include <godot_cpp/classes/multi_mesh_instance3d.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <vector>
namespace godot {
class ProbeSplatDemo : public MultiMeshInstance3D {
    GDCLASS(ProbeSplatDemo,MultiMeshInstance3D)
    struct Tri { Vector3 p[3], n[3]; Color c[3]; Vector3 center; };
    struct Branch { Vector3 lo,hi; int start=0,count=0,left=-1,right=-1; };
    std::vector<Tri> triangles;
    std::vector<int> order;
    std::vector<Branch> tree;
    std::vector<int> prior_triangle;
    Ref<MultiMesh> instances;
    double capture_ms=0,reassignment=0;
    int splats=0;
    int build(int start,int end);
    bool bounds(const Branch &b,const Vector3 &o,const Vector3 &inv,float limit) const;
    int trace(Vector3 o,Vector3 d,float &distance,float &u,float &v) const;
protected:
    static void _bind_methods();
public:
    void load_mesh(const Ref<Mesh> &mesh);
    void capture(Transform3D object_transform,Vector3 origin,int resolution);
    double get_capture_ms() const { return capture_ms; }
    double get_reassignment() const { return reassignment; }
    int get_splat_count() const { return splats; }
};
}
