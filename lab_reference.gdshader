shader_type spatial;
render_mode unshaded, cull_disabled;
// Already linear floating-point pixels, deliberately no source_color hint.
uniform sampler2D base_texture : filter_linear, repeat_enable;
uniform bool textured = false;
uniform bool lighting = true;
varying vec3 surface_normal;
vec3 linear_color(vec3 c) {
    return mix(c/12.92,pow((c+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),c));
}
vec3 display_color(vec3 c) {
    if (!OUTPUT_IS_SRGB) return c;
    return mix(12.92*c,1.055*pow(max(c,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),c));
}
void vertex() { surface_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment() {
    vec3 c = textured ? texture(base_texture,UV).rgb : linear_color(COLOR.rgb);
    float light = lighting ? 0.30+0.70*max(dot(normalize(surface_normal),normalize(vec3(-0.6,0.8,0.6))),0.0) : 1.0;
    ALBEDO=display_color(c*light);
}
