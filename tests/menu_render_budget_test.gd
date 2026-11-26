extends Node
## Lauf: einzeln (Name menurender)
## Modi: kern
## Hidden menu pages must stop the animated offscreen logo viewport and resume correctly.
var failures := 0

func check(ok: bool, message: String) -> void:
	if ok:print("OK   ",message)
	else:
		failures += 1
		printerr("FAIL ",message)

func _ready() -> void:
	var page := Control.new()
	add_child(page)
	var logo := Wc3Logo.new()
	page.add_child(logo)
	check(logo.is_processing(),"visible logo animates")
	check(logo.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"visible viewport renders animated logo")
	page.hide()
	check(not logo.is_processing(),"hidden parent stops logo animation")
	check(logo.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"hidden parent stops offscreen render")
	page.show()
	check(logo.is_processing(),"returning to page resumes animation")
	check(logo.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"returning to page resumes offscreen render")
	page.free()
	print("Menu render budget: ",failures," errors")
	get_tree().quit(1 if failures else 0)
