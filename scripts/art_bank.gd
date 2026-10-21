class_name ArtBank
extends RefCounted

const UNIT_TEX := {
	"song_xiangjun": preload("res://art/units/song_xiangjun.png"),
	"song_spear": preload("res://art/units/song_spear.png"),
	"song_archer": preload("res://art/units/song_archer.png"),
	"xia_tieyaozi": preload("res://art/units/xia_tieyaozi.png"),
	"xia_buba": preload("res://art/units/xia_buba.png"),
	"xia_tribal": preload("res://art/units/xia_tribal.png"),
	"liao_pishi": preload("res://art/units/liao_pishi.png"),
}
const FACE := {
	"normal": preload("res://art/advisor/normal.png"),
	"smug": preload("res://art/advisor/smug.png"),
	"disgust": preload("res://art/advisor/disgust.png"),
	"shock": preload("res://art/advisor/shock.png"),
	"sleepy": preload("res://art/advisor/sleepy.png"),
	"serious": preload("res://art/advisor/serious.png"),
	"think": preload("res://art/advisor/think.png"),
	"awkward": preload("res://art/advisor/awkward.png"),
	"moved": preload("res://art/advisor/moved.png"),
	"off": preload("res://art/advisor/off.png"),
}

static func unit_tex(sprite_id: String) -> Texture2D:
	if UNIT_TEX.has(sprite_id):
		return UNIT_TEX[sprite_id]
	return UNIT_TEX["song_xiangjun"]


static func face_tex(mood: String) -> Texture2D:
	if FACE.has(mood):
		return FACE[mood]
	return FACE["normal"]
