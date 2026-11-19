// Dieselben Dreiecke wie HdArenaMountains.ground_height; keine zweite Geländeform im Effekt.
uniform sampler2D terrain_height : filter_nearest, repeat_disable;
uniform vec4 terrain_grid = vec4(0.0,0.0,2.0,0.0);
uniform float terrain_enabled = 0.0;
float hd_effect_height(vec2 at) {
	if(terrain_enabled<.5) { return 0.0; }
	vec2 grid=(at-terrain_grid.xy)/terrain_grid.z;
	ivec2 cell_index=ivec2(floor(grid));
	ivec2 size=textureSize(terrain_height,0);
	if(any(lessThan(cell_index,ivec2(0))) || any(greaterThanEqual(cell_index,size-ivec2(1)))) { return 0.0; }
	vec2 f=fract(grid);
	vec2 a=texelFetch(terrain_height,cell_index,0).rg;
	vec2 b=texelFetch(terrain_height,cell_index+ivec2(1,0),0).rg;
	vec2 c=texelFetch(terrain_height,cell_index+ivec2(0,1),0).rg;
	if(f.x+f.y<=1.0) {
		if(min(a.g,min(b.g,c.g))<.5) { return 0.0; }
		return max(0.0,a.r*(1.0-f.x-f.y)+b.r*f.x+c.r*f.y);
	}
	vec2 d=texelFetch(terrain_height,cell_index+ivec2(1,1),0).rg;
	if(min(d.g,min(b.g,c.g))<.5) { return 0.0; }
	return max(0.0,d.r*(f.x+f.y-1.0)+c.r*(1.0-f.x)+b.r*(1.0-f.y));
}
