-- npc: NPC entities and spawning utilities

-- Global table for shared functions
npc = {}
npc._refs = {}  -- track spawned NPC objectrefs

--- Spawn an NPC entity at a position with a nametag.
-- @param pos       vector: spawn position
-- @param name      string: display name above the NPC
-- @param texture   string: texture file name (default "character.png")
-- @return ObjectRef of the spawned entity, or nil
function npc.spawn_npc(pos, name, texture)
	local obj = minetest.add_entity(pos, "npc:npc")
	if not obj then
		minetest.log("error", "[npc] Failed to spawn NPC '" .. name .. "'")
		return nil
	end

	obj:set_properties({
		nametag = name,
		nametag_color = "#FFFFFF",
		textures = {texture or "npc_wapenverkoper.png"},
	})

	local lua = obj:get_luaentity()
	if lua then
		lua._display_name = name
		lua._texture = texture or "npc_wapenverkoper.png"
	end

	npc._refs[name] = obj
	minetest.log("action", "[npc] Spawned NPC '" .. name .. "' at " .. minetest.pos_to_string(pos))
	return obj
end

-- Build shop formspec (reusable so we can re-show it)
local function build_shop_formspec(npc_name, coins)
	return
		"formspec_version[4]" ..
		"size[13,8]" ..
		"label[0.5,0.5;" .. minetest.formspec_escape(npc_name) .. "]" ..
		"label[0.5,1.0;Je hebt " .. coins .. " munten.]" ..

		-- Houten Zwaard (5 coins)
		"image_button[0.5,1.8;2,2;registered_sword_wood.png;buy_sword_wood;]" ..
		"label[0.5,4.0;Houten Zwaard]" ..
		"label[0.5,4.5;5 munten]" ..

		-- Stalen Zwaard (15 coins)
		"image_button[3.0,1.8;2,2;registered_sword_steel.png;buy_sword_steel;]" ..
		"label[3.0,4.0;Stalen Zwaard]" ..
		"label[3.0,4.5;15 munten]" ..

		-- Bronzen Zwaard (25 coins)
		"image_button[5.5,1.8;2,2;registered_sword_bronze.png;buy_sword_bronze;]" ..
		"label[5.5,4.0;Bronzen Zwaard]" ..
		"label[5.5,4.5;25 munten]" ..

		-- Fanta Bazooka (30 coins)
		"image_button[8.0,1.8;2,2;registered_fanta_bazooka.png;buy_fanta_bazooka;]" ..
		"label[8.0,4.0;Fanta Bazooka]" ..
		"label[8.0,4.5;10 munten]" ..

		"button_exit[5.0,6.5;3,0.8;close;Sluiten]"
end

-- Build food shop formspec
local function build_food_formspec(npc_name, coins)
	return
		"formspec_version[4]" ..
		"size[12,8]" ..
		"label[0.5,0.5;" .. minetest.formspec_escape(npc_name) .. "]" ..
		"label[0.5,1.0;Je hebt " .. coins .. " munten.]" ..

		-- Appel (2 coins)
		"image_button[0.5,1.8;2,2;registered_apple.png;buy_apple;]" ..
		"label[0.5,4.0;Appel]" ..
		"label[0.5,4.5;2 munten]" ..

		-- Brood (4 coins)
		"image_button[3.0,1.8;2,2;registered_bread.png;buy_bread;]" ..
		"label[3.0,4.0;Brood]" ..
		"label[3.0,4.5;4 munten]" ..

		-- Vis (6 coins)
		"image_button[5.5,1.8;2,2;registered_fish.png;buy_fish;]" ..
		"label[5.5,4.0;Vis]" ..
		"label[5.5,4.5;6 munten]" ..

		-- Vlees (8 coins)
		"image_button[8.0,1.8;2,2;registered_meat.png;buy_meat;]" ..
		"label[8.0,4.0;Vlees]" ..
		"label[8.0,4.5;8 munten]" ..

		"button_exit[4.5,6.5;3,0.8;close;Sluiten]"
end

-- NPC entity definition
minetest.register_entity("npc:npc", {
	initial_properties = {
		visual = "mesh",
		mesh = "character.b3d",
		textures = {"npc_wapenverkoper.png"},
		physical = true,
		collide_with_objects = true,
		collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
		visual_size = {x = 1, y = 1, z = 1},
		makes_footstep_sound = false,
		nametag = "",
		nametag_color = "#FFFFFF",
		static_save = true,
	},

	_display_name = "",
	_texture = "npc_wapenverkoper.png",

	get_staticdata = function(self)
		return minetest.serialize({
			display_name = self._display_name,
			texture = self._texture,
		})
	end,

	on_activate = function(self, staticdata)
		-- Restore saved state
		if staticdata and staticdata ~= "" then
			local data = minetest.deserialize(staticdata)
			if data then
				self._display_name = data.display_name or ""
				self._texture = data.texture or "npc_wapenverkoper.png"
			end
		end

		-- Re-apply properties
		if self._display_name ~= "" then
			self.object:set_properties({
				nametag = self._display_name,
				nametag_color = "#FFFFFF",
				textures = {self._texture},
			})
			npc._refs[self._display_name] = self.object
		end

		-- Play stand animation
		self.object:set_animation({x = 0, y = 79}, 30, 0, true)
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		if not puncher or not puncher:is_player() then return end
		local pname = puncher:get_player_name()
		local npc_name = self._display_name

		if not npc_name or npc_name == "" then return end

		-- Show greeting in chat
		minetest.chat_send_player(pname,
			"Hallo, " .. pname .. "! Kijk eens naar mijn waren.")

		-- Show the correct shop formspec after 0.5 seconds
		minetest.after(0.5, function()
			local player = minetest.get_player_by_name(pname)
			if not player then return end

			local meta = player:get_meta()
			local coins = meta:get_int("coins")

			if npc_name == "Eetverkoper" then
				minetest.show_formspec(pname, "npc:food_shop",
					build_food_formspec(npc_name, coins))
			else
				minetest.show_formspec(pname, "npc:shop",
					build_shop_formspec(npc_name, coins))
			end
		end)

		-- Don't deal damage to NPC
		return true
	end,

	on_step = function(self, dtime)
		-- Turn to face the nearest player
		local pos = self.object:get_pos()
		if not pos then return end

		local nearest = nil
		local nearest_dist = math.huge

		for _, player in ipairs(minetest.get_connected_players()) do
			local ppos = player:get_pos()
			local dist = vector.distance(pos, ppos)
			if dist < nearest_dist then
				nearest = ppos
				nearest_dist = dist
			end
		end

		if nearest then
			local dir = vector.direction(pos, nearest)
			self.object:set_yaw(minetest.dir_to_yaw(dir))
		end
	end,
})

-- Spawn NPCs once (check if already alive to avoid duplicates)
local npc_spawned = false

local function ensure_npcs()
	if npc_spawned then return end
	npc_spawned = true

	minetest.after(1, function()
		-- Only spawn if not already alive
		local ref_w = npc._refs["Wapenverkoper"]
		if not ref_w or not ref_w:get_pos() then
			npc.spawn_npc(vector.new(14, 1.5, 0.8), "Wapenverkoper", "npc_wapenverkoper.png")
		end
		local ref_e = npc._refs["Eetverkoper"]
		if not ref_e or not ref_e:get_pos() then
			npc.spawn_npc(vector.new(10, 1.5, 1), "Eetverkoper", "npc_eetverkoper.png")
		end
	end)
end

minetest.register_on_joinplayer(function(player)
	ensure_npcs()
end)

-- Shop formspec handler
local SHOP_ITEMS = {
	buy_sword_wood    = {item = "registered:sword_wood",    price = 5,  name = "Houten Zwaard"},
	buy_sword_steel   = {item = "registered:sword_steel",   price = 15, name = "Stalen Zwaard"},
	buy_sword_bronze  = {item = "registered:sword_bronze",  price = 25, name = "Bronzen Zwaard"},
	buy_fanta_bazooka = {item = "registered:fanta_bazooka", price = 10, name = "Fanta Bazooka"},
}

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "npc:shop" then return end

	local pname = player:get_player_name()
	local meta = player:get_meta()
	local coins = meta:get_int("coins")

	for field, info in pairs(SHOP_ITEMS) do
		if fields[field] then
			if coins >= info.price then
				local inv = player:get_inventory()
				if inv:room_for_item("main", info.item) then
					inv:add_item("main", info.item)
					coins = coins - info.price
					meta:set_int("coins", coins)
					minetest.chat_send_player(pname,
						"Je hebt " .. info.name .. " gekocht! Munten over: " .. coins)
				else
					minetest.chat_send_player(pname, "Je inventaris is vol!")
				end
			else
				minetest.chat_send_player(pname,
					"Niet genoeg munten! Je hebt " .. coins .. ", maar " .. info.name .. " kost " .. info.price .. ".")
			end
			-- Re-show formspec with updated balance (don't close)
			minetest.show_formspec(pname, "npc:shop", build_shop_formspec("Wapenverkoper", coins))
			return true
		end
	end
end)

-- Food shop formspec handler
local FOOD_ITEMS = {
	buy_apple = {item = "registered:apple",  price = 2, name = "Appel"},
	buy_bread = {item = "registered:bread",  price = 4, name = "Brood"},
	buy_fish  = {item = "registered:fish",   price = 6, name = "Vis"},
	buy_meat  = {item = "registered:meat",   price = 8, name = "Vlees"},
}

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "npc:food_shop" then return end

	local pname = player:get_player_name()
	local meta = player:get_meta()
	local coins = meta:get_int("coins")

	for field, info in pairs(FOOD_ITEMS) do
		if fields[field] then
			if coins >= info.price then
				local inv = player:get_inventory()
				if inv:room_for_item("main", info.item) then
					inv:add_item("main", info.item)
					coins = coins - info.price
					meta:set_int("coins", coins)
					minetest.chat_send_player(pname,
						"Je hebt " .. info.name .. " gekocht! Munten over: " .. coins)
				else
					minetest.chat_send_player(pname, "Je inventaris is vol!")
				end
			else
				minetest.chat_send_player(pname,
					"Niet genoeg munten! Je hebt " .. coins .. ", maar " .. info.name .. " kost " .. info.price .. ".")
			end
			-- Re-show formspec with updated balance (don't close)
			minetest.show_formspec(pname, "npc:food_shop", build_food_formspec("Eetverkoper", coins))
			return true
		end
	end
end)

dofile(minetest.get_modpath("npc") .. "/teachers.lua")
