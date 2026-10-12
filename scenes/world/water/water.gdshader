shader_type spatial;
// Low-poly sea: gentle waves, flat-shaded facets, lighter where it's shallow
// and white foam where it touches the shore.
render_mode cull_disabled, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.3, 0.72, 0.76, 0.7);
uniform vec4 deep_color : source_color = vec4(0.1, 0.4, 0.62, 0.95);
uniform float deep_distance = 5.0;
uniform float foam_distance = 0.5;
uniform float wave_height = 0.22;
uniform float wave_speed = 0.7;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	VERTEX.y += (sin(world.x * 0.15 + t)
			+ sin(world.z * 0.21 + t * 1.3)
			+ 0.5 * sin((world.x + world.z) * 0.33 + t * 0.7)) * wave_height;
}

void fragment() {
	// Flat shading: each triangle gets one normal, like the rest of the world.
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));

	// How much water is between the surface and the ground behind it.
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	float water_depth = max(VERTEX.z - behind.z, 0.0);

	vec4 color = mix(shallow_color, deep_color, clamp(water_depth / deep_distance, 0.0, 1.0));
	float foam = 1.0 - smoothstep(0.0, foam_distance, water_depth);
	ALBEDO = mix(color.rgb, vec3(0.95, 0.97, 1.0), foam * 0.85);
	ALPHA = max(color.a, foam);
	ROUGHNESS = 0.2;
	SPECULAR = 0.4;
}
