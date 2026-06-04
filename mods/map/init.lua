-- map: place arena schematic and handle player spawning

-- ── Arena 1 ─────────────────────────────────────────────────────────────────
local SCHEM_PATH       = minetest.get_modpath("map") .. "/schems/fietsarena.mts"

-- Place the schematic at origin
local ORIGIN           = vector.new(0, 0, 0)
local SCHEM_SIZE       = vector.new(85, 14, 62)

-- Spawn point: center of the schematic, inside the arena
local SPAWN_POS        = vector.new(
	math.floor(ORIGIN.x + SCHEM_SIZE.x / 2),
	ORIGIN.y + SCHEM_SIZE.y - 10,
	math.floor(ORIGIN.z + SCHEM_SIZE.z / 2)
)

local schematic_placed = false

-- Export spawn position for other mods (e.g. boss reaction)
map                    = map or {}
map.SPAWN_POS          = SPAWN_POS

-- ── Arena 2 ─────────────────────────────────────────────────────────────────
local SCHEM2_PATH      = minetest.get_modpath("map") .. "/schems/barlaeus_arena.mts"
local ORIGIN2          = vector.new(-330, 177, -440)
local schem2_placed    = false

-- Place schematics once when their area is generated
minetest.register_on_generated(function(minp, maxp)
	-- Arena 1
	if not schematic_placed then
		if ORIGIN.x >= minp.x and ORIGIN.x <= maxp.x
			and ORIGIN.y >= minp.y and ORIGIN.y <= maxp.y
			and ORIGIN.z >= minp.z and ORIGIN.z <= maxp.z then
			minetest.place_schematic(ORIGIN, SCHEM_PATH, "0", nil, true)
			schematic_placed = true
			minetest.log("action", "[map] Arena 1 placed at " .. minetest.pos_to_string(ORIGIN))
		end
	end

	-- Arena 2
	if not schem2_placed then
		if ORIGIN2.x >= minp.x and ORIGIN2.x <= maxp.x
			and ORIGIN2.y >= minp.y and ORIGIN2.y <= maxp.y
			and ORIGIN2.z >= minp.z and ORIGIN2.z <= maxp.z then
			minetest.place_schematic(ORIGIN2, SCHEM2_PATH, "0", nil, true)
			schem2_placed = true
			minetest.log("action", "[map] Arena 2 placed at " .. minetest.pos_to_string(ORIGIN2))
		end
	end
end)

-- Spawn players at the arena
minetest.register_on_newplayer(function(player)
	player:set_pos(SPAWN_POS)

	-- Give starting coins
	local meta = player:get_meta()
	meta:set_int("coins", 20)
end)

-- Teleport ALL players (new and returning) to the arena on join
minetest.register_on_joinplayer(function(player)
	minetest.after(0.5, function()
		local p = minetest.get_player_by_name(player:get_player_name())
		if p then
			p:set_pos(SPAWN_POS)
		end
	end)
end)

minetest.register_on_respawnplayer(function(player)
	player:set_pos(SPAWN_POS)
	return true
end)

-- Auto-place arena 2 on every server start using emerge_area so mapblocks exist first
minetest.register_on_mods_loaded(function()
	local minp = ORIGIN2
	local maxp = vector.add(ORIGIN2, vector.new(51, 9, 62))
	minetest.emerge_area(minp, maxp, function(blockpos, action, calls_remaining)
		if calls_remaining == 0 then
			minetest.after(0.1, function()
				minetest.place_schematic(ORIGIN2, SCHEM2_PATH, "0", nil, true)
				schem2_placed = true
				minetest.log("action", "[map] Arena 2 placed after emerge at "
					.. minetest.pos_to_string(ORIGIN2))
			end)
		end
	end)
end)

-- ── Schematic opslaan commando ──────────────────────────────────────────────
-- Gebruik: /save_arena — slaat de huidige fietsarena op als nieuw .mts bestand
-- Added by Ege
minetest.register_chatcommand("save_arena", {
	description = "Sla de fietsarena op als schematic (.mts)",
	privs = {server = true},
	func = function(name, param)
		-- Opslaan in world-map (mod-map is beveiligd door mod security)
		local filepath = minetest.get_worldpath() .. "/fietsarena.mts"
		-- Maak een schematic van het hele arena-gebied
		local minp = vector.new(ORIGIN.x, ORIGIN.y, ORIGIN.z)
		local maxp = vector.new(
			ORIGIN.x + SCHEM_SIZE.x - 1,
			ORIGIN.y + SCHEM_SIZE.y - 1,
			ORIGIN.z + SCHEM_SIZE.z - 1
		)
		minetest.create_schematic(minp, maxp, nil, filepath)
		return true, "Arena opgeslagen als fietsarena.mts! (" ..
			minetest.pos_to_string(minp) .. " tot " ..
			minetest.pos_to_string(maxp) .. ")"
	end,
})
