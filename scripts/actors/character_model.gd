class_name CharacterModel
extends Node3D
## Wraps an animated KayKit character (glTF): plays and blends animations,
## attaches weapons to the hand bones and applies material overlays.
## The model is turned so that it faces -Z like every other node in the game.

const CHAR_DIR := "res://assets/kaykit/characters/"
const WEAPON_DIR := "res://assets/kaykit/weapons/"

## Animations that should loop.
const LOOPING := [
	"Idle", "Idle_B", "Idle_Combat", "2H_Melee_Idle", "Unarmed_Idle",
	"Walking_A", "Walking_B", "Walking_C", "Walking_D_Skeletons", "Walking_Backwards",
	"Running_A", "Running_B", "Running_C", "Running_Strafe_Left", "Running_Strafe_Right",
	"Spellcasting", "Blocking", "Lie_Idle", "Skeletons_Inactive_Floor_Pose",
]

static var _scenes: Dictionary = {}

var model: Node3D
var anim: AnimationPlayer
var skeleton: Skeleton3D
var meshes: Array[MeshInstance3D] = []
var current := ""
var _oneshot := ""
var _after_oneshot := ""


static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]


func setup(file: String, scale_factor := 0.85) -> CharacterModel:
	model = scene(CHAR_DIR + file).instantiate()
	model.rotation.y = PI
	model.scale = Vector3.ONE * scale_factor
	add_child(model)
	anim = model.find_child("AnimationPlayer", true, false)
	var sk := model.find_children("*", "Skeleton3D", true, false)
	if not sk.is_empty():
		skeleton = sk[0]
	for m in model.find_children("*", "MeshInstance3D", true, false):
		meshes.append(m)
	if anim:
		for n in LOOPING:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		anim.animation_finished.connect(_on_finished)
	return self


## Hides meshes whose name contains any of the given parts (e.g. unused weapons).
func hide_meshes(parts: Array) -> void:
	for m in meshes:
		for p in parts:
			if String(m.name).contains(p):
				m.visible = false


func attach(weapon_file: String, bone := "handslot.r", offset := Transform3D()) -> Node3D:
	if skeleton == null or skeleton.find_bone(bone) < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skeleton.add_child(ba)
	var w: Node3D = scene(WEAPON_DIR + weapon_file).instantiate()
	w.transform = offset
	ba.add_child(w)
	for m in w.find_children("*", "MeshInstance3D", true, false):
		meshes.append(m)
	return w


func set_overlay(mat: Material) -> void:
	for m in meshes:
		m.material_overlay = mat


func set_override(mat: Material) -> void:
	for m in meshes:
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func has(anim_name: String) -> bool:
	return anim != null and anim.has_animation(anim_name)


## Plays a looping/base animation unless a one-shot is running.
func loop(anim_name: String, speed := 1.0, blend := 0.2) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	_after_oneshot = anim_name
	if _oneshot != "":
		return
	if current == anim_name:
		anim.speed_scale = speed
		return
	current = anim_name
	anim.play(anim_name, blend, speed)


## Plays an animation once, then returns to the last looping one.
func once(anim_name: String, speed := 1.0, blend := 0.1) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	_oneshot = anim_name
	current = anim_name
	anim.play(anim_name, blend, speed)
	anim.seek(0.0, true)


## Plays and holds the last frame (death).
func final(anim_name: String, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	_oneshot = "__final__"
	current = anim_name
	anim.play(anim_name, 0.15, speed)


func busy() -> bool:
	return _oneshot != "" and _oneshot != "__final__"


func reset_state() -> void:
	_oneshot = ""
	current = ""


func _on_finished(anim_name: StringName) -> void:
	if _oneshot == "__final__":
		return
	if String(anim_name) == _oneshot:
		_oneshot = ""
		current = ""
		if _after_oneshot != "":
			loop(_after_oneshot)
