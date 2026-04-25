extends Node

const ITEM_POOL := {
	"Item_0": {"display_name": "Flower Pot Pauldrons", "rarity": "common", "description": "-1 incoming damage", "modifiers": {"damage_reduction": 1}},
	"Item_1": {"display_name": "Foraged Broken Blade", "rarity": "common", "description": "+2 base damage", "modifiers": {"attack_bonus": 2}},
	"Item_2": {"display_name": "Well Preserved Energy Drink", "rarity": "common", "description": "+80 movement radius", "modifiers": {"move_radius_bonus": 80.0}},
	"Item_3": {"display_name": "Makeshift Tile Armor", "rarity": "common", "description": "+15 max HP", "modifiers": {"max_hp_bonus": 15}},
	"Item_4": {"display_name": "Taekwondo for Dummies", "rarity": "common", "description": "1.1x base damage multiplier", "modifiers": {"attack_multiplier": 0.10}},
	"Item_5": {"display_name": "Trail Mix", "rarity": "common", "description": "Heal 2 HP every turn", "modifiers": {"heal_per_turn": 2}},
	"Item_6": {"display_name": "Broken Glasses", "rarity": "common", "description": "+5% chance to crit (3x damage)", "modifiers": {"crit_chance": 0.05}},
	"Item_7": {"display_name": "Beef Jerky", "rarity": "common", "description": "Heal 1 HP on hit", "modifiers": {"lifesteal": 1}},
	"Item_8": {"display_name": "Decoy Plush", "rarity": "common", "description": "Negate 1 instance of damage per battle", "modifiers": {"decoy_per_battle": 1}},
	"Item_9": {"display_name": "Zombie Anatomy Book", "rarity": "uncommon", "description": "+15% crit chance", "modifiers": {"crit_chance": 0.15}},
	"Item_10": {"display_name": "Extra Sharp Onion Magazine", "rarity": "uncommon", "description": "Apply 2 bleed per hit", "modifiers": {"bleed_on_hit": 2}},
	"Item_11": {"display_name": "Gatorade Lite", "rarity": "uncommon", "description": "+2 AP max", "modifiers": {"ap_max_bonus": 2}},
	"Item_12": {"display_name": "Makeshift Thorns Armor", "rarity": "uncommon", "description": "Reflect 1/2 damage when hit", "modifiers": {"thorns_fraction": 0.5}},
	"Item_13": {"display_name": "Non-newtonian Armor", "rarity": "uncommon", "description": "10% chance to negate incoming damage", "modifiers": {"damage_negate_chance": 0.10}},
	"Item_14": {"display_name": "Rubble Armor", "rarity": "uncommon", "description": "+3 temporary HP per turn", "modifiers": {"temp_hp_per_turn": 3}},
	"Item_15": {"display_name": "Leaded Gas", "rarity": "uncommon", "description": "1 burn applied to enemy at battle start", "modifiers": {"burn_battle_start": 1}},
	"Item_16": {"display_name": "Box of Bandages", "rarity": "uncommon", "description": "Allow overhealing of 10%", "modifiers": {"overheal_percent": 0.10}},
	"Item_17": {"display_name": "Serene Death", "rarity": "rare", "description": "+1% chance to instant kill", "modifiers": {"instant_kill_chance": 0.01}},
	"Item_18": {"display_name": "Exquisite Gem", "rarity": "rare", "description": "+5 max AP", "modifiers": {"ap_max_bonus": 5}},
	"Item_19": {"display_name": "Pretty Rock", "rarity": "rare", "description": "+1 AP per turn", "modifiers": {"ap_regen_bonus": 1}},
	"Item_20": {"display_name": "Strange Painkillers", "rarity": "rare", "description": "Heal 1 HP for each bleed/burn stack on yourself each turn", "modifiers": {"status_heal_per_instance": 1}},
	"Item_21": {"display_name": "Syringe Crossbow", "rarity": "legendary", "description": "All healing can heal over max HP", "modifiers": {"overheal_all": true}},
	"Item_22": {"display_name": "Exotic Katana", "rarity": "legendary", "description": "Guaranteed critical hits on bleeding enemies", "modifiers": {"guaranteed_crit_bleeding": true}},
	"Item_23": {"display_name": "Essence of Noob", "rarity": "legendary", "description": "5% chance per attack to add a zombie ally in battle (placeholder)", "modifiers": {"zombie_ally_chance": 0.05}},
	"Item_24": {"display_name": "Boom Stick", "rarity": "legendary", "description": "Base damage +100", "modifiers": {"attack_bonus": 100}},
	"Item_25": {"display_name": "Bottled God Particle", "rarity": "legendary", "description": "Every 10 turns, revive yourself or another zombified player (placeholder)", "modifiers": {"god_particle": true}}
}

const RARITY_WEIGHTS := {"common": 50, "uncommon": 30, "rare": 15, "legendary": 5}

const CHARACTER_DATABASE := {
	1: {"display_name": "Penny", "base_hp": 20, "base_attack": 5, "move_radius": 400.0, "special_cost": 15, "special_name": "Placebo Pills", "basic_name": "Panicked Attack", "block_name": "Block", "money": 0},
	2: {"display_name": "Astrea", "base_hp": 24, "base_attack": 8, "move_radius": 500.0, "special_cost": 10, "special_name": "Drake Hunter", "basic_name": "Knife Slash", "block_name": "Block", "money": 0},
	3: {"display_name": "Ember", "base_hp": 20, "base_attack": 5, "move_radius": 400.0, "special_cost": 15, "special_name": "Burn It All", "basic_name": "Curt Blow", "block_name": "Block", "money": 10},
	4: {"display_name": "Nova", "base_hp": 20, "base_attack": 5, "move_radius": 600.0, "special_cost": 10, "special_name": "Experimental Gadget", "basic_name": "Ol' Reliable", "block_name": "Block", "money": 0},
	5: {"display_name": "Rhea", "base_hp": 24, "base_attack": 8, "move_radius": 500.0, "special_cost": 1, "special_name": "Muay Thai Counter", "basic_name": "Right Cross", "block_name": "Block", "money": 0},
	6: {"display_name": "Hina", "base_hp": 28, "base_attack": 5, "move_radius": 400.0, "special_cost": 1, "special_name": "Brutal Tackle", "basic_name": "Calculated Strike", "block_name": "Block", "money": 0},
	7: {"display_name": "Jun", "base_hp": 24, "base_attack": 5, "move_radius": 400.0, "special_cost": 10, "special_name": "Serrated Slash", "basic_name": "Mechanical Blow", "block_name": "Block", "money": 0},
	8: {"display_name": "Vex", "base_hp": 20, "base_attack": 8, "move_radius": 500.0, "special_cost": 10, "special_name": "Assassination", "basic_name": "Back Stab", "block_name": "Block", "money": 0},
	9: {"display_name": "Kyra", "base_hp": 20, "base_attack": 5, "move_radius": 400.0, "special_cost": 15, "special_name": "Budget Necromancy", "basic_name": "Karate Jab", "block_name": "Block", "money": 0}
}

const ZOMBIE_TYPES := {
	"walker": {"display_name": "Walker", "hp": 10, "attack_damage": 3, "money_drop": 5, "sprite_path": "res://assets/zombies/1.png"},
	"brute": {"display_name": "Brute", "hp": 15, "attack_damage": 3, "money_drop": 5, "sprite_path": "res://assets/zombies/2.png"},
	"runner": {"display_name": "Runner", "hp": 10, "attack_damage": 5, "money_drop": 5, "sprite_path": "res://assets/zombies/3.png"},
	"boss": {"display_name": "Boss", "hp": 300, "attack_damage": 25, "money_drop": 25, "sprite_path": "res://assets/zombies/4.png"}
}

var player_count: int = 1
var selected_characters: Array = []
var players: Array = []
var global_turn: int = 1
var unlocked_dungeons: Dictionary = {}
var total_bosses_required: int = 5
var defeated_bosses: Dictionary = {}
var warehouse_win_prompt_shown: bool = false
var cooperative_win_achieved: bool = false
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
			"collected_items": [],
			"bleed_stacks": 0,
			"burn_stacks": 0,
			"temporary_hp": 0,
			"placebo_turns": 0,
			"counter_active": false,
			"zombie_damage_memory": []
		})

func reset_run_state() -> void:
	global_turn = 1
	players.clear()
	unlocked_dungeons.clear()
	defeated_bosses.clear()
	warehouse_win_prompt_shown = false
	cooperative_win_achieved = false
	selected_characters.clear()

func is_dungeon_unlocked(dungeon_id: String) -> bool:
	return unlocked_dungeons.get(dungeon_id, false)

func unlock_dungeon(dungeon_id: String) -> void:
	unlocked_dungeons[dungeon_id] = true


func register_boss_defeated(boss_id: String) -> bool:
	if boss_id == "":
		return false
	if defeated_bosses.get(boss_id, false):
		return false
	defeated_bosses[boss_id] = true
	return true

func is_boss_defeated(boss_id: String) -> bool:
	return defeated_bosses.get(boss_id, false)

func get_defeated_boss_count() -> int:
	return defeated_bosses.size()

func are_all_bosses_defeated() -> bool:
	return get_defeated_boss_count() >= total_bosses_required

func get_character_data(character_id: int) -> Dictionary:
	return CHARACTER_DATABASE.get(character_id, CHARACTER_DATABASE[1]).duplicate(true)

func get_item_data(item_id: String) -> Dictionary:
	var data: Dictionary = ITEM_POOL.get(item_id, {}).duplicate(true)
	data["item_id"] = item_id
	return data

func roll_random_item_id() -> String:
	var rarity := roll_random_rarity()
	var candidates: Array = []
	for item_id in ITEM_POOL.keys():
		var data: Dictionary = ITEM_POOL[item_id]
		if str(data.get("rarity", "common")).to_lower() == rarity:
			candidates.append(item_id)
	if candidates.is_empty():
		return ITEM_POOL.keys()[0]
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func roll_random_rarity() -> String:
	var total := 0
	for weight in RARITY_WEIGHTS.values():
		total += int(weight)
	var roll := rng.randi_range(1, max(total, 1))
	var running := 0
	for rarity in ["common", "uncommon", "rare", "legendary"]:
		running += int(RARITY_WEIGHTS.get(rarity, 0))
		if roll <= running:
			return rarity
	return "common"

func get_zombie_type_data(type_name: String) -> Dictionary:
	match type_name:
		"walker":
			return {
				"display_name": "Walker",
				"hp": 15,
				"attack_damage": 4,
				"money_drop": 5,
				"sprite_path": "res://assets/zombies/1.png",
				"portrait_path": "res://assets/zombies/portraits/1.png"
			}
		"runner":
			return {
				"display_name": "Runner",
				"hp": 10,
				"attack_damage": 6,
				"money_drop": 6,
				"sprite_path": "res://assets/zombies/2.png",
				"portrait_path": "res://assets/zombies/portraits/2.png"
			}
		"brute":
			return {
				"display_name": "Brute",
				"hp": 25,
				"attack_damage": 8,
				"money_drop": 10,
				"sprite_path": "res://assets/zombies/3.png",
				"portrait_path": "res://assets/zombies/portraits/3.png"
			}
		_:
			return {}

func roll_random_zombie_type() -> String:
	var roll := rng.randi_range(0, 99)
	if roll < 20:
		return "runner"
	if roll < 35:
		return "brute"
	return "walker"
