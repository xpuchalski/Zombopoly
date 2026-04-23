extends Node

const ITEM_POOL := {
	"iron_blade": {
		"display_name": "Iron Blade",
		"rarity": "common",
		"description": "+2 base damage",
		"modifiers": {"attack_bonus": 2}
	},
	"sturdy_boots": {
		"display_name": "Sturdy Boots",
		"rarity": "common",
		"description": "+80 movement radius",
		"modifiers": {"move_radius_bonus": 80.0}
	},
	"field_tonic": {
		"display_name": "Field Tonic",
		"rarity": "common",
		"description": "+15 max HP",
		"modifiers": {"max_hp_bonus": 15}
	},
	"lucky_coin": {
		"display_name": "Lucky Coin",
		"rarity": "common",
		"description": "+5 money on pickup",
		"modifiers": {"money_on_pickup": 5}
	},
	"scope_lens": {
		"display_name": "Scope Lens",
		"rarity": "uncommon",
		"description": "+1 AP max, +1 damage",
		"modifiers": {"ap_max_bonus": 1, "attack_bonus": 1}
	},
	"blood_charm": {
		"display_name": "Blood Charm",
		"rarity": "uncommon",
		"description": "Heal 1 on hit",
		"modifiers": {"lifesteal": 1}
	},
	"guard_plate": {
		"display_name": "Guard Plate",
		"rarity": "uncommon",
		"description": "+2 block power",
		"modifiers": {"block_bonus": 2}
	},
	"flash_battery": {
		"display_name": "Flash Battery",
		"rarity": "rare",
		"description": "+2 AP max, special costs 1 less",
		"modifiers": {"ap_max_bonus": 2, "special_cost_delta": -1}
	},
	"chain_mail": {
		"display_name": "Chain Mail",
		"rarity": "rare",
		"description": "Reflect 1 damage when hit",
		"modifiers": {"thorns": 1, "max_hp_bonus": 10}
	},
	"war_banner": {
		"display_name": "War Banner",
		"rarity": "rare",
		"description": "+3 base damage",
		"modifiers": {"attack_bonus": 3}
	},
	"phase_spool": {
		"display_name": "Phase Spool",
		"rarity": "epic",
		"description": "+140 movement radius, +2 AP max",
		"modifiers": {"move_radius_bonus": 140.0, "ap_max_bonus": 2}
	},
	"phoenix_pin": {
		"display_name": "Phoenix Pin",
		"rarity": "legendary",
		"description": "+25 max HP, heal 2 on hit",
		"modifiers": {"max_hp_bonus": 25, "lifesteal": 2}
	}
}

const ITEM_WEIGHTS := {
	"iron_blade": 12,
	"sturdy_boots": 12,
	"field_tonic": 12,
	"lucky_coin": 12,
	"scope_lens": 9,
	"blood_charm": 9,
	"guard_plate": 9,
	"flash_battery": 6,
	"chain_mail": 6,
	"war_banner": 5,
	"phase_spool": 3,
	"phoenix_pin": 1
}

const CHARACTER_DATABASE := {
	1: {"display_name": "Character 1", "base_hp": 100, "base_attack": 6, "move_radius": 1000.0, "special_cost": 10, "special_name": "Double Tap", "basic_name": "Burst Shot", "block_name": "Brace", "money": 100},
	2: {"display_name": "Character 2", "base_hp": 110, "base_attack": 5, "move_radius": 980.0, "special_cost": 12, "special_name": "Piercing Drill", "basic_name": "Heavy Swing", "block_name": "Guard Stance", "money": 100},
	3: {"display_name": "Character 3", "base_hp": 95, "base_attack": 6, "move_radius": 1080.0, "special_cost": 10, "special_name": "Shadow Step", "basic_name": "Quick Cut", "block_name": "Evasion", "money": 100},
	4: {"display_name": "Character 4", "base_hp": 105, "base_attack": 5, "move_radius": 1020.0, "special_cost": 13, "special_name": "Arc Blast", "basic_name": "Spark Shot", "block_name": "Static Guard", "money": 100},
	5: {"display_name": "Character 5", "base_hp": 120, "base_attack": 4, "move_radius": 930.0, "special_cost": 14, "special_name": "Bulwark", "basic_name": "Shield Bash", "block_name": "Fortify", "money": 100},
	6: {"display_name": "Character 6", "base_hp": 90, "base_attack": 7, "move_radius": 1120.0, "special_cost": 11, "special_name": "Hunter's Mark", "basic_name": "Arrow Shot", "block_name": "Sidestep", "money": 100},
	7: {"display_name": "Character 7", "base_hp": 100, "base_attack": 6, "move_radius": 1040.0, "special_cost": 15, "special_name": "Overclock", "basic_name": "Pulse Hit", "block_name": "Screen", "money": 100},
	8: {"display_name": "Character 8", "base_hp": 115, "base_attack": 5, "move_radius": 960.0, "special_cost": 12, "special_name": "Crush Route", "basic_name": "Hook Strike", "block_name": "Body Check", "money": 100},
	9: {"display_name": "Character 9", "base_hp": 100, "base_attack": 5, "move_radius": 1050.0, "special_cost": 10, "special_name": "Field Aid", "basic_name": "Needle Jab", "block_name": "Cover", "money": 100}
}

const ZOMBIE_TYPES := {
	"walker": {"display_name": "Walker", "hp": 10, "attack_damage": 4, "money_drop": 5, "sprite_path": "res://assets/zombies/1.png"},
	"brute": {"display_name": "Brute", "hp": 16, "attack_damage": 7, "money_drop": 8, "sprite_path": "res://assets/zombies/2.png"},
	"runner": {"display_name": "Runner", "hp": 8, "attack_damage": 5, "money_drop": 6, "sprite_path": "res://assets/zombies/3.png"},
	"boss": {"display_name": "Boss", "hp": 36, "attack_damage": 10, "money_drop": 25, "sprite_path": "res://assets/zombies/4.png"}
}

var player_count: int = 1
var selected_characters: Array = []
var players: Array = []
var global_turn: int = 1
var unlocked_dungeons: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func build_players() -> void:
	players.clear()
	for i in range(selected_characters.size()):
		var character_id: int = selected_characters[i]
		var data := get_character_data(character_id)
		players.append({
			"player_id": i + 1,
			"character_id": character_id,
			"max_hp": data.get("base_hp", 100),
			"hp": data.get("base_hp", 100),
			"move_radius": data.get("move_radius", 1000.0),
			"money": data.get("money", 100),
			"is_zombified": false,
			"base_damage": data.get("base_attack", 5),
			"max_ap": 20,
			"current_ap": 20,
			"collected_items": []
		})

func reset_run_state() -> void:
	global_turn = 1
	players.clear()
	unlocked_dungeons.clear()
	selected_characters.clear()

func is_dungeon_unlocked(dungeon_id: String) -> bool:
	return unlocked_dungeons.get(dungeon_id, false)

func unlock_dungeon(dungeon_id: String) -> void:
	unlocked_dungeons[dungeon_id] = true

func get_character_data(character_id: int) -> Dictionary:
	return CHARACTER_DATABASE.get(character_id, CHARACTER_DATABASE[1]).duplicate(true)

func get_item_data(item_id: String) -> Dictionary:
	var data: Dictionary = ITEM_POOL.get(item_id, {}).duplicate(true)
	data["item_id"] = item_id
	return data

func roll_random_item_id() -> String:
	var total := 0
	for weight in ITEM_WEIGHTS.values():
		total += int(weight)
	var roll := rng.randi_range(1, max(total, 1))
	var running := 0
	for item_id in ITEM_WEIGHTS.keys():
		running += int(ITEM_WEIGHTS[item_id])
		if roll <= running:
			return item_id
	return ITEM_WEIGHTS.keys()[0]

func get_zombie_type_data(zombie_type: String) -> Dictionary:
	return ZOMBIE_TYPES.get(zombie_type, ZOMBIE_TYPES["walker"]).duplicate(true)

func roll_random_zombie_type() -> String:
	var roll := rng.randi_range(0, 99)
	if roll < 20:
		return "runner"
	if roll < 35:
		return "brute"
	return "walker"
