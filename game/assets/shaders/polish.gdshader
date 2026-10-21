shader_type canvas_item;
// Acabado de pantalla: bloom suave en lo brillante, viñeta, un poco más de color y contraste
// y una leve aberración cromática hacia los bordes. Se dibuja bajo el HUD.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float bloom : hint_range(0.0, 1.0) = 0.45;
uniform float vignette : hint_range(0.0, 1.0) = 0.5;
uniform float saturation = 1.14;
uniform float contrast = 1.07;
uniform vec3 tint = vec3(1.0);
uniform float pulse = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 c = uv - 0.5;
	float edge = dot(c, c);
	vec2 ca = c * edge * 0.012;
	vec3 col = vec3(texture(screen_tex, uv + ca).r, texture(screen_tex, uv).g, texture(screen_tex, uv - ca).b);
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = 6.2831853 * float(i) / 8.0;
		vec2 o = vec2(cos(a), sin(a));
		vec3 s1 = texture(screen_tex, uv + o * px * 3.0).rgb;
		vec3 s2 = texture(screen_tex, uv + o * px * 7.0).rgb;
		glow += max(s1 - 0.62, 0.0) + max(s2 - 0.62, 0.0) * 0.8;
	}
	col += glow * bloom * 0.22;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	col = (col - 0.5) * contrast + 0.5;
	col *= tint;
	col *= 1.0 - vignette * smoothstep(0.12, 0.62, edge * 1.8);
	col += pulse * vec3(0.06, 0.02, 0.02);
	COLOR = vec4(col, 1.0);
}
