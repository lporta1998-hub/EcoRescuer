shader_type canvas_item;

uniform float oscurita : hint_range(0.0, 1.0) = 0.8;
uniform float direzione_luce : hint_range(-1.0, 1.0) = 0.5;
uniform float altezza_luce : hint_range(-1.0, 1.0) = -0.3;

void fragment() {
    vec4 colore = texture(TEXTURE, UV);
    
    // Crea un gradiente basato sulla direzione della luce
    float luce_ambient = dot(vec3(0.0, 1.0, 0.0), vec3(direzione_luce, altezza_luce, 0.0));
    luce_ambient = (luce_ambient + 1.0) * 0.5;
    
    // Aggiungi oscurità nelle parti basse
    float buio_alto = 1.0 - UV.y;
    float buio = mix(luce_ambient, buio_alto, oscurita);
    
    COLOR.rgb = colore.rgb * buio;
    COLOR.a = colore.a;
}