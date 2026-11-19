extends RefCounted
## Gecachte topografische Karte aus dem echten Höhenfeld und den Vegetationspositionen.
const RESOLUTION := 256

static func _pixel(at: Vector3, bounds: Rect2) -> Vector2:
	return (Vector2(at.x,at.z)-bounds.position)/bounds.size*RESOLUTION

static func _disk(image: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(maxi(0,floori(center.y-radius)),mini(RESOLUTION,ceili(center.y+radius)+1)):
		for x in range(maxi(0,floori(center.x-radius)),mini(RESOLUTION,ceili(center.x+radius)+1)):
			if Vector2(x,y).distance_squared_to(center)<=radius*radius:image.set_pixel(x,y,color)

static func hidden_mask(bounds: Rect2, revealed: Array) -> Image:
	var mask := Image.create(RESOLUTION,RESOLUTION,false,Image.FORMAT_RGBA8)
	mask.fill(Color.BLACK)
	for site in HdExplorationLayout.sites():
		if revealed.has(str(site.id)):continue
		_disk(mask,_pixel(site.pos,bounds),5.5,Color.WHITE)
	return mask

static func build(game, bounds: Rect2, domain: String, revealed: Array) -> Texture2D:
	var image := Image.create(RESOLUTION,RESOLUTION,false,Image.FORMAT_RGBA8)
	var heights := PackedFloat32Array()
	heights.resize(RESOLUTION*RESOLUTION)
	var noise := FastNoiseLite.new()
	noise.seed=681749
	noise.frequency=.065
	var main := domain=="main"
	var mask: Image = hidden_mask(bounds,revealed) if main else null
	for y in RESOLUTION:
		for x in RESOLUTION:
			var at := bounds.position+(Vector2(x,y)+Vector2(.5,.5))/RESOLUTION*bounds.size
			heights[y*RESOLUTION+x]=HdArenaMountains.ground_height(game.arena_layout,Vector3(at.x,0,at.y)) if main else 0.0
	for y in RESOLUTION:
		for x in RESOLUTION:
			var at := bounds.position+(Vector2(x,y)+Vector2(.5,.5))/RESOLUTION*bounds.size
			var p := Vector3(at.x,0,at.y)
			var h := heights[y*RESOLUTION+x]
			var grain := noise.get_noise_2d(at.x,at.y)
			var color := Color("686959").lerp(Color("929184"),clampf(h/22.0,0,1))
			if main:
				if HdArenaMountains._city_clearance(p,game,game.cfg.arena.get("boundaries",{}))<0:
					color=Color("848477")
				else:color=color.lerp(Color("53684d"),.4*(1.0-clampf(h/12.0,0,1)))
				var dx := heights[y*RESOLUTION+mini(x+1,RESOLUTION-1)]-heights[y*RESOLUTION+maxi(x-1,0)]
				var dy := heights[mini(y+1,RESOLUTION-1)*RESOLUTION+x]-heights[maxi(y-1,0)*RESOLUTION+x]
				var shade := clampf(1.0-dx*.13-dy*.18,.55,1.32)
				color*=shade+grain*.08
				# Dezente Höhenlinien wie in einer Geländekarte.
				if h>1.0 and fposmod(h,3.0)<.16:color*=.83
				if h>17.0:color=color.lerp(Color("c4c6b9"),clampf((h-17)/15,0,.65))
				# Kein Talverlauf oder blanker Zugang verrät einen noch unentdeckten Nebenpfad.
				if mask.get_pixel(x,y).r>.5:color=Color("3b543f")*(1.0+grain*.2)
			else:
				var walk: bool = HdExplorationLayout.clearance(p)<0 if domain=="cave" else (game.final.layout.inside(p) if domain=="final" else true)
				color=(Color("777368") if walk else Color("383d3b"))*(1.0+grain*.15)
			color.a=1
			image.set_pixel(x,y,color)
	if main:
		var step := 3.0 if Display.quality==Display.LOW else 2.0
		var data: Dictionary = HdArenaMountains._geometry.get(hash([game.arena_layout.geometry_signature,step]),{})
		for id in data.get("scatter",{}):
			if not str(id).begins_with("pine"):continue
			for placement: Transform3D in data.scatter[id]:
				var center := _pixel(placement.origin,bounds)
				var radius := clampf(placement.basis.get_scale().y*.22*RESOLUTION/bounds.size.x,1.1,3.0)
				_disk(image,center+Vector2(.7,.9),radius,Color("344735"))
				_disk(image,center,radius*.8,Color("4c6446"))
	return ImageTexture.create_from_image(image)
