extends RefCounted
## Gewachsene Altstadt nach Habsburger Vorbild (Lukas 2026-11-19): Häuserzeilen folgen leicht gekrümmten
## Gassen, Fluchten springen vor und zurück, Breiten/Drehungen schwanken, Quergassen sind je Block versetzt
## (T-Kreuzungen) und einzelne Blöcke bleiben als Plätze frei. Alles hängt nur von Weltkoordinaten und
## festen Hashes ab: identischer Grundriss auf allen Grafikstufen und bei allen Mitspielern.

## Krümmung der Gassen: Versatz quer zur Zeile (m) und Wellenlänge des Feldes (m).
const BEND := 5.0
const BEND_SCALE := 46.0
## Versatz entlang der Zeile, staucht/dehnt die Abstände zwischen Häusern.
const DRIFT := 2.0
## Kleine Einzelabweichungen je Haus: Flucht vor/zurück, seitlich, Drehung.
const SETBACK := .9
const SIDESTEP := .45
const TWIST := deg_to_rad(6.0)
## Anteil der Blöcke, die als Platz frei bleiben.
const PLAZA_SHARE := 30
## Höchstzahl Plätze und Mindestabstand zwischen ihnen (m).
const PLAZA_COUNT := 3
const PLAZA_SPACING := 45.0


static func plan(game, layout: HdArena, points: Array, safe: Array, step: float) -> Array:
	var result: Array=[]
	var bounds: Array=game.cfg.arena.bounds
	var minimum := Vector2(float(bounds[0])-HdArenaMountains.APRON,float(bounds[1])-HdArenaMountains.APRON)
	var plazas := {}
	for row in 29:
		var pair := row/2
		# Quergassen je Gassenpaar versetzt: Blöcke stoßen als T-Kreuzungen aneinander statt als Schachbrett.
		var shift := _hash(pair,7)%4
		for column in 35:
			if (column+shift)%4==2:continue
			var block := (column+shift)/4
			var plaza := _hash(pair*41+block,13)%100<PLAZA_SHARE
			var lattice := Vector3(-170+column*10,0,-168+row*12)
			var at := _organic(lattice,row,column)
			if at.x>float(bounds[2])-12 or at.z>float(bounds[3])-12:continue
			if layout.inside(at,-5.2) or layout.divider_distance(at)<8:continue
			if HdExplorationLayout.sites().any(func(site):return Vector2(at.x-site.pos.x,at.z-site.pos.z).length()<13):continue
			if HdExplorationLayout.clearance(at)<7:continue
			if Vector2(at.x+33,at.z+33).length()<24 or Vector2(at.x-33,at.z-33).length()<17:continue
			if Vector2(at.x,at.z).length()<22:plaza=false
			var yaw := _street_yaw(lattice,row)+(float(_hash(row*131+column,5)%1000)/999.0-.5)*2.0*TWIST
			var front := Vector3.BACK.rotated(Vector3.UP,yaw)
			var lo := INF
			var hi := -INF
			var flat_district := true
			for dz in [-4.0,0.0,4.0]:
				for dx in [-3.6,0.0,3.6]:
					var probe := at+Vector3(dx,0,dz).rotated(Vector3.UP,yaw)
					if layout.boundary_kind(probe)!="city":flat_district=false
					var h := _height(points,safe,minimum,step,probe)
					lo=minf(lo,h)
					hi=maxf(hi,h)
			# Blockierende Gebäude müssen auf allen Grafikstufen dieselben Bauplätze haben.
			if not flat_district:continue
			var approach := at+front*6
			if layout.divider_distance(approach)<4 or HdExplorationLayout.clearance(approach)<3.5:continue
			var score := posmod(column*37+row*61,101)
			var site := {"pos":at+Vector3.UP*(hi+.03),"yaw":yaw,"ruin":score>86,"foundation":hi-lo+.25,"score":score,"row":row,"column":column}
			if plaza:
				var key := Vector2i(pair,block)
				if not plazas.has(key):plazas[key]=[]
				plazas[key].append(site)
				continue
			result.append(site)
	result=_keep_doors_free(result)
	# Aus den Kandidaten-Blöcken werden wenige, weit verteilte Plätze; der Rest wird wieder bebaut.
	var keys: Array=plazas.keys()
	keys.sort_custom(func(a,b):return _hash(a.x*41+a.y,29)<_hash(b.x*41+b.y,29))
	var chosen: Array=[]
	for key in keys:
		var lots: Array=plazas[key]
		var center := Vector3.ZERO
		for lot in lots:center+=lot.pos
		center/=float(maxi(1,lots.size()))
		center.y=0
		if lots.size()<4 or chosen.size()>=PLAZA_COUNT or chosen.any(func(c):return c.distance_to(center)<PLAZA_SPACING):
			result.append_array(_keep_doors_free_against(result,lots))
			continue
		chosen.append(center)
		result.append({"pos":center,"plaza":true,"radius":11.0,"yaw":float(_hash(key.x*17+key.y,3)%360)*PI/180.0,"lots":lots.size()})
	return result


## Versetzte Fluchten dürfen keine Haustür zustellen: Liegt der Vorplatz eines Hauses im (erweiterten)
## Grundriss eines Nachbarn, bleibt die spätere Parzelle frei. Gleicher Fußabdruck wie HdCathedral._townhouse.
static func _keep_doors_free(sites: Array) -> Array:
	var kept: Array=[]
	for site in sites:
		var front := Vector3.BACK.rotated(Vector3.UP,float(site.yaw))
		var blocked := false
		for other in kept:
			for probe in [site.pos+front*5.2,site.pos+front*6.6]:
				if _in_footprint(other,probe,1.0):blocked=true
			var other_front := Vector3.BACK.rotated(Vector3.UP,float(other.yaw))
			for probe in [other.pos+other_front*5.2,other.pos+other_front*6.6]:
				if _in_footprint(site,probe,1.0):blocked=true
			if blocked:break
		if not blocked:kept.append(site)
	return kept


static func _keep_doors_free_against(placed: Array, lots: Array) -> Array:
	var houses: Array=placed.filter(func(site):return not site.get("plaza",false))
	var before := houses.size()
	houses.append_array(lots)
	# Bereits geprüfte Häuser behindern sich nicht und bleiben vorn erhalten; neu ist nur der Rest.
	return _keep_doors_free(houses).slice(before)


static func _in_footprint(site: Dictionary, p: Vector3, margin: float) -> bool:
	var local: Vector3=(p-site.pos).rotated(Vector3.UP,-float(site.yaw))
	return absf(local.x)<3.6+margin and absf(local.z)<3.65+margin


## Gitterpunkt → gewachsene Lage. Gegenüberliegende Zeilen eines Gassenpaars teilen sich die Krümmung der
## Gassenmitte, damit die Gasse ihre Breite behält; Rückseiten zweier Paare dürfen enger oder weiter werden.
static func _organic(lattice: Vector3, row: int, column: int) -> Vector3:
	var street_z := -168.0+float(row/2)*24.0+6.0
	var bend := _field(Vector2(lattice.x,street_z),0)*BEND
	var drift := _field(Vector2(lattice.x,street_z),1)*DRIFT
	var front := Vector3.BACK if row%2==0 else Vector3.FORWARD
	var setback := (float(_hash(row*977+column*31,11)%1000)/999.0-.5)*2.0*SETBACK
	var sidestep := (float(_hash(row*389+column*53,17)%1000)/999.0-.5)*2.0*SIDESTEP
	return lattice+Vector3(drift+sidestep,0,bend)+front*setback


## Blickrichtung zur Gasse: senkrecht auf die gekrümmte Gassenmitte.
static func _street_yaw(lattice: Vector3, row: int) -> float:
	var street_z := -168.0+float(row/2)*24.0+6.0
	var a := _field(Vector2(lattice.x-2.5,street_z),0)*BEND
	var b := _field(Vector2(lattice.x+2.5,street_z),0)*BEND
	var slope := atan2(b-a,5.0)
	# Vorderseite (+Z bei Yaw 0) folgt der Normale der Gassenkurve.
	return (0.0 if row%2==0 else PI)-slope


## Glattes Feld in [-1, 1], deterministisch über den gemeinsamen Boden-Hash.
static func _field(at: Vector2, channel: int) -> float:
	# Quer zu den Gassen gestaucht: Nachbargassen krümmen sich ähnlich, Rückseiten bleiben frei.
	var p := Vector2(at.x,at.y*.45)/BEND_SCALE+Vector2(13.7+channel*31.1,5.3-channel*17.9)
	return (HdTerrain._ground_noise(p)*.7+HdTerrain._ground_noise(p*2.1+Vector2(3.1,8.4))*.3-.5)*2.0


static func _hash(a: int, salt: int) -> int:
	var v := (a*73856093)^(salt*19349663)
	v=(v^(v>>13))*1274126177
	return absi(v^(v>>16))


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
