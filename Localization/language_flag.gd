class_name LanguageFlag
extends Control
## A small flag drawn in code (no image files, sharp at any size): "it" Italy,
## "en" United Kingdom, "es" Spain, "pt" Portugal, "el" Greece. Used by the
## main menu's language picker.

const IT_GREEN := Color("009246")
const IT_WHITE := Color("f1f2f1")
const IT_RED := Color("ce2b37")
const UK_BLUE := Color("012169")
const UK_RED := Color("c8102e")
const GR_BLUE := Color("0d5eaf")
const ES_RED := Color("c60b1e")
const ES_YELLOW := Color("ffc400")
const PT_GREEN := Color("046a38")
const PT_RED := Color("da291c")
const PT_YELLOW := Color("ffe900")

var code := "it":
	set(value):
		code = value
		queue_redraw()


func _ready() -> void:
	clip_contents = true  # the Union Jack's diagonals stop at the edges
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	match code:
		"it":
			draw_rect(Rect2(0, 0, w / 3.0, h), IT_GREEN)
			draw_rect(Rect2(w / 3.0, 0, w / 3.0, h), IT_WHITE)
			draw_rect(Rect2(w * 2.0 / 3.0, 0, w - w * 2.0 / 3.0, h), IT_RED)
		"en":
			draw_rect(Rect2(0, 0, w, h), UK_BLUE)
			var diag := h * 0.2
			draw_line(Vector2(-diag, -diag * h / w), Vector2(w + diag, h + diag * h / w), Color.WHITE, diag)
			draw_line(Vector2(-diag, h + diag * h / w), Vector2(w + diag, -diag * h / w), Color.WHITE, diag)
			draw_line(Vector2(-diag, -diag * h / w), Vector2(w + diag, h + diag * h / w), UK_RED, h * 0.07)
			draw_line(Vector2(-diag, h + diag * h / w), Vector2(w + diag, -diag * h / w), UK_RED, h * 0.07)
			var white := h / 3.0
			draw_rect(Rect2(0, (h - white) / 2.0, w, white), Color.WHITE)
			draw_rect(Rect2((w - white) / 2.0, 0, white, h), Color.WHITE)
			var red := h / 5.0
			draw_rect(Rect2(0, (h - red) / 2.0, w, red), UK_RED)
			draw_rect(Rect2((w - red) / 2.0, 0, red, h), UK_RED)
		"el":
			var stripe := h / 9.0
			for i in 9:
				draw_rect(Rect2(0, i * stripe, w, stripe + 0.5), GR_BLUE if i % 2 == 0 else Color.WHITE)
			var canton := stripe * 5.0
			draw_rect(Rect2(0, 0, canton, canton), GR_BLUE)
			draw_rect(Rect2(0, stripe * 2.0, canton, stripe), Color.WHITE)
			draw_rect(Rect2(stripe * 2.0, 0, stripe, canton), Color.WHITE)
		"es":
			draw_rect(Rect2(0, 0, w, h), ES_RED)
			draw_rect(Rect2(0, h / 4.0, w, h / 2.0), ES_YELLOW)
			# simplified coat of arms
			draw_rect(Rect2(w * 0.24, h * 0.36, w * 0.1, h * 0.28), ES_RED)
		"pt":
			draw_rect(Rect2(0, 0, w * 0.4, h), PT_GREEN)
			draw_rect(Rect2(w * 0.4, 0, w * 0.6, h), PT_RED)
			# simplified armillary sphere and shield
			var c := Vector2(w * 0.4, h / 2.0)
			draw_circle(c, h * 0.26, PT_YELLOW)
			draw_circle(c, h * 0.17, PT_RED)
			draw_rect(Rect2(c - Vector2(h * 0.1, h * 0.12), Vector2(h * 0.2, h * 0.24)), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6), false, 1.5)
