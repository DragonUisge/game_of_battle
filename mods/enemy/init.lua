-- enemy: Student enemy entities and wave spawning system
-- Waves spawn at school break times: 10:10, 12:10, 14:15
-- 7 levels, 10 students + 1 boss each (except level 7: boss only)
-- Students: 1 HP, 1 damage, size scales from 60% (level 1) to 100% (level 6)

enemy = {}

-- ============================================================
-- Dynamic BGM loop system for boss waves
-- Flow: intro → begin2 → [shuffled middle/bridge loop] → stop
-- ============================================================

local bgm = {
	handle = nil,       -- current minetest.sound_play handle
	active = false,     -- flag checked by minetest.after callbacks
	sequence = {},      -- upcoming tracks to play
}

-- Track durations in seconds (measured via ffprobe)
local TRACK_DURATIONS = {
	intro   = 20.37,
	begin2  = 30.35,
	middle1 = 30.45,
	middle2 = 30.45,
	middle3 = 30.45,
	bridge1 = 16.12,
	bridge2 = 16.12,
	bridge3 = 30.45,
	bridge4 = 30.45,
}

-- Tracks that form the repeating loop body
local LOOP_TRACKS = {"middle1", "middle2", "middle3", "bridge1", "bridge2", "bridge3", "bridge4"}

local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(1, i)
		t[i], t[j] = t[j], t[i]
	end
end

-- Play a single track (stereo, no position = global to all players)
local function play_track(name)
	if not bgm.active then return 0 end

	if bgm.handle then
		minetest.sound_stop(bgm.handle)
	end

	bgm.handle = minetest.sound_play(name, {gain = 0.8})
	return TRACK_DURATIONS[name] or 30.0
end

-- Play next track from the shuffled sequence, regenerate when exhausted
local function play_next()
	if not bgm.active then return end

	if #bgm.sequence == 0 then
		local seq = {}
		for _, t in ipairs(LOOP_TRACKS) do seq[#seq + 1] = t end
		shuffle(seq)
		bgm.sequence = seq
	end

	local track = table.remove(bgm.sequence, 1)
	local dur = play_track(track)

	minetest.after(dur, function()
		play_next()
	end)
end

-- Start BGM: intro (once) → begin2 → shuffled loop
function enemy.start_bgm()
	bgm.active = true
	bgm.sequence = {}

	local dur_intro = play_track("intro")

	minetest.after(dur_intro, function()
		if not bgm.active then return end
		local dur_begin = play_track("begin2")

		minetest.after(dur_begin, function()
			play_next()
		end)
	end)
end

-- Stop BGM immediately
function enemy.stop_bgm()
	bgm.active = false
	if bgm.handle then
		minetest.sound_stop(bgm.handle)
		bgm.handle = nil
	end
	bgm.sequence = {}
end

-- Wave state
enemy.current_level = 0      -- 0 = no wave active yet, 1-7 = current level
enemy.wave_active = false     -- true while enemies are alive
enemy.alive_students = {}     -- objectrefs of living students
enemy.boss_alive = nil        -- objectref of living boss
enemy.wave_triggered = {}     -- track which break times have already triggered

-- Break times (hour, minute)
local BREAK_TIMES = {
	{h = 10, m = 10},
	{h = 12, m = 10},
	{h = 14, m = 15},
}

-- Student spawn area (stairs)
local SPAWN_MIN = vector.new(0.8, 3.5, 7.2)
local SPAWN_MAX = vector.new(4.2, 4.5, 8.2)

-- Boss spawn position
local BOSS_SPAWN = vector.new(3, 1.5, 3)

-- Student size per level (60% to 100%)
local function student_scale(level)
	if level >= 6 then return 1.0 end
	return 0.6 + (level - 1) * 0.08
end

-- Random student texture (2 boys, 2 girls)
local STUDENT_TEXTURES = {
	"student_boy1.png",
	"student_boy2.png",
	"student_girl1.png",
	"student_girl2.png",
}

local function random_student_texture()
	return STUDENT_TEXTURES[math.random(1, #STUDENT_TEXTURES)]
end

-- Random position in spawn area
local function random_spawn_pos()
	return vector.new(
		SPAWN_MIN.x + math.random() * (SPAWN_MAX.x - SPAWN_MIN.x),
		SPAWN_MIN.y + math.random() * (SPAWN_MAX.y - SPAWN_MIN.y),
		SPAWN_MIN.z + math.random() * (SPAWN_MAX.z - SPAWN_MIN.z)
	)
end

-- Student entity
minetest.register_entity("enemy:student", {
	initial_properties = {
		visual = "mesh",
		mesh = "character.b3d",
		textures = {"student_boy1.png"},
		physical = true,
		collide_with_objects = true,
		collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
		visual_size = {x = 0.6, y = 0.6, z = 0.6},
		makes_footstep_sound = true,
		static_save = false,
		hp_max = 1,
	},

	_hp = 1,
	_damage = 1,
	_attack_cooldown = 0,
	_level = 1,

	on_activate = function(self, staticdata)
		self.object:set_animation({x = 168, y = 187}, 30, 0, true) -- walk
		self.object:set_armor_groups({fleshy = 100})
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		if not puncher then return end
		local is_stunt = puncher:get_luaentity() and puncher:get_luaentity().name == "trailer:stunt_double"
		if not puncher:is_player() and not is_stunt then return end

		-- Calculate damage from tool
		local dmg = 1
		if tool_capabilities and tool_capabilities.damage_groups and tool_capabilities.damage_groups.fleshy then
			dmg = tool_capabilities.damage_groups.fleshy
		end

		-- Fire sword: spawn fire particles
		local wielded = puncher:get_wielded_item()
		local itemdef = minetest.registered_items[wielded:get_name()]
		if itemdef and itemdef._fire_sword then
			local pos = self.object:get_pos()
			if pos then
				minetest.add_particlespawner({
					amount = 20,
					time = 0.5,
					minpos = vector.add(pos, vector.new(-0.3, 0.5, -0.3)),
					maxpos = vector.add(pos, vector.new(0.3, 1.8, 0.3)),
					minvel = vector.new(-1, 1, -1),
					maxvel = vector.new(1, 3, 1),
					minacc = vector.new(0, 1, 0),
					maxacc = vector.new(0, 2, 0),
					minexptime = 0.3,
					maxexptime = 0.7,
					minsize = 2,
					maxsize = 4,
					texture = "draconis_fire_particle.png",
					glow = 14,
				})
			end
		end

		self._hp = self._hp - dmg
		if self._hp <= 0 then
			-- Remove from alive list
			for i, ref in ipairs(enemy.alive_students) do
				if ref == self.object then
					table.remove(enemy.alive_students, i)
					break
				end
			end
			self.object:remove()
			enemy.check_wave_clear()
		end
		return true  -- prevent engine damage handling
	end,

	on_step = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then return end

		-- Find nearest player (or stunt double in trailer mode)
		local nearest = nil
		local nearest_dist = math.huge
		if trailer and trailer.active and trailer.stunt and trailer.stunt:get_pos() then
			nearest = trailer.stunt
			nearest_dist = vector.distance(pos, trailer.stunt:get_pos())
		else
			for _, player in ipairs(minetest.get_connected_players()) do
				local ppos = player:get_pos()
				local dist = vector.distance(pos, ppos)
				if dist < nearest_dist then
					nearest = player
					nearest_dist = dist
				end
			end
		end

		if not nearest then return end

		local ppos = nearest:get_pos()
		local dir = vector.direction(pos, ppos)

		-- Face the player
		self.object:set_yaw(minetest.dir_to_yaw(dir))

		-- Move toward player
		local speed = 2.5
		self.object:set_velocity(vector.new(dir.x * speed, -9.81, dir.z * speed))

		-- Attack if close enough
		self._attack_cooldown = self._attack_cooldown - dtime
		if nearest_dist < 2.0 and self._attack_cooldown <= 0 then
			-- In trailer mode, punch the stunt double entity instead of set_hp
			if nearest:is_player() then
				nearest:set_hp(nearest:get_hp() - self._damage, {type = "punch"})
			else
				nearest:punch(self.object, 1.0, {damage_groups = {fleshy = self._damage}}, vector.new(0, 0, 0))
			end
			self._attack_cooldown = 1.0
			-- Play mine animation briefly
			self.object:set_animation({x = 189, y = 198}, 30, 0, false)
			minetest.after(0.5, function()
				if self.object and self.object:get_pos() then
					self.object:set_animation({x = 168, y = 187}, 30, 0, true)
				end
			end)
		end
	end,
})

-- Spawn a wave of students for a given level
function enemy.spawn_wave(level)
	if level > 7 then return end

	enemy.current_level = level
	enemy.wave_active = true
	enemy.alive_students = {}
	enemy.boss_alive = nil

	local scale = student_scale(level)

	-- Level 7: boss only
	if level < 7 then
		for i = 1, 10 do
			local pos = random_spawn_pos()
			local obj = minetest.add_entity(pos, "enemy:student")
			if obj then
				local cbox_s = 0.3 * scale
				local cbox_h = 1.7 * scale
				obj:set_properties({
					visual_size = {x = scale, y = scale, z = scale},
					textures = {random_student_texture()},
					collisionbox = {-cbox_s, 0.0, -cbox_s, cbox_s, cbox_h, cbox_s},
				})
				local lua = obj:get_luaentity()
				if lua then
					lua._level = level
				end
				table.insert(enemy.alive_students, obj)
			end
		end
	end

	-- Spawn boss
	local boss_obj = minetest.add_entity(BOSS_SPAWN, "boss:teacher")
	if boss_obj then
		enemy.boss_alive = boss_obj
		boss.set_level(boss_obj, level)
	end

	-- Announce wave
	local msg = "=== Golf " .. level .. " begint! ==="
	if level == 7 then
		msg = "=== LAATSTE GOLF! Margriet verschijnt! ==="
	end
	for _, player in ipairs(minetest.get_connected_players()) do
		minetest.chat_send_player(player:get_player_name(), msg)
	end

	-- Start battle music
	enemy.start_bgm()
end

-- Check if all enemies in the wave are dead
function enemy.check_wave_clear()
	if not enemy.wave_active then return end

	-- Check students
	local students_alive = false
	for _, ref in ipairs(enemy.alive_students) do
		if ref and ref:get_pos() then
			students_alive = true
			break
		end
	end

	-- Check boss
	local boss_alive = enemy.boss_alive and enemy.boss_alive:get_pos()

	if not students_alive and not boss_alive then
		enemy.wave_active = false
		enemy.stop_bgm()

		local level = enemy.current_level

		-- Reward coins
		local reward = 10 + level * 2
		for _, player in ipairs(minetest.get_connected_players()) do
			local meta = player:get_meta()
			local coins = meta:get_int("coins") + reward
			meta:set_int("coins", coins)
			minetest.chat_send_player(player:get_player_name(),
				"Golf " .. level .. " verslagen! +" .. reward .. " munten (totaal: " .. coins .. ")")
		end

		if level >= 7 then
			-- Game won!
			for _, player in ipairs(minetest.get_connected_players()) do
				minetest.chat_send_player(player:get_player_name(),
					"*** GEFELICITEERD! Je hebt alle golven verslagen! ***")
			end
		end
	end
end

-- Reset everything (called on player death)
function enemy.reset_all()
	enemy.stop_bgm()

	-- Remove all living students
	for _, ref in ipairs(enemy.alive_students) do
		if ref and ref:get_pos() then
			ref:remove()
		end
	end
	enemy.alive_students = {}

	-- Remove boss (and its summoned dragon)
	if enemy.boss_alive and enemy.boss_alive:get_pos() then
		local blua = enemy.boss_alive:get_luaentity()
		if blua and blua._summoned_dragon and blua._summoned_dragon:get_pos() then
			blua._summoned_dragon:remove()
		end
		enemy.boss_alive:remove()
	end
	enemy.boss_alive = nil

	enemy.wave_active = false
	enemy.current_level = 0
	enemy.wave_triggered = {}

	-- Reset time to 08:00
	game_time.reset()
end

-- Player death
-- Multiplayer: individual respawn, game continues (the arena fight goes on).
-- Solo: full reset from the beginning (original behaviour).
minetest.register_on_dieplayer(function(player)
	local dying_name = player:get_player_name()
	local total_players = #minetest.get_connected_players()

	if total_players > 1 then
		-- Multiplayer: penalise only the dead player, others continue
		local meta = player:get_meta()
		meta:set_int("coins", 20)

		minetest.chat_send_player(dying_name,
			"*** Je bent gevallen! Je herleeft bij het startpunt... ***")
		for _, p in ipairs(minetest.get_connected_players()) do
			if p:get_player_name() ~= dying_name then
				minetest.chat_send_player(p:get_player_name(),
					"*** " .. dying_name .. " is gevallen! Verdedig de arena! ***")
			end
		end
	else
		-- Solo: full reset from the beginning
		enemy.reset_all()

		local meta = player:get_meta()
		meta:set_int("coins", 20)

		minetest.chat_send_player(dying_name,
			"*** Je bent gesneuveld! Alles begint opnieuw... ***")
	end
end)

-- /restart  — host command to manually reset the game in multiplayer
minetest.register_chatcommand("restart", {
	description = "Herstart het spel (reset golven en tijd) — alleen voor admins",
	privs = {server = true},
	func = function(name)
		enemy.reset_all()
		for _, p in ipairs(minetest.get_connected_players()) do
			local meta = p:get_meta()
			meta:set_int("coins", 20)
		end
		minetest.chat_send_all("*** Het spel is herstart door " .. name .. "! ***")
		return true, "Spel herstart."
	end,
})

-- Time-based wave spawning
local last_check_time = ""

minetest.register_globalstep(function(dtime)
	if enemy.wave_active then return end
	if enemy.current_level >= 7 then return end

	local h = game_time.get_hour()
	local m = game_time.get_minute()
	local time_key = string.format("%02d:%02d", h, m)

	-- Don't check the same minute twice
	if time_key == last_check_time then return end
	last_check_time = time_key

	-- Check if it's a break time
	for _, bt in ipairs(BREAK_TIMES) do
		if h == bt.h and m == bt.m then
			-- Check if this specific break has already triggered
			local wave_key = enemy.current_level + 1 .. "_" .. time_key
			if not enemy.wave_triggered[wave_key] then
				enemy.wave_triggered[wave_key] = true
				enemy.spawn_wave(enemy.current_level + 1)
			end
			return
		end
	end
end)