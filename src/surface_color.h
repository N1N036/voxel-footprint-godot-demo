#pragma once
#include <godot_cpp/classes/shader_material.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/classes/image.hpp>
#include <cmath>

namespace godot {
// The reference and both samplers consume the same material, UV0 and linear
// image. Bilinear repeat at mip zero; no Unreal shader/normal-map emulation.
struct SurfaceColor {
    Ref<Image> image;
    explicit SurfaceColor(const Ref<Material> &material) {
        Ref<ShaderMaterial> shader = material;
        if (shader.is_valid()) {
            Ref<Texture2D> texture = shader->get_shader_parameter("base_texture");
            if (texture.is_valid()) image = texture->get_image();
        }
    }
    Color sample(Vector2 uv, Color fallback) const {
        if (image.is_null()) return fallback.srgb_to_linear();
        int w=image->get_width(), h=image->get_height();
        float x=(uv.x-std::floor(uv.x))*w-0.5f, y=(uv.y-std::floor(uv.y))*h-0.5f;
        int ix=int(std::floor(x)), iy=int(std::floor(y));
        float fx=x-ix, fy=y-iy;
        auto pixel=[&](int a,int b) { return image->get_pixel((a%w+w)%w,(b%h+h)%h); };
        return pixel(ix,iy).lerp(pixel(ix+1,iy),fx).lerp(pixel(ix,iy+1).lerp(pixel(ix+1,iy+1),fx),fy);
    }
};
}
