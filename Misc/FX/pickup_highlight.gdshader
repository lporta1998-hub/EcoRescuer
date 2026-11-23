shader_type canvas_item;
// Makes pickups and secret crates easy to spot on any ground: a dark 1 px
// outline (reads on snow and sand), a pulsing coloured glow around it (reads
// on grass and dark floors) and a glint that sweeps across now and then.
// The quad is grown by `pad` texture pixels so the outline is not clipped at
// the edge of tight sprites.

uniform vec4 outline_color : source_color = vec4(0.05, 0.04, 0.08, 0.9);
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.3, 1.0);
uniform float glow_strength = 0.85;
uniform float pulse_speed = 3.2;
uniform float glint_period = 3.0;
uniform float glint_strength = 0.55;
uniform float phase = 0.0;
uniform float px_scale = 1.0;   // texture pixels per outline pixel (2 for sprites drawn at half size)

const float pad = 4.0;

// the node's modulate (COLOR in fragment() already has the texture in it)
varying vec4 tint;

void vertex() {
	tint = COLOR;
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	VERTEX += (UV * 2.0 - 1.0) * pad;
	UV = (UV - 0.5) * (tex_size + 2.0 * pad) / tex_size + 0.5;
}

float alpha_at(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

float ring(sampler2D tex, vec2 uv, vec2 step) {
	float a = 0.0;
	a = max(a, alpha_at(tex, uv + vec2(step.x, 0.0)));
	a = max(a, alpha_at(tex, uv - vec2(step.x, 0.0)));
	a = max(a, alpha_at(tex, uv + vec2(0.0, step.y)));
	a = max(a, alpha_at(tex, uv - vec2(0.0, step.y)));
	a = max(a, alpha_at(tex, uv + step * 0.7));
	a = max(a, alpha_at(tex, uv - step * 0.7));
	a = max(a, alpha_at(tex, uv + vec2(step.x, -step.y) * 0.7));
	a = max(a, alpha_at(tex, uv + vec2(-step.x, step.y) * 0.7));
	return a;
}

void fragment() {
	vec4 c = vec4(0.0);
	if (UV.x >= 0.0 && UV.y >= 0.0 && UV.x <= 1.0 && UV.y <= 1.0) {
		c = texture(TEXTURE, UV);
	}
	vec2 px = TEXTURE_PIXEL_SIZE * px_scale;
	float inner = ring(TEXTURE, UV, px);
	float outer = max(ring(TEXTURE, UV, px * 2.0), ring(TEXTURE, UV, px * 3.0) * 0.5);
	float pulse = 0.55 + 0.45 * sin(TIME * pulse_speed + phase);

	// glint: a diagonal band that crosses the sprite once per period
	float t = fract((TIME + phase) / glint_period);
	float band = (UV.x + UV.y) * 0.5;
	float glint = smoothstep(0.09, 0.0, abs(band - (t * 3.0 - 1.0)));
	c.rgb = mix(c.rgb, vec3(1.0), glint * glint_strength * c.a);

	// sprite over outline over glow ("over" compositing, straight alpha)
	vec3 rgb = c.rgb;
	float a = c.a;
	float oa = inner * outline_color.a;
	float na = a + oa * (1.0 - a);
	rgb = (rgb * a + outline_color.rgb * oa * (1.0 - a)) / max(na, 0.0001);
	a = na;
	float ga = outer * (1.0 - inner) * glow_strength * pulse * glow_color.a;
	na = a + ga * (1.0 - a);
	rgb = (rgb * a + glow_color.rgb * ga * (1.0 - a)) / max(na, 0.0001);
	a = na;
	COLOR = vec4(rgb, a) * tint;
}
