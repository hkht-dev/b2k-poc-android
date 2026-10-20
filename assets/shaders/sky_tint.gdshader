// The Street's sky: Poly Haven's overcast panorama with a tint the story
// can move (scripts/street/daylight.gd, data/daylight.json). The same
// shader PanoramaSkyMaterial generates, plus `tint`: Godot 4.3 has no tint
// on a panorama sky, and GDD §5 (Hollow Vale) wants "the first rose tint
// allowed into the sky" in Act 4 and no pink before it.
//
// PLACEHOLDER: the painted sky of GDD §10 replaces the HDR panorama; the
// tint stays, since the stages in data/daylight.json drive it.
shader_type sky;

uniform sampler2D panorama : filter_linear, repeat_enable, source_color, hint_default_black;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float energy : hint_range(0.0, 8.0) = 1.0;

void sky() {
	COLOR = texture(panorama, SKY_COORDS).rgb * tint * energy;
}
