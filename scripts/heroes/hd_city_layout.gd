extends RefCounted
## Feste Hausreihen mit gemeinsamen Gassen; unabhängig von Grafikqualität und Zufallsreihenfolge.
static func plan(game, layout: HdArena, points: Array, safe: Array, step: float) -> Array:
	var result: Array=[]
	var bounds: Array=game.cfg.arena.bounds
	var minimum := Vector2(float(bounds[0])-HdArenaMountains.APRON,float(bounds[1])-HdArenaMountains.APRON)
	for row in 29:
		for column in 35:
			# Jede vierte Parzelle bleibt als Querstraße/Hof frei.
			if column%4==2:continue
			var at := Vector3(-170+column*10,0,-168+row*12)
			if at.x>float(bounds[2])-12 or at.z>float(bounds[3])-12:continue
			if layout.inside(at,-5.2) or layout.divider_distance(at)<8:continue
			if HdExplorationLayout.sites().any(func(site):return Vector2(at.x-site.pos.x,at.z-site.pos.z).length()<13):continue
			if HdExplorationLayout.clearance(at)<7:continue
			if Vector2(at.x+33,at.z+33).length()<24 or Vector2(at.x-33,at.z-33).length()<17:continue
			var lo := INF
			var hi := -INF
			var flat_district := true
			for dz in [-4.0,0.0,4.0]:
				for dx in [-3.6,0.0,3.6]:
					if layout.boundary_kind(at+Vector3(dx,0,dz))!="city":flat_district=false
					var h := _height(points,safe,minimum,step,at+Vector3(dx,0,dz))
					lo=minf(lo,h)
					hi=maxf(hi,h)
			# Blockierende Gebäude müssen auf allen Grafikstufen dieselben Bauplätze haben.
			if not flat_district:continue
			var front := Vector3.BACK if row%2==0 else Vector3.FORWARD
			var approach := at+front*6
			if layout.divider_distance(approach)<4 or HdExplorationLayout.clearance(approach)<3.5:continue
			var score := posmod(column*37+row*61,101)
			at.y=hi+.03
			result.append({"pos":at,"yaw":0.0 if row%2==0 else PI,"ruin":score>86,"foundation":hi-lo+.25,"score":score,"row":row,"column":column})
	return result

static func _height(points: Array, safe: Array, minimum: Vector2, step: float, at: Vector3) -> float:
	var uv := (Vector2(at.x,at.z)-minimum)/step
	var x := floori(uv.x)
	var z := floori(uv.y)
	var fx := uv.x-x
	var fz := uv.y-z
	if fx+fz<=1:
		if not (safe[z][x] and safe[z][x+1] and safe[z+1][x]):return 0
		return maxf(0,points[z][x].y*(1-fx-fz)+points[z][x+1].y*fx+points[z+1][x].y*fz)
	if not (safe[z+1][x+1] and safe[z+1][x] and safe[z][x+1]):return 0
	return maxf(0,points[z+1][x+1].y*(fx+fz-1)+points[z+1][x].y*(1-fx)+points[z][x+1].y*(1-fz))
