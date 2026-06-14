-- registered: node and item definitions for game_of_battle

-- Sound helpers
local function sound_stone()
	return {
		footstep = { name = "default_hard_footstep", gain = 0.3 },
		place = { name = "default_place_node_hard", gain = 1.0 },
		dug = { name = "default_dug_node", gain = 0.5 },
	}
end

local function sound_glass()
	return {
		footstep = { name = "default_glass_footstep", gain = 0.3 },
		place = { name = "default_place_node_hard", gain = 1.0 },
		dug = { name = "default_break_glass", gain = 1.0 },
	}
end

-- Stone
minetest.register_node("registered:stone", {
	description = "Stone",
	tiles = { "default_stone.png" },
	groups = { cracky = 3, stone = 1, oddly_breakable_by_hand = 3 },
	sounds = sound_stone(),
})

-- Diamond Block
minetest.register_node("registered:diamondblock", {
	description = "Diamond Block",
	tiles = { "default_diamond_block.png" },
	is_ground_content = false,
	groups = { cracky = 1, level = 3 },
	sounds = sound_stone(),
})

-- Glass
minetest.register_node("registered:glass", {
	description = "Glass",
	tiles = { "default_glass.png" },
	drawtype = "glasslike",
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = { cracky = 3, oddly_breakable_by_hand = 3 },
	sounds = sound_glass(),
	use_texture_alpha = "clip",
})

-- Mese Lamp
minetest.register_node("registered:meselamp", {
	description = "Mese Lamp",
	drawtype = "glasslike",
	tiles = { "default_meselamp.png" },
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = { cracky = 3, oddly_breakable_by_hand = 3 },
	sounds = sound_glass(),
	light_source = minetest.LIGHT_MAX,
})

-- Wood planks
local function sound_wood()
	return {
		footstep = { name = "default_wood_footstep", gain = 0.3 },
		place    = { name = "default_place_node", gain = 1.0 },
		dug      = { name = "default_dug_node", gain = 0.5 },
	}
end

minetest.register_node("registered:wood", {
	description = "Houten Plank",
	tiles = { "default_wood.png" },
	groups = { choppy = 3, oddly_breakable_by_hand = 2, flammable = 3, wood = 1 },
	sounds = sound_wood(),
})

minetest.register_node("registered:bed", {
    description = "Bed",
	tiles = "registered_bed.png",
	groups = {choppy = 2, flammable = 3, wood = 1},
	sounds = sound_wood()
})

-- ── Schedule Computer ──────────────────────────────────────────────────────
-- Right-click opens the school timetable editor.
-- Changes break times (when student waves spawn) and subject assignments.

local function schedule_formspec()
	local S        = enemy and enemy.SUBJECTS or
		{ "Frans", "Latijn", "Engels", "Aardrijkskunde", "Natuurkunde",
			"Wiskunde", "Tekenen", "Muziek", "Nederlands", "Biologie" }
	local sched    = (enemy and enemy.schedule) or
		{ "Wiskunde", "Nederlands", "Engels", "Aardrijkskunde", "Latijn", "Frans", "Muziek" }
	local bt       = (enemy and enemy.break_times) or
		{ { h = 10, m = 10, lesson = nil }, { h = 12, m = 10, lesson = nil }, { h = 14, m = 15, lesson = nil } }

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
			"label[0.4,%.2f;%s]" ..
			"dropdown[3.2,%.2f;6.0,0.6;subj%d;%s;%d]",
			y, label, y - 0.1, n, subj_str, subj_idx(sched[n] or S[1])
		)
	end

	-- Generate one break row: coloured bar + lesson/pauze dropdown + time fields
	local function break_row(bn, label, y)
		return string.format(
			"box[0.2,%.2f;11.6,0.62;#3d1010]" ..
			"label[0.4,%.2f;⚡ %s]" ..
			"dropdown[3.2,%.2f;3.5,0.6;brtype%d;%s;%d]" ..
			"label[6.8,%.2f;om:]" ..
			"field[7.5,%.2f;1.3,0.55;br%dh;;%02d]" ..
			"label[8.85,%.2f;:]" ..
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
		"formspec_version[4]" ..
		"size[12,10.8]" ..
		"no_prepend[]" ..
		"bgcolor[#111122;true;#0d0d1f]" ..
		-- Title bar
		"box[0.2,0.2;11.6,0.55;#1a2a5a]" ..
		"label[0.4,0.38;⚙  Schoolrooster — Barlaeus klassen]" ..
		-- Column headers
		"label[0.4,1.1;Uur]" ..
		"label[3.2,1.1;Vak]" ..
		-- Periods 1-2, Pauze 1, Periods 3-4, Pauze 2, Periods 5-6, Pauze 3, Period 7
		period_row(1, "08:00 – 09:00", 1.65) ..
		period_row(2, "09:00 – 10:00", 2.45) ..
		break_row(1, "Pauze 1  (Golf 1)", 3.15) ..
		period_row(3, "10:10 – 11:10", 3.95) ..
		period_row(4, "11:10 – 12:10", 4.75) ..
		break_row(2, "Pauze 2  (Golf 2)", 5.45) ..
		period_row(5, "12:10 – 13:10", 6.25) ..
		period_row(6, "13:10 – 14:10", 7.05) ..
		break_row(3, "Pauze 3  (Golf 3)", 7.75) ..
		period_row(7, "14:15 – 15:00", 8.55) ..
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
	groups = { cracky = 2, oddly_breakable_by_hand = 1 },
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
		enemy.break_times[bn] = { h = bh, m = bm, lesson = lesson_val }
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
				enemy.break_times[bn] = { h = d.h, m = d.m, lesson = nil }
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
		"[Rooster] Wijzigingen opgeslagen. " ..
		"Pauzes: " ..
		string.format("%02d:%02d", enemy.break_times[1].h, enemy.break_times[1].m) .. " / " ..
		string.format("%02d:%02d", enemy.break_times[2].h, enemy.break_times[2].m) .. " / " ..
		string.format("%02d:%02d", enemy.break_times[3].h, enemy.break_times[3].m)
	)
end)

-- Aliases so the .mts schematic (which uses default: names) resolves correctly
minetest.register_alias("default:stone", "registered:stone")
minetest.register_alias("default:diamondblock", "registered:diamondblock")
minetest.register_alias("default:glass", "registered:glass")
minetest.register_alias("default:meselamp", "registered:meselamp")
minetest.register_alias("default:wood", "registered:wood")
minetest.register_alias("default:cobble", "registered:cobble")

-- Mapgen aliases (suppress Luanti mapgen warnings)
minetest.register_alias("mapgen_stone", "registered:stone")
minetest.register_node("registered:water_source", {
	description = "Water",
	drawtype = "liquid",
	tiles = { "default_water.png" },
	special_tiles = { "default_water.png" },
	use_texture_alpha = "blend",
	paramtype = "light",
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	is_ground_content = false,
	liquidtype = "source",
	liquid_alternative_flowing = "registered:water_source",
	liquid_alternative_source = "registered:water_source",
	liquid_viscosity = 1,
	post_effect_color = { a = 103, r = 30, g = 60, b = 90 },
	groups = { water = 3, liquid = 3 },
})
minetest.register_alias("mapgen_water_source", "registered:water_source")

-- Dry grass aliases (suppress NodeResolver warnings)
for i = 1, 5 do
	minetest.register_alias("default:dry_grass_" .. i, "air")
end

-- Swords

minetest.register_tool("registered:sword_wood", {
	description = "Houten Zwaard",
	inventory_image = "registered_sword_wood.png",
	tool_capabilities = {
		full_punch_interval = 1.0,
		max_drop_level = 0,
		damage_groups = { fleshy = 3 },
	},
})

minetest.register_tool("registered:sword_steel", {
	description = "Stalen Zwaard",
	inventory_image = "registered_sword_steel.png",
	tool_capabilities = {
		full_punch_interval = 0.8,
		max_drop_level = 1,
		damage_groups = { fleshy = 5 },
	},
})

minetest.register_tool("registered:sword_bronze", {
	description = "Bronzen Zwaard",
	inventory_image = "registered_sword_bronze.png",
	tool_capabilities = {
		full_punch_interval = 0.8,
		max_drop_level = 1,
		damage_groups = { fleshy = 6 },
	},
})

minetest.register_tool("registered:sword_fire", {
	description = "Vuurzwaard",
	inventory_image = "registered_sword_fire.png",
	_fire_sword = true,
	tool_capabilities = {
		full_punch_interval = 0.6,
		max_drop_level = 2,
		damage_groups = { fleshy = 30 },
	},
})

minetest.register_tool("registered:sword_diamond", {
	description = "Diamanten Zwaard",
	inventory_image = "registered_sword_diamond.png",
	tool_capabilities = {
		full_punch_interval = 0.5,
		max_drop_level = 2,
		damage_groups = { fleshy = 40 },
	},
})

minetest.register_tool("registered:sword_ancient", {
	description = "Oud Zwaard",
	inventory_image = "registered_sword_ancient.png",
	tool_capabilities = {
		full_punch_interval = 0.5,
		max_drop_level = 3,
		damage_groups = { fleshy = 50 },
	},
	on_secondary_use = function(itemstack, user, pointed_thing)
		if not user:is_player() then return end
		local pos   = user:get_pos()
		pos.y       = pos.y + 1.4
		local yaw   = user:get_look_horizontal()
		local pitch = user:get_look_vertical()
		for i = 1, 5 do
			local sy = yaw + (math.random() - 0.5) * math.pi * 0.5
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
		damage_groups = { fleshy = 190 },
		wield_scale = { x = 2.0, y = 2.0, z = 2.0 },
	},
})

-- Глобальный список всех брошенных конфет в мире для поиска студентами
active_skittles = {}

-- Функция спавна 3 летящих конфет при броске (с разбросом)
local function skittles_shoot(itemstack, user, pointed_thing)
	if not user or not user:is_player() then return itemstack end
	local pname = user:get_player_name()
	local pos = user:get_pos()
	if not pos then return itemstack end

	-- Проверяем, сколько конфет есть в руке (бросаем 3, но если осталась 1 или 2 — бросаем сколько есть)
	local current_count = itemstack:get_count()
	local to_throw = math.min(current_count, 3)
	if to_throw <= 0 then return itemstack end

	-- Корректируем высоту спавна под глаза игрока
	pos.y = pos.y + 1.5
	local dir = user:get_look_dir()
	local speed = 27

	-- Цикл для спавна нужного количества конфет
	for i = 1, to_throw do
		-- Добавляем случайный разброс по осям X, Y, Z, чтобы конфеты летели веером
		local spread_dir = vector.new(
			dir.x + (math.random() - 0.5) * 0.25,
			dir.y + (math.random() - 0.5) * 0.25,
			dir.z + (math.random() - 0.5) * 0.25
		)
		-- Нормализуем вектор, чтобы скорость броска оставалась одинаковой
		spread_dir = vector.normalize(spread_dir)

		local drag = minetest.add_entity(pos, "registered:skittles")
		if drag then
			drag:set_velocity(vector.multiply(spread_dir, speed))
			local ent = drag:get_luaentity()
			if ent then
				ent._owner = pname
			end
		end
	end

	-- Забираем ровно столько штук, сколько было выпущено
	itemstack:take_item(1)

	-- Звук броска
	minetest.sound_play("default_place_node_hard",
		{ pos = pos, gain = 0.5, max_hear_distance = 15 })

	return itemstack
end
-- Регистрация самого предмета "Конфета skittles" в инвентаре
minetest.register_craftitem("registered:skittles", {
	description = "skittles",
	inventory_image = "registered_skittles.png",
	stack_max = 99,
	on_secondary_use = skittles_shoot,
	on_place = skittles_shoot,
})

-- Регистрация летящей/лежащей на полу сущности skittles
minetest.register_entity("registered:skittles", {
	initial_properties = {
		visual               = "sprite",
		visual_size          = { x = 0.3, y = 0.3, z = 0.3 },
		textures             = { "registered_skittles.png" },
		physical             = true,
		collide_with_objects = false,
		collisionbox         = { -0.15, -0.15, -0.15, 0.15, 0.15, 0.15 },
		static_save          = false,
		pointable            = false,
	},

	_lifetime = 0,
	_landed   = false,

	on_step = function(self, dtime, moveresult)
		self._lifetime = self._lifetime + dtime

		-- Защита от вечного лежания (удаляем через 11 секунд на всякий случай)
		if self._lifetime > 11 then
			local pos = self.object:get_pos()
			for i, d in ipairs(active_skittles) do
				if d == self.object then
					table.remove(active_skittles, i)
					break
				end
			end
			-- 2. Spawn new student(s)
			if pos then
				local new_student = minetest.add_entity(pos, "enemy:student")
				if new_student then
					local ent = new_student:get_luaentity()
					if ent then
						-- Wave
						ent._level = (enemy and enemy.current_level) or 1
					end
					
					-- White particles
					minetest.add_particlespawner({
						amount = 15,
						time = 0.2,
						minpos = vector.add(pos, vector.new(-0.3, 0, -0.3)),
						maxpos = vector.add(pos, vector.new(0.3, 1.0, 0.3)),
						minvel = vector.new(-1, 1, -1),
						maxvel = vector.new(1, 3, 1),
						texture = "water_particle.png",
						glow = 10,
					})
				end
			end
			self.object:remove()
			return
		end

		-- Проверка приземления на блок
		if not self._landed and moveresult and moveresult.collisions then
			for _, col in ipairs(moveresult.collisions) do
				if col.type == "node" then
					self._landed = true
					self.object:set_velocity(vector.new(0, 0, 0))
					self.object:set_acceleration(vector.new(0, 0, 0))
					-- Добавляем в глобальный список, чтобы студенты её увидели
					table.insert(active_skittles, self.object)
					break
				end
			end
		end
	end,
})

-- ══════════════════════════════════════════════════════════════
-- Sword of Four Elements — states: ijs / vuur / water / wind
-- Sneak + Rightclick cycles to the next element.
-- Ice (ijs)  : punch freezes the enemy inside freeze_ent.
-- Fire (vuur): punch spawns fire particles (like sword_fire).
-- Water / Wind: abilities to be implemented later.
-- ══════════════════════════════════════════════════════════════

local ELEMENTS_NEXT  = { ice = "fire", fire = "water", water = "wind", wind = "nothing", nothing = "ice" }
local ELEMENTS_ITEM  = {
	ice     = "registered:sword_elements_ice",
	fire    = "registered:sword_elements_fire",
	water   = "registered:sword_elements_water",
	wind    = "registered:sword_elements_wind",
	nothing = "registered:sword_elements",
}
local ELEMENTS_LABEL = { ice = "Ijs", fire = "Vuur", water = "Water", wind = "Wind", nothing = "Geen" }

local function elements_cycle(itemstack, user)
	if not user or not user:is_player() then return itemstack end
	if not user:get_player_control().sneak then return itemstack end
	local name = itemstack:get_name()
	local cur  = name:match("sword_elements_?(.*)$") or ""
	if cur == "" then cur = "nothing" end
	local nxt   = ELEMENTS_NEXT[cur] or "fire"
	local count = itemstack:get_count()
	itemstack   = ItemStack(ELEMENTS_ITEM[nxt])
	itemstack:set_count(count)
	minetest.chat_send_player(user:get_player_name(),
		"Element: " .. ELEMENTS_LABEL[nxt])
	return itemstack
end

local ELEMENTS_CAPS = {
	full_punch_interval = 0.3,
	max_drop_level = 4,
	damage_groups = { fleshy = 80 },
}

-- ══════════════════════════════════════════════════════════════
-- Water Ball — projectile fired by the water element sword (LMB).
-- Travels in the look direction. On contact: darkens the enemy
-- (wet overlay), deals 10 damage, disappears. Leaves droplets.
-- ══════════════════════════════════════════════════════════════

local function water_splash(pos)
	minetest.add_particlespawner({
		amount = 24,
		time = 0.3,
		minpos = vector.add(pos, vector.new(-0.4, -0.4, -0.4)),
		maxpos = vector.add(pos, vector.new(0.4, 0.4, 0.4)),
		minvel = vector.new(-5, 1, -5),
		maxvel = vector.new(5, 6, 5),
		minacc = vector.new(0, -9, 0),
		maxacc = vector.new(0, -6, 0),
		minexptime = 0.25,
		maxexptime = 0.7,
		minsize = 2,
		maxsize = 5,
		texture = "water_particle.png^[colorize:#4488FF:200",
		glow = 8,
	})
	minetest.sound_play("elements_sword_water",
		{ pos = pos, gain = 1, max_hear_distance = 20 })
end

minetest.register_entity("registered:water_ball", {
	initial_properties = {
		visual               = "cube",
		visual_size          = { x = 0.45, y = 0.45, z = 0.45 },
		textures             = {
			"water_particle.png^[colorize:#03b1fc:180",
			"water_particle.png^[colorize:#03b1fc:180",
			"water_particle.png^[colorize:#03b1fc:180",
			"water_particle.png^[colorize:#03b1fc:180",
			"water_particle.png^[colorize:#03b1fc:180",
			"water_particle.png^[colorize:#03b1fc:180",
		},
		physical             = true,
		collide_with_objects = false,
		collisionbox         = { -0.18, -0.18, -0.18, 0.18, 0.18, 0.18 },
		static_save          = false,
		pointable            = false,
		use_texture_alpha    = true,
		glow                 = 10,
	},

	_owner             = nil,
	_lifetime          = 0,
	_hit               = false,

	on_activate        = function(self)
		self.object:set_armor_groups({ immortal = 1 })
	end,

	on_step            = function(self, dtime, moveresult)
		if self._hit then return end
		local pos = self.object:get_pos()
		if not pos then return end

		self._lifetime = self._lifetime + dtime

		-- Auto-remove after 5 s
		if self._lifetime > 5 then
			water_splash(pos)
			self._hit = true
			self.object:remove()
			return
		end

		-- Trailing droplet particles
		if math.fmod(self._lifetime, 0.07) < dtime then
			minetest.add_particlespawner({
				amount = 5,
				time = 0.1,
				minpos = vector.add(pos, vector.new(-0.12, -0.12, -0.12)),
				maxpos = vector.add(pos, vector.new(0.12, 0.12, 0.12)),
				minvel = vector.new(-0.4, -0.4, -0.4),
				maxvel = vector.new(0.4, 0.4, 0.4),
				minacc = vector.new(0, -3, 0),
				maxacc = vector.new(0, -1, 0),
				minexptime = 0.15,
				maxexptime = 0.4,
				minsize = 1,
				maxsize = 3,
				texture = "water_particle.png^[colorize:#03b1fc:200",
				glow = 8,
			})
		end

		-- Node (wall / floor / ceiling) collision
		if moveresult and moveresult.collisions then
			for _, col in ipairs(moveresult.collisions) do
				if col.type == "node" then
					water_splash(pos)
					self._hit = true
					self.object:remove()
					return
				end
			end
		end

		-- Object collision (entities and other players)
		if self._lifetime > 0.1 then
			for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 0.9)) do
				if obj == self.object then
					-- skip self
				elseif obj:is_player() then
					local pname = obj:get_player_name()
					if not self._owner or pname ~= self._owner then
						obj:set_hp(math.max(0, obj:get_hp() - 10), { type = "punch" })
						water_splash(pos)
						self._hit = true
						self.object:remove()
						return
					end
				else
					local ent = obj:get_luaentity()
					if ent and ent._hp
						and ent.name ~= "registered:water_ball"
						and ent.name ~= "registered:freeze_ent"
						and ent.name ~= "registered:wind_clone"
						and ent.name ~= "boss:drumstick_visual" then
						-- Wet-darken the enemy (only once per entity)
						if not ent._wet then
							local props = obj:get_properties()
							if props and props.textures then
								local wet = {}
								for i, t in ipairs(props.textures) do
									wet[i] = t .. "^[colorize:#001133:80"
								end
								obj:set_properties({ textures = wet })
							end
							ent._wet = true
						end
						-- Deal 10 damage
						obj:punch(self.object, 1.0,
							{ full_punch_interval = 1.0, damage_groups = { fleshy = 10 } }, nil)
						water_splash(pos)
						self._hit = true
						self.object:remove()
						return
					end
				end
			end
		end
	end,
})

-- ══════════════════════════════════════════════════════════════
-- Wind Clone — spawned by the wind sword double-jump trick.
-- Mimics the player (same skin, mesh), performs a cinematic
-- jump-flip-to-ceiling sequence, then dissolves.
-- The real player is hidden and attached to the clone during
-- the trick, then detached and restored.
-- ══════════════════════════════════════════════════════════════

-- Per-player double-jump tracking: {last_time, was_pressed, active}
local wind_jump_state = {}

minetest.register_entity("registered:wind_clone", {
	initial_properties = {
		visual      = "mesh",
		mesh        = "character.b3d",
		textures    = { "character.png" },
		visual_size = { x = 1, y = 1, z = 1 },
		physical    = false, -- we drive position/velocity manually
		static_save = false,
		pointable   = false,
	},

	_owner_name        = nil,
	_phase             = "rise", -- rise → tilt → ceiling → hold → vanish
	_timer             = 0,
	_start_yaw         = 0,
	_ceiling_y         = nil, -- world Y of the ceiling block bottom face (set by wind_trigger)

	on_activate        = function(self)
		self.object:set_armor_groups({ immortal = 1 })
		self.object:set_animation({ x = 168, y = 187 }, 30, 0, true)
	end,

	on_step            = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then return end

		self._timer = self._timer + dtime

		local player = self._owner_name and minetest.get_player_by_name(self._owner_name)

		-- Safety: if owner disconnected, clean up quietly
		if not player then
			self.object:remove()
			return
		end

		local yaw = self._start_yaw

		-- Ceiling guard: stop rising as soon as we reach the ceiling block.
		-- Applies to every upward phase so the player can never pass through walls.
		if self._ceiling_y
			and self._phase ~= "hold"
			and self._phase ~= "vanish"
			and pos.y >= self._ceiling_y then
			self.object:set_pos(vector.new(pos.x, self._ceiling_y, pos.z))
			self.object:set_velocity(vector.new(0, 0, 0))
			self.object:set_rotation(vector.new(0, yaw, math.pi))
			self.object:set_animation({ x = 0, y = 79 }, 15, 0, true)
			self._timer = 0
			self._phase = "hold"
		end

		if self._phase == "rise" then
			-- Float upward with walk animation; begin tilting slightly
			self.object:set_velocity(vector.new(0, 9.0, 0))
			local t    = math.min(self._timer / 0.33, 1.0)
			local roll = t * (math.pi * 0.25) -- 0 → 45°
			self.object:set_rotation(vector.new(0, yaw, roll))
			if self._timer >= 0.33 then
				self._timer = 0
				self._phase = "tilt"
				self.object:set_animation({ x = 0, y = 79 }, 15, 0, true)
			end
		elseif self._phase == "tilt" then
			-- Slow rise; tilt from 45° to 90° (fully on its side)
			self.object:set_velocity(vector.new(0, 3.0, 0))
			local t    = math.min(self._timer / 0.28, 1.0)
			local roll = (math.pi * 0.25) + t * (math.pi * 0.25) -- 45° → 90°
			self.object:set_rotation(vector.new(0, yaw, roll))
			if self._timer >= 0.28 then
				self._timer = 0
				self._phase = "ceiling"
			end
		elseif self._phase == "ceiling" then
			-- Flip from side (90°) to fully upside-down (180°) while rising fast
			self.object:set_velocity(vector.new(0, 11.0, 0))
			local t    = math.min(self._timer / 0.23, 1.0)
			local roll = (math.pi * 0.5) + t * (math.pi * 0.5) -- 90° → 180°
			self.object:set_rotation(vector.new(0, yaw, roll))
			if self._timer >= 0.23 then
				self._timer = 0
				self._phase = "hold"
				self.object:set_velocity(vector.new(0, 0, 0))
				self.object:set_rotation(vector.new(0, yaw, math.pi))
			end
		elseif self._phase == "hold" then
			-- Frozen upside-down against the "ceiling" for a beat
			self.object:set_velocity(vector.new(0, 0, 0))
			if self._timer >= 0.25 then
				self._timer = 0
				self._phase = "vanish"
				-- Detach and restore player before entity dissolves
				local cpos = self.object:get_pos()
				player:set_detach()
				if cpos then
					player:set_pos(vector.new(cpos.x, cpos.y - 1.8, cpos.z))
				end
				player:set_properties({ visual_size = { x = 1, y = 1, z = 1 } })
				player:set_velocity(vector.new(0, 0, 0))
				wind_jump_state[self._owner_name] = nil
			end
		elseif self._phase == "vanish" then
			-- Shrink and dissolve with wind-puff particles
			self.object:set_velocity(vector.new(0, 0, 0))
			local t = math.min(self._timer / 0.18, 1.0)
			local s = 1.0 - t
			self.object:set_properties({ visual_size = { x = s, y = s, z = s } })
			if math.fmod(self._timer, 0.09) < dtime then
				minetest.add_particlespawner({
					amount = 8,
					time = 0.1,
					minpos = vector.add(pos, vector.new(-0.5, -0.5, -0.5)),
					maxpos = vector.add(pos, vector.new(0.5, 1.5, 0.5)),
					minvel = vector.new(-3, -2, -3),
					maxvel = vector.new(3, 2, 3),
					minacc = vector.new(0, -1, 0),
					maxacc = vector.new(0, 0, 0),
					minexptime = 0.15,
					maxexptime = 0.45,
					minsize = 1,
					maxsize = 3,
					texture = "aura_particle.png^[colorize:#AADDFF:160",
					glow = 6,
				})
			end
			if self._timer >= 0.35 then
				self.object:remove()
			end
		end
	end,
})

-- Trigger function: hides the player, spawns the clone and attaches player to it.
local function wind_trigger(player)
	local pname     = player:get_player_name()
	local pos       = player:get_pos()

	-- Raycast upward to find the ceiling height.
	-- The entity will stop rising when its feet (origin) reach this Y.
	-- With roll=π the character appears upside-down: its feet are at the
	-- entity origin, so the feet touch the ceiling at ceiling_block.y.
	local ray_from  = vector.new(pos.x, pos.y + 0.3, pos.z)
	local ray_to    = vector.new(pos.x, pos.y + 14, pos.z)
	local ceiling_y = pos.y + 14 -- fallback: no ceiling found within 14 blocks
	local ray       = minetest.raycast(ray_from, ray_to, false, false)
	for pt in ray do
		if pt.type == "node" then
			-- Bottom face of the solid ceiling block; leave 0.05 gap to avoid clipping
			ceiling_y = pt.under.y - 0.05
			break
		end
	end
	-- Always keep at least 2.5 units of vertical room for the animation
	ceiling_y = math.max(ceiling_y, pos.y + 2.5)

	-- Read player's skin texture for accurate clone appearance
	local skin = "character.png"
	local pprops = player:get_properties()
	if pprops and pprops.textures and pprops.textures[1] then
		skin = pprops.textures[1]
	end

	local clone = minetest.add_entity(pos, "registered:wind_clone")
	if not clone then
		wind_jump_state[pname] = nil
		return
	end

	local yaw = player:get_look_horizontal()
	clone:set_yaw(yaw)
	clone:set_properties({ textures = { skin } })

	local ent = clone:get_luaentity()
	if ent then
		ent._owner_name = pname
		ent._start_yaw  = yaw
		ent._ceiling_y  = ceiling_y
	end

	-- Hide player and attach to clone (player sees the world from clone's position)
	player:set_properties({ visual_size = { x = 0, y = 0, z = 0 } })
	player:set_attach(clone, "", vector.new(0, 0.9, 0), vector.new(0, 0, 0))
end

-- Double-jump detector: runs every frame.
-- Fires wind_trigger when the player taps jump twice in < 0.4 s
-- while holding the wind sword.
minetest.register_globalstep(function(dtime)
	for _, player in ipairs(minetest.get_connected_players()) do
		local pname = player:get_player_name()
		local item  = player:get_wielded_item()

		if item:get_name() == "registered:sword_elements_wind" then
			local ctrl = player:get_player_control()
			local st   = wind_jump_state[pname]
			if not st then
				st = { last_time = 0, was_pressed = false, active = false }
				wind_jump_state[pname] = st
			end

			if not st.active then
				local now = minetest.get_us_time() / 1e6
				if ctrl.jump and not st.was_pressed then
					-- Rising edge: jump key just pressed
					st.was_pressed = true
					local gap = now - (st.last_time or 0)
					if gap < 0.4 and gap > 0.05 then
						-- Double-jump confirmed — trigger the wind trick
						st.active = true
						wind_trigger(player)
						minetest.sound_play("elements_sword_wind",
							{ pos = player:get_pos(), gain = 0.5, max_hear_distance = 18 })
					else
						st.last_time = now
					end
				elseif not ctrl.jump then
					st.was_pressed = false
				end
			end
		else
			-- Not holding wind sword: reset state (but don't interrupt active trick)
			local st = wind_jump_state[pname]
			if st and not st.active then
				wind_jump_state[pname] = nil
			end
		end
	end
end)

-- ── registered:freeze_ent ─────────────────────────────────────────────────
-- Visual ice-block that envelops a frozen entity.
-- Spawned by the ice sword on punch. Reads target visual_size and mirrors it.
-- Zeroes the target's velocity every frame. Unfreezes after _duration seconds.
minetest.register_entity("registered:freeze_ent", {
	initial_properties = {
		visual            = "cube",
		visual_size       = { x = 1.2, y = 1.2, z = 1.2 },
		textures          = {
			"freeze_ent.png",
			"freeze_ent.png",
			"freeze_ent.png",
			"freeze_ent.png",
			"freeze_ent.png",
			"freeze_ent.png",
		},
		physical          = false,
		pointable         = false,
		static_save       = false,
		glow              = 12,
		use_texture_alpha = true,
	},

	_target            = nil,
	_timer             = 0,
	_duration          = 3.5,
	_y_off             = 0.7, -- vertical center offset (set by registered_apply_freeze)

	on_activate        = function(self)
		self.object:set_armor_groups({ immortal = 1 })
	end,

	on_step            = function(self, dtime)
		self._timer = self._timer + dtime
		if not self._target or not self._target:get_pos() then
			self.object:remove()
			return
		end
		-- Track target position (offset Y so cube is centered on the entity body)
		local tpos = self._target:get_pos()
		self.object:set_pos(vector.new(tpos.x, tpos.y + self._y_off, tpos.z))
		-- Override velocity to zero every frame
		self._target:set_velocity(vector.new(0, 0, 0))
		-- Ice sparkles
		if math.fmod(self._timer, 0.4) < dtime then
			minetest.add_particlespawner({
				amount = 6,
				time = 0.1,
				minpos = vector.add(tpos, vector.new(-0.6, 0.1, -0.6)),
				maxpos = vector.add(tpos, vector.new(0.6, 1.8, 0.6)),
				minvel = vector.new(-0.3, 0.3, -0.3),
				maxvel = vector.new(0.3, 1.0, 0.3),
				minacc = vector.new(0, -0.5, 0),
				maxacc = vector.new(0, 0, 0),
				minexptime = 0.5,
				maxexptime = 1.0,
				minsize = 1,
				maxsize = 2,
				texture = "aura_particle.png^[colorize:#AADDFF:230",
				glow = 14,
			})
		end
		-- Unfreeze after duration
		if self._timer >= self._duration then
			local ent = self._target:get_luaentity()
			if ent then ent._frozen = false end
			self.object:remove()
		end
	end,
})

-- Helper called from boss/enemy on_punch when the ice sword hits.
-- Spawns a freeze_ent sized to the target and marks it _frozen.
function registered_apply_freeze(target_obj)
	local ent = target_obj:get_luaentity()
	if not ent or ent._frozen then return end
	ent._frozen = true
	local tpos = target_obj:get_pos()
	if not tpos then return end
	local props = target_obj:get_properties()
	-- Use collisionbox for accurate physical size (visual_size is a mesh scale multiplier)
	local cb    = props and props.collisionbox
	local sx, sy, y_off
	if cb and #cb >= 6 then
		sx    = (cb[4] - cb[1]) + 0.2 -- X width + padding
		sy    = (cb[5] - cb[2]) + 0.2 -- Y height + padding
		y_off = cb[2] + (cb[5] - cb[2]) / 2 -- center of box in Y
	else
		sx, sy, y_off = 1.2, 1.4, 0.7
	end
	local fent = minetest.add_entity(tpos, "registered:freeze_ent")
	if fent then
		fent:set_properties({ visual_size = { x = sx, y = sy, z = sx } })
		local fe = fent:get_luaentity()
		if fe then
			fe._target = target_obj
			fe._y_off  = y_off
		end
	end
end

minetest.register_tool("registered:sword_elements", {
	description        = "Zwaard van de Vier Elementen",
	inventory_image    = "registered_sword_elements.png",
	_is_elements_sword = true,
	_elements_state    = "nothing",
	tool_capabilities  = ELEMENTS_CAPS,
	on_secondary_use   = elements_cycle,
	on_place           = elements_cycle,
})

minetest.register_tool("registered:sword_elements_ice", {
	description        = "Zwaard van de Vier Elementen (Ijs)",
	inventory_image    = "registered_sword_ice.png",
	_is_elements_sword = true,
	_elements_state    = "ice",
	tool_capabilities  = ELEMENTS_CAPS,
	on_secondary_use   = elements_cycle,
	on_place           = elements_cycle,
})

minetest.register_tool("registered:sword_elements_fire", {
	description        = "Zwaard van de Vier Elementen (Vuur)",
	inventory_image    = "registered_sword_fire.png",
	_is_elements_sword = true,
	_elements_state    = "fire",
	tool_capabilities  = ELEMENTS_CAPS,
	on_secondary_use   = elements_cycle,
	on_place           = elements_cycle,
})

minetest.register_tool("registered:sword_elements_water", {
	description        = "Zwaard van de Vier Elementen (Water)",
	inventory_image    = "registered_sword_water.png",
	_is_elements_sword = true,
	_elements_state    = "water",
	tool_capabilities  = ELEMENTS_CAPS,
	on_secondary_use   = elements_cycle,
	on_place           = elements_cycle,
	-- LMB: fire a water ball
	on_use             = function(itemstack, user, pointed_thing)
		if not user or not user:is_player() then return end
		local pos  = user:get_pos()
		pos.y      = pos.y + 1.4 -- eye height
		local dir  = user:get_look_dir()
		local ball = minetest.add_entity(pos, "registered:water_ball")
		if ball then
			ball:set_velocity(vector.multiply(dir, 22))
			local ent = ball:get_luaentity()
			if ent then ent._owner = user:get_player_name() end
		end
		minetest.sound_play("default_water_footstep",
			{ pos = pos, gain = 0.5, max_hear_distance = 12 })
		return itemstack
	end,
})

minetest.register_tool("registered:sword_elements_wind", {
	description        = "Zwaard van de Vier Elementen (Wind)",
	inventory_image    = "registered_sword_wind.png",
	_is_elements_sword = true,
	_elements_state    = "wind",
	tool_capabilities  = ELEMENTS_CAPS,
	on_secondary_use   = elements_cycle,
	on_place           = elements_cycle,
	-- Ability triggered by double-tap jump (see globalstep below)
	on_use             = function(itemstack, user, pointed_thing)
		if user and user:is_player() then
			minetest.chat_send_player(user:get_player_name(),
				"dubbel tap Spatie om de Tornado van Wind te activeren!")
		end
		return itemstack
	end,
})

minetest.register_tool("registered:pick", {
	description = "Admin Houweel",
	inventory_image = "registered_pick.png",
	tool_capabilities = {
		full_punch_interval = 0.01,
		max_drop_level = 3,
		damage_groups = { fleshy = 20 },
		groupcaps = {
			cracky                  = { times = { [1] = 2.0, [2] = 1.0, [3] = 0.5 }, uses = 0, maxlevel = 3 },
			choppy                  = { times = { [1] = 2.0, [2] = 1.0, [3] = 0.5 }, uses = 0, maxlevel = 3 },
			crumbly                 = { times = { [1] = 2.0, [2] = 1.0, [3] = 0.5 }, uses = 0, maxlevel = 3 },
			oddly_breakable_by_hand = { times = { [1] = 1.0, [2] = 0.5, [3] = 0.3 }, uses = 0, maxlevel = 3 },
		},
	},
})

-- Admin-only: non-server-priv players cannot dig with the pick.
-- register_on_dignode fires after the node is removed, so we re-place it
-- and clean up any accidentally spawned item drops.
minetest.register_on_dignode(function(pos, oldnode, digger)
	if not digger or not digger:is_player() then return end
	if digger:get_wielded_item():get_name() ~= "registered:pick" then return end
	if digger:get_player_name() ~= "Scottii" or not digger:get_player_name() ~= "Tarnagh" then return end

	-- Undo: restore the node
	minetest.set_node(pos, oldnode)
	-- Remove any item entities that were spawned by the (unwanted) dig
	for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 1.5)) do
		local ent = obj:get_luaentity()
		if ent and ent.name == "__builtin:item" then
			obj:remove()
		end
	end
	minetest.chat_send_player(digger:get_player_name(),
		"Alleen Tarnagh mag dit gebruiken! Je actie is ongedaan gemaakt.")
end)

minetest.register_craftitem("registered:drumstick", {
	description = "Brams Drumstok",
	inventory_image = "registered_drumstick.png",
})


-- ============================================================
-- Appelflap Boomerang entity (registered:appelflap_boomerang)
-- Phase 1 (0–1.5 s): flies forward in a straight line.
-- Phase 2 (1.5 s+): homes back toward the owner.
-- Deals 10 damage on hit (boss or player enemy). Vanishes when
-- caught by owner or after 6 s.
-- ============================================================

-- Appelflap Boomerang — thrown weapon; right-click to throw.
-- Buy from the weaponsmith for 25 coins. Damage: 10.
minetest.register_tool("registered:appelflap_boomerang", {
	description = "Appelflap Boomerang",
	inventory_image = "registered_appelflap_boomerang.png",
	tool_capabilities = {
		full_punch_interval = 0.8,
		damage_groups = { fleshy = 10 },
	},
	on_use = function(itemstack, user, pointed_thing)
		if not user:is_player() then return end
		local pos = user:get_pos()
		pos.y = pos.y + 1.4
		local dir = user:get_look_dir()
		local boomobj = minetest.add_entity(pos, "registered:appelflap_boomerang_ent")
		if boomobj then
			boomobj:set_velocity(vector.multiply(dir, 18))
			local ent = boomobj:get_luaentity()
			if ent then ent._owner = user:get_player_name() end
		end
		itemstack:take_item(1)
		return itemstack
	end,
})

local function boomerang_damage_boss(boomerang_obj, target_obj, pos)
	local bpos = boomerang_obj:get_pos() or pos
	local tpos = target_obj:get_pos() or pos
	local dir = vector.direction(bpos, tpos)
	target_obj:punch(boomerang_obj, 1.0,
		{ full_punch_interval = 1.0, damage_groups = { fleshy = 10 } }, dir)
end

minetest.register_entity("registered:appelflap_boomerang_ent", {
	initial_properties = {
		visual               = "cube",
		visual_size          = { x = 0.65, y = 0.07, z = 0.65 },
		textures             = {
			"registered_appelflap_boomerang.png",
			"registered_appelflap_boomerang.png",
			"registered_appelflap_boomerang.png",
			"registered_appelflap_boomerang.png",
			"registered_appelflap_boomerang.png",
			"registered_appelflap_boomerang.png",
		},
		physical             = true,
		collide_with_objects = false,
		collisionbox         = { -0.3, -0.07, -0.3, 0.3, 0.07, 0.3 },
		static_save          = false,
		pointable            = false,
		glow                 = 4,
	},

	_owner             = nil,
	_returning         = false,
	_lifetime          = 0,
	_done              = false,
	_hit_cd            = 0,
	_spin              = 0,
	_prev_speed        = 18,

	on_activate        = function(self)
		self.object:set_armor_groups({ immortal = 1 })
	end,

	on_step            = function(self, dtime)
		if self._done then return end
		local pos = self.object:get_pos()
		if not pos then return end

		self._lifetime = self._lifetime + dtime
		self._hit_cd   = math.max(0, self._hit_cd - dtime)

		-- Auto-remove after 6 s
		if self._lifetime > 6 then
			self._done = true
			self.object:remove()
			return
		end

		-- Spin like a frisbee (rotate around Y axis)
		self._spin = self._spin + dtime * 14
		self.object:set_rotation(vector.new(0, self._spin, 0))

		-- Detect wall hit: velocity drops sharply while still going forward
		if not self._returning then
			local vel = self.object:get_velocity()
			local speed = vector.length(vel)
			if self._lifetime > 0.1 and speed < self._prev_speed * 0.3 then
				-- Hit a wall — start returning immediately
				self._returning = true
			end
			self._prev_speed = speed
		end

		-- Switch to return phase after 1.5 s (normal arc)
		if not self._returning and self._lifetime > 1.5 then
			self._returning = true
		end

		-- Return phase: steer toward owner each step
		if self._returning and self._owner then
			local owner_obj = minetest.get_player_by_name(self._owner)
			if owner_obj then
				local opos = owner_obj:get_pos()
				opos.y = opos.y + 1.2
				local dist = vector.distance(pos, opos)
				if dist < 1.0 then
					-- Caught — return to inventory
					local inv = owner_obj:get_inventory()
					if inv:room_for_item("main", "registered:appelflap_boomerang") then
						inv:add_item("main", "registered:appelflap_boomerang")
					else
						-- Inventory full — drop at player feet
						minetest.add_item(opos, "registered:appelflap_boomerang")
					end
					self._done = true
					self.object:remove()
					return
				end
				self.object:set_velocity(vector.multiply(
					vector.direction(pos, opos), 18))
			end
		end

		-- Hit detection
		if self._hit_cd > 0 then return end
		for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 1.2)) do
			if obj == self.object then
				-- skip self
			elseif obj:is_player() then
				local pname = obj:get_player_name()
				if not self._owner or pname ~= self._owner then
					obj:set_hp(math.max(0, obj:get_hp() - 10), { type = "punch" })
					minetest.sound_play("appelflap_hit", { pos = pos, gain = 1.0, max_hear_distance = 20 })
					self._hit_cd    = 0.8
					self._returning = true
				end
			else
				local ent = obj:get_luaentity()
				if ent and ent._hp and ent._level then
					minetest.sound_play("appelflap_hit", { pos = pos, gain = 1.0, max_hear_distance = 20 })
					boomerang_damage_boss(self.object, obj, pos)
					self._hit_cd    = 0.8
					self._returning = true
					return
				end
			end
		end
	end,
})

-- ══════════════════════════════════════════════════════════════
-- Fanta Bazooka — shoots Fanta cans that explode on impact
-- Added by Ege
-- ══════════════════════════════════════════════════════════════

-- Fanta explosion: orange splash dealing area damage
local function fanta_explode(pos, owner)
	-- Damage to nearby enemies (radius of 2 blocks)
	for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 2.0)) do
		if obj:is_player() then
			-- No damage to the shooter
			if not owner or obj:get_player_name() ~= owner then
				obj:set_hp(math.max(0, obj:get_hp() - 6), { type = "punch" })
			end
		else
			local ent = obj:get_luaentity()
			-- Damage to enemies (students and bosses)
			-- 50 damage per Fanta: a boss (100 HP) goes down in 2 shots!
			if ent and ent._hp then
				ent._hp = ent._hp - 50
				if ent._hp <= 0 then
					-- Student defeated
					if ent.name == "enemy:student" then
						for i, ref in ipairs(enemy.alive_students) do
							if ref == obj then
								table.remove(enemy.alive_students, i)
								break
							end
						end
						obj:remove()
						enemy.check_wave_clear()
						-- Boss defeated
					elseif ent._level then
						local bpos = obj:get_pos()
						local BOSSES = {
							[1] = { drop = "registered:sword_bronze" },
							[3] = { drop = "registered:sword_diamond" },
							[4] = { drop = "registered:sword_ancient" },
							[6] = { drop = "registered:sword_dragonpower" },
							[7] = { drop = "registered:sword_elements" },
						}
						local bdata = BOSSES[ent._level]
						if bpos and bdata and bdata.drop then
							minetest.add_item(bpos, bdata.drop)
						end
						if ent._drumstick_entity and ent._drumstick_entity:get_pos() then
							ent._drumstick_entity:remove()
						end
						enemy.boss_alive = nil
						obj:remove()
						enemy.check_wave_clear()
					end
				end
			end
		end
	end

	-- Orange splash particles (the Fanta effect!)
	minetest.add_particlespawner({
		amount = 40,
		time = 0.5,
		minpos = vector.add(pos, vector.new(-0.5, -0.3, -0.5)),
		maxpos = vector.add(pos, vector.new(0.5, 0.5, 0.5)),
		minvel = vector.new(-5, 1, -5),
		maxvel = vector.new(5, 6, 5),
		minacc = vector.new(0, -9, 0),
		maxacc = vector.new(0, -6, 0),
		minexptime = 0.3,
		maxexptime = 0.8,
		minsize = 2,
		maxsize = 5,
		texture = "aura_particle.png^[colorize:#FF8C00:230",
		glow = 10,
	})

	-- Second layer: white bubbles (carbonation!)
	minetest.add_particlespawner({
		amount = 15,
		time = 0.3,
		minpos = vector.add(pos, vector.new(-0.3, 0, -0.3)),
		maxpos = vector.add(pos, vector.new(0.3, 0.3, 0.3)),
		minvel = vector.new(-2, 2, -2),
		maxvel = vector.new(2, 5, 2),
		minacc = vector.new(0, -3, 0),
		maxacc = vector.new(0, -1, 0),
		minexptime = 0.2,
		maxexptime = 0.5,
		minsize = 1,
		maxsize = 2,
		texture = "aura_particle.png^[colorize:#FFFFFF:200",
		glow = 14,
	})

	-- Explosion sound
	minetest.sound_play("default_water_footstep",
		{ pos = pos, gain = 0.8, max_hear_distance = 20 })
end

-- Fanta can projectile entity
-- Spins in the air, explodes immediately on wall or enemy collision
minetest.register_entity("registered:fanta_can", {
	initial_properties = {
		visual = "cube",
		visual_size = { x = 0.3, y = 0.4, z = 0.3 },
		textures = {
			"registered_fanta_can.png",
			"registered_fanta_can.png",
			"registered_fanta_can.png",
			"registered_fanta_can.png",
			"registered_fanta_can.png",
			"registered_fanta_can.png",
		},
		physical = true,
		collide_with_objects = false,
		collisionbox = { -0.1, -0.1, -0.1, 0.1, 0.1, 0.1 },
		static_save = false,
	},

	_owner = nil,
	_lifetime = 0,
	_exploded = false,
	_last_pos = nil, -- previous position for wall detection

	on_activate = function(self)
		self.object:set_armor_groups({ immortal = 1 })
	end,

	on_step = function(self, dtime, moveresult)
		if self._exploded then return end
		local pos = self.object:get_pos()
		if not pos then return end

		-- Auto-remove after 6 seconds
		self._lifetime = self._lifetime + dtime
		if self._lifetime > 6 then
			self._exploded = true
			self.object:remove()
			return
		end

		-- Spin the can while it flies
		local yaw = self.object:get_yaw() or 0
		self.object:set_yaw(yaw + dtime * 8)

		-- WALL COLLISION: moveresult contains node collision info
		-- Detects immediately when the can hits a wall/floor/ceiling
		if moveresult and moveresult.collisions and #moveresult.collisions > 0 then
			for _, collision in ipairs(moveresult.collisions) do
				if collision.type == "node" then
					fanta_explode(pos, self._owner)
					self._exploded = true
					self.object:remove()
					return
				end
			end
		end

		-- ENEMY COLLISION: check nearby objects
		-- Larger radius (1.5) because the can moves fast and might pass through
		-- enemies between two frames
		-- Small delay (0.1s) so the can doesn't immediately hit the shooter
		if self._lifetime > 0.1 then
			for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 1.5)) do
				if obj ~= self.object then
					if obj:is_player() then
						-- No damage to the shooter
						if not self._owner or obj:get_player_name() ~= self._owner then
							fanta_explode(pos, self._owner)
							self._exploded = true
							self.object:remove()
							return
						end
					else
						local ent = obj:get_luaentity()
						-- Hit everything except other Fanta cans and boomerangs
						if ent and ent.name ~= "registered:fanta_can"
							and ent.name ~= "registered:appelflap_boomerang_ent"
							and ent.name ~= "boss:drumstick_visual" then
							fanta_explode(pos, self._owner)
							self._exploded = true
							self.object:remove()
							return
						end
					end
				end
			end
		end
	end,
})

-- ══════════════════════════════════════════════════════════════
-- Fanta Bazooka weapon — added by Ege
-- Right-click to shoot Fanta cans.
-- Requires ammo: buy a Fanta 6-pack from the food seller!
-- Each 6-pack gives 6 shots. Cannot shoot without ammo.
-- 1.5-second cooldown to prevent spam.
-- on_place + on_secondary_use: works both when aiming at a block
-- and in mid-air (otherwise it always fires in the same direction).
-- ══════════════════════════════════════════════════════════════

-- Fanta ammo: buy from the food seller as a 6-pack
minetest.register_craftitem("registered:fanta_ammo", {
	description = "Fanta Blikje (munitie)",
	inventory_image = "registered_fanta_can.png",
	stack_max = 99,
})

-- Per-player cooldown tracker (prevents machine-gun spam)
local fanta_cooldown = {}

-- Shoot function: called on right-click
-- Checks whether the player has ammo and consumes 1 Fanta per shot
local function fanta_shoot(itemstack, user, pointed_thing)
	if not user:is_player() then return end
	local pname = user:get_player_name()

	-- Cooldown: at least 1.5 seconds between each shot
	local now = minetest.get_us_time() / 1000000
	if fanta_cooldown[pname] and now - fanta_cooldown[pname] < 1.5 then
		return itemstack -- too fast, wait a moment!
	end

	-- Ammo check: does the player have Fanta cans in inventory?
	local inv = user:get_inventory()
	if not inv:contains_item("main", "registered:fanta_ammo") then
		minetest.chat_send_player(pname,
			"Geen Fanta munitie! Koop een 6-pack bij de kantineguy.")
		return itemstack
	end

	-- Consume 1 Fanta can as ammo
	inv:remove_item("main", "registered:fanta_ammo 1")
	fanta_cooldown[pname] = now

	-- Spawn position: eye-height of the player
	local pos = user:get_pos()
	pos.y = pos.y + 1.4

	-- Look direction: fires exactly where the crosshair (+) points
	local dir = user:get_look_dir()

	-- Create the Fanta can and launch it at speed 25
	local speed = 25
	local can = minetest.add_entity(pos, "registered:fanta_can")
	if can then
		can:set_velocity(vector.multiply(dir, speed))
		local ent = can:get_luaentity()
		if ent then
			ent._owner = pname
		end
	end

	-- Play shoot sound
	minetest.sound_play("default_place_node_hard",
		{ pos = pos, gain = 0.6, max_hear_distance = 15 })

	return itemstack
end

minetest.register_tool("registered:fanta_bazooka", {
	description = "Fanta Bazooka",
	inventory_image = "registered_fanta_bazooka.png",
	wield_scale = { x = 2.0, y = 2.0, z = 2.0 }, -- larger in hand
	tool_capabilities = {
		full_punch_interval = 1.5,
		max_drop_level = 2,
		damage_groups = { fleshy = 3 }, -- melee hit is weak; the Fanta does the work!
	},
	-- Both callbacks needed: on_place when aiming at a block,
	-- on_secondary_use when aiming in mid-air
	on_secondary_use = fanta_shoot,
	on_place = fanta_shoot,
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

-- ══════════════════════════════════════════════════════════════
-- Bouwers Hamer — breekt alle blokken instant (voor arena-bouw)
-- Added by Ege
-- ══════════════════════════════════════════════════════════════

minetest.register_tool("registered:builder_hammer", {
	description = "Bouwers Hamer (breekt alles)",
	inventory_image = "registered_builder_hammer.png",
	tool_capabilities = {
		full_punch_interval = 0.1,
		max_drop_level = 3,
		groupcaps = {
			cracky  = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses = 0, maxlevel = 3},
			choppy  = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses = 0, maxlevel = 3},
			snappy  = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses = 0, maxlevel = 3},
			crumbly = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses = 0, maxlevel = 3},
			oddly_breakable_by_hand = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses = 0, maxlevel = 3},
		},
	},
})

-- ══════════════════════════════════════════════════════════════
-- Sloophamer — sla op een muurblok en de hele muur verdwijnt
-- Scant de muur horizontaal EN verticaal:
--   Verticaal: verwijdert alles TUSSEN vloer en plafond (laat beide intact)
--   Horizontaal: breidt uit in alle 4 richtingen langs de muur
-- Added by Ege
-- ══════════════════════════════════════════════════════════════

minetest.register_tool("registered:destruction_hammer", {
	description = "Sloophamer (vernietigt hele muren)",
	inventory_image = "registered_destruction_hammer.png",
	tool_capabilities = {
		full_punch_interval = 0.5,
		max_drop_level = 3,
		groupcaps = {
			cracky  = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses = 0, maxlevel = 3},
			choppy  = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses = 0, maxlevel = 3},
			snappy  = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses = 0, maxlevel = 3},
			crumbly = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses = 0, maxlevel = 3},
			oddly_breakable_by_hand = {times = {[1]=0.0, [2]=0.0, [3]=0.0}, uses = 0, maxlevel = 3},
		},
	},
	after_use = function(itemstack, user, node, digparams)
		return itemstack  -- voorkom slijtage
	end,
})

-- Helper: vind de muur-grenzen voor een kolom
local destruction_floor_y = 0

local function find_wall_bounds(x, hit_y, z)
	local top_y = hit_y
	while true do
		local above = minetest.get_node(vector.new(x, top_y + 1, z))
		if above.name == "air" or above.name == "ignore" then break end
		top_y = top_y + 1
		if top_y > hit_y + 20 then break end
	end
	local min_y = destruction_floor_y + 1
	return min_y, top_y
end

local function remove_wall_column(x, z, min_y, max_y)
	local removed = 0
	for y = min_y, max_y do
		local p = vector.new(x, y, z)
		local n = minetest.get_node(p)
		if n.name ~= "air" and n.name ~= "ignore" then
			minetest.remove_node(p)
			removed = removed + 1
		end
	end
	return removed
end

minetest.register_on_dignode(function(pos, oldnode, digger)
	if not digger or not digger:is_player() then return end
	if digger:get_wielded_item():get_name() ~= "registered:destruction_hammer" then return end

	destruction_floor_y = math.floor(digger:get_pos().y)

	local min_y, max_y = find_wall_bounds(pos.x, pos.y, pos.z)
	local total_removed = 0

	total_removed = total_removed + remove_wall_column(pos.x, pos.z, min_y, max_y)

	local directions = {
		{dx = 1, dz = 0},
		{dx = -1, dz = 0},
		{dx = 0, dz = 1},
		{dx = 0, dz = -1},
	}

	for _, dir in ipairs(directions) do
		local step = 1
		while step <= 50 do
			local cx = pos.x + dir.dx * step
			local cz = pos.z + dir.dz * step
			local check = minetest.get_node(vector.new(cx, pos.y, cz))
			if check.name == "air" or check.name == "ignore" then
				break
			end
			local col_min, col_max = find_wall_bounds(cx, pos.y, cz)
			total_removed = total_removed + remove_wall_column(cx, cz, col_min, col_max)
			step = step + 1
		end
	end

	minetest.add_particlespawner({
		amount = 50,
		time = 0.4,
		minpos = vector.new(pos.x - 2, min_y, pos.z - 2),
		maxpos = vector.new(pos.x + 2, max_y, pos.z + 2),
		minvel = vector.new(-4, -1, -4),
		maxvel = vector.new(4, 4, 4),
		minacc = vector.new(0, -5, 0),
		maxacc = vector.new(0, -3, 0),
		minexptime = 0.3,
		maxexptime = 0.8,
		minsize = 1,
		maxsize = 3,
		texture = "default_stone.png",
	})

	minetest.sound_play("default_break_glass",
		{pos = pos, gain = 1.0, max_hear_distance = 20})

	minetest.chat_send_player(digger:get_player_name(),
		total_removed .. " blokken vernietigd!")
end)

-- ══════════════════════════════════════════════════════════════
-- Decoratieve fietsenrekken — multi-color bikes voor fietsenstalling
-- Added by Ege
-- ══════════════════════════════════════════════════════════════

-- Elk rek bevat 3 fietsen met elk een eigen kleur (via 3 materialen in de mesh)
-- Groter formaat: 1.5 blokken breed, 1.5 blokken hoog
-- Lijst met alle rack-namen voor willekeurige plaatsing
local bike_rack_names = {}
local bike_racks = {
	{name = "bike_rack",       desc = "Fietsenrek (Rood/Blauw/Groen)",
		t1 = "registered_bike_rack_red.png",
		t2 = "registered_bike_rack_blue.png",
		t3 = "registered_bike_rack_green.png"},
	{name = "bike_rack_warm",  desc = "Fietsenrek (Oranje/Roze/Rood)",
		t1 = "registered_bike_rack_orange.png",
		t2 = "registered_bike_rack_pink.png",
		t3 = "registered_bike_rack_red.png"},
	{name = "bike_rack_cool",  desc = "Fietsenrek (Blauw/Groen/Zwart)",
		t1 = "registered_bike_rack_blue.png",
		t2 = "registered_bike_rack_green.png",
		t3 = "registered_bike_rack_black.png"},
	{name = "bike_rack_dark",  desc = "Fietsenrek (Zwart/Rood/Blauw)",
		t1 = "registered_bike_rack_black.png",
		t2 = "registered_bike_rack_red.png",
		t3 = "registered_bike_rack_blue.png"},
	{name = "bike_rack_bright", desc = "Fietsenrek (Roze/Oranje/Groen)",
		t1 = "registered_bike_rack_pink.png",
		t2 = "registered_bike_rack_orange.png",
		t3 = "registered_bike_rack_green.png"},
	{name = "bike_rack_mixed", desc = "Fietsenrek (Groen/Zwart/Oranje)",
		t1 = "registered_bike_rack_green.png",
		t2 = "registered_bike_rack_black.png",
		t3 = "registered_bike_rack_orange.png"},
}

for _, rack in ipairs(bike_racks) do
	bike_rack_names[#bike_rack_names + 1] = "registered:" .. rack.name
	minetest.register_node("registered:" .. rack.name, {
		description = rack.desc,
		drawtype = "mesh",
		mesh = "bike_rack.obj",
		paramtype = "light",
		paramtype2 = "facedir",
		use_texture_alpha = "clip",
		-- 3 tiles: één per fiets/materiaal in de mesh
		tiles = {rack.t1, rack.t2, rack.t3},
		inventory_image = rack.t1,
		wield_image = rack.t1,
		walkable = true,
		selection_box = {
			type = "fixed",
			fixed = {-0.75, -0.5, -0.4, 0.75, 1.0, 0.4},
		},
		collision_box = {
			type = "fixed",
			fixed = {-0.75, -0.5, -0.4, 0.75, 1.0, 0.4},
		},
		groups = {cracky = 2, oddly_breakable_by_hand = 2},
		sounds = sound_stone(),
		on_blast = function() end,
		-- Bij plaatsing: wissel naar een willekeurig kleurcombi
		after_place_node = function(pos, placer, itemstack, pointed_thing)
			local random_rack = bike_rack_names[math.random(#bike_rack_names)]
			local node = minetest.get_node(pos)
			minetest.swap_node(pos, {name = random_rack, param2 = node.param2})
		end,
	})
end
