extends Node
## Global signal bus. Systems talk through here so later phases (quests,
## dialogue, ship combat, followers) can subscribe without reaching into scenes.

signal game_started
signal game_paused(paused: bool)
signal returned_to_menu
signal player_vitals_changed(health: float, max_health: float, shield: float, max_shield: float)
signal player_ammo_changed(magazine: int, reserve: int, reloading: bool)
signal player_damaged(amount: float)
signal player_healed
signal player_died
signal hit_confirm
signal enemy_killed(kind: String)
signal interaction_prompt(text: String)
signal settings_changed
signal request_launch
signal request_pause
signal request_resume
signal request_menu
signal request_retry
signal stats_changed
signal xp_changed(level: int, xp: int, xp_needed: int)
signal level_up(level: int)
signal skills_changed
signal ability_cast(id: String)
signal inventory_changed
signal quest_updated(id: String)
signal ship_changed
signal toast(text: String)
signal open_panel(panel: String)
