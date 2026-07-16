shader_type canvas_item;

uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform float intensity : hint_range(0.1, 2.0) = 0.8;
uniform vec4 color1 : source_color = vec4(1.0, 0.3, 0.1, 1.0);
uniform vec4 color2 : source_color = vec4(0.8, 0.1, 0.8, 1.0);

void fragment() {
    // Distorsione basata sul tempo
    float wave = sin(UV.x * 10.0 + TIME * speed) * cos(UV.y * 8.0 + TIME * 0.8) * 0.1;
    vec2 distorted_uv = UV + vec2(wave, wave * 0.5);

    // Colore magico che si muove
    float gradient = sin(distorted_uv.x * 5.0 + TIME) * cos(distorted_uv.y * 5.0 - TIME);
    gradient = gradient * 0.5 + 0.5;

    // Miscela i colori
    vec4 magic_color = mix(color1, color2, gradient);
    magic_color.a = texture(TEXTURE, UV).a * intensity;

    // Aggiungi un bagliore
    float glow = sin(UV.x * 20.0 + TIME * 2.0) * 0.5 + 0.5;
    magic_color.rgb += vec3(glow * 0.3);

    COLOR = magic_color;
}