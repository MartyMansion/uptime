shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float strength = 0.4;
void fragment(){ float d = length(UV - 0.5) * 2.0; ALBEDO = vec3(0.1,0.06,0.05); ALPHA = strength * smoothstep(1.0, 0.25, d); }
