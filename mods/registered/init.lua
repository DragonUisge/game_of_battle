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

-- Wood planks
local function sound_wood()
	return {
		footstep = {name = "default_wood_footstep", gain = 0.3},
		place    = {name = "default_place_node",      gain = 1.0},
		dug      = {name = "default_dug_node",        gain = 0.5},
	}
end

minetest.register_node("registered:wood", {
	description = "Houten Plank",
	tiles = {"default_wood.png"},
	groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 3, wood = 1},
	sounds = sound_wood(),
})

-- ── Schedule Computer ──────────────────────────────────────────────────────
-- Right-click opens the school timetable editor.
-- Changes break times (when student waves spawn) and subject assignments.

local function schedule_formspec()
	local S    = enemy and enemy.SUBJECTS or
		{"Frans","Latijn","Engels","Aardrijkskunde","Natuurkunde",
		 "Wiskunde","Tekenen","Muziek","Nederlands","Biologie"}
	local sched = (enemy and enemy.schedule) or
		{"Wiskunde","Nederlands","Engels","Aardrijkskunde","Latijn","Frans","Muziek"}
	local bt   = (enemy and enemy.break_times) or
		{{h=10,m=10,lesson=nil},{h=12,m=10,lesson=nil},{h=14,m=15,lesson=nil}}

	local subj_str = table.concat(S, ",")

	local function subj_idx(name)
		for i, s in ipairs(S) do if s == name then return i end end
		return 1
	end

	-- Dropdown options for break slots: "Pauze" first, then all subjects
	local break_options = "Pauze," .. subj_str

	-- Index of a break slot choice (1 = Pauze, 2+ = subject index+1)
	local function break_choice_idx(bdata)
		if not bdata.lesson then return 1 end
		for i, s in ipairs(S) do
			if s == bdata.lesson then return i + 1 end
		end
		return 1
	end

	-- Generate one period row: time label + subject dropdown
	local function period_row(n, label, y)
		return string.format(
			"label[0.4,%.2f;%s]"..
			"dropdown[3.2,%.2f;6.0,0.6;subj%d;%s;%d]",
			y, label, y - 0.1, n, subj_str, subj_idx(sched[n] or S[1])
		)
	end

	-- Generate one break row: coloured bar + lesson/pauze dropdown + time fields
	local function break_row(bn, label, y)
		return string.format(
			"box[0.2,%.2f;11.6,0.62;#3d1010]"..
			"label[0.4,%.2f;⚡ %s]"..
			"dropdown[3.2,%.2f;3.5,0.6;brtype%d;%s;%d]"..
			"label[6.8,%.2f;om:]"..
			"field[7.5,%.2f;1.3,0.55;br%dh;;%02d]"..
			"label[8.85,%.2f;:]"..
			"field[9.05,%.2f;1.3,0.55;br%dm;;%02d]",
			y,
			y + 0.12, label,
			y - 0.1, bn, break_options, break_choice_idx(bt[bn]),
			y + 0.12,
			y + 0.02, bn, bt[bn].h,
			y + 0.12,
			y + 0.02, bn, bt[bn].m
		)
	end

	return
		"formspec_version[4]"..
		"size[12,10.8]"..
		"no_prepend[]"..
		"bgcolor[#111122;true;#0d0d1f]"..
		-- Title bar
		"box[0.2,0.2;11.6,0.55;#1a2a5a]"..
		"label[0.4,0.38;⚙  Schoolrooster — Barlaeus klassen]"..
		-- Column headers
		"label[0.4,1.1;Uur]"..
		"label[3.2,1.1;Vak]"..
		-- Periods 1-2, Pauze 1, Periods 3-4, Pauze 2, Periods 5-6, Pauze 3, Period 7
		period_row(1, "08:00 – 09:00", 1.65)..
		period_row(2, "09:00 – 10:00", 2.45)..
		break_row(1, "Pauze 1  (Golf 1)", 3.15)..
		period_row(3, "10:10 – 11:10", 3.95)..
		period_row(4, "11:10 – 12:10", 4.75)..
		break_row(2, "Pauze 2  (Golf 2)", 5.45)..
		period_row(5, "12:10 – 13:10", 6.25)..
		period_row(6, "13:10 – 14:10", 7.05)..
		break_row(3, "Pauze 3  (Golf 3)", 7.75)..
		period_row(7, "14:15 – 15:00", 8.55)..
		-- Save
		"button_exit[4.0,9.5;4.0,0.7;save;💾 Opslaan]"
end

minetest.register_node("registered:cobble", {
	description = "Computer (Schoolrooster)",
	tiles = {
		"default_steel_block.png",
		"default_steel_block.png",
		"default_steel_block.png^[colorize:#222222:160",
	},
	paramtype2 = "facedir",
	groups = {cracky = 2, oddly_breakable_by_hand = 1},
	sounds = sound_stone(),
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		if not clicker:is_player() then return end
		minetest.show_formspec(clicker:get_player_name(),
			"schedule_computer", schedule_formspec())
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "schedule_computer" then return end
	if not fields.save then return end
	if not (enemy and enemy.break_times and enemy.schedule) then return end

	local S = enemy.SUBJECTS

	-- Update subject schedule
	for i = 1, 7 do
		local v = fields["subj" .. i]
		if v and v ~= "" then enemy.schedule[i] = v end
	end

	-- Update break times + lesson choice
	local function parse_int(s, default)
		local n = tonumber(s)
		return (n and math.floor(n)) or default
	end
	for bn = 1, 3 do
		local bh = parse_int(fields["br" .. bn .. "h"], enemy.break_times[bn].h)
		local bm = parse_int(fields["br" .. bn .. "m"], enemy.break_times[bn].m)
		bh = math.max(0, math.min(23, bh))
		bm = math.max(0, math.min(59, bm))
		-- brtype: "Pauze" = real break, anything else = lesson (no wave)
		local chosen = fields["brtype" .. bn]
		local lesson_val = nil
		if chosen and chosen ~= "Pauze" and chosen ~= "" then
			lesson_val = chosen
		end
		enemy.break_times[bn] = {h = bh, m = bm, lesson = lesson_val}
	end

	-- Allow new break times to fire even if the minute already passed
	if enemy.refresh_schedule then enemy.refresh_schedule() end

	-- ── Teinetarnagh reaction ──────────────────────────────────────────────
	-- If the victory Dragon is alive, he grabs the player, flies them back
	-- to arena 1, resets the schedule, then disappears.
	if boss and boss._victory_dragon_obj then
		local vobj = boss._victory_dragon_obj
		if vobj:get_pos() then
			-- Reset schedule to defaults first
			for i = 1, 7 do
				enemy.schedule[i] = enemy.DEFAULT_SCHEDULE[i]
			end
			for bn = 1, 3 do
				local d = enemy.DEFAULT_BREAK_TIMES[bn]
				enemy.break_times[bn] = {h = d.h, m = d.m, lesson = nil}
			end
			-- Do NOT call refresh_schedule() here — resetting last_check_time
			-- would immediately re-trigger a break and restart the BGM.

			-- Broadcast warning
			minetest.chat_send_player(player:get_player_name(),
				"[Teinetarnagh] Wat denk jij dat je doet? " ..
				"Dit rooster staat al eeuwen vast. Ik breng je terug.")

			-- Carry the player back to arena 1
			boss.return_player(player)
			return
		end
	end

	local pname = player:get_player_name()
	minetest.chat_send_player(pname,
		"[Rooster] Wijzigingen opgeslagen. "..
		"Pauzes: "..
		string.format("%02d:%02d", enemy.break_times[1].h, enemy.break_times[1].m).." / "..
		string.format("%02d:%02d", enemy.break_times[2].h, enemy.break_times[2].m).." / "..
		string.format("%02d:%02d", enemy.break_times[3].h, enemy.break_times[3].m)
	)
end)

-- Aliases so the .mts schematic (which uses default: names) resolves correctly
minetest.register_alias("default:stone",       "registered:stone")
minetest.register_alias("default:diamondblock","registered:diamondblock")
minetest.register_alias("default:glass",       "registered:glass")
minetest.register_alias("default:meselamp",    "registered:meselamp")
minetest.register_alias("default:wood",        "registered:wood")
minetest.register_alias("default:cobble",      "registered:cobble")

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
