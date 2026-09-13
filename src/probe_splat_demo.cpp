#include "probe_splat_demo.h"
#include <godot_cpp/classes/quad_mesh.hpp>
#include <godot_cpp/classes/shader.hpp>
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <algorithm>
#include <chrono>
#include <numeric>
#include <cmath>
using namespace godot;
void ProbeSplatDemo::_bind_methods() {
    ClassDB::bind_method(D_METHOD("load_mesh","mesh"),&ProbeSplatDemo::load_mesh);
    ClassDB::bind_method(D_METHOD("capture","object_transform","origin","resolution"),&ProbeSplatDemo::capture);
    ClassDB::bind_method(D_METHOD("get_capture_ms"),&ProbeSplatDemo::get_capture_ms);
    ClassDB::bind_method(D_METHOD("get_reassignment"),&ProbeSplatDemo::get_reassignment);
    ClassDB::bind_method(D_METHOD("get_splat_count"),&ProbeSplatDemo::get_splat_count);
}
void ProbeSplatDemo::load_mesh(const Ref<Mesh> &mesh) {
    triangles.clear(); order.clear(); tree.clear(); prior_triangle.clear();
    for(int s=0;s<mesh->get_surface_count();++s) {
        Array a=mesh->surface_get_arrays(s); PackedVector3Array p=a[Mesh::ARRAY_VERTEX],n=a[Mesh::ARRAY_NORMAL];
        PackedColorArray c=a[Mesh::ARRAY_COLOR]; PackedInt32Array indices=a[Mesh::ARRAY_INDEX];
        int count=indices.is_empty()?p.size():indices.size();
        for(int i=0;i+2<count;i+=3) {
            Tri t;
            for(int k=0;k<3;++k) { int j=indices.is_empty()?i+k:indices[i+k]; t.p[k]=p[j]; t.n[k]=n.is_empty()?Vector3(0,1,0):n[j]; t.c[k]=c.is_empty()?Color(0.8f,0.6f,0.3f):c[j]; }
            t.center=(t.p[0]+t.p[1]+t.p[2])/3; triangles.push_back(t);
        }
    }
    order.resize(triangles.size()); std::iota(order.begin(),order.end(),0); if(!order.empty())build(0,int(order.size()));
    instances.instantiate(); instances->set_transform_format(MultiMesh::TRANSFORM_3D); instances->set_use_colors(true); instances->set_use_custom_data(true);
    Ref<QuadMesh> quad; quad.instantiate(); quad->set_size(Vector2(1,1));
    Ref<Shader> shader; shader.instantiate();
    shader->set_code("shader_type spatial; render_mode unshaded, cull_disabled; varying flat vec3 n; void vertex(){n=normalize(INSTANCE_CUSTOM.xyz);} void fragment(){float l=0.30+0.70*max(dot(normalize(n),normalize(vec3(-0.6,0.8,0.6))),0.0); ALBEDO=COLOR.rgb*l;}");
    Ref<ShaderMaterial> material; material.instantiate(); material->set_shader(shader);
    quad->set_material(material); instances->set_mesh(quad); set_multimesh(instances);
    set_cast_shadows_setting(GeometryInstance3D::SHADOW_CASTING_SETTING_OFF);
}
int ProbeSplatDemo::build(int start,int end) {
    Branch b; b.start=start; b.count=end-start; b.lo=Vector3(1e9,1e9,1e9); b.hi=-b.lo;
    for(int i=start;i<end;++i)for(Vector3 p:triangles[order[i]].p) { b.lo=b.lo.min(p); b.hi=b.hi.max(p); }
    int id=int(tree.size()); tree.push_back(b);
    if(end-start>8) {
        Vector3 extent=b.hi-b.lo; int axis=extent.max_axis_index(); int mid=(start+end)/2;
        std::nth_element(order.begin()+start,order.begin()+mid,order.begin()+end,[&](int a,int c){return triangles[a].center[axis]<triangles[c].center[axis];});
        int left=build(start,mid),right=build(mid,end); tree[id].left=left; tree[id].right=right;
    }
    return id;
}
bool ProbeSplatDemo::bounds(const Branch &b,const Vector3 &o,const Vector3 &inv,float limit) const {
    float near=0,far=limit;
    for(int k=0;k<3;++k) { float a=(b.lo[k]-o[k])*inv[k],c=(b.hi[k]-o[k])*inv[k]; if(a>c)std::swap(a,c); near=std::max(near,a); far=std::min(far,c); if(near>far)return false; }
    return true;
}
int ProbeSplatDemo::trace(Vector3 o,Vector3 d,float &distance,float &u,float &v) const {
    Vector3 inv; for(int k=0;k<3;++k)inv[k]=1.0f/(std::abs(d[k])<1e-12f?1e-12f:d[k]);
    int stack[128],top=0,result=-1; stack[top++]=0;
    while(top) {
        const Branch &b=tree[stack[--top]]; if(!bounds(b,o,inv,distance))continue;
        if(b.left>=0) { stack[top++]=b.left; stack[top++]=b.right; continue; }
        for(int i=b.start;i<b.start+b.count;++i) {
            int id=order[i]; const Tri &t=triangles[id]; Vector3 e1=t.p[1]-t.p[0],e2=t.p[2]-t.p[0],q=d.cross(e2);
            float det=e1.dot(q); if(std::abs(det)<1e-8f)continue;
            float inverse=1/det; Vector3 s=o-t.p[0]; float a=s.dot(q)*inverse; if(a<0||a>1)continue;
            Vector3 r=s.cross(e1); float c=d.dot(r)*inverse; if(c<0||a+c>1)continue;
            float hit=e2.dot(r)*inverse;
            if(hit>0.001f&&hit<distance) { distance=hit;u=a;v=c;result=id; }
        }
    }
    return result;
}
void ProbeSplatDemo::capture(Transform3D object_transform,Vector3 origin,int resolution) {
    if(tree.empty())return;
    auto start=std::chrono::steady_clock::now();
    resolution=std::clamp(resolution,32,512);
    Transform3D inverse=object_transform.affine_inverse(); Vector3 o=inverse.xform(origin);
    // Cubemap face bases. Texel centers trace the *same triangle mesh* as the
    // voxel converter. CPU first-hit rays replace cubemap rasterization here.
    Vector3 forward[6]={Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,1,0),Vector3(0,-1,0),Vector3(0,0,1),Vector3(0,0,-1)};
    Vector3 right[6]={Vector3(0,0,-1),Vector3(0,0,1),Vector3(1,0,0),Vector3(1,0,0),Vector3(1,0,0),Vector3(-1,0,0)};
    Vector3 up[6]={Vector3(0,1,0),Vector3(0,1,0),Vector3(0,0,-1),Vector3(0,0,1),Vector3(0,1,0),Vector3(0,1,0)};
    std::vector<float> values; values.reserve(100000);
    std::vector<int> ids(6*resolution*resolution,-1);
    int changed=0,visible_union=0; bool comparable=prior_triangle.size()==ids.size();
    for(int face=0;face<6;++face)for(int y=0;y<resolution;++y)for(int x=0;x<resolution;++x) {
        int index=face*resolution*resolution+y*resolution+x;
        Vector3 ray=forward[face]+right[face]*(2*(x+0.5f)/resolution-1)+up[face]*(2*(y+0.5f)/resolution-1);
        float distance=1e6f,u=0,v=0;
        int hit=trace(o,inverse.basis.xform(ray),distance,u,v); ids[index]=hit;
        if(comparable&&(hit>=0||prior_triangle[index]>=0)) { ++visible_union; if(hit!=prior_triangle[index])++changed; }
        if(hit<0)continue;
        const Tri &t=triangles[hit]; Vector3 p=origin+ray*distance;
        Vector3 n=object_transform.basis.inverse().transposed().xform(t.n[0]*(1-u-v)+t.n[1]*u+t.n[2]*v).normalized();
        Color c=t.c[0]*(1-u-v)+t.c[1]*u+t.c[2]*v;
        // Shared Chebyshev depth at all four corners: a cubemap-face-aligned
        // world quad, NOT a view-facing billboard. Fixed 3% overlap.
        float width=2*distance/resolution*1.03f;
        Vector3 a=right[face]*width,b=up[face]*width,z=forward[face];
        float data[20]={a.x,b.x,z.x,p.x,a.y,b.y,z.y,p.y,a.z,b.z,z.z,p.z,c.r,c.g,c.b,1,n.x,n.y,n.z,0};
        values.insert(values.end(),data,data+20);
    }
    splats=int(values.size()/20); instances->set_instance_count(splats);
    PackedFloat32Array buffer; buffer.resize(values.size()); std::copy(values.begin(),values.end(),buffer.ptrw()); instances->set_buffer(buffer);
    prior_triangle=std::move(ids); reassignment=visible_union?double(changed)/visible_union:0;
    capture_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();
}
