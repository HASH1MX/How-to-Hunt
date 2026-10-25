extends SceneTree
## Draws the game icon (crosshair on a green rounded square) and saves PNGs next to this
## script. Run: godot --headless --path . -s res://tools/installer/draw_icon.gd
## Then pack them: python tools/installer/make_ico.py tools/installer tools/installer/icon.ico

func _sd_round_rect(p: Vector2, half: float, r: float) -> float:
	var q := p.abs() - Vector2(half - r, half - r)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r

func _cover(d: float, px: float) -> float:
	return clampf(0.5 - d / px, 0.0, 1.0)

func _initialize() -> void:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var px := 1.0 / n * 2.0
	var cream := Color(1.0, 0.95, 0.84)
	var orange := Color(0.95, 0.47, 0.22)
	for y in n:
		for x in n:
			var p := Vector2((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0)
			var bg := _cover(_sd_round_rect(p, 0.96, 0.32), px)
			if bg <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var t := (p.y + 1.0) * 0.5
			var c := Color(0.42, 0.66, 0.3).lerp(Color(0.16, 0.34, 0.17), t)
			# Soft dark rim.
			c = c.lerp(Color(0.1, 0.2, 0.1), (1.0 - _cover(_sd_round_rect(p, 0.96, 0.32) + 0.06, px)) * 0.5)
			var r := p.length()
			var ring := _cover(absf(r - 0.5) - 0.075, px)
			var ticks := 0.0
			for axis in [Vector2(1, 0), Vector2(0, 1)]:
				var along := absf(p.dot(axis))
				var across := absf(p.dot(Vector2(-axis.y, axis.x)))
				if along > 0.27 and along < 0.8:
					ticks = maxf(ticks, _cover(across - 0.055, px))
			var shade := maxf(ring, ticks)
			# Shadow under the crosshair.
			var sp := p - Vector2(0.03, 0.04)
			var sr := sp.length()
			var shadow := _cover(absf(sr - 0.5) - 0.075, px * 3.0) * 0.35
			c = c.lerp(Color(0.05, 0.12, 0.05), shadow * (1.0 - shade))
			c = c.lerp(cream, shade)
			var dot := _cover(r - 0.13, px)
			c = c.lerp(orange, dot)
			c.a = bg
			img.set_pixel(x, y, c)
	var dir := "res://tools/installer/"
	img.save_png(dir + "icon_256.png")
	for s in [16, 24, 32, 48, 64, 128]:
		var small := img.duplicate() as Image
		small.resize(s, s, Image.INTERPOLATE_LANCZOS)
		small.save_png(dir + "icon_%d.png" % s)
	quit()
