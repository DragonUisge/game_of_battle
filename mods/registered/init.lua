-- registered: node and item definitions for game_of_battle

-- Sound helpers
local function sound_stone()
	return {
		footstep = {name = "default_hard_footstep", gain = 0.3},
		place = {name = "default_place_node_hard", gain = 1.0},
		dug = {name = "default_dug_node", gain = 0.5},
	}
end

local function sound_glass()
	return {
		footstep = {name = "default_glass_footstep", gain = 0.3},
		place = {name = "default_place_node_hard", gain = 1.0},
		dug = {name = "default_break_glass", gain = 1.0},
	}
end

-- Stone
minetest.register_node("registered:stone", {
	description = "Stone",
	tiles = {"default_stone.png"},
	groups = {cracky = 3, stone = 1, oddly_breakable_by_hand = 3},
	sounds = sound_stone(),
})

-- Diamond Block
minetest.register_node("registered:diamondblock", {
	description = "Diamond Block",
	tiles = {"default_diamond_block.png"},
	is_ground_content = false,
	groups = {cracky = 1, level = 3},
	sounds = sound_stone(),
})

-- Glass
minetest.register_node("registered:glass", {
	description = "Glass",
	tiles = {"default_glass.png"},
	drawtype = "glasslike",
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = {cracky = 3, oddly_breakable_by_hand = 3},
	sounds = sound_glass(),
	use_texture_alpha = "clip",
})

-- Mese Lamp
minetest.register_node("registered:meselamp", {
	description = "Mese Lamp",
	drawtype = "glasslike",
	tiles = {"default_meselamp.png"},
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = {cracky = 3, oddly_breakable_by_hand = 3},
	sounds = sound_glass(),
	light_source = minetest.LIGHT_MAX,
})

-- Aliases so the .mts schematic (which uses default: names) resolves correctly
minetest.register_alias("default:stone", "registered:stone")
minetest.register_alias("default:diamondblock", "registered:diamondblock")
minetest.register_alias("default:glass", "registered:glass")
minetest.register_alias("default:meselamp", "registered:meselamp")

-- Swords

minetest.register_tool("registered:sword_wood", {
	description = "Houten Zwaard",
	inventory_image = "registered_sword_wood.png",
	tool_capabilities = {
		full_punch_interval = 1.0,
		max_drop_level = 0,
		damage_groups = {fleshy = 3},
	},
})

minetest.register_tool("registered:sword_steel", {
	description = "Stalen Zwaard",
	inventory_image = "registered_sword_steel.png",
	tool_capabilities = {
		full_punch_interval = 0.8,
		max_drop_level = 1,
		damage_groups = {fleshy = 5},
	},
})

minetest.register_tool("registered:sword_bronze", {
	description = "Bronzen Zwaard",
	inventory_image = "registered_sword_bronze.png",
	tool_capabilities = {
		full_punch_interval = 0.8,
		max_drop_level = 1,
		damage_groups = {fleshy = 6},
	},
})

minetest.register_tool("registered:sword_fire", {
	description = "Vuurzwaard",
	inventory_image = "registered_sword_fire.png",
	_fire_sword = true,
	tool_capabilities = {
		full_punch_interval = 0.6,
		max_drop_level = 2,
		damage_groups = {fleshy = 30},
	},
})

minetest.register_tool("registered:sword_diamond", {
	description = "Diamanten Zwaard",
	inventory_image = "registered_sword_diamond.png",
	tool_capabilities = {
		full_punch_interval = 0.5,
		max_drop_level = 2,
		damage_groups = {fleshy = 40},
	},
})

minetest.register_tool("registered:sword_ancient", {
	description = "Oud Zwaard",
	inventory_image = "registered_sword_ancient.png",
	tool_capabilities = {
		full_punch_interval = 0.5,
		max_drop_level = 3,
		damage_groups = {fleshy = 50},
	},
	on_secondary_use = function(itemstack, user, pointed_thing)
		if not user:is_player() then return end
		local pos = user:get_pos()
		pos.y = pos.y + 1.4
		local yaw   = user:get_look_horizontal()
		local pitch = user:get_look_vertical()
		for i = 1, 5 do
			local sy = yaw   + (math.random() - 0.5) * math.pi * 0.5
			local sp = pitch + (math.random() - 0.5) * 0.35
			local dir = vector.new(
				-math.sin(sy) * math.cos(sp),
				-math.sin(sp),
				-math.cos(sy) * math.cos(sp)
			)
			local speed = 22 + math.random() * 12
			local raisin = minetest.add_entity(pos, "boss:raisin")
			if raisin then
				raisin:set_velocity(vector.multiply(dir, speed))
				local ent = raisin:get_luaentity()
				if ent then ent._owner = user:get_player_name() end
			end
		end
		return itemstack
	end,
})

minetest.register_tool("registered:sword_dragonpower", {
	description = "Strijdbijl van Drakenkracht",
	inventory_image = "registered_sword_dragonpower.png",
	tool_capabilities = {
		full_punch_interval = 0.4,
		max_drop_level = 3,
		damage_groups = {fleshy = 190},
	},
})

minetest.register_tool("registered:sword_elements", {
	description = "Zwaard van Vier Elementen",
	inventory_image = "registered_sword_elements.png",
	tool_capabilities = {
		full_punch_interval = 0.3,
		max_drop_level = 4,
		damage_groups = {fleshy = 80},
	},
})

minetest.register_craftitem("registered:drumstick", {
	description = "Trommelstok",
	inventory_image = "registered_sword_bronze.png^[colorize:#4A2000:200",
})

-- Food items

minetest.register_craftitem("registered:meat", {
	description = "Vlees",
	inventory_image = "registered_meat.png",
	on_use = minetest.item_eat(10),
})

minetest.register_craftitem("registered:fish", {
	description = "Vis",
	inventory_image = "registered_fish.png",
	on_use = minetest.item_eat(7),
})

minetest.register_craftitem("registered:bread", {
	description = "Brood",
	inventory_image = "registered_bread.png",
	on_use = minetest.item_eat(5),
})

minetest.register_craftitem("registered:apple", {
	description = "Appel",
	inventory_image = "registered_apple.png",
	on_use = minetest.item_eat(3),
})
