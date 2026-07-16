shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.0, 1.0, 0.5, 1.0);
uniform float pulse_speed = 2.0;
uniform float intensity = 0.5;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    
    // Identifica le aree luminose (es. pixel molto verdi/blu)
    float glow_mask = step(0.7, color.g); // Aggiusta in base ai tuoi colori
    
    // Effetto pulsante
    float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
    
    // Mescola il colore originale con il glow
    vec3 final_color = mix(color.rgb, glow_color.rgb, glow_mask * pulse * intensity);
    COLOR = vec4(final_color, color.a);
}
