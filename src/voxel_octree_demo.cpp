#include "voxel_octree_demo.h"
#include <godot_cpp/classes/box_mesh.hpp>
#include <godot_cpp/classes/standard_material3d.hpp>
#include <godot_cpp/classes/shader.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/classes/viewport.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <algorithm>
#include <cmath>
#include <chrono>
using namespace godot;
namespace {
constexpr float CELL = 0.075f;
constexpr float PI = 3.14159265359f;
float noise(Vector3 p) { return std::sin(p.x*19.17f+p.y*73.13f+p.z*39.73f)*0.012f; }
float ground(float x, float z) {
    return 0.8f + 0.28f*std::sin(x*0.7f)*std::cos(z*0.8f) + 0.15f*std::sin(z*1.4f+x);
}
}
void VoxelOctreeDemo::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_target_pixel_footprint", "value"), &VoxelOctreeDemo::set_target_pixel_footprint);
    ClassDB::bind_method(D_METHOD("get_target_pixel_footprint"), &VoxelOctreeDemo::get_target_pixel_footprint);
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "target_pixel_footprint"), "set_target_pixel_footprint", "get_target_pixel_footprint");
    ClassDB::bind_method(D_METHOD("set_diagnostic", "value"), &VoxelOctreeDemo::set_diagnostic);
    ClassDB::bind_method(D_METHOD("set_frozen", "value"), &VoxelOctreeDemo::set_frozen);
    ClassDB::bind_method(D_METHOD("get_selected_count"), &VoxelOctreeDemo::get_selected_count);
    ClassDB::bind_method(D_METHOD("get_leaf_count"), &VoxelOctreeDemo::get_leaf_count);
    ClassDB::bind_method(D_METHOD("get_selection_ms"), &VoxelOctreeDemo::get_selection_ms);
    ClassDB::bind_method(D_METHOD("validate_cut"), &VoxelOctreeDemo::validate_cut);
}
void VoxelOctreeDemo::sample(Vector3 p, Color c, Vector3 normal) {
    int xyz[3];
    for (int a=0;a<3;++a) { xyz[a]=int(std::floor((p[a]+19.2f)/CELL)); if(xyz[a]<0||xyz[a]>=512) return; }
    uint64_t key=uint64_t(xyz[0]) | (uint64_t(xyz[1])<<9) | (uint64_t(xyz[2])<<18);
    if(!occupied.insert(key).second) return;
    ++leaf_count;
    float n=noise(p);
    c=Color(std::clamp(c.r+n,0.0f,1.0f),std::clamp(c.g+n,0.0f,1.0f),std::clamp(c.b+n,0.0f,1.0f),1);
    int index=0;
    for(int depth=0;depth<=9;++depth) {
        nodes[index].position += p; nodes[index].color += c; nodes[index].normal += normal; ++nodes[index].count;
        if(depth==9) break;
        int bit=8-depth;
        int slot=((xyz[0]>>bit)&1)*4+((xyz[1]>>bit)&1)*2+((xyz[2]>>bit)&1);
        int next=nodes[index].children[slot];
        if(next<0) {
            Node child; child.size=nodes[index].size*0.5f;
            child.center=nodes[index].center+Vector3((slot&4)?1:-1,(slot&2)?1:-1,(slot&1)?1:-1)*child.size*0.5f;
            next=int(nodes.size()); nodes[index].children[slot]=next; nodes.push_back(child);
        }
        index=next;
    }
}
void VoxelOctreeDemo::box(Vector3 p, Vector3 size, Color c) {
    for(int axis=0;axis<3;++axis) {
        int a=(axis+1)%3,b=(axis+2)%3;
        int na=int(std::ceil(size[a]/0.06f)),nb=int(std::ceil(size[b]/0.06f));
        for(int sign : {-1,1}) for(int i=0;i<=na;++i) for(int j=0;j<=nb;++j) {
            Vector3 q=p; q[axis]+=sign*size[axis]*0.5f;
            q[a]+=size[a]*(float(i)/na-0.5f); q[b]+=size[b]*(float(j)/nb-0.5f);
            Vector3 normal; normal[axis]=float(sign); sample(q,c,normal);
        }
    }
}
void VoxelOctreeDemo::ellipsoid(Vector3 p, Vector3 scale, Color c) {
    int rings=int(std::ceil(PI*std::max({scale.x,scale.y,scale.z})/0.06f));
    for(int i=0;i<=rings;++i) {
        float theta=PI*i/rings; int steps=std::max(8,int(2*rings*std::sin(theta)));
        for(int j=0;j<steps;++j) {
            float phi=2*PI*j/steps;
            Vector3 direction(std::sin(theta)*std::cos(phi),std::cos(theta),std::sin(theta)*std::sin(phi));
            sample(p+direction*scale,c,(direction/scale).normalized());
        }
    }
}
void VoxelOctreeDemo::cylinder(Vector3 p,float radius,float top_radius,float height,Color c) {
    int steps=int(std::ceil(2*PI*std::max(radius,top_radius)/0.055f));
    int rows=int(std::ceil(height/0.06f));
    for(int y=0;y<=rows;++y) {
        float t=float(y)/rows,r=radius+(top_radius-radius)*t;
        for(int i=0;i<steps;++i) { float a=2*PI*i/steps; sample(p+Vector3(r*std::cos(a),t*height,r*std::sin(a)),c,Vector3(std::cos(a),(radius-top_radius)/height,std::sin(a)).normalized()); }
    }
    for(int cap=0;cap<2;++cap) {
        float r=cap?top_radius:radius;
        for(float x=-r;x<=r;x+=0.06f) for(float z=-r;z<=r;z+=0.06f)
            if(x*x+z*z<=r*r) sample(p+Vector3(x,cap*height,z),c,Vector3(0,cap?1:-1,0));
    }
}
void VoxelOctreeDemo::build_scene() {
    nodes.reserve(400000); nodes.emplace_back();
    // Densely sampled surfaces: empty interior cells are never allocated.
    for(float x=-7.5f;x<=7.5f;x+=0.06f) for(float z=-6;z<=6;z+=0.06f) {
        float r=std::sqrt(x*x/49+z*z/25);
        float edge=1+0.045f*std::sin(std::atan2(z,x)*9);
        if(r>edge) continue;
        float y=ground(x,z)-std::max(0.0f,r-0.80f)*5;
        float path=std::abs(x-(1.0f+0.42f*z));
        Color c=path<0.55f&&z>0?Color::html("bdac7d"):Color::html("64744a");
        if(r>0.86f)c=Color::html("a39672");
        Vector3 normal=Vector3((ground(x-0.03f,z)-ground(x+0.03f,z))/0.06f,1,(ground(x,z-0.03f)-ground(x,z+0.03f))/0.06f).normalized();
        if(r>0.8f)normal=Vector3(x/7,1,z/5).normalized();
        sample(Vector3(x,y,z),c,normal);
        if(r>0.9f) for(float h=-0.85f;h<y;h+=0.06f) sample(Vector3(x,h,z),Color::html("686d66"),Vector3(x,0,z).normalized());
    }
    cylinder(Vector3(-1,0.75f,-1),1.4f,1.4f,0.45f,Color::html("b6a17b"));
    cylinder(Vector3(-1,1.2f,-1),1.12f,0.966f,3.2f,Color::html("e5d2a3"));
    cylinder(Vector3(-1,4.4f,-1),0.966f,0.923f,0.9f,Color::html("b36345"));
    cylinder(Vector3(-1,5.3f,-1),0.923f,0.85f,1.5f,Color::html("e5d2a3"));
    cylinder(Vector3(-1,6.8f,-1),1.3f,1.3f,0.22f,Color::html("524e47"));
    cylinder(Vector3(-1,8.1f,-1),1.25f,0.08f,0.75f,Color::html("a84f36"));
    cylinder(Vector3(-1,8.85f,-1),0.06f,0.035f,0.5f,Color::html("393e3c"));
    for(int i=0;i<8;++i) { float a=i*PI/4; box(Vector3(-1+0.86f*std::cos(a),7.55f,-1+0.86f*std::sin(a)),Vector3(0.10f,1.08f,0.10f),Color::html("434b46")); }
    box(Vector3(-1,1.85f,0.12f),Vector3(0.55f,1.3f,0.09f),Color::html("344647"));
    for(float y : {3.1f,5.8f}) box(Vector3(-1,y,-0.02f),Vector3(0.26f,0.48f,0.09f),Color::html("455e62"));
    // Keeper's cottage and a stepped terracotta gable.
    box(Vector3(2.65f,1.65f,-1.7f),Vector3(2.3f,1.7f,2.1f),Color::html("c9b88b"));
    for(int i=0;i<14;++i) box(Vector3(2.65f,2.5f+i*0.065f,-1.7f),Vector3(2.7f-i*0.17f,0.075f,2.55f),Color::html("9d563c"));
    box(Vector3(3.25f,3.3f,-2.15f),Vector3(0.35f,1.0f,0.4f),Color::html("af9878"));
    for(float x : {2.05f,3.25f}) { box(Vector3(x,1.8f,-0.62f),Vector3(0.48f,0.58f,0.08f),Color::html("314f50")); box(Vector3(x,1.43f,-0.55f),Vector3(0.7f,0.12f,0.22f),Color::html("e0cea1")); }
    // Landing pier and bollards.
    for(int i=0;i<27;++i) box(Vector3(3.3f,0.3f,3.5f+i*0.18f),Vector3(1.5f,0.12f,0.15f),Color::html(i%3?"8e7354":"a48a62"));
    for(float z : {4.3f,6.0f,7.8f}) for(float x : {2.56f,4.04f}) { box(Vector3(x,0.10f,z),Vector3(0.15f,1.2f,0.15f),Color::html("655641")); box(Vector3(x,0.68f,z),Vector3(0.23f,0.13f,0.23f),Color::html("c1ae81")); }
    // Wind-shaped pines with irregular flattened crowns.
    for(Vector3 p : {Vector3(-4,0,1.1f),Vector3(-4.8f,0,-1.8f),Vector3(4.7f,0,0.5f),Vector3(1.8f,0,-4)}) {
        p.y=ground(p.x,p.z);
        cylinder(p,0.16f,0.075f,2.35f,Color::html("6e5943"));
        ellipsoid(p+Vector3(-0.4f,2.25f,0),Vector3(1.3f,0.5f,0.92f),Color::html("334f42"));
        ellipsoid(p+Vector3(-0.85f,2.7f,0.2f),Vector3(1.05f,0.48f,0.8f),Color::html("4f6847"));
        ellipsoid(p+Vector3(-0.4f,3.02f,0.15f),Vector3(0.65f,0.28f,0.6f),Color::html("79824e"));
    }
    for(int i=0;i<23;++i) {
        float a=i*2.39996f; Vector3 p(6.5f*std::cos(a),-0.22f,5.2f*std::sin(a));
        float s=0.3f+0.18f*(i%4); ellipsoid(p,Vector3(s,s*0.7f,s*0.8f),Color::html("7b8580"));
    }
    for(int i=0;i<110;++i) {
        float a=i*2.39996f,r=2+3.5f*float(i%17)/17; float x=r*std::cos(a),z=r*0.68f*std::sin(a);
        if(std::abs(x-1-0.42f*z)<0.8f)continue;
        box(Vector3(x,ground(x,z)+0.12f,z),Vector3(0.075f,0.18f,0.075f),Color::html("566747"));
        sample(Vector3(x,ground(x,z)+0.24f,z),Color::html(i%3?"c7af64":"ce8960"));
    }
    for(Node &n:nodes) {
        n.position/=float(n.count); n.color/=float(n.count); n.color.a=1;
        n.normal=n.normal.length_squared()>0.001f?n.normal.normalized():Vector3(0,1,0);
    }
    occupied.clear(); occupied.rehash(0);
}
void VoxelOctreeDemo::_ready() {
    build_scene();
    instances.instantiate(); instances->set_transform_format(MultiMesh::TRANSFORM_3D); instances->set_use_colors(true); instances->set_use_custom_data(true);
    Ref<BoxMesh> cube; cube.instantiate(); cube->set_size(Vector3(1,1,1));
    Ref<Shader> shader; shader.instantiate();
    shader->set_code("shader_type spatial; render_mode specular_disabled; void vertex() { NORMAL = normalize(INSTANCE_CUSTOM.xyz); } void fragment() { ALBEDO = COLOR.rgb; ROUGHNESS = 1.0; }");
    Ref<ShaderMaterial> material; material.instantiate(); material->set_shader(shader);
    cube->set_material(material); instances->set_mesh(cube); set_multimesh(instances);
    set_custom_aabb(AABB(Vector3(-19.2f,-19.2f,-19.2f),Vector3(38.4f,38.4f,38.4f)));
}
void VoxelOctreeDemo::select(int index,const Transform3D &view,float focal,float near_plane,std::vector<int> &cut) {
    Node &n=nodes[index]; Vector3 p=view.xform(n.center);
    // Camera-space near face gives a conservative, monotonic depth bound.
    float depth=std::max(near_plane,-p.z-n.size*0.866026f);
    float pixels=n.size*focal/depth;
    bool leaf=n.size<CELL*1.01f;
    float threshold=target*(n.split?0.88f:1.12f);
    if(leaf||pixels<=threshold) { n.split=false; cut.push_back(index); return; }
    n.split=true;
    for(int child:n.children) if(child>=0)select(child,view,focal,near_plane,cut);
}
void VoxelOctreeDemo::_process(double) {
    if(nodes.empty()||!instances.is_valid())return;
    Camera3D *camera=get_viewport()->get_camera_3d(); if(!camera)return;
    auto start=std::chrono::steady_clock::now(); std::vector<int> cut;
    if(frozen&&!previous_cut.empty())cut=previous_cut;
    else {
        Vector2 size=get_viewport()->get_visible_rect().size;
        float axis=camera->get_keep_aspect_mode()==Camera3D::KEEP_HEIGHT?size.y:size.x;
        float focal=axis/(2*std::tan(camera->get_fov()*PI/360));
        select(0,camera->get_global_transform().affine_inverse()*get_global_transform(),focal,camera->get_near(),cut);
    }
    selection_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();
    if(cut==previous_cut&&!dirty)return;
    instances->set_instance_count(int(cut.size()));
    PackedFloat32Array buffer; buffer.resize(int(cut.size())*20); float *data=buffer.ptrw();
    for(size_t i=0;i<cut.size();++i) {
        const Node &n=nodes[cut[i]]; float s=n.size*1.08f;
        // Bound the filtered centroid's offset so adjacent cubes overlap even
        // when source samples sit on opposite edges of their leaf cells.
        Vector3 offset=n.position-n.center;
        for(int axis=0;axis<3;++axis)offset[axis]=std::clamp(offset[axis],-n.size*0.025f,n.size*0.025f);
        Vector3 p=n.center+offset; Color c=n.color;
        if(diagnostic)c=Color::from_hsv(std::fmod(std::log2(n.size/CELL)*0.16f+0.04f,1.0f),0.65f,0.95f);
        float values[20]={s,0,0,p.x,0,s,0,p.y,0,0,s,p.z,c.r,c.g,c.b,1,n.normal.x,n.normal.y,n.normal.z,0};
        std::copy(values,values+20,data+i*20);
    }
    instances->set_buffer(buffer); previous_cut=std::move(cut); dirty=false;
}
void VoxelOctreeDemo::set_target_pixel_footprint(float value) { target=std::clamp(value,0.5f,8.0f); }
bool VoxelOctreeDemo::validate_cut() const {
    // Every source leaf must have exactly one selected ancestor (or itself).
    if(previous_cut.empty())return false;
    std::vector<int> marked(nodes.size(),0);
    for(int index:previous_cut) { if(++marked[index]!=1)return false; }
    std::vector<std::pair<int,int>> stack{{0,0}};
    while(!stack.empty()) {
        auto entry=stack.back(); stack.pop_back();
        int coverage=entry.second+marked[entry.first];
        if(coverage>1)return false;
        bool leaf=true;
        for(int child:nodes[entry.first].children)if(child>=0) { leaf=false; stack.push_back({child,coverage}); }
        if(leaf&&coverage!=1)return false;
    }
    return true;
}
