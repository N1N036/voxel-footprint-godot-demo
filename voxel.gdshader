shader_type spatial;
render_mode specular_disabled;

// 0: one representative surface normal per voxel (default).
// 1: ordinary cube-face normals, for comparison.
// 2: unlit world-space representative normals, encoded as RGB.
uniform int normal_mode : hint_range(0, 2) = 0;
varying flat vec3 representative_normal_view;
varying flat vec3 representative_normal_world;

void vertex() {
    // INSTANCE_CUSTOM is identical at every vertex of this cube.
    // Flat varyings explicitly prevent interpolation and keep one direction
    // across every triangle/face. Normals are transformed with normal matrices.
    vec3 n = normalize(INSTANCE_CUSTOM.xyz);
    representative_normal_view = normalize(MODELVIEW_NORMAL_MATRIX * n);
    representative_normal_world = normalize(MODEL_NORMAL_MATRIX * n);
}

void fragment() {
    if (normal_mode != 1) {
        NORMAL = normalize(representative_normal_view);
    }
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 1.0;
    if (normal_mode == 2) {
        // Emission-only debug output: no illumination, ambient or shadow
        // changes can masquerade as changes in the stored normal.
        ALBEDO = vec3(0.0);
        EMISSION = representative_normal_world * 0.5 + 0.5;
    }
}
