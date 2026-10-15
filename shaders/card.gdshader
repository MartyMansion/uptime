shader_type spatial;
// A paper cut-out card. Layer 0 = printed art with a white die-cut border; layer 1 = paper core
// (kraft edge, only visible mid-flip). Cards pick up a little of the scene's warm light.
render_mode cull_disabled, specular_disabled, diffuse_lambert;
uniform sampler2D tex : filter_linear_mipmap;
uniform float border_px = 5.0;
uniform float core = 0.0;
uniform float lit = 0.35;           // how much scene light tints the card
uniform vec3 tint = vec3(1.0, 0.96, 0.9);
uniform bool mirror = false;
void fragment(){
	vec2 uv = mirror ? vec2(1.0 - UV.x, UV.y) : UV;
	vec4 c = texture(tex, uv);
	vec2 px = border_px / vec2(textureSize(tex, 0));
	float m = c.a;
	for (int i = 0; i < 12; i++){ float a = float(i) * 6.2831 / 12.0; m = max(m, texture(tex, uv + vec2(cos(a), sin(a)) * px).a); }
	if (m < 0.5) discard;
	vec3 rgb = mix(vec3(0.99, 0.97, 0.93), c.rgb / max(c.a, 0.001), step(0.5, c.a));
	if (core > 0.5) rgb = vec3(0.78, 0.66, 0.5);
	rgb *= tint;
	ALBEDO = rgb * lit;
	EMISSION = rgb * (1.0 - lit);
}
