shader_type canvas_item;

uniform vec4 base_color : source_color;
uniform vec2 light_direction = vec2(0.5, 0.5); // Direction of light source
uniform float depth_strength = 0.1; // How strong the depth effect is
uniform float pixel_size = 2.0; // For pixel art effect

void fragment() {
    // Hexagon masking (flat-top)
    vec2 p = UV - vec2(0.5, 0.5);
    p.x /= 0.866025; // Adjust for aspect ratio of hex
    p = abs(p);
    float d = max(p.x - 0.25 * p.y, 0.5 * p.x); // Distance function for hex (simplified)
    d = max(d, p.y - 0.4330125); // 0.4330125 is sin(60)/2 for aspect corrected p.y

    // Discard pixels outside the hexagon
    if (d > 0.0) {
        discard;
    }

    // Apply pixel art effect by quantizing UVs
    vec2 snapped_uv = floor(UV * (1.0 / pixel_size)) * pixel_size;
    vec4 tex_color = texture(TEXTURE, snapped_uv); // Use TEXTURE for potential base texture or just for UV snapping

    // Calculate normal based on hex shape (simplified for depth effect)
    vec3 normal = vec3(p.x, p.y, 0.5); // Simplified normal facing outwards, z for depth
    normal = normalize(normal);

    // Light calculation
    vec3 light_dir_norm = normalize(vec3(light_direction, 1.0)); // Assume light comes from above
    float light_intensity = dot(normal, light_dir_norm);
    light_intensity = clamp(light_intensity, 0.5, 1.0); // Keep it from being too dark

    // Apply depth effect by modifying color based on light
    vec4 final_color = base_color * light_intensity;
    final_color.a = base_color.a;

    COLOR = final_color;
}