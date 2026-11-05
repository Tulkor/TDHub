class_name HdTelegraph
extends MeshInstance3D
## Warnfläche am Boden (Design Abschnitt 5a): die ganze Fläche schwach gefüllt mit kräftigem Umriss,
## darin wächst die kräftige Füllung, bis sie beim Auslösen die Fläche genau ausfüllt (progress 0–1).
## Füllrichtung je Form: Kreis von der Mitte nach außen, Ring von innen nach außen, Kegel vom
## Ausgangspunkt nach außen, Linie vom Ausgangspunkt zum Ende. flash = kurzer Aufblitzer beim Auslösen.
## Ein gemeinsamer Shader für Gegner (rot), Helden (blau) und liegende Flächen (Giftpfütze).
## Ausrichtung: Kegel und Linie zeigen nach −Z des Knotens (aim() dreht ihn).

const CIRCLE := 0
const RING := 1
const CONE := 2
const LINE := 3

const RED := Color(1.0, 0.16, 0.12, 1.0)
const BLUE := Color(0.25, 0.65, 1.0, 1.0)
const POISON := Color(0.45, 0.9, 0.2, 0.85)
const SUMMON := Color(0.75, 0.3, 1.0, 1.0)

const CODE := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform int shape = 0;
uniform float radius = 2.0;
uniform float inner = 0.0;
uniform float half_angle = 0.7;
uniform float len = 8.0;
uniform float width = 1.0;
uniform float progress = 0.0;
uniform float flash = 0.0;
uniform float base_alpha = 0.18;
uniform float edge = 0.14;
uniform vec4 color : source_color = vec4(1.0, 0.16, 0.12, 1.0);
varying vec2 p;
void vertex() {
	p = VERTEX.xz;
}
void fragment() {
	float d = length(p);
	float e;
	float fill;
	if (shape == 0) {
		e = radius - d;
		fill = step(d, radius * progress);
	} else if (shape == 1) {
		e = min(radius - d, inner > 0.0 ? d - inner : radius);
		fill = step(d, inner + (radius - inner) * progress);
	} else if (shape == 2) {
		float a = abs(atan(p.x, -p.y));
		e = min(radius - d, (half_angle - a) * max(d, 0.3));
		fill = step(d, radius * progress);
	} else {
		float f = -p.y;
		e = min(min(f + 0.02, len - f), width * 0.5 - abs(p.x));
		fill = step(f, len * progress);
	}
	if (e < 0.0) {
		discard;
	}
	float rim = 1.0 - smoothstep(0.0, edge, e);
	float a = mix(base_alpha, 0.55, fill);
	a = max(a, rim * 0.95);
	a = max(a, flash);
	ALBEDO = mix(color.rgb, vec3(1.0, 0.95, 0.85), flash * 0.6);
	ALPHA = clamp(a, 0.0, 1.0) * color.a;
}
"""

static var _shader: Shader

var shape := CIRCLE
var radius := 2.0
var inner := 0.0
var angle := 90.0
var length := 8.0
var width := 1.0
var progress := 0.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		if _mat:
			_mat.set_shader_parameter("progress", progress)
var flash := 0.0:
	set(v):
		flash = clampf(v, 0.0, 1.0)
		if _mat:
			_mat.set_shader_parameter("flash", flash)
var color := RED
var fade := -1.0           ## >= 0: blendet aus und löscht sich (Sekunden übrig)
var follow: Node3D = null  ## Wirbelwind: wandert mit dem Gegner
var _fade_total := 0.2
var _mat: ShaderMaterial


static func make(kind: int, col: Color = RED) -> HdTelegraph:
	var t := HdTelegraph.new()
	t.shape = kind
	t.color = col
	return t


static func circle(r: float, col: Color = RED) -> HdTelegraph:
	var t := make(CIRCLE, col)
	t.radius = r
	return t


static func ring(r_in: float, r_out: float, col: Color = RED) -> HdTelegraph:
	var t := make(RING, col)
	t.inner = r_in
	t.radius = r_out
	return t


static func cone(r: float, deg: float, col: Color = RED) -> HdTelegraph:
	var t := make(CONE, col)
	t.radius = r
	t.angle = deg
	return t


static func line(l: float, w: float, col: Color = RED) -> HdTelegraph:
	var t := make(LINE, col)
	t.length = l
	t.width = w
	return t


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE
	var m := PlaneMesh.new()
	if shape == LINE:
		m.size = Vector2(width + 0.1, length + 0.1)
		m.center_offset = Vector3(0, 0, -length * 0.5)
	else:
		m.size = Vector2.ONE * (radius * 2.0 + 0.2)
	mesh = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.set_shader_parameter("shape", shape)
	_mat.set_shader_parameter("radius", radius)
	_mat.set_shader_parameter("inner", inner)
	_mat.set_shader_parameter("half_angle", deg_to_rad(angle * 0.5))
	_mat.set_shader_parameter("len", length)
	_mat.set_shader_parameter("width", width)
	_mat.set_shader_parameter("progress", progress)
	_mat.set_shader_parameter("flash", flash)
	_mat.set_shader_parameter("color", color)
	material_override = _mat


## Richtung (XZ) setzen: Kegel und Linie zeigen danach in diese Richtung.
func aim(dir: Vector3) -> void:
	if dir.length_squared() > 0.0001:
		rotation.y = atan2(-dir.x, -dir.z)


func forward() -> Vector3:
	return Vector3(-sin(rotation.y), 0, -cos(rotation.y))


## Liegt der Punkt in der Fläche? extra = Radius des Getroffenen. Telegraphen hängen direkt unter
## dem Spiel (Ursprung), deshalb reicht position.
func contains(at: Vector3, extra := 0.0) -> bool:
	return in_shape(shape, position, forward(), radius, inner, angle, length, width, at, extra)


## Trefferprüfung ohne Knoten (auch für die Fähigkeiten des Helden). dir zeigt bei Kegel und Linie
## vom Ausgangspunkt weg, angle in Grad (ganzer Öffnungswinkel).
static func in_shape(kind: int, origin: Vector3, dir: Vector3, r: float, r_in: float, deg: float,
		l: float, w: float, at: Vector3, extra := 0.0) -> bool:
	var local := at - origin
	local.y = 0.0
	var d := local.length()
	match kind:
		CIRCLE:
			return d <= r + extra
		RING:
			return d <= r + extra and d >= r_in - extra
		CONE:
			if d > r + extra:
				return false
			if d < extra + 0.3:
				return true
			return rad_to_deg(dir.angle_to(local)) <= deg * 0.5 + rad_to_deg(atan2(extra, d))
		LINE:
			var f := Vector3(dir.x, 0, dir.z).normalized()
			var along := local.dot(f)
			var side := absf(local.dot(Vector3(-f.z, 0, f.x)))
			return along >= -extra and along <= l + extra and side <= w * 0.5 + extra
	return false


## Kurz aufblitzen und ausblenden.
func trigger(time := 0.22) -> void:
	flash = 1.0
	progress = 1.0
	fade = time
	_fade_total = time


func _process(dt: float) -> void:
	if follow and is_instance_valid(follow):
		global_position = Vector3(follow.global_position.x, global_position.y, follow.global_position.z)
	if fade >= 0.0:
		fade -= dt
		flash = clampf(fade / _fade_total, 0.0, 1.0)
		if _mat:
			_mat.set_shader_parameter("color", Color(color.r, color.g, color.b, color.a * clampf(fade / _fade_total, 0.0, 1.0)))
		if fade <= 0.0:
			queue_free()
