class_name AttackPreview
extends RefCounted

## Numbers combat already calculated. UI shows them and does not derive them.
## damage_on_hit and damage_if_blocked are the smallest outcomes. The _max fields are the largest:
## they equal the smallest when the ability has a fixed base.

var hit_chance: int
var block_chance: int
var damage_on_hit: int
var damage_if_blocked: int
var guard_reduction: int
var damage_on_hit_max: int
var damage_if_blocked_max: int


func _init() -> void:
	hit_chance = 0
	block_chance = 0
	damage_on_hit = 0
	damage_if_blocked = 0
	guard_reduction = 0
	damage_on_hit_max = 0
	damage_if_blocked_max = 0
