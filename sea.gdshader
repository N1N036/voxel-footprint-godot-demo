shader_type spatial;
render_mode cull_disabled, specular_disabled;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 p = world_position.xz;
    float waves = sin(p.x*0.9+p.y*3.7+TIME*0.35)*sin(p.y*2.1-p.x*0.8-TIME*0.25);
    float fine = sin(p.x*4.0+p.y*8.0+TIME)*sin(p.y*5.0-TIME);
    float glints = smoothstep(0.86, 0.99, waves) * 0.035;
    float ellipse = length(p / vec2(7.15, 5.1));
    float shore = (1.0-smoothstep(1.0,1.35,ellipse))*smoothstep(0.9,1.02,ellipse);
    float foam = shore * smoothstep(0.75,0.99,sin(ellipse*72.0-TIME*0.8)+fine*0.12);
    ALBEDO = mix(vec3(0.055,0.16,0.19),vec3(0.10,0.24,0.25),0.5+waves*0.1);
    ALBEDO += glints * vec3(0.70,0.70,0.50) + foam*vec3(0.13,0.19,0.17);
    ROUGHNESS = 1.0;
}
