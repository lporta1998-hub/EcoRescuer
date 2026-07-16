shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);
uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 0.3, 1.0);
uniform float glow_size = 0.05;
uniform float intensity = 2.0;

void fragment() {
    vec2 uv = UV;

    // distanza dal bordo
    float edge = 0.0;
    edge += 1.0 - smoothstep(0.0, glow_size, uv.x);
    edge += 1.0 - smoothstep(0.0, glow_size, uv.y);
    edge += 1.0 - smoothstep(0.0, glow_size, 1.0 - uv.x);
    edge += 1.0 - smoothstep(0.0, glow_size, 1.0 - uv.y);

    edge = clamp(edge, 0.0, 1.0);

    // colore finale
    vec3 final_rgb = base_color.rgb + glow_color.rgb * edge * intensity;

    COLOR = vec4(final_rgb, base_color.a);
}