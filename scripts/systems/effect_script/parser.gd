extends RefCounted
## Small, bounded expression parser. Never evaluates GDScript or Lua.

var source := ""
var at := 0
var error := ""
var count := 0
var catalog: Dictionary
var passive: Array = []


func compile(text: String, definitions: Dictionary) -> Dictionary:
	source = text
	catalog = definitions
	if text.length() > 16384:
		return {"ok": false, "error": "Skript ist zu lang (max. 16384 Zeichen).", "ast": [], "passive": []}
	var ast: Array = []
	_skip()
	while at < source.length() and error.is_empty():
		var value = _value(0)
		if not value is Dictionary:
			_fail("Effektaufruf erwartet")
			break
		ast.append(value)
		_validate(value, true)
		_skip()
		if at < source.length() and source[at] in [";", ","]:
			at += 1
		_skip()
	return {"ok": error.is_empty(), "error": error, "ast": ast if error.is_empty() else [], "passive": passive if error.is_empty() else []}


func _fail(message: String) -> void:
	if error.is_empty():
		error = "%s (Zeichen %d)." % [message, at + 1]


func _skip() -> void:
	while at < source.length():
		if source[at] in [" ", "\r", "\n", "\t"]:
			at += 1
		elif source.substr(at, 2) in ["//", "--"] or source[at] == "#":
			while at < source.length() and source[at] != "\n":
				at += 1
		else:
			break


func _value(depth: int):
	_skip()
	count += 1
	if depth > 24 or count > 256:
		_fail("Zu viele oder zu tief verschachtelte Ausdrücke")
		return null
	if at >= source.length():
		_fail("Ausdruck fehlt")
		return null
	var start := at
	if source[at] in ['"', "'"]:
		var quote := source[at]
		at += 1
		var result := ""
		while at < source.length():
			var ch := source[at]
			at += 1
			if ch == quote:
				return result
			if ch == "\\" and at < source.length():
				ch = source[at]
				at += 1
				ch = {"n": "\n", "t": "\t", "r": "\r"}.get(ch, ch)
			result += ch
		_fail("Zeichenkette nicht geschlossen")
		return null
	var rx := RegEx.new()
	rx.compile("^[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:[eE][+-]?[0-9]+)?")
	var found := rx.search(source.substr(at))
	if found:
		var raw := found.get_string()
		at += raw.length()
		var exponent := raw.to_lower().split("e")
		if exponent.size() > 1 and int(exponent[1]) > 308:
			_fail("Zahl außerhalb des erlaubten Bereichs")
			return null
		var n := float(raw)
		if at < source.length() and source[at] == "%":
			n /= 100.0
			at += 1
		elif at < source.length() and source[at] in ["m", "s"]:
			at += 1
		return n
	while at < source.length() and source[at] in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789":
		at += 1
	var name := source.substr(start, at - start)
	_skip()
	if name.is_empty() or at >= source.length() or source[at] != "(":
		_fail("Funktionsaufruf oder Zahl erwartet; Texte in Anführungszeichen setzen")
		return null
	at += 1
	_skip()
	var args: Array = []
	while at < source.length() and source[at] != ")" and error.is_empty():
		args.append(_value(depth + 1))
		_skip()
		if at < source.length() and source[at] == ",":
			at += 1
			_skip()
			if at < source.length() and source[at] == ")":
				_fail("Ausdruck nach Komma fehlt")
		elif at < source.length() and source[at] != ")":
			_fail("Komma oder schließende Klammer erwartet")
	if at >= source.length():
		_fail("Schließende Klammer fehlt")
	else:
		at += 1
	return {"name": name, "args": args}


func _validate(node: Dictionary, root: bool) -> void:
	var name: String = node.name
	var functions: Dictionary = catalog.get("functions", {})
	if not functions.has(name):
		_fail("Unbekannte Funktion: " + name)
		return
	var spec: Dictionary = functions[name]
	var args: Array = node.args
	if bool(spec.get("root", false)) and not root:
		_fail(name + " ist nur auf oberster Ebene erlaubt")
		return
	var params: Array = spec.get("params", [])
	var offset := 0
	if spec.get("chance", false) and not args.is_empty() and args[0] is float:
		if args[0] < 0 or args[0] > 1:
			_fail("Chance muss zwischen 0% und 100% liegen")
		offset = 1
	var required := params.size()
	var children := bool(spec.get("children", false))
	var optional: Array = spec.get("optional", [])
	if args.size() < required + offset + (1 if children else 0) or (not children and args.size() > required + optional.size()):
		_fail("Falsche Argumentzahl für " + name)
		return
	for i in required + optional.size():
		if i + offset >= args.size():
			break
		var kind: String = params[i] if i < required else optional[i - required]
		var value = args[i + offset]
		if (kind == "number" and not value is float) or (kind == "string" and not value is String):
			_fail("%s: Argument %d muss %s sein" % [name, i + 1, kind])
			return
		var ranges: Array = spec.get("ranges", [])
		if spec.get("integers", []).has(i) and value != floorf(float(value)):
			_fail("%s: Argument %d muss eine ganze Zahl sein" % [name, i + 1])
		if i < ranges.size() and ranges[i] is Array:
			if value < ranges[i][0] or value > ranges[i][1] or not is_finite(float(value)):
				_fail("%s: Argument %d außerhalb des erlaubten Bereichs" % [name, i + 1])
	if name == "Ring" and args[0] > args[1]:
		_fail("Ring: Innenradius größer als Außenradius")
	if name == "Native":
		var native = JSON.parse_string(args[0])
		if not native is Dictionary or str(native.get("type", "")).is_empty():
			_fail("Native erwartet ein JSON-Objekt mit type")
		else:
			var natives: Dictionary = catalog.get("native", {})
			if not natives.has(str(native.type)):
				_fail("Unbekannte native Fähigkeit: " + str(native.type))
				return
			for key in natives[str(native.type)]:
				if not native.has(key):
					native[key] = natives[str(native.type)][key]
			for key in native:
				if key == "type":
					continue
				if not natives[str(native.type)].has(key) and not catalog.get("native_optional", {}).get(str(native.type), []).has(key):
					_fail("Native: unbekannter Parameter " + key)
					return
				var defaults: Dictionary = natives[str(native.type)]
				var expected := str(catalog.get("native_optional_types", {}).get(str(native.type), {}).get(key, "number"))
				if defaults.has(key) and defaults[key] is String:
					expected = "string"
				var number := native[key] is float or native[key] is int
				if (expected == "number" and (not number or not is_finite(float(native[key])))) or (expected == "string" and not native[key] is String):
					_fail("Native: ungültiger Parametertyp: " + key)
					return
				var enums: Array = catalog.get("native_enums", {}).get(str(native.type), {}).get(key, [])
				if not enums.is_empty() and not enums.has(native[key]):
					_fail("Native: unbekannter Parameterwert: " + key)
					return
				if key == "color" and not Color.html_is_valid(str(native[key])):
					_fail("Native: ungültige HTML-Farbe")
					return
				var bounds: Array = catalog.get("native_param_ranges", {}).get(str(native.type), {}).get(key, catalog.get("native_ranges", {}).get(key, []))
				if number and not bounds.is_empty() and (native[key] < bounds[0] or native[key] > bounds[1]):
					_fail("Native: Parameter außerhalb des erlaubten Bereichs: " + key)
					return
				if number and catalog.get("native_integers", []).has(key) and native[key] != floorf(float(native[key])):
					_fail("Native: Parameter muss eine ganze Zahl sein: " + key)
					return
			passive.append(native)
	if name == "Invoke" and not JSON.parse_string(args[1]) is Dictionary:
		_fail("Invoke erwartet ein JSON-Objekt als zweites Argument")
	if children:
		for i in range(required + offset, args.size()):
			if not args[i] is Dictionary:
				_fail(name + ": Effekt als Argument erwartet")
				return
			_validate(args[i], false)
