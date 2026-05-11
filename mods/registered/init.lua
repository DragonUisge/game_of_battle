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
	description = "Drumstok",
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
		damage_groups = {fleshy = 10},
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
		{full_punch_interval = 1.0, damage_groups = {fleshy = 10}}, dir)
end

minetest.register_entity("registered:appelflap_boomerang_ent", {
	initial_properties = {
		visual          = "cube",
		visual_size     = {x = 0.65, y = 0.07, z = 0.65},
		textures        = {
			"registered_appelflap_boomerang.png",
			"registered_appelflap_boomerang.png",
			"registered_appelflap_boomerang.png",
			"registered_appelflap_boomerang.png",
			"registered_appelflap_boomerang.png",
			"registered_appelflap_boomerang.png",
		},
		physical        = true,
		collide_with_objects = false,
		collisionbox    = {-0.3, -0.07, -0.3, 0.3, 0.07, 0.3},
		static_save     = false,
		pointable       = false,
		glow            = 4,
	},

	_owner      = nil,
	_returning  = false,
	_lifetime   = 0,
	_done       = false,
	_hit_cd     = 0,
	_spin       = 0,
	_prev_speed = 18,

	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,

	on_step = function(self, dtime)
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
					obj:set_hp(math.max(0, obj:get_hp() - 10), {type = "punch"})
					minetest.sound_play("appelflap_hit", {pos = pos, gain = 1.0, max_hear_distance = 20})
					self._hit_cd    = 0.8
					self._returning = true
				end
			else
				local ent = obj:get_luaentity()
				if ent and ent._hp and ent._level then
					minetest.sound_play("appelflap_hit", {pos = pos, gain = 1.0, max_hear_distance = 20})
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
-- Fanta Bazooka — schiet Fanta-blikjes die exploderen bij impact
-- Toegevoegd door Ege
-- ══════════════════════════════════════════════════════════════

-- Fanta explosie: oranje splash met schade in een gebied
local function fanta_explode(pos, owner)
	-- Schade aan vijanden in de buurt (straal van 2 blokken)
	for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 2.0)) do
		if obj:is_player() then
			-- Geen schade aan de schutter zelf
			if not owner or obj:get_player_name() ~= owner then
				obj:set_hp(math.max(0, obj:get_hp() - 6), {type = "punch"})
			end
		else
			local ent = obj:get_luaentity()
			-- Schade aan vijanden (studenten en bosses)
			if ent and ent._hp then
				ent._hp = ent._hp - 12
				if ent._hp <= 0 then
					-- Student verslagen
					if ent.name == "enemy:student" then
						for i, ref in ipairs(enemy.alive_students) do
							if ref == obj then
								table.remove(enemy.alive_students, i)
								break
							end
						end
						obj:remove()
						enemy.check_wave_clear()
					-- Boss verslagen
					elseif ent._level then
						local bpos = obj:get_pos()
						local BOSSES = {
							[1] = {drop = "registered:sword_bronze"},
							[3] = {drop = "registered:sword_diamond"},
							[4] = {drop = "registered:sword_ancient"},
							[6] = {drop = "registered:sword_dragonpower"},
							[7] = {drop = "registered:sword_elements"},
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

	-- Oranje splash-deeltjes (het Fanta-effect!)
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

	-- Tweede laag: witte bubbels (koolzuur!)
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

	-- Explosie geluid
	minetest.sound_play("default_water_footstep",
		{pos = pos, gain = 0.8, max_hear_distance = 20})
end

-- Fanta-blik projectiel entity
minetest.register_entity("registered:fanta_can", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 0.3, y = 0.4, z = 0.3},
		textures = {
			-- alle 6 zijden van de kubus (boven, onder, rechts, links, voor, achter)
			"registered_fanta_can.png",
			"registered_fanta_can.png",
			"registered_fanta_can.png",
			"registered_fanta_can.png",
			"registered_fanta_can.png",
			"registered_fanta_can.png",
		},
		physical = true,
		collide_with_objects = false,
		collisionbox = {-0.1, -0.1, -0.1, 0.1, 0.1, 0.1},
		static_save = false,
	},

	_owner = nil,
	_lifetime = 0,
	_exploded = false,

	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,

	on_step = function(self, dtime)
		if self._exploded then return end
		local pos = self.object:get_pos()
		if not pos then return end

		-- Na 6 seconden automatisch verwijderen
		self._lifetime = self._lifetime + dtime
		if self._lifetime > 6 then
			self._exploded = true
			self.object:remove()
			return
		end

		-- Draai het blikje terwijl het vliegt (cool effect)
		local vel = self.object:get_velocity()
		local yaw = self.object:get_yaw() or 0
		self.object:set_yaw(yaw + dtime * 8)

		-- Check of we iets raken (vijanden)
		if self._lifetime > 0.15 then
			for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 0.6)) do
				if obj ~= self.object then
					if obj:is_player() then
						if not self._owner or obj:get_player_name() ~= self._owner then
							fanta_explode(pos, self._owner)
							self._exploded = true
							self.object:remove()
							return
						end
					else
						local ent = obj:get_luaentity()
						if ent and ent._hp then
							fanta_explode(pos, self._owner)
							self._exploded = true
							self.object:remove()
							return
						end
					end
				end
			end
		end

		-- Check of we een muur raken (snelheid stopt plotseling)
		if self._lifetime > 0.2 then
			if math.abs(vel.x) < 0.5 and math.abs(vel.z) < 0.5 and self._lifetime > 0.3 then
				fanta_explode(pos, self._owner)
				self._exploded = true
				self.object:remove()
				return
			end
		end
	end,
})

-- Het wapen zelf: de Fanta Bazooka
minetest.register_tool("registered:fanta_bazooka", {
	description = "Fanta Bazooka",
	inventory_image = "registered_fanta_bazooka.png",
	-- Grotere weergave als je het vasthoudt
	wield_scale = {x = 2.0, y = 2.0, z = 2.0},
	tool_capabilities = {
		full_punch_interval = 1.5,
		max_drop_level = 2,
		-- Directe klap doet weinig schade (het gaat om de Fanta!)
		damage_groups = {fleshy = 3},
	},
	-- Rechter-muisknop = schiet een Fanta-blik
	on_secondary_use = function(itemstack, user, pointed_thing)
		if not user:is_player() then return end
		local pos = user:get_pos()
		pos.y = pos.y + 1.4  -- ooghoogte

		-- Richting waar de speler kijkt
		local yaw = user:get_look_horizontal()
		local pitch = user:get_look_vertical()
		local dir = vector.new(
			-math.sin(yaw) * math.cos(pitch),
			-math.sin(pitch),
			-math.cos(yaw) * math.cos(pitch)
		)

		-- Maak het Fanta-blik aan en schiet het weg
		local speed = 25
		local can = minetest.add_entity(pos, "registered:fanta_can")
		if can then
			can:set_velocity(vector.multiply(dir, speed))
			local ent = can:get_luaentity()
			if ent then
				ent._owner = user:get_player_name()
			end
		end

		-- Schiet-geluid
		minetest.sound_play("default_place_node_hard",
			{pos = pos, gain = 0.6, max_hear_distance = 15})

		return itemstack
	end,
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
