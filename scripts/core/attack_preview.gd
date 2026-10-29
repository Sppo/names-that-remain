class_name AttackPreview
extends RefCounted

## Numbers combat already calculated. UI shows them and does not derive them.

var hit_chance: int
var block_chance: int
var damage_on_hit: int
var damage_if_blocked: int
var guard_reduction: int


func _init() -> void:
	hit_chance = 0
	block_chance = 0
	damage_on_hit = 0
	damage_if_blocked = 0
	guard_reduction = 0
