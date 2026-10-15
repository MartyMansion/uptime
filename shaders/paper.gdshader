shader_type spatial;
// Construction paper / cardboard: flat toon light + paper fibre grain (world-space, no texture).
render_mode diffuse_lambert_wrap, specular_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float glow = 0.0;
uniform float grain = 1.0;
varying vec3 wp;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment(){
	vec2 p = floor((wp.xy + wp.zz) * 60.0);
	float fib = 0.03 * sin(wp.x * 31.0 + wp.y * 7.0 + wp.z * 13.0);
	float g = 1.0 + grain * (0.05 * (h(p) - 0.5) + fib);
	ALBEDO = col.rgb * g * 0.92;
	EMISSION = col.rgb * glow * 2.0;
}
