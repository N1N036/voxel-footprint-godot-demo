shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float pixel_size = 2.0;
uniform bool matched_pixels = true;
uniform bool normal_is_world = false;
uniform bool lighting = true;
uniform int coverage_mode = 0; // 0 baseline, 1 continuous, 2 quarters, 3 diagnostic
varying flat vec3 surface_normal;
varying flat float coverage;

vec3 display_color(vec3 c) {
    if (!OUTPUT_IS_SRGB) return c;
    return mix(12.92*c, 1.055*pow(max(c,vec3(0.0)),vec3(1.0/2.4))-0.055, step(vec3(0.0031308),c));
}
void vertex() {
    coverage=clamp(INSTANCE_CUSTOM.w,0.0,1.0);
    if (coverage_mode==2) coverage=floor(coverage*4.0+0.5)/4.0;
    surface_normal = normalize(normal_is_world ? INSTANCE_CUSTOM.xyz : MODEL_NORMAL_MATRIX*INSTANCE_CUSTOM.xyz);
    if (matched_pixels) {
        // Ignore instance size/orientation: identical continuous pixel width
        // for both sampling methods, at every depth and camera orientation.
        vec4 center = PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX * vec4(0.0,0.0,0.0,1.0);
        float support=(coverage_mode==1 || coverage_mode==2)?sqrt(coverage):1.0;
        center.xy += VERTEX.xy * (2.0*pixel_size*support/VIEWPORT_SIZE) * center.w;
        POSITION = center;
    }
}
void fragment() {
    float light = lighting ? 0.30+0.70*max(dot(normalize(surface_normal),normalize(vec3(-0.6,0.8,0.6))),0.0) : 1.0;
    ALBEDO = display_color(COLOR.rgb*light);
    if(coverage_mode==3) ALBEDO=vec3(coverage);
}
