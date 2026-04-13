-- map: place arena schematic and handle player spawning

local SCHEM_PATH = minetest.get_modpath("map") .. "/schems/fietsarena.mts"

-- Place the schematic at origin
local ORIGIN = vector.new(0, 0, 0)
local SCHEM_SIZE = vector.new(85, 14, 62)

-- Spawn point: center of the schematic, inside the arena
local SPAWN_POS = vector.new(
	math.floor(ORIGIN.x + SCHEM_SIZE.x / 2),
	ORIGIN.y + SCHEM_SIZE.y - 10,
	math.floor(ORIGIN.z + SCHEM_SIZE.z / 2)
)

local schematic_placed = false

-- Place schematic once when the area is generated
minetest.register_on_generated(function(minp, maxp)
	if schematic_placed then
		return
	end

	-- Check if the origin is within this mapblock
	if ORIGIN.x >= minp.x and ORIGIN.x <= maxp.x
	and ORIGIN.y >= minp.y and ORIGIN.y <= maxp.y
	and ORIGIN.z >= minp.z and ORIGIN.z <= maxp.z then
		minetest.place_schematic(ORIGIN, SCHEM_PATH, "0", nil, true)
		schematic_placed = true
		minetest.log("action", "[map] Arena schematic placed at " .. minetest.pos_to_string(ORIGIN))
	end
end)

-- Spawn players at the arena
minetest.register_on_newplayer(function(player)
	player:set_pos(SPAWN_POS)

	-- Give starting coins
	local meta = player:get_meta()
	meta:set_int("coins", 20)
end)

minetest.register_on_respawnplayer(function(player)
	player:set_pos(SPAWN_POS)
	return true
end)
