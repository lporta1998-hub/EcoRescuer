extends SceneTree
## Renders the Trash Patrol pixel-art logo (main menu title + loading screen):
##
##   /path/to/Godot --path . -s Tools/render_logo.gd
##   /path/to/Godot --path . -s Tools/render_logo.gd -- colors=lime out=/tmp/x.png
##
## (not --headless: it needs a renderer). 16-bit style lettering: the words are
## drawn about `cap` pixels tall, their soft edges reduced to one in-between
## shade (hand-antialiased pixel art), then shaded with the app icon's palette
## (TRASH in trash-bag metal with toxic slime dripping on top, like the icon's
## barrel; PATROL in recycle lime), given a 1 px outline and a 2 px drop, and
## every pixel is scaled up `scale` times with no filtering. Pixelify Sans is
## in Tools/fonts (SIL Open Font License).
## The menu shows the logo at 1:1 on an iPhone: after changing it, set the
## Title rect in main_menu.tscn to image size / 1.82.

const FONTS := {
	"pixelify": ["res://Tools/fonts/PixelifySans-Variable.ttf", 700],
	"comfortaa": ["res://silent_wolf/assets/fonts/Comfortaa-Bold.ttf", 0],
}
const DEFAULTS := {"font": "pixelify", "cap": "28", "scale": "6", "colors": "metal",
		"out": "res://Misc/AppIcon/launch_logo.png"}
const LINE_GAP := 4

# The app icon's palette.
const LIME := ["e8ffb0", "dffc9b", "c6f06a", "b3e94c", "9edc4a", "86cf45", "6fbe41", "5eb341", "4d9937", "3b7c2d"]
const METAL := ["d4d8e0", "c3c8d3", "aeb3bf", "9da2af", "868c9b", "707686", "5b6170", "494d5c", "3a3e4c", "2f333e"]
const SLIME := ["e8ffb0", "c6f06a", "9edc4a"]
const OUTLINE := Color("242330")
const DROP := Color("12323d")


func _initialize() -> void:
	_render.call_deferred()


func _font(key: String, size: int) -> Font:
	var base := FontFile.new()
	base.load_dynamic_font(FONTS[key][0])
	base.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	base.hinting = TextServer.HINTING_NONE
	base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	if FONTS[key][1] == 0:
		return base
	var f := FontVariation.new()
	f.base_font = base
	f.variation_opentype = {"wght": FONTS[key][1]}
	return f


## `text` drawn white on transparent; returns the alpha image.
func _word(font: Font, size: int, text: String) -> Image:
	var w := ceili(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(w + 8, ceili(font.get_height(size)) + 8)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var c := Control.new()
	c.draw.connect(func(): font.draw_string(c.get_canvas_item(), Vector2(4, 4 + font.get_ascent(size)), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE))
	vp.add_child(c)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img.get_region(img.get_used_rect())


func _render() -> void:
	var a := DEFAULTS.duplicate()
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		if kv.size() == 2:
			a[kv[0]] = kv[1]
	var cap := int(a.cap)
	var scale := int(a.scale)
	# font size giving letters about `cap` pixels tall
	var probe := _font(a.font, 200)
	var probe_img: Image = await _word(probe, 200, "H")
	var size := maxi(6, roundi(200.0 * cap / probe_img.get_height()))
	var font := _font(a.font, size)
	var words := [["TRASH", METAL if a.colors == "metal" else LIME, a.colors == "metal"], ["PATROL", LIME, false]]
	var imgs := []
	for w in words:
		imgs.append(await _word(font, size, w[0]))
	var width := 0
	var height := 0
	for im in imgs:
		width = maxi(width, im.get_width())
		height += im.get_height()
	height += LINE_GAP * (imgs.size() - 1)
	var cw := width + 2
	var ch := height + 4
	# 0 empty, 1 edge (in-between shade), 2 solid
	var kind := PackedByteArray()
	kind.resize(cw * ch)
	var color := []
	color.resize(cw * ch)
	var y := 1
	for i in imgs.size():
		var im: Image = imgs[i]
		var bands: Array = words[i][1]
		var x0 := 1 + (width - im.get_width()) / 2
		for px in im.get_width():
			var drip: int = [0, 3, 0, 2, 5, 0, 1, 0, 4, 0, 0, 2][(px * 7 + 3) % 12] if words[i][2] else 0
			for py in im.get_height():
				var al := im.get_pixel(px, py).a
				if al < 0.3:
					continue
				var idx := (y + py) * cw + x0 + px
				var band := mini(int(float(py) / im.get_height() * bands.size()), bands.size() - 1)
				var c := Color(bands[band])
				if words[i][2] and py < 3 + drip:
					c = Color(SLIME[mini(py, 2)])
				if al < 0.7:
					kind[idx] = 1
					c = c.lerp(OUTLINE, 0.45)
				else:
					kind[idx] = 2
				color[idx] = c
		y += im.get_height() + LINE_GAP
	var img := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var on := func(x: int, yy: int) -> bool:
		return x >= 0 and yy >= 0 and x < cw and yy < ch and kind[yy * cw + x] > 0
	var near := func(x: int, yy: int) -> bool:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if on.call(x + dx, yy + dy):
					return true
		return false
	for yy in ch:
		for x in cw:
			if on.call(x, yy):
				img.set_pixel(x, yy, color[yy * cw + x])
			elif near.call(x, yy):
				img.set_pixel(x, yy, OUTLINE)
			elif near.call(x, yy - 1) or near.call(x, yy - 2):
				img.set_pixel(x, yy, DROP)
	img = img.get_region(img.get_used_rect())
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	img.save_png(a.out)
	print("Logo saved: %s %s (font size %d)" % [a.out, img.get_size(), size])
	quit()
