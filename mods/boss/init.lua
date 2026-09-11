-- boss: Teacher boss entity
-- Each wave has one boss (teacher). Higher levels = more HP and damage.
-- Level 7 boss is the "Directeur" (principal) — final boss.
-- Hugo (level 2) has kung fu abilities and summons a Dragon at low HP.

boss = {}

-- Singleton reference to the victory dragon (Teinetarnagh); nil when not active
boss._victory_dragon_obj = nil

-- Boss data per level: name, HP, damage, texture
local BOSSES = {
	[1] = { name = "Bram", hp = 100, dmg = 2, tex = "boss_bram.png", drop = "registered:sword_bronze" },
	[2] = { name = "Hugo", hp = 150, dmg = 3, tex = "boss_hugo.png" },
	[3] = { name = "Joachim", hp = 200, dmg = 4, tex = "boss_joachim.png", drop = "registered:sword_diamond" },
	[4] = { name = "Julian", hp = 250, dmg = 5, tex = "boss_julian.png", drop = "registered:sword_ancient" },
	[5] = { name = "Vanessa", hp = 300, dmg = 6, tex = "boss_vanessa.png" },
	[6] = { name = "Jan Willem", hp = 350, dmg = 7, tex = "boss_janwillem.png", drop = "registered:sword_elements" },
	[7] = { name = "Margriet", hp = 450, dmg = 8, tex = "boss_margriet.png", drop = "registered:sword_dragonpower" },
}

-- ============================================================
-- Helper: find nearest player (or stunt double in trailer mode)
-- ============================================================
local function find_nearest_player(pos)
	local nearest, nearest_dist = nil, math.huge
	-- In trailer mode, target the stunt double instead
	if trailer and trailer.active and trailer.stunt and trailer.stunt:get_pos() then
		local spos = trailer.stunt:get_pos()
		return trailer.stunt, vector.distance(pos, spos)
	end
	for _, player in ipairs(minetest.get_connected_players()) do
		local ppos = player:get_pos()
		local dist = vector.distance(pos, ppos)
		if dist < nearest_dist then
			nearest = player
			nearest_dist = dist
		end
	end
	return nearest, nearest_dist
end

-- ============================================================
-- Hugo (level 2) — kung fu phases
-- "stalk"   : circle around player, sizing them up
-- "dash"    : explosive rush with Dragon cry
-- "recover" : brief pause after dash
-- "summon"  : retreating + channeling Dragon at low HP
-- "linked"  : invulnerable while Dragon lives
-- ============================================================

-- Hugo stalk: move sideways around the player at medium distance
local function enemy_boss_dragoncall_stalk(self, dtime, pos, nearest, nearest_dist)
	self._enemy_boss_dragoncall_timer = self._enemy_boss_dragoncall_timer - dtime

	local ppos = nearest:get_pos()
	local dir = vector.direction(pos, ppos)
	self.object:set_yaw(minetest.dir_to_yaw(dir))

	-- Circle strafe: perpendicular direction
	local strafe = vector.new(-dir.z, 0, dir.x)
	local target_dist = 5.0

	if nearest_dist < target_dist - 0.5 then
		-- Back away slightly
		local away = vector.multiply(dir, -1.5)
		self.object:set_velocity(vector.new(away.x + strafe.x * 2, -9.81, away.z + strafe.z * 2))
	elseif nearest_dist > target_dist + 1.0 then
		-- Approach
		self.object:set_velocity(vector.new(dir.x * 2.0, -9.81, dir.z * 2.0))
	else
		-- Circle strafe
		self.object:set_velocity(vector.new(strafe.x * 2.5, -9.81, strafe.z * 2.5))
	end

	-- Stand animation (menacing idle)
	self.object:set_animation({ x = 0, y = 79 }, 15, 0, true)

	-- Transition to dash after timer expires
	if self._enemy_boss_dragoncall_timer <= 0 then
		-- Random attack selection
		local roll = math.random()
		if roll < 0.35 then
			-- Standard dash (35%)
			self._enemy_boss_dragoncall_phase = "dash"
			self._enemy_boss_dragoncall_timer = 0.6
		elseif roll < 0.60 then
			-- Spinning kick (25%)
			self._enemy_boss_dragoncall_phase = "spinkick_approach"
			self._enemy_boss_dragoncall_timer = 1.5
		elseif roll < 0.80 then
			-- Tornado (20%)
			self._enemy_boss_dragoncall_phase = "tornado"
			self._enemy_boss_dragoncall_timer = 2.5
			self._spinkick_yaw = minetest.dir_to_yaw(dir)
			self._tornado_dmg_tick = 0.25
		else
			-- Feint (20%)
			self._enemy_boss_dragoncall_phase = "feint_dash"
			self._enemy_boss_dragoncall_timer = 0.4
		end
		-- Karate cry for any attack
		minetest.sound_play("hugo_karate" .. math.random(1, 4),
			{ pos = pos, gain = 1.2, max_hear_distance = 30 })
		self.object:set_animation({ x = 168, y = 187 }, 60, 0, true)
	end
end

-- Hugo dash: explosive rush toward player, high damage
local function enemy_boss_dragoncall_dash(self, dtime, pos, nearest, nearest_dist)
	self._enemy_boss_dragoncall_timer = self._enemy_boss_dragoncall_timer - dtime

	local ppos = nearest:get_pos()
	local dir = vector.direction(pos, ppos)
	self.object:set_yaw(minetest.dir_to_yaw(dir))

	-- Very fast rush
	local speed = 8.0
	self.object:set_velocity(vector.new(dir.x * speed, -9.81, dir.z * speed))

	-- Deal damage on contact (double damage kung fu strike)
	self._attack_cooldown = self._attack_cooldown - dtime
	if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
		if nearest:is_player() then
			nearest:set_hp(nearest:get_hp() - self._damage * 2, { type = "punch" })
		else
			nearest:punch(self.object, 1.0, { damage_groups = { fleshy = self._damage * 2 } }, vector.new(0, 0, 0))
		end
		self._attack_cooldown = 0.4
		minetest.sound_play("hugo_hit", { pos = pos, gain = 1.0, max_hear_distance = 20 })
		self.object:set_animation({ x = 189, y = 198 }, 50, 0, false)
	end

	if self._enemy_boss_dragoncall_timer <= 0 then
		self._enemy_boss_dragoncall_phase = "recover"
		self._enemy_boss_dragoncall_timer = 1.0
		self.object:set_velocity(vector.new(0, -9.81, 0))
		self.object:set_animation({ x = 0, y = 79 }, 15, 0, true)
	end
end

-- Hugo recover: brief pause after dash
local function enemy_boss_dragoncall_recover(self, dtime)
	self._enemy_boss_dragoncall_timer = self._enemy_boss_dragoncall_timer - dtime
	self.object:set_velocity(vector.new(0, -9.81, 0))

	if self._enemy_boss_dragoncall_timer <= 0 then
		self._enemy_boss_dragoncall_phase = "stalk"
		self._enemy_boss_dragoncall_timer = 2.0 + math.random() * 2.0
	end
end

-- Hugo spinning kick: dash close → jump → tilt back 30° → full spin → damage on land
local function enemy_boss_dragoncall_spinkick_approach(self, dtime, pos, nearest, nearest_dist)
	self._enemy_boss_dragoncall_timer = self._enemy_boss_dragoncall_timer - dtime
	local ppos                        = nearest:get_pos()
	local dir                         = vector.direction(pos, ppos)
	self.object:set_yaw(minetest.dir_to_yaw(dir))
	self.object:set_velocity(vector.new(dir.x * 6.0, -9.81, dir.z * 6.0))
	self.object:set_animation({ x = 168, y = 187 }, 60, 0, true)
	if nearest_dist < 2.5 or self._enemy_boss_dragoncall_timer <= 0 then
		self._enemy_boss_dragoncall_phase = "spinkick_wind"
		self._enemy_boss_dragoncall_timer = 0.75
		self._spinkick_yaw = minetest.dir_to_yaw(dir)
		self.object:set_velocity(vector.new(dir.x * 1.5, 8, dir.z * 1.5))
		minetest.sound_play("hugo_karate" .. math.random(1, 4),
			{ pos = pos, gain = 1.3, max_hear_distance = 25 })
	end
end

local function enemy_boss_dragoncall_spinkick_wind(self, dtime, pos, nearest, nearest_dist)
	self._enemy_boss_dragoncall_timer = self._enemy_boss_dragoncall_timer - dtime
	-- One full rotation over 0.75 s; also tilt back 30°
	local spin_speed = (math.pi * 2) / 0.75
	self._spinkick_yaw = self._spinkick_yaw + spin_speed * dtime
	self.object:set_rotation({ x = -math.pi / 6, y = self._spinkick_yaw, z = 0 })
	self.object:set_animation({ x = 189, y = 198 }, 50, 0, true)
	-- Gentle drift toward player while airborne
	local ppos = nearest:get_pos()
	local dir  = vector.direction(pos, ppos)
	self.object:set_velocity(vector.new(dir.x * 1.5, 0.5, dir.z * 1.5))
	if self._enemy_boss_dragoncall_timer <= 0 then
		-- Deal damage only on landing hit
		if nearest_dist < 3.5 then
			if nearest:is_player() then
				nearest:set_hp(math.max(0, nearest:get_hp() - self._damage * 3), { type = "punch" })
			else
				nearest:punch(self.object, 1.0,
					{ damage_groups = { fleshy = self._damage * 3 } }, dir)
			end
			nearest:add_velocity(vector.multiply(dir, 5))
			minetest.sound_play("hugo_hit", { pos = pos, gain = 1.3, max_hear_distance = 22 })
		end
		-- Impact particles
		minetest.add_particlespawner({
			amount = 20,
			time = 0.2,
			minpos = vector.add(pos, vector.new(-0.8, 0, -0.8)),
			maxpos = vector.add(pos, vector.new(0.8, 1.5, 0.8)),
			minvel = vector.new(-4, 1, -4),
			maxvel = vector.new(4, 4, 4),
			minacc = vector.new(0, -3, 0),
			maxacc = vector.new(0, 0, 0),
			minexptime = 0.2,
			maxexptime = 0.5,
			minsize = 1,
			maxsize = 3,
			texture = "aura_particle.png^[colorize:#FFCC44:180",
			glow = 8,
		})
		self.object:set_rotation({ x = 0, y = self._spinkick_yaw, z = 0 })
		self._enemy_boss_dragoncall_phase = "recover"
		self._enemy_boss_dragoncall_timer = 0.8
	end
end

-- Hugo tornado: spin in place, continuous damage to nearby targets
local function enemy_boss_dragoncall_tornado(self, dtime, pos, nearest, nearest_dist)
	self._enemy_boss_dragoncall_timer = self._enemy_boss_dragoncall_timer - dtime
	self._tornado_dmg_tick = self._tornado_dmg_tick - dtime
	-- 3 full rotations per second
	self._spinkick_yaw = self._spinkick_yaw + math.pi * 6 * dtime
	self.object:set_rotation({ x = 0, y = self._spinkick_yaw, z = 0 })
	self.object:set_velocity(vector.new(0, -9.81, 0))
	self.object:set_animation({ x = 168, y = 187 }, 80, 0, true)
	-- Wind particles
	minetest.add_particlespawner({
		amount = 5,
		time = 0.1,
		minpos = vector.add(pos, vector.new(-1.2, 0.3, -1.2)),
		maxpos = vector.add(pos, vector.new(1.2, 2.0, 1.2)),
		minvel = vector.new(-5, 0.5, -5),
		maxvel = vector.new(5, 2.0, 5),
		minacc = vector.new(0, -1, 0),
		maxacc = vector.new(0, 0, 0),
		minexptime = 0.2,
		maxexptime = 0.5,
		minsize = 1,
		maxsize = 2.5,
		texture = "aura_particle.png^[colorize:#CCFFFF:140",
		glow = 5,
	})
	-- Damage nearby every 0.25 s
	if self._tornado_dmg_tick <= 0 then
		self._tornado_dmg_tick = 0.25
		if nearest_dist < 2.5 then
			if nearest:is_player() then
				nearest:set_hp(math.max(0, nearest:get_hp() - self._damage), { type = "punch" })
			else
				nearest:punch(self.object, 1.0,
					{ damage_groups = { fleshy = self._damage } }, vector.new(0, 0, 0))
			end
		end
	end
	if self._enemy_boss_dragoncall_timer <= 0 then
		self.object:set_rotation({ x = 0, y = self._spinkick_yaw, z = 0 })
		self._enemy_boss_dragoncall_phase = "recover"
		self._enemy_boss_dragoncall_timer = 1.0
	end
end

-- Hugo feint: fake rush past the player, hard reverse, backstab
local function enemy_boss_dragoncall_feint_dash(self, dtime, pos, nearest, nearest_dist)
	self._enemy_boss_dragoncall_timer = self._enemy_boss_dragoncall_timer - dtime
	local ppos                        = nearest:get_pos()
	local dir                         = vector.direction(pos, ppos)
	-- Overshoot: aim slightly past the player
	self._feint_dir                   = dir
	self.object:set_yaw(minetest.dir_to_yaw(dir))
	self.object:set_velocity(vector.new(dir.x * 9, -9.81, dir.z * 9))
	self.object:set_animation({ x = 168, y = 187 }, 70, 0, true)
	if self._enemy_boss_dragoncall_timer <= 0 then
		self._enemy_boss_dragoncall_phase = "feint_backstab"
		self._enemy_boss_dragoncall_timer = 0.5
		minetest.sound_play("hugo_karate" .. math.random(1, 4),
			{ pos = pos, gain = 1.1, max_hear_distance = 22 })
	end
end

local function enemy_boss_dragoncall_feint_backstab(self, dtime, pos, nearest, nearest_dist)
	self._enemy_boss_dragoncall_timer = self._enemy_boss_dragoncall_timer - dtime
	-- Reverse hard back toward player's previous position
	local ppos = nearest:get_pos()
	local back = vector.direction(pos, ppos)
	self.object:set_yaw(minetest.dir_to_yaw(back))
	self.object:set_velocity(vector.new(back.x * 10, -9.81, back.z * 10))
	self.object:set_animation({ x = 189, y = 198 }, 60, 0, true)
	if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
		-- Extra damage for a back strike
		if nearest:is_player() then
			nearest:set_hp(math.max(0, nearest:get_hp() - self._damage * 2.5), { type = "punch" })
		else
			nearest:punch(self.object, 1.0,
				{ damage_groups = { fleshy = math.floor(self._damage * 2.5) } }, back)
		end
		self._attack_cooldown = 1.0
		minetest.sound_play("hugo_hit", { pos = pos, gain = 1.1, max_hear_distance = 20 })
	end
	if self._enemy_boss_dragoncall_timer <= 0 then
		self._enemy_boss_dragoncall_phase = "recover"
		self._enemy_boss_dragoncall_timer = 1.2
	end
end

-- Hugo summon: retreat + channel Dragon
local function enemy_boss_dragoncall_summon(self, dtime, pos, nearest)
	self._enemy_boss_dragoncall_timer = self._enemy_boss_dragoncall_timer - dtime

	-- Retreat from player
	local ppos = nearest:get_pos()
	local away = vector.direction(ppos, pos)
	self.object:set_velocity(vector.new(away.x * 3, -9.81, away.z * 3))
	self.object:set_yaw(minetest.dir_to_yaw(vector.direction(pos, ppos)))

	-- Glow effect intensifies
	local glow = math.floor(14 - self._enemy_boss_dragoncall_timer * 4)
	self.object:set_properties({ glow = math.min(glow, 14) })

	-- Channeling particles (swirling dark energy around Hugo)
	minetest.add_particlespawner({
		amount = 8,
		time = 0.2,
		minpos = vector.add(pos, vector.new(-1.5, 0, -1.5)),
		maxpos = vector.add(pos, vector.new(1.5, 2.5, 1.5)),
		minvel = vector.new(-2, 1, -2),
		maxvel = vector.new(2, 3, 2),
		minacc = vector.new(0, 0.5, 0),
		maxacc = vector.new(0, 1.5, 0),
		minexptime = 0.3,
		maxexptime = 0.7,
		minsize = 2,
		maxsize = 4,
		texture = "aura_particle.png^[colorize:#386dff:200",
		glow = 12,
	})

	-- Turn black at halfway
	if self._enemy_boss_dragoncall_timer < 1.5 and not self._enemy_boss_dragoncall_turned_black then
		self._enemy_boss_dragoncall_turned_black = true
		self.object:set_properties({
			textures = { "boss_hugo.png^[colorize:#000000:200" },
		})
		-- Dark flash burst
		minetest.add_particlespawner({
			amount = 30,
			time = 0.3,
			minpos = vector.add(pos, vector.new(-0.5, 0.5, -0.5)),
			maxpos = vector.add(pos, vector.new(0.5, 2.0, 0.5)),
			minvel = vector.new(-4, 0, -4),
			maxvel = vector.new(4, 4, 4),
			minacc = vector.new(0, -2, 0),
			maxacc = vector.new(0, 0, 0),
			minexptime = 0.5,
			maxexptime = 1.0,
			minsize = 3,
			maxsize = 6,
			texture = "aura_particle.png^[colorize:#1a3888:200",
			glow = 10,
		})
	end

	if self._enemy_boss_dragoncall_timer <= 0 then
		-- Summon the Dragon!
		self.object:set_velocity(vector.new(0, -9.81, 0))
		local spawn_pos = vector.add(pos, vector.new(0, 2, 3))
		-- Block summon while victory dragon is alive
		if boss._victory_dragon_obj and boss._victory_dragon_obj:get_pos() then return end
		local dragon = minetest.add_entity(spawn_pos, "boss:summoned_dragon")
		if dragon then
			self._summoned_dragon = dragon
			local dlua = dragon:get_luaentity()
			if dlua then
				dlua._master = self.object
			end
			minetest.sound_play("dragon_roar1", { pos = spawn_pos, gain = 1.5, max_hear_distance = 50 })

			-- Lightning bolt particles from sky
			minetest.add_particlespawner({
				amount = 40,
				time = 0.2,
				minpos = vector.add(spawn_pos, vector.new(-0.3, 10, -0.3)),
				maxpos = vector.add(spawn_pos, vector.new(0.3, 15, 0.3)),
				minvel = vector.new(-0.5, -30, -0.5),
				maxvel = vector.new(0.5, -20, 0.5),
				minacc = vector.new(0, 0, 0),
				maxacc = vector.new(0, 0, 0),
				minexptime = 0.15,
				maxexptime = 0.3,
				minsize = 2,
				maxsize = 4,
				texture = "aura_particle.png^[colorize:#CC88FF:120",
				glow = 14,
			})
		end

		self._enemy_boss_dragoncall_phase = "linked"
		self.object:set_properties({
			nametag = "Hugo [beschermd door de Draak]",
			nametag_color = "#AA00FF",
		})
	end
end

-- Hugo linked: invulnerable while Dragon lives, stands still
local function enemy_boss_dragoncall_linked(self, dtime, pos, nearest)
	-- Check if Dragon is still alive
	if not self._summoned_dragon or not self._summoned_dragon:get_pos() then
		-- Dragon died — Hugo dies too
		enemy.boss_alive = nil
		self.object:remove()
		enemy.check_wave_clear()
		return
	end

	-- Hugo stands completely still, facing player
	local ppos = nearest:get_pos()
	self.object:set_yaw(minetest.dir_to_yaw(vector.direction(pos, ppos)))
	self.object:set_velocity(vector.new(0, -9.81, 0))
	self.object:set_animation({ x = 0, y = 79 }, 10, 0, true)

	-- Play ambient hugo1-4 clips periodically
	self._hugo_ambient_timer = self._hugo_ambient_timer - dtime
	if self._hugo_ambient_timer <= 0 then
		self._hugo_ambient_timer = 3.5 + math.random() * 3.0 -- next clip in 3.5-6.5 s
		minetest.sound_play("hugo" .. math.random(1, 4),
			{ pos = pos, gain = 0.1, max_hear_distance = 20 })
	end
end

-- ============================================================
-- Bram (level 1) — drumstick rage phase
-- "normal"   : standard walk + swing
-- "pullout"  : freezes, theatrically pulls drumsticks from ears
-- "drumstick": fast furious drumstick attacks
-- ============================================================

local function bram_normal_step(self, dtime, pos, nearest, nearest_dist)
	local ppos = nearest:get_pos()
	local dir = vector.direction(pos, ppos)
	self.object:set_yaw(minetest.dir_to_yaw(dir))
	self.object:set_velocity(vector.new(dir.x * 1.8, -9.81, dir.z * 1.8))
	self.object:set_animation({ x = 168, y = 187 }, 30, 0, true)

	self._attack_cooldown = self._attack_cooldown - dtime
	if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
		if nearest:is_player() then
			nearest:set_hp(nearest:get_hp() - self._damage, { type = "punch" })
		else
			nearest:punch(self.object, 1.0, { damage_groups = { fleshy = self._damage } }, vector.new(0, 0, 0))
		end
		self._attack_cooldown = 1.5
		self.object:set_animation({ x = 189, y = 198 }, 30, 0, false)
	end
end

local function bram_pullout_step(self, dtime, pos)
	self.object:set_velocity(vector.new(0, -9.81, 0))
	self._bram_timer = self._bram_timer - dtime

	-- Idle "rummaging" animation
	self.object:set_animation({ x = 0, y = 79 }, 10, 0, true)

	if self._bram_timer <= 0 then
		self._bram_phase = "drumstick"
		self._attack_cooldown = 0
		-- Spawn drumstick and attach to right arm
		if not self._drumstick_entity then
			local ds = minetest.add_entity(pos, "boss:drumstick_visual")
			if ds then
				ds:set_attach(self.object, "Arm_Right", vector.new(0, -6, 0), vector.new(90, 0, 0))
				self._drumstick_entity = ds
			end
		end
		self.object:set_properties({
			nametag = "Bram [TROMMELSTOKKEN!!!]",
			nametag_color = "#FF8800",
		})
	end
end

local function bram_drumstick_step(self, dtime, pos, nearest, nearest_dist)
	local ppos = nearest:get_pos()
	local dir = vector.direction(pos, ppos)
	self.object:set_yaw(minetest.dir_to_yaw(dir))

	-- Faster charge
	self.object:set_velocity(vector.new(dir.x * 3.5, -9.81, dir.z * 3.5))
	self.object:set_animation({ x = 168, y = 187 }, 55, 0, true)

	self._attack_cooldown = self._attack_cooldown - dtime
	if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
		local dmg = math.ceil(self._damage * 1.5)
		if nearest:is_player() then
			nearest:set_hp(nearest:get_hp() - dmg, { type = "punch" })
		else
			nearest:punch(self.object, 1.0, { damage_groups = { fleshy = dmg } }, vector.new(0, 0, 0))
		end
		self._attack_cooldown = 0.5 -- rapid drumstick cadence
		self.object:set_animation({ x = 189, y = 198 }, 65, 0, false)
	end
end

-- ============================================================
-- ============================================================
-- Choco splash helper (used by Julian's choco_drop entity)
-- ============================================================
local function choco_splash(pos)
	minetest.add_particlespawner({
		amount = 20,
		time = 0.3,
		minpos = vector.add(pos, vector.new(-0.2, 0, -0.2)),
		maxpos = vector.add(pos, vector.new(0.2, 0.1, 0.2)),
		minvel = vector.new(-3, 1, -3),
		maxvel = vector.new(3, 4, 3),
		minacc = vector.new(0, -10, 0),
		maxacc = vector.new(0, -10, 0),
		minexptime = 0.25,
		maxexptime = 0.6,
		minsize = 1.5,
		maxsize = 3,
		texture = "wool_brown.png",
	})
	minetest.sound_play("default_water_footstep", { pos = pos, gain = 0.6, max_hear_distance = 14 })
end

-- ============================================================
-- Generic boss on_step (non-Hugo, non-Bram levels)
-- ============================================================
local function generic_on_step(self, dtime, pos, nearest, nearest_dist)
	local ppos = nearest:get_pos()
	local dir = vector.direction(pos, ppos)

	self.object:set_yaw(minetest.dir_to_yaw(dir))

	local speed = 1.8
	self.object:set_velocity(vector.new(dir.x * speed, -9.81, dir.z * speed))

	self._attack_cooldown = self._attack_cooldown - dtime
	if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
		if nearest:is_player() then
			nearest:set_hp(nearest:get_hp() - self._damage, { type = "punch" })
		else
			nearest:punch(self.object, 1.0, { damage_groups = { fleshy = self._damage } }, vector.new(0, 0, 0))
		end
		self._attack_cooldown = 1.5
		self.object:set_animation({ x = 189, y = 198 }, 30, 0, false)
		minetest.after(0.5, function()
			if self.object and self.object:get_pos() then
				self.object:set_animation({ x = 168, y = 187 }, 30, 0, true)
			end
		end)
	end
end

-- ============================================================
-- Julian (level 4): hot chocolate shoulder pour attack
-- ============================================================
local function julian_step(self, dtime, pos, nearest, nearest_dist)
	self._julian_timer = self._julian_timer - dtime

	if self._julian_phase == "normal" then
		-- Walk toward player
		local ppos = nearest:get_pos()
		local dir = vector.direction(pos, ppos)
		self.object:set_yaw(minetest.dir_to_yaw(dir))
		self.object:set_velocity(vector.new(dir.x * 2.0, -9.81, dir.z * 2.0))
		self.object:set_animation({ x = 168, y = 187 }, 30, 0, true)

		-- Melee
		self._attack_cooldown = self._attack_cooldown - dtime
		if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
			if nearest:is_player() then
				nearest:set_hp(math.max(0, nearest:get_hp() - self._damage), { type = "punch" })
			else
				nearest:punch(self.object, 1.0, { damage_groups = { fleshy = self._damage } }, vector.new(0, 0, 0))
			end
			self._attack_cooldown = 1.5
			self.object:set_animation({ x = 189, y = 198 }, 30, 0, false)
		end

		-- Transition to pour
		if self._julian_timer <= 0 then
			self._julian_phase = "pour"
			self._julian_timer = 2.8
			self._julian_pour_tick = 0
			self._attack_cooldown = 0
		end
	elseif self._julian_phase == "pour" then
		-- Stand still, face player
		local ppos = nearest:get_pos()
		local dir = vector.direction(pos, ppos)
		self.object:set_yaw(minetest.dir_to_yaw(dir))
		self.object:set_velocity(vector.new(0, -9.81, 0))
		self.object:set_animation({ x = 189, y = 198 }, 20, 0, true)

		-- Right-shoulder position
		local yaw = minetest.dir_to_yaw(dir)
		local shoulder_pos = vector.add(pos, vector.new(
			math.cos(yaw + math.pi / 2) * 0.55,
			1.5,
			math.sin(yaw + math.pi / 2) * 0.55
		))

		-- Particle burst every tick
		self._julian_pour_tick = self._julian_pour_tick + dtime
		if self._julian_pour_tick >= 0.07 then
			self._julian_pour_tick = 0
			minetest.add_particlespawner({
				amount = 14,
				time = 0.12,
				minpos = vector.add(shoulder_pos, vector.new(-0.08, 0, -0.08)),
				maxpos = vector.add(shoulder_pos, vector.new(0.08, 0.1, 0.08)),
				minvel = vector.new(dir.x * 3 - 0.4, -0.5, dir.z * 3 - 0.4),
				maxvel = vector.new(dir.x * 5 + 0.4, 0.5, dir.z * 5 + 0.4),
				minacc = vector.new(-0.2, -9, -0.2),
				maxacc = vector.new(0.2, -6, 0.2),
				minexptime = 0.35,
				maxexptime = 0.75,
				minsize = 2.5,
				maxsize = 5,
				texture = "aura_particle.png^[colorize:#3b1200:210",
				glow = 0,
			})
			-- Spawn a physical choco drop every 5th tick (~0.35 s)
			self._julian_drop_counter = (self._julian_drop_counter or 0) + 1
			if self._julian_drop_counter >= 5 then
				self._julian_drop_counter = 0
				local drop = minetest.add_entity(shoulder_pos, "boss:choco_drop")
				if drop then
					drop:set_velocity(vector.new(
						dir.x * 4 + (math.random() - 0.5) * 1.5,
						0.3 + math.random() * 0.6,
						dir.z * 4 + (math.random() - 0.5) * 1.5
					))
				end
			end
		end

		-- Damage players in forward splash cone every 0.45 s
		self._attack_cooldown = self._attack_cooldown - dtime
		if self._attack_cooldown <= 0 then
			for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 4.5)) do
				if obj:is_player() then
					local to_obj = vector.direction(pos, obj:get_pos())
					local dot = to_obj.x * dir.x + to_obj.z * dir.z
					if dot > 0.25 then
						obj:set_hp(math.max(0, obj:get_hp() - self._damage), { type = "punch" })
					end
				end
			end
			self._attack_cooldown = 0.45
		end

		-- End pour, reset cooldown for next one
		if self._julian_timer <= 0 then
			self._julian_phase = "normal"
			self._julian_timer = 7.0 + math.random() * 4.0
			self._attack_cooldown = 1.0
		end
	end
end

-- ============================================================
-- Raisin projectile (Ancient Sword right-click ability)
-- Bounces off walls; explodes on 3rd bounce OR on entity hit
-- ============================================================
local function raisin_explode(pos, owner)
	for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 1.5)) do
		if obj:is_player() then
			if not owner or obj:get_player_name() ~= owner then
				obj:set_hp(math.max(0, obj:get_hp() - 8), { type = "punch" })
			end
		else
			local ent = obj:get_luaentity()
			if ent and ent._hp and ent._level then
				ent._hp = ent._hp - 15
				if ent._hp <= 0 then
					local bpos = obj:get_pos()
					local bdata = BOSSES[ent._level] or BOSSES[1]
					if bpos and bdata.drop then minetest.add_item(bpos, bdata.drop) end
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
	minetest.add_particlespawner({
		amount = 30,
		time = 0.4,
		minpos = vector.add(pos, vector.new(-0.4, -0.4, -0.4)),
		maxpos = vector.add(pos, vector.new(0.4, 0.4, 0.4)),
		minvel = vector.new(-6, -4, -6),
		maxvel = vector.new(6, 5, 6),
		minacc = vector.new(0, -6, 0),
		maxacc = vector.new(0, -3, 0),
		minexptime = 0.15,
		maxexptime = 0.45,
		minsize = 2,
		maxsize = 5,
		texture = "aura_particle.png^[colorize:#111111:220",
		glow = 2,
	})
	minetest.sound_play("default_explode", { pos = pos, gain = 0.5, max_hear_distance = 20 })
end

minetest.register_entity("boss:choco_drop", {
	initial_properties = {
		visual = "sprite",
		visual_size = { x = 0.3, y = 0.3 },
		textures = { "aura_particle.png^[colorize:#3b1200:255" },
		physical = true,
		collide_with_objects = false,
		collisionbox = { -0.1, -0.1, -0.1, 0.1, 0.1, 0.1 },
		static_save = false,
		pointable = false,
	},

	_lifetime = 0,
	_splashed = false,
	_prev_vy = 0,

	on_activate = function(self)
		self.object:set_armor_groups({ immortal = 1 })
	end,

	on_step = function(self, dtime)
		if self._splashed then return end
		local pos = self.object:get_pos()
		if not pos then return end

		self._lifetime = self._lifetime + dtime
		if self._lifetime > 5 then
			self._splashed = true
			self.object:remove()
			return
		end

		local vel = self.object:get_velocity()

		-- Hit player directly
		if self._lifetime > 0.1 then
			for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 0.3)) do
				if obj:is_player() then
					obj:set_hp(math.max(0, obj:get_hp() - 2), { type = "punch" })
					minetest.add_particlespawner({
						amount = 10,
						time = 0.2,
						minpos = vector.add(pos, vector.new(-0.15, 0, -0.15)),
						maxpos = vector.add(pos, vector.new(0.15, 0.1, 0.15)),
						minvel = vector.new(-2, 0.5, -2),
						maxvel = vector.new(2, 2, 2),
						minacc = vector.new(0, -9, 0),
						maxacc = vector.new(0, -9, 0),
						minexptime = 0.2,
						maxexptime = 0.5,
						minsize = 1,
						maxsize = 2.5,
						texture = "aura_particle.png^[colorize:#3b1200:210",
					})
					self._splashed = true
					self.object:remove()
					return
				end
			end
		end

		-- Detect ground landing: was falling, now stopped in Y
		if self._lifetime > 0.2 and self._prev_vy < -1.5 and math.abs(vel.y) < 0.8 then
			minetest.add_particlespawner({
				amount = 16,
				time = 0.25,
				minpos = vector.add(pos, vector.new(-0.2, 0, -0.2)),
				maxpos = vector.add(pos, vector.new(0.2, 0.05, 0.2)),
				minvel = vector.new(-3, 0.5, -3),
				maxvel = vector.new(3, 2.5, 3),
				minacc = vector.new(0, -9, 0),
				maxacc = vector.new(0, -9, 0),
				minexptime = 0.2,
				maxexptime = 0.55,
				minsize = 1.5,
				maxsize = 3.5,
				texture = "aura_particle.png^[colorize:#3b1200:210",
			})
			minetest.sound_play("default_water_footstep", { pos = pos, gain = 0.5, max_hear_distance = 12 })
			self._splashed = true
			self.object:remove()
			return
		end

		self._prev_vy = vel.y
	end,
})

minetest.register_entity("boss:raisin", {
	initial_properties = {
		visual = "cube",
		visual_size = { x = 0.15, y = 0.15, z = 0.15 },
		textures = {
			"aura_particle.png^[colorize:#111111:255",
			"aura_particle.png^[colorize:#111111:255",
			"aura_particle.png^[colorize:#111111:255",
			"aura_particle.png^[colorize:#111111:255",
			"aura_particle.png^[colorize:#111111:255",
			"aura_particle.png^[colorize:#111111:255",
		},
		physical = true,
		collide_with_objects = false,
		collisionbox = { -0.07, -0.07, -0.07, 0.07, 0.07, 0.07 },
		static_save = false,
	},

	_bounces = 0,
	_prev_vel = nil,
	_bounce_cd = 0,
	_exploded = false,
	_owner = nil,
	_lifetime = 0,

	on_activate = function(self)
		self.object:set_armor_groups({ immortal = 1 })
	end,

	on_step = function(self, dtime)
		if self._exploded then return end
		local pos = self.object:get_pos()
		if not pos then return end

		-- Auto-remove after 8 seconds
		self._lifetime = self._lifetime + dtime
		if self._lifetime > 8 then
			self._exploded = true
			self.object:remove()
			return
		end

		self._bounce_cd = math.max(0, self._bounce_cd - dtime)
		local vel = self.object:get_velocity()

		-- Explode on contact with any entity
		for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 0.5)) do
			if obj ~= self.object then
				if obj:is_player() then
					if not self._owner or obj:get_player_name() ~= self._owner then
						raisin_explode(pos, self._owner)
						self._exploded = true
						self.object:remove()
						return
					end
				else
					local ent = obj:get_luaentity()
					if ent and ent.name ~= "boss:raisin" and ent.name ~= "boss:drumstick_visual" then
						if ent._hp then
							raisin_explode(pos, self._owner)
							self._exploded = true
							self.object:remove()
							return
						end
					end
				end
			end
		end

		if self._prev_vel and self._bounce_cd <= 0 then
			local pv = self._prev_vel
			local nv = { x = vel.x, y = vel.y, z = vel.z }
			local hit = false

			if math.abs(pv.x) > 2 and math.abs(vel.x) < 0.5 then
				nv.x = -pv.x * 0.85
				hit = true
			end
			if math.abs(pv.y) > 2 and math.abs(vel.y) < 0.5 then
				nv.y = math.abs(pv.y) * 0.75
				hit = true
			end
			if math.abs(pv.z) > 2 and math.abs(vel.z) < 0.5 then
				nv.z = -pv.z * 0.85
				hit = true
			end

			if hit then
				self._bounces = self._bounces + 1
				self._bounce_cd = 0.15
				if self._bounces >= 3 then
					raisin_explode(pos, self._owner)
					self._exploded = true
					self.object:remove()
					return
				end
				self.object:set_velocity(vector.new(nv.x, nv.y, nv.z))
			end
		end

		self._prev_vel = vector.new(vel.x, vel.y, vel.z)
	end,
})

-- ============================================================
-- Jan Willem (level 6): ROF (взлет), телепорт и ускорение
-- ============================================================

local JAN_WILLEM_GLITCH_NAMES = {
	"DNSProbeStart",
	"ERROR_404",
	"Jan 010110",
	"NilVariable",
	"NULL_Willem",
	"NullFile?",
	"ErrFileNotFound",
	"NxDomainFinish",
	"Willem_Exception",   -- Исключение в коде Яна
	"Jan_Core_Dumped",     -- Критический сбой ядра Яна
	"Jan_NaN_Value",       -- Не-число в вычислениях
	"Willem_Overclock",    -- Опасный разгон процессора Виллема
	"Stack_Overflow",      -- Переполнение стека
	"Segmentation_Fault",  -- Ошибка обращения к памяти
	"Kernel_Panic",        -- Паника ядра операционной системы
	"Jan_GET_403_Forbidden" -- Доступ заблокирован
}

-- Квантовая копия Яна Виллема (Иллюзия)
minetest.register_entity("boss:jan_willem_clone", {
	initial_properties = {
		visual = "mesh",
		mesh = "character.b3d",
		textures = { "boss_janwillem.png" }, -- Твоя стандартная текстура босса
		physical = true,
		collide_with_objects = false,
		collisionbox = { -0.4, 0.0, -0.4, 0.4, 2.0, 0.4 },
		visual_size = { x = 1.2, y = 1.2, z = 1.2 },
		static_save = false,
		nametag = "Jan Willem",
		nametag_color = "#ff7a70",
	},
	_lifetime = 2.0, -- Исчезнет через 2 секунды
	_glitch_timer = 0,

	on_activate = function(self)
		self.object:set_animation({ x = 168, y = 187 }, 30, 0, true) -- Стойка/ходьба
		self.object:set_armor_groups({ fleshy = 100 })
	end,

	on_punch = function(self, puncher)
		-- Если игрок бьет фантома, он мгновенно испаряется
		if puncher and puncher:is_player() then
			local pos = self.object:get_pos()
			if pos then
				-- Взрыв частиц мела при исчезновении
				minetest.add_particlespawner({
					amount = 15, time = 0.2,
					minpos = vector.add(pos, vector.new(-0.4, 0.5, -0.4)), maxpos = vector.add(pos, vector.new(0.4, 1.8, 0.4)),
					minvel = vector.new(-1, 0.5, -1), maxvel = vector.new(1, 2, 1),
					minexptime = 0.3, maxexptime = 0.6, minsize = 1.5, maxsize = 3,
					texture = "jan_willem_chalk.png", glow = 6,
				})
			end
			self.object:remove()
		end
		return true
	end,

	on_step = function(self, dtime)
		self._lifetime = self._lifetime - dtime
		if self._lifetime <= 0 then
			local pos = self.object:get_pos()
			if pos then
				-- Облако мела при авто-исчезновении по таймеру
				minetest.add_particlespawner({
					amount = 10, time = 0.1,
					minpos = vector.add(pos, vector.new(-0.3, 0.5, -0.3)), maxpos = vector.add(pos, vector.new(0.3, 1.8, 0.3)),
					minvel = vector.new(-0.5, 0.2, -0.5), maxvel = vector.new(0.5, 1, 0.5),
					minexptime = 0.4, maxexptime = 0.7, minsize = 1, maxsize = 2,
					texture = "jan_willem_chalk.png", glow = 4,
				})
			end
			self.object:remove()
		end
		-- МЕХАНИКА ГЛЮЧАЩЕГО НЕЙМТЕГА
		self._glitch_timer = self._glitch_timer - dtime
		if self._glitch_timer <= 0 then
			-- Меняем имя ОЧЕНЬ часто (каждые 0.08 сек)
			self._glitch_timer = 0.08 

			-- Шанс 75%, что имя будет правильным, и 25%, что выскочит бред на доли секунды
			local current_name = "Jan Willem"
			if math.random() < 0.40 then
				current_name = JAN_WILLEM_GLITCH_NAMES[math.random(1, #JAN_WILLEM_GLITCH_NAMES)]
			end

			self.object:set_properties({
				nametag = current_name,
				-- Можно сделать, чтобы у бредовых имён цвет тоже становился фиолетовым/жёлтым для пущего эффекта
				nametag_color = (current_name == "Jan Willem") and "#ff7a70" or "#00FFFF",
			})
		end
	end,
})

-- Декоративный объект Jan Willem: Школьная Доска с эффектом мела
minetest.register_entity("boss:jan_willem_board", {
	initial_properties = {
		visual = "sprite",
		textures = { "jan_willem_board.png" },
		visual_size = { x = 1.3, y = 1.3 },
		physical = false,
		collisionbox = { 0, 0, 0, 0, 0, 0 },
		static_save = false,
		pointable = false,
		glow = 10,
	},
	_spin              = 0,
	_bob               = 0,
	_particle_timer    = 0,

	on_activate        = function(self)
		self.object:set_armor_groups({ immortal = 1 })
	end,

	on_step            = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then return end

		-- 2. Покачиваем вверх-вниз (Bobbing)
		self._bob = self._bob + dtime * 3.0
		self.object:set_velocity(vector.new(0, math.sin(self._bob) * 0.6, 0))

		-- 3. Спавним МЕЛ в виде частиц вокруг доски!
		self._particle_timer = self._particle_timer - dtime
		if self._particle_timer <= 0 then
			self._particle_timer = 0.15 -- Частота появления крошек мела
			minetest.add_particlespawner({
				amount = 4,
				time = 0.15,
				minpos = vector.add(pos, vector.new(-0.5, -0.5, -0.5)),
				maxpos = vector.add(pos, vector.new(0.5, 0.5, 0.5)),
				minvel = vector.new(-0.5, 0.3, -0.5),
				maxvel = vector.new(0.5, 1.0, 0.5),
				minacc = vector.new(0, -0.4, 0),
				maxacc = vector.new(0, 0, 0),
				minexptime = 0.4,
				maxexptime = 0.8,
				minsize = 1,
				maxsize = 2.5,
				texture = "jan_willem_chalk.png", -- Твоя текстура мела
				glow = 5,
			})
		end
	end,
})

local function jan_willem_step(self, dtime, pos, nearest, nearest_dist)
	self._jan_timer = self._jan_timer - dtime

	local data = BOSSES[self._level]

	-- Таймер режима ускорения
	if self._speed_timer > 0 then
		self._speed_timer = self._speed_timer - dtime
		if self._speed_timer <= 0 then
			self._speed_mult = 1.0
			-- Сброс имени на обычное
			self.object:set_properties({
				nametag = (data and data.name or "Jan Willem") .. " [" .. math.max(0, self._hp) .. "/" .. self._max_hp .. "]",
				nametag_color = "#FFFFFF",
			})
		end
	end

	if self._jan_phase == "normal" then
		-- Бег к игроку
		local ppos = nearest:get_pos()
		local dir = vector.direction(pos, ppos)
		self.object:set_yaw(minetest.dir_to_yaw(dir))

		local speed = 1.8 * self._speed_mult
		self.object:set_velocity(vector.new(dir.x * speed, -9.81, dir.z * speed))
		self.object:set_animation({ x = 168, y = 187 }, 30 * self._speed_mult, 0, true)

		-- Ближний бой
		self._attack_cooldown = self._attack_cooldown - dtime
		if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
			if nearest:is_player() then
				nearest:set_hp(math.max(0, nearest:get_hp() - self._damage), { type = "punch" })
			else
				nearest:punch(self.object, 1.0, { damage_groups = { fleshy = self._damage } }, vector.new(0, 0, 0))
			end
			self._attack_cooldown = 1.5 / self._speed_mult
			self.object:set_animation({ x = 189, y = 198 }, 30 * self._speed_mult, 0, false)
		end

		-- Переход в режим ROF (Взлет)
		if self._jan_timer <= 0 then
			self._jan_phase = "floating_prep"
			self._jan_timer = 3.5
			self._jan_board_spawned = false
			self._jan_next_attack = (math.random() > 0.5) and "teleport" or "speed"

			if self._jan_board_entity and self._jan_board_entity:get_pos() then
				self._jan_board_entity:remove()
				self._jan_board_entity = nil
			end

			-- Взлетаем вверх
			self.object:set_velocity(vector.new(0, 5, 0))

			-- Включаем речь
			if self._jan_speech_sound then
				minetest.sound_stop(self._jan_speech_sound)
			end
			self._jan_speech_sound = minetest.sound_play("jan_speech" .. math.random(1, 2),
				{ pos = pos, gain = 1.5, max_hear_distance = 30, loop = false })

			minetest.chat_send_all("Jan Willem pakt zijn bord...")
		end

	elseif self._jan_phase == "floating_prep" then
		-- Парение во время подготовки
		self.object:set_velocity(vector.new(0, 0.2, 0))
		self.object:set_animation({ x = 189, y = 198 }, 20, 0, true)
		
		local ppos = nearest:get_pos()
		self.object:set_yaw(minetest.dir_to_yaw(vector.direction(pos, ppos)))

		-- Спавн крутящейся доски (с твоими частицами мела внутри энтити!)
		if not self._jan_board_spawned and self._jan_timer < 3.0 then
			self._jan_board_spawned = true
			local spawn_pos = vector.add(pos, vector.new(0.5, 1.8, 0))
			local ent = minetest.add_entity(spawn_pos, "boss:jan_willem_board")
			self._jan_board_entity = ent
			
			minetest.sound_play("default_place_node_hard", { pos = pos, gain = 0.5, max_hear_distance = 15 })
		end

		if self._jan_board_entity and self._jan_board_entity:get_pos() then
			self._jan_board_entity:set_pos(vector.add(pos, vector.new(0.5, 1.8, 0)))
		end

		-- ROF закончен -> Время Квантового Разделения!
		if self._jan_timer <= 0 then
			if self._jan_speech_sound then
				minetest.sound_stop(self._jan_speech_sound)
				self._jan_speech_sound = nil
			end
			if self._jan_board_entity and self._jan_board_entity:get_pos() then
				self._jan_board_entity:remove()
				self._jan_board_entity = nil
			end

			-- СПАВН 2 КОПИЙ (Суперпозиция)
			-- Настоящий босс и копии будут стоять в треугольнике вокруг игрока или текущей позиции
			for i = 1, 3 do
				local offset = vector.new(math.random(-4, 4), 0, math.random(-4, 4))
				local clone_pos = vector.add(pos, offset)
				local clone = minetest.add_entity(clone_pos, "boss:jan_willem_clone")
				if clone then
					clone:set_yaw(self.object:get_yaw())
					-- Облако мела при появлении копии
					minetest.add_particlespawner({
						amount = 15, time = 0.2,
						minpos = vector.add(clone_pos, vector.new(-0.4, 0, -0.4)), maxpos = vector.add(clone_pos, vector.new(0.4, 1.5, 0.4)),
						minvel = vector.new(-1, 1, -1), maxvel = vector.new(1, 2, 1),
						minexptime = 0.4, maxexptime = 0.8, minsize = 2, maxsize = 4,
						texture = "jan_willem_chalk.png", glow = 8,
					})
				end
			end

			-- Сама атака босса
			if self._jan_next_attack == "teleport" then
				-- АТАКА 1: Телепорт к игроку за спину / впритык
				local tpos = nearest:get_pos()
				self.object:set_pos(tpos)

				-- Частицы мела на месте появления настоящего босса
				minetest.add_particlespawner({
					amount = 20, time = 0.2,
					minpos = vector.add(tpos, vector.new(-0.5, 0, -0.5)), maxpos = vector.add(tpos, vector.new(0.5, 1.5, 0.5)),
					minvel = vector.new(-2, 1, -2), maxvel = vector.new(2, 3, 2),
					minexptime = 0.4, maxexptime = 0.8, minsize = 2, maxsize = 4,
					texture = "jan_willem_chalk.png", glow = 8,
				})

				if nearest:is_player() then
					nearest:set_hp(math.max(0, nearest:get_hp() - (self._damage * 1.5)), { type = "punch" })
				else
					nearest:punch(self.object, 1.0, { damage_groups = { fleshy = math.floor(self._damage * 1.5) } }, vector.new(0,0,0))
				end
				self._attack_cooldown = 1.2

				self._jan_phase = "normal"
				self._jan_timer = 7.0 + math.random() * 4.0

			elseif self._jan_next_attack == "speed" then
				-- АТАКА 2: Разгон частиц (Скорость x2!)
				self._speed_mult = 2.0
				self._speed_timer = 8.0 -- Бешеный бег длится 8 секунд
				
				self.object:set_properties({
					nametag = "Jan Willem [" .. math.max(0, self._hp) .. "/" .. self._max_hp .. "] 2X snelheid!",
					nametag_color = "#FF1111",
				})

				self._jan_phase = "normal"
				self._jan_timer = 10.0 + math.random() * 3.0
			end
		end
	end
end

-- Phases: "normal" → "drawing" → "armed" → (redraw after timer)
-- Allowed weapons (blacklist: diamond, ancient, dragonpower, elements)
-- ============================================================

local VANESSA_WEAPONS = {
	{ item = "registered:sword_wood",   dmg = 4, name = "Houten Zwaard" },
	{ item = "registered:sword_steel",  dmg = 7, name = "Stalen Zwaard" },
	{ item = "registered:sword_bronze", dmg = 9, name = "Bronzen Zwaard" },
}

-- Unfinished weapon entity: floats and spins while Vanessa draws
minetest.register_entity("boss:unfinished_weapon", {
	initial_properties = {
		visual = "sprite",
		textures = { "drawing_item_ent.png" },
		visual_size = { x = 1.0, y = 1.0 },
		physical = false,
		collisionbox = { 0, 0, 0, 0, 0, 0 },
		static_save = false,
		pointable = false,
		glow = 10,
	},
	_spin              = 0,
	_bob               = 0,
	_particle_timer    = 0,
	on_activate        = function(self)
		self.object:set_armor_groups({ immortal = 1 })
	end,
	on_step            = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then return end
		-- Spin
		self._spin = self._spin + dtime * 5.0
		self.object:set_yaw(self._spin)
		-- Bob up/down
		self._bob = self._bob + dtime * 3.0
		self.object:set_velocity(vector.new(0, math.sin(self._bob) * 0.6, 0))
		-- Sketch particles
		self._particle_timer = self._particle_timer - dtime
		if self._particle_timer <= 0 then
			self._particle_timer = 0.15
			minetest.add_particlespawner({
				amount = 3,
				time = 0.15,
				minpos = vector.add(pos, vector.new(-0.4, -0.4, -0.4)),
				maxpos = vector.add(pos, vector.new(0.4, 0.4, 0.4)),
				minvel = vector.new(-0.5, 0.5, -0.5),
				maxvel = vector.new(0.5, 1.5, 0.5),
				minacc = vector.new(0, -0.5, 0),
				maxacc = vector.new(0, 0, 0),
				minexptime = 0.3,
				maxexptime = 0.7,
				minsize = 1,
				maxsize = 2.5,
				texture = "boss_vanessa_stick.png",
				glow = 4,
			})
		end
	end,
})

-- Vanessa drawing logic
local function vanessa_step(self, dtime, pos, nearest, nearest_dist)
	self._vanessa_timer = self._vanessa_timer - dtime

	if self._vanessa_phase == "normal" then
		-- Walk + melee, then trigger drawing phase
		local ppos = nearest:get_pos()
		local dir = vector.direction(pos, ppos)
		self.object:set_yaw(minetest.dir_to_yaw(dir))
		self.object:set_velocity(vector.new(dir.x * 2.0, -9.81, dir.z * 2.0))
		self.object:set_animation({ x = 168, y = 187 }, 30, 0, true)

		self._attack_cooldown = self._attack_cooldown - dtime
		if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
			if nearest:is_player() then
				nearest:set_hp(math.max(0, nearest:get_hp() - self._damage), { type = "punch" })
			else
				nearest:punch(self.object, 1.0, { damage_groups = { fleshy = self._damage } }, vector.new(0, 0, 0))
			end
			self._attack_cooldown = 1.5
			self.object:set_animation({ x = 189, y = 198 }, 30, 0, false)
		end

		if self._vanessa_timer <= 0 then
			self._vanessa_phase   = "drawing"
			self._vanessa_timer   = 3.5
			self._drawing_spawned = false
			-- Remove old weapon visual
			if self._weapon_entity and self._weapon_entity:get_pos() then
				self._weapon_entity:remove()
				self._weapon_entity = nil
			end
			-- Start drawing sound (looped, stopped when drawing ends)
			if self._draw_sound then
				minetest.sound_stop(self._draw_sound)
			end
			self._draw_sound = minetest.sound_play("vanessa_draw",
				{ pos = pos, gain = 1.0, max_hear_distance = 20, loop = true })
			-- Random voice clip while drawing
			local vanessa_clips = { "vanessa_doodle", "vanessa_tch" }
			minetest.sound_play(vanessa_clips[math.random(1, #vanessa_clips)],
				{ pos = pos, gain = 1.2, max_hear_distance = 25 })
			-- Jump/float up
			self.object:set_velocity(vector.new(0, 5, 0))
			for _, p in ipairs(minetest.get_connected_players()) do
				minetest.chat_send_player(p:get_player_name(),
					"Vanessa pakt haar potlood... ze tekent haar nieuwe wapen!")
			end
		end
	elseif self._vanessa_phase == "drawing" then
		-- Float in place, run mine animation
		self.object:set_velocity(vector.new(0, 0.2, 0))
		self.object:set_animation({ x = 189, y = 198 }, 20, 0, true)
		local ppos = nearest:get_pos()
		self.object:set_yaw(minetest.dir_to_yaw(vector.direction(pos, ppos)))

		-- Spawn the unfinished weapon entity once, shortly after entry
		if not self._drawing_spawned and self._vanessa_timer < 3.0 then
			self._drawing_spawned = true
			local spawn_pos = vector.add(pos, vector.new(0, 1.8, 0))
			local ent = minetest.add_entity(spawn_pos, "boss:unfinished_weapon")
			self._drawing_entity = ent
			minetest.add_particlespawner({
				amount = 20,
				time = 0.3,
				minpos = vector.add(spawn_pos, vector.new(-0.5, -0.5, -0.5)),
				maxpos = vector.add(spawn_pos, vector.new(0.5, 0.5, 0.5)),
				minvel = vector.new(-2, 1, -2),
				maxvel = vector.new(2, 3, 2),
				minacc = vector.new(0, -1, 0),
				maxacc = vector.new(0, 0, 0),
				minexptime = 0.3,
				maxexptime = 0.8,
				minsize = 1,
				maxsize = 3,
				texture = "boss_vanessa_stick.png",
				glow = 6,
			})
			minetest.sound_play("default_place_node_hard",
				{ pos = pos, gain = 0.5, max_hear_distance = 15 })
		end

		-- Keep unfinished weapon hovering near her hand
		if self._drawing_entity and self._drawing_entity:get_pos() then
			self._drawing_entity:set_pos(vector.add(pos, vector.new(0.5, 1.8, 0)))
		end

		-- Drawing done — pick weapon and enter armed phase
		if self._vanessa_timer <= 0 then
			-- Stop drawing sound
			if self._draw_sound then
				minetest.sound_stop(self._draw_sound)
				self._draw_sound = nil
			end
			if self._drawing_entity and self._drawing_entity:get_pos() then
				self._drawing_entity:remove()
				self._drawing_entity = nil
			end

			-- Pick random allowed weapon
			local wdata = VANESSA_WEAPONS[math.random(1, #VANESSA_WEAPONS)]
			self._drawn_weapon = wdata
			self._damage = wdata.dmg

			-- Attach weapon visual to right arm
			local wobj = minetest.add_entity(pos, "boss:drumstick_visual")
			if wobj then
				wobj:set_properties({ wield_item = wdata.item })
				wobj:set_attach(self.object, "Arm_Right", vector.new(0, -6, 0), vector.new(90, 0, 0))
				self._weapon_entity = wobj
			end

			-- Update nametag
			local data = BOSSES[self._level] or BOSSES[1]
			self.object:set_properties({
				nametag = data.name .. " [" .. math.max(0, self._hp) .. "/" .. self._max_hp .. "] ✏ " .. wdata.name,
				nametag_color = "#FF88AA",
			})

			-- Completion flash
			minetest.add_particlespawner({
				amount = 25,
				time = 0.3,
				minpos = vector.add(pos, vector.new(-0.5, 0.5, -0.5)),
				maxpos = vector.add(pos, vector.new(0.5, 2.0, 0.5)),
				minvel = vector.new(-3, 1, -3),
				maxvel = vector.new(3, 4, 3),
				minacc = vector.new(0, -2, 0),
				maxacc = vector.new(0, 0, 0),
				minexptime = 0.2,
				maxexptime = 0.6,
				minsize = 2,
				maxsize = 4,
				texture = "aura_particle.png^[colorize:#FFAACC:200",
				glow = 8,
			})
			minetest.sound_play("default_place_node_hard",
				{ pos = pos, gain = 0.8, max_hear_distance = 20 })

			self._vanessa_phase = "armed"
			self._vanessa_timer = 12.0 + math.random() * 8.0 -- redraw after 12–20 sec
		end
	elseif self._vanessa_phase == "armed" then
		-- Fight with drawn weapon
		local ppos = nearest:get_pos()
		local dir = vector.direction(pos, ppos)
		self.object:set_yaw(minetest.dir_to_yaw(dir))
		self.object:set_velocity(vector.new(dir.x * 2.2, -9.81, dir.z * 2.2))
		self.object:set_animation({ x = 168, y = 187 }, 35, 0, true)

		self._attack_cooldown = self._attack_cooldown - dtime
		if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
			if nearest:is_player() then
				nearest:set_hp(math.max(0, nearest:get_hp() - self._damage), { type = "punch" })
			else
				nearest:punch(self.object, 1.0, { damage_groups = { fleshy = self._damage } }, vector.new(0, 0, 0))
			end
			self._attack_cooldown = 1.2
			self.object:set_animation({ x = 189, y = 198 }, 40, 0, false)
		end

		-- Redraw timer expired → go draw again
		if self._vanessa_timer <= 0 then
			self._vanessa_phase = "normal"
			self._vanessa_timer = 0.1
		end
	end
end

-- ============================================================
-- Margriet (level 7): summons Joachim, Vanessa or Jan Willem
-- ============================================================
local function margriet_step(self, dtime, pos, nearest, nearest_dist)
	local ppos = nearest:get_pos()
	local dir  = vector.direction(pos, ppos)

	if self._margriet_phase == "normal" then
		-- Standard walk + melee
		self.object:set_yaw(minetest.dir_to_yaw(dir))
		self.object:set_velocity(vector.new(dir.x * 2.2, -9.81, dir.z * 2.2))
		self.object:set_animation({ x = 168, y = 187 }, 30, 0, true)

		self._attack_cooldown = self._attack_cooldown - dtime
		if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
			if nearest:is_player() then
				nearest:set_hp(math.max(0, nearest:get_hp() - self._damage), { type = "punch" })
			else
				nearest:punch(self.object, 1.0, { damage_groups = { fleshy = self._damage } }, vector.new(0, 0, 0))
			end
			self._attack_cooldown = 1.5
			self.object:set_animation({ x = 189, y = 198 }, 30, 0, false)
		end

		-- Periodic summon every 20 seconds
		self._margriet_timer = self._margriet_timer - dtime
		if self._margriet_timer <= 0 then
			self._margriet_phase = "summon"
			self._margriet_timer = 3.0 -- channeling duration
		end
	elseif self._margriet_phase == "summon" then
		-- Stand still, channel for 3 seconds, then spawn a helper boss
		self._margriet_timer = self._margriet_timer - dtime
		self.object:set_velocity(vector.new(0, -9.81, 0))
		self.object:set_yaw(minetest.dir_to_yaw(dir))
		self.object:set_animation({ x = 0, y = 79 }, 10, 0, true)

		-- Swirling orange/red channeling particles
		minetest.add_particlespawner({
			amount     = 10,
			time       = 0.2,
			minpos     = vector.add(pos, vector.new(-1.8, 0, -1.8)),
			maxpos     = vector.add(pos, vector.new(1.8, 3.0, 1.8)),
			minvel     = vector.new(-2, 1, -2),
			maxvel     = vector.new(2, 3, 2),
			minacc     = vector.new(0, 0.5, 0),
			maxacc     = vector.new(0, 1.5, 0),
			minexptime = 0.3,
			maxexptime = 0.7,
			minsize    = 2,
			maxsize    = 5,
			texture    = "aura_particle.png^[colorize:#FF5500:180",
			glow       = 10,
		})

		if self._margriet_timer <= 0 then
			-- Summon one random boss from: Joachim(3), Vanessa(5), Jan Willem(6)
			local pool = { 3, 5, 6 }
			local pick = pool[math.random(#pool)]
			local offset = vector.new(math.random(-3, 3), 0, math.random(-3, 3))
			local spawn_pos = vector.add(pos, offset)
			local new_obj = minetest.add_entity(spawn_pos, "boss:teacher")
			if new_obj then
				boss.set_level(new_obj, pick)
				self._margriet_summon_ref = new_obj
				local bname = BOSSES[pick] and BOSSES[pick].name or "?"
				minetest.chat_send_all("Margriet roept " .. bname .. " op!")
				-- Summon flash
				minetest.add_particlespawner({
					amount     = 30,
					time       = 0.3,
					minpos     = vector.add(spawn_pos, vector.new(-0.5, 0.5, -0.5)),
					maxpos     = vector.add(spawn_pos, vector.new(0.5, 2.0, 0.5)),
					minvel     = vector.new(-4, 0, -4),
					maxvel     = vector.new(4, 4, 4),
					minacc     = vector.new(0, -2, 0),
					maxacc     = vector.new(0, 0, 0),
					minexptime = 0.5,
					maxexptime = 1.0,
					minsize    = 3,
					maxsize    = 6,
					texture    = "aura_particle.png^[colorize:#FF8800:200",
					glow       = 12,
				})
			end
			self._margriet_phase = "linked"
			self.object:set_properties({
				nametag = "Margriet [beschermd door haar helper]",
				nametag_color = "#FF8800",
			})
		end
	elseif self._margriet_phase == "linked" then
		-- Invulnerable while summoned boss lives; still walks and attacks
		if not self._margriet_summon_ref or not self._margriet_summon_ref:get_pos() then
			-- Helper died — Margriet returns to normal; next summon in 15 s
			self._margriet_phase      = "normal"
			self._margriet_timer      = 15.0
			self._margriet_summon_ref = nil
			local data                = BOSSES[7]
			self.object:set_properties({
				nametag       = (data and data.name or "Margriet") ..
					" [" .. math.max(0, self._hp) .. "/" .. self._max_hp .. "] WOEDEND",
				nametag_color = "#FF0000",
			})
			minetest.chat_send_all("Margriet is woedend!")
			minetest.sound_play("margriet" .. math.random(1, 2),
				{ pos = pos, gain = 1.3, max_hear_distance = 35 })
		else
			-- Continue attacking while protected
			self.object:set_yaw(minetest.dir_to_yaw(dir))
			self.object:set_velocity(vector.new(dir.x * 1.8, -9.81, dir.z * 1.8))
			self.object:set_animation({ x = 168, y = 187 }, 30, 0, true)

			self._attack_cooldown = self._attack_cooldown - dtime
			if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
				if nearest:is_player() then
					nearest:set_hp(math.max(0, nearest:get_hp() - self._damage), { type = "punch" })
				else
					nearest:punch(self.object, 1.0,
						{ damage_groups = { fleshy = self._damage } }, vector.new(0, 0, 0))
				end
				self._attack_cooldown = 1.5
				self.object:set_animation({ x = 189, y = 198 }, 30, 0, false)
			end
		end
	end
end

-- ============================================================
-- Drumstick visual (attached to Bram during rage phase)
-- ============================================================
minetest.register_entity("boss:drumstick_visual", {
	initial_properties = {
		visual = "wielditem",
		wield_item = "registered:drumstick",
		visual_size = { x = 0.5, y = 0.5 },
		physical = false,
		collisionbox = { 0, 0, 0, 0, 0, 0 },
		static_save = false,
		pointable = false,
	},
	on_activate = function(self)
		self.object:set_armor_groups({ immortal = 1 })
	end,
	on_step = function(self, dtime)
		if not self.object:get_attach() then
			self.object:remove()
		end
	end,
})

-- ============================================================
-- Boss entity
-- ============================================================
minetest.register_entity("boss:teacher", {
	initial_properties                  = {
		visual = "mesh",
		mesh = "character.b3d",
		textures = { "boss_bram.png" },
		physical = true,
		collide_with_objects = true,
		collisionbox = { -0.4, 0.0, -0.4, 0.4, 2.0, 0.4 },
		visual_size = { x = 1.2, y = 1.2, z = 1.2 },
		makes_footstep_sound = true,
		static_save = false,
		nametag = "",
		nametag_color = "#FF3333",
	},

	_hp                                 = 100,
	_max_hp                             = 100,
	_damage                             = 2,
	_attack_cooldown                    = 0,
	_level                              = 1,

	-- Bram-specific state
	_bram_phase                         = "normal",
	_bram_timer                         = 0,
	_drumstick_entity                   = nil,

	-- Hugo-specific state
	_enemy_boss_dragoncall_phase        = "stalk",
	_enemy_boss_dragoncall_timer        = 3.0,
	_enemy_boss_dragoncall_turned_black = false,
	_summoned_dragon                    = nil,
	_hugo_ambient_timer                 = 4.0, -- interval for hugo1-4 ambient clips during linked phase
	_hugo_speech_timer                  = 18.0, -- interval for hugo_speech during combat phases
	_spinkick_yaw                       = 0, -- yaw accumulator for spinning attacks
	_tornado_dmg_tick                   = 0.25, -- damage tick counter for tornado
	_feint_dir                          = nil, -- feint overshoot direction

	-- Julian-specific state
	_julian_phase                       = "normal",
	_julian_timer                       = 8.0,
	_julian_pour_tick                   = 0,
	_julian_drop_counter                = 0,

	-- Vanessa-specific state
	_vanessa_phase                      = "normal",
	_vanessa_timer                      = 5.0,
	_drawn_weapon                       = nil,
	_drawing_entity                     = nil,
	_drawing_spawned                    = false,
	_weapon_entity                      = nil,
	_draw_sound                         = nil,

	-- Margriet-specific state
	_margriet_phase                     = "normal",
	_margriet_timer                     = 20.0, -- first summon after 20 s
	_margriet_summon_ref                = nil,

	_frozen                             = false,

	on_activate                         = function(self, staticdata)
		self.object:set_animation({ x = 168, y = 187 }, 30, 0, true)
		self.object:set_armor_groups({ fleshy = 100 })
	end,

	on_punch                            = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		if not puncher then return end
		-- Accept hits from players, stunt double, or boomerang
		local is_stunt = puncher:get_luaentity() and puncher:get_luaentity().name == "trailer:stunt_double"
		local is_boomerang = puncher:get_luaentity() and
			puncher:get_luaentity().name == "registered:appelflap_boomerang_ent"
		if not puncher:is_player() and not is_stunt and not is_boomerang then return end

		-- Hugo linked phase: invulnerable while Dragon lives
		if self._level == 2 and self._enemy_boss_dragoncall_phase == "linked" then
			if puncher:is_player() then
				minetest.chat_send_player(puncher:get_player_name(),
					"Hugo is beschermd! Versla eerst de Draak!")
				gamelog.event("HIT_BLOCKED", {
					player = puncher:get_player_name(),
					target = "Hugo", reason = "linked_met_draak",
				}, puncher)
			end
			return true
		end

		-- Margriet linked phase: invulnerable while summoned boss lives
		if self._level == 7 and self._margriet_phase == "linked" then
			if puncher:is_player() then
				minetest.chat_send_player(puncher:get_player_name(),
					"Margriet is beschermd! Versla eerst haar helper!")
				gamelog.event("HIT_BLOCKED", {
					player = puncher:get_player_name(),
					target = "Margriet", reason = "linked_met_helper",
				}, puncher)
			end
			return true
		end

		local dmg = 1
		if tool_capabilities and tool_capabilities.damage_groups and tool_capabilities.damage_groups.fleshy then
			dmg = tool_capabilities.damage_groups.fleshy
		end

		-- Fire sword: spawn fire particles on boss
		if puncher:is_player() then
			local wielded = puncher:get_wielded_item()
			local itemdef = minetest.registered_items[wielded:get_name()]
			if itemdef and itemdef._fire_sword then
				local fpos = self.object:get_pos()
				if fpos then
					minetest.add_particlespawner({
						amount = 25,
						time = 0.6,
						minpos = vector.add(fpos, vector.new(-0.4, 0.5, -0.4)),
						maxpos = vector.add(fpos, vector.new(0.4, 2.0, 0.4)),
						minvel = vector.new(-1, 1, -1),
						maxvel = vector.new(1, 3, 1),
						minacc = vector.new(0, 1, 0),
						maxacc = vector.new(0, 2, 0),
						minexptime = 0.3,
						maxexptime = 0.8,
						minsize = 3,
						maxsize = 5,
						texture = "draconis_fire_particle.png",
						glow = 14,
					})
				end
			end
			-- Elements sword (ice / fire)
			if itemdef and itemdef._is_elements_sword then
				local estate = itemdef._elements_state or "ice"
				local fpos   = self.object:get_pos()
				if estate == "fire" and fpos then
					minetest.add_particlespawner({
						amount = 25,
						time = 0.6,
						minpos = vector.add(fpos, vector.new(-0.4, 0.5, -0.4)),
						maxpos = vector.add(fpos, vector.new(0.4, 2.0, 0.4)),
						minvel = vector.new(-1, 1, -1),
						maxvel = vector.new(1, 3, 1),
						minacc = vector.new(0, 1, 0),
						maxacc = vector.new(0, 2, 0),
						minexptime = 0.3,
						maxexptime = 0.8,
						minsize = 3,
						maxsize = 5,
						texture = "draconis_fire_particle.png",
						glow = 14,
					})
				elseif estate == "ice" then
					registered_apply_freeze(self.object)
				end
			end
		end -- puncher:is_player()

		self._hp = self._hp - dmg

		-- Update nametag with HP
		local data = BOSSES[self._level] or BOSSES[1]
		self.object:set_properties({
			nametag = data.name .. " [" .. math.max(0, self._hp) .. "/" .. self._max_hp .. "]",
		})

		-- Bram: trigger drumstick rage at 50% HP
		if self._level == 1 and self._bram_phase == "normal"
			and self._hp > 0 and self._hp <= self._max_hp * 0.5 then
			self._bram_phase = "pullout"
			self._bram_timer = 1.8 -- seconds of ear-rummaging theatre
		end

		local boss_data = BOSSES[self._level] or BOSSES[1]
		gamelog.damage_dealt(puncher, boss_data.name, dmg, {
			target_hp  = math.max(self._hp, 0),
			target_max = self._max_hp,
			level      = self._level,
			phase      = self._level == 2 and self._enemy_boss_dragoncall_phase
				or (self._level == 7 and self._margriet_phase)
				or (self._level == 5 and self._vanessa_phase)
				or (self._level == 1 and self._bram_phase)
				or "normal",
		})

		-- Hugo: trigger Dragon summon at 25% HP
		if self._level == 2 and self._enemy_boss_dragoncall_phase ~= "summon" and self._enemy_boss_dragoncall_phase ~= "linked"
			and self._hp > 0 and self._hp <= self._max_hp * 0.25 then
			self._enemy_boss_dragoncall_phase = "summon"
			self._enemy_boss_dragoncall_timer = 3.0 -- 3 second channeling
			gamelog.progress("BOSS_PHASE", {
				boss = boss_data.name, level = 2, phase = "summon", trigger = "hp_25pct",
			})
		end

		if self._hp <= 0 then
			local pos = self.object:get_pos()
			local data = BOSSES[self._level] or BOSSES[1]
			gamelog.kill(puncher, data.name, {
				boss  = true,
				level = self._level,
				drop  = data.drop or "none",
				at    = pos,
			})
			if pos and data.drop then
				minetest.add_item(pos, data.drop)
			end
			if self._jan_speech_sound then
				minetest.sound_stop(self._jan_speech_sound)
				self._jan_speech_sound = nil
			end
			if self._jan_board_entity and self._jan_board_entity:get_pos() then
				self._jan_board_entity:remove()
			end
			if self._drumstick_entity and self._drumstick_entity:get_pos() then
				self._drumstick_entity:remove()
			end
			if self._weapon_entity and self._weapon_entity:get_pos() then
				self._weapon_entity:remove()
			end
			if self._drawing_entity and self._drawing_entity:get_pos() then
				self._drawing_entity:remove()
			end
			enemy.boss_alive = nil
			self.object:remove()
			enemy.check_wave_clear()
		end
		return true
	end,

	on_step                             = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then return end

		if self._frozen then
			self.object:set_velocity(vector.new(0, 0, 0))
			return
		end

		local nearest, nearest_dist = find_nearest_player(pos)
		if not nearest then return end

		-- Bram (level 1): drumstick phases
		if self._level == 1 then
			if self._bram_phase == "pullout" then
				bram_pullout_step(self, dtime, pos)
			elseif self._bram_phase == "drumstick" then
				bram_drumstick_step(self, dtime, pos, nearest, nearest_dist)
			else
				bram_normal_step(self, dtime, pos, nearest, nearest_dist)
			end
			return
		end

		-- Hugo (level 2): special kung fu behavior
		if self._level == 2 then
			-- hugo_speech every 15-20 s during combat phases (stalk / dash / recover)
			local phase = self._enemy_boss_dragoncall_phase
			local is_combat = phase == "stalk" or phase == "dash" or phase == "recover"
				or phase == "spinkick_approach" or phase == "spinkick_wind"
				or phase == "tornado" or phase == "feint_dash" or phase == "feint_backstab"
			if is_combat then
				self._hugo_speech_timer = self._hugo_speech_timer - dtime
				if self._hugo_speech_timer <= 0 then
					self._hugo_speech_timer = 15.0 + math.random() * 5.0
					minetest.sound_play("hugo_speech",
						{ pos = pos, gain = 0.8, max_hear_distance = 25 })
				end
			end

			if phase == "stalk" then
				enemy_boss_dragoncall_stalk(self, dtime, pos, nearest, nearest_dist)
			elseif phase == "dash" then
				enemy_boss_dragoncall_dash(self, dtime, pos, nearest, nearest_dist)
			elseif phase == "recover" then
				enemy_boss_dragoncall_recover(self, dtime)
			elseif phase == "spinkick_approach" then
				enemy_boss_dragoncall_spinkick_approach(self, dtime, pos, nearest, nearest_dist)
			elseif phase == "spinkick_wind" then
				enemy_boss_dragoncall_spinkick_wind(self, dtime, pos, nearest, nearest_dist)
			elseif phase == "tornado" then
				enemy_boss_dragoncall_tornado(self, dtime, pos, nearest, nearest_dist)
			elseif phase == "feint_dash" then
				enemy_boss_dragoncall_feint_dash(self, dtime, pos, nearest, nearest_dist)
			elseif phase == "feint_backstab" then
				enemy_boss_dragoncall_feint_backstab(self, dtime, pos, nearest, nearest_dist)
			elseif phase == "summon" then
				enemy_boss_dragoncall_summon(self, dtime, pos, nearest)
			elseif phase == "linked" then
				enemy_boss_dragoncall_linked(self, dtime, pos, nearest)
			end
			return
		end

		-- Julian (level 4): hot chocolate pour attack
		if self._level == 4 then
			julian_step(self, dtime, pos, nearest, nearest_dist)
			return
		end

		-- Vanessa (level 5): drawing ability
		if self._level == 5 then
			vanessa_step(self, dtime, pos, nearest, nearest_dist)
			return
		end

		-- Jan Willem (level 6): teleport and speed attacks
		if self._level == 6 then
			jan_willem_step(self, dtime, pos, nearest, nearest_dist)
			return
		end

		-- Margriet (level 7): summon ability
		if self._level == 7 then
			margriet_step(self, dtime, pos, nearest, nearest_dist)
			return
		end

		-- Generic boss behavior for other levels
		generic_on_step(self, dtime, pos, nearest, nearest_dist)
	end,
})

-- ============================================================
-- Summoned Dragon entity (Hugo's Dragon)
-- ============================================================
minetest.register_entity("boss:summoned_dragon", {
	initial_properties = {
		visual = "mesh",
		mesh = "draconis_fire_dragon.b3d",
		textures = { "blue_dragon.png^draconis_baked_in_shading.png" },
		physical = true,
		collide_with_objects = false,
		collisionbox = { -0.5, 0.0, -0.5, 0.5, 2.5, 0.5 },
		visual_size = { x = 6, y = 6, z = 6 },
		makes_footstep_sound = false,
		static_save = false,
		nametag = "Kearach",
		nametag_color = "#1869db",
		glow = 8,
		backface_culling = false,
	},

	_hp = 50,
	_max_hp = 20,
	_damage = 2,
	_attack_cooldown = 0,
	_roar_timer = 3.0,
	_breath_timer = 0,
	_anim_timer = 0, -- prevent animation restart mid-play
	_current_anim = "fly",
	_master = nil, -- Hugo objectref
	_aura_timer = 0,
	_smoke_timer = 0,
	_glow_phase = 0,

	_frozen = false,

	on_activate = function(self, staticdata)
		self.object:set_animation({ x = 211, y = 249 }, 30, 0, true) -- walk
		self.object:set_armor_groups({ fleshy = 100 })

		-- Summoning dark energy pillar
		local pos = self.object:get_pos()
		if pos then
			-- Vertical dark energy column
			minetest.add_particlespawner({
				amount = 80,
				time = 2.0,
				minpos = vector.add(pos, vector.new(-1.5, -1, -1.5)),
				maxpos = vector.add(pos, vector.new(1.5, 0, 1.5)),
				minvel = vector.new(-0.5, 6, -0.5),
				maxvel = vector.new(0.5, 12, 0.5),
				minacc = vector.new(0, 2, 0),
				maxacc = vector.new(0, 4, 0),
				minexptime = 0.8,
				maxexptime = 1.5,
				minsize = 4,
				maxsize = 8,
				texture = "aura_particle.png^[colorize:#386dff:200",
				glow = 14,
			})
			-- Ground shockwave ring
			minetest.add_particlespawner({
				amount = 40,
				time = 0.5,
				minpos = vector.add(pos, vector.new(-0.5, 0.1, -0.5)),
				maxpos = vector.add(pos, vector.new(0.5, 0.3, 0.5)),
				minvel = vector.new(-6, 0.5, -6),
				maxvel = vector.new(6, 1.5, 6),
				minacc = vector.new(0, -2, 0),
				maxacc = vector.new(0, -1, 0),
				minexptime = 0.5,
				maxexptime = 1.0,
				minsize = 3,
				maxsize = 5,
				texture = "aura_particle.png^[colorize:#386dff:200",
				glow = 10,
			})
		end
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		if not puncher then return end
		local is_stunt = puncher:get_luaentity() and puncher:get_luaentity().name == "trailer:stunt_double"
		if not puncher:is_player() and not is_stunt then return end

		local dmg = 1
		if tool_capabilities and tool_capabilities.damage_groups and tool_capabilities.damage_groups.fleshy then
			dmg = tool_capabilities.damage_groups.fleshy
		end

		-- Fire sword: spawn fire particles on Dragon
		if puncher:is_player() then
			local wielded = puncher:get_wielded_item()
			local itemdef = minetest.registered_items[wielded:get_name()]
			if itemdef and itemdef._fire_sword then
				local fpos = self.object:get_pos()
				if fpos then
					minetest.add_particlespawner({
						amount = 30,
						time = 0.7,
						minpos = vector.add(fpos, vector.new(-1, 0.5, -1)),
						maxpos = vector.add(fpos, vector.new(1, 3.0, 1)),
						minvel = vector.new(-1, 1, -1),
						maxvel = vector.new(1, 4, 1),
						minacc = vector.new(0, 1, 0),
						maxacc = vector.new(0, 3, 0),
						minexptime = 0.3,
						maxexptime = 0.9,
						minsize = 3,
						maxsize = 6,
						texture = "aura_particle.png^[colorize:#1869db:200",
						glow = 14,
					})
				end
			end
			-- Elements sword (ice / fire)
			if itemdef and itemdef._is_elements_sword then
				local estate = itemdef._elements_state or "ice"
				local fpos   = self.object:get_pos()
				if estate == "fire" and fpos then
					minetest.add_particlespawner({
						amount = 30,
						time = 0.7,
						minpos = vector.add(fpos, vector.new(-1, 0.5, -1)),
						maxpos = vector.add(fpos, vector.new(1, 3.0, 1)),
						minvel = vector.new(-1, 1, -1),
						maxvel = vector.new(1, 4, 1),
						minacc = vector.new(0, 1, 0),
						maxacc = vector.new(0, 3, 0),
						minexptime = 0.3,
						maxexptime = 0.9,
						minsize = 3,
						maxsize = 6,
						texture = "aura_particle.png^[colorize:#34c3eb:180",
						glow = 14,
					})
				elseif estate == "ice" then
					registered_apply_freeze(self.object)
				end
			end
		end -- puncher:is_player()

		self._hp = self._hp - dmg

		self.object:set_properties({
			nametag = "Kearach",
		})

		-- Roar when hit
		if math.random() < 0.4 then
			local pos = self.object:get_pos()
			minetest.sound_play("dragon_roar" .. math.random(1, 2),
				{ pos = pos, gain = 5.0, max_hear_distance = 50 })
		end

		if self._hp <= 0 then
			-- Dragon dies — kill Hugo too
			local pos = self.object:get_pos()
			gamelog.kill(puncher, "Hugo's Draak", { boss = true, level = 2, at = pos })
			if pos then
				minetest.sound_play("dragon_roar2", { pos = pos, gain = 7.0, max_hear_distance = 60 })
			end

			-- Drop diamond sword
			if pos then
				minetest.add_item(pos, "registered:sword_diamond")
			end

			-- Kill Hugo via the linked check (remove Dragon, enemy_boss_dragoncall_linked detects it)
			self.object:remove()
			return true
		end
		return true
	end,

	on_step = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then return end

		if self._frozen then
			self.object:set_velocity(vector.new(0, 0, 0))
			return
		end

		local nearest, nearest_dist = find_nearest_player(pos)
		if not nearest then return end

		local ppos = nearest:get_pos()
		local dir = vector.direction(pos, ppos)

		self.object:set_yaw(minetest.dir_to_yaw(dir))

		-- Pulsating glow effect
		self._glow_phase = self._glow_phase + dtime * 2.0
		local glow = math.floor(8 + math.sin(self._glow_phase) * 4)
		self.object:set_properties({ glow = glow })

		-- Dark aura particles (continuous swirling purple mist)
		self._aura_timer = self._aura_timer - dtime
		if self._aura_timer <= 0 then
			self._aura_timer = 0.3
			minetest.add_particlespawner({
				amount = 6,
				time = 0.3,
				minpos = vector.add(pos, vector.new(-1.5, 0.2, -1.5)),
				maxpos = vector.add(pos, vector.new(1.5, 2.5, 1.5)),
				minvel = vector.new(-0.8, 0.3, -0.8),
				maxvel = vector.new(0.8, 1.2, 0.8),
				minacc = vector.new(0, 0.5, 0),
				maxacc = vector.new(0, 1.0, 0),
				minexptime = 0.6,
				maxexptime = 1.2,
				minsize = 2,
				maxsize = 4,
				texture = "aura_particle.png^[colorize:#6600AA:180",
				glow = 8,
			})
		end

		-- Smoke trail (dark wisps behind Dragon)
		self._smoke_timer = self._smoke_timer - dtime
		if self._smoke_timer <= 0 then
			self._smoke_timer = 0.15
			local back = vector.multiply(dir, -2)
			local smoke_pos = vector.add(pos, vector.new(back.x, 1.5, back.z))
			minetest.add_particlespawner({
				amount = 3,
				time = 0.15,
				minpos = vector.add(smoke_pos, vector.new(-0.5, -0.3, -0.5)),
				maxpos = vector.add(smoke_pos, vector.new(0.5, 0.3, 0.5)),
				minvel = vector.new(-0.3, 0.5, -0.3),
				maxvel = vector.new(0.3, 1.5, 0.3),
				minacc = vector.new(0, 0.2, 0),
				maxacc = vector.new(0, 0.5, 0),
				minexptime = 0.8,
				maxexptime = 1.8,
				minsize = 3,
				maxsize = 6,
				texture = "aura_particle.png^[colorize:#1a0033:200",
				glow = 2,
			})
		end

		-- Animation timer (prevent restarts mid-play)
		self._anim_timer = self._anim_timer - dtime

		-- Move toward player (menacing but not too fast)
		local speed = 2.5
		self.object:set_velocity(vector.new(dir.x * speed, -9.81, dir.z * speed))
		if self._current_anim ~= "walk" and self._anim_timer <= 0 then
			self._current_anim = "walk"
			self.object:set_animation({ x = 211, y = 249 }, 30, 0, true)
		end

		-- Random roar
		self._roar_timer = self._roar_timer - dtime
		if self._roar_timer <= 0 then
			minetest.sound_play("dragon_roar" .. math.random(1, 2),
				{ pos = pos, gain = 3.2, max_hear_distance = 50 })
			self._roar_timer = 4.0 + math.random() * 4.0
		end

		-- Fire breath attack (enhanced cinematic version)
		self._attack_cooldown = self._attack_cooldown - dtime
		if nearest_dist < 5.0 and self._attack_cooldown <= 0 and self._anim_timer <= 0 then
			-- Fire breath animation (plays ~2 sec, don't interrupt)
			self._current_anim = "walk_fire"
			self._anim_timer = 2.0
			self.object:set_animation({ x = 61, y = 119 }, 30, 0, false)
			minetest.sound_play("draconis_fire_breath",
				{ pos = pos, gain = 1.0, max_hear_distance = 30 })

			-- Damage target
			if nearest:is_player() then
				nearest:set_hp(nearest:get_hp() - self._damage, { type = "punch" })
			else
				nearest:punch(self.object, 1.0, { damage_groups = { fleshy = self._damage } }, vector.new(0, 0, 0))
			end
			self._attack_cooldown = 2.5

			-- Main fire stream (dense core)
			local breath_dir = vector.direction(pos, ppos)
			local mouth = vector.add(pos, vector.new(breath_dir.x * 2, 2.0, breath_dir.z * 2))
			minetest.add_particlespawner({
				amount = 50,
				time = 0.8,
				minpos = mouth,
				maxpos = vector.add(mouth, vector.new(0.3, 0.3, 0.3)),
				minvel = vector.multiply(breath_dir, 6),
				maxvel = vector.add(vector.multiply(breath_dir, 10), vector.new(0, 2, 0)),
				minacc = vector.new(0, 1, 0),
				maxacc = vector.new(0, 3, 0),
				minexptime = 0.3,
				maxexptime = 0.8,
				minsize = 3,
				maxsize = 7,
				texture = "aura_particle.png^[colorize:#1a0033:200",
				glow = 14,
			})

			-- Ground scorch (fire on impact area)
			minetest.add_particlespawner({
				amount = 20,
				time = 1.2,
				minpos = vector.add(ppos, vector.new(-1.5, 0.1, -1.5)),
				maxpos = vector.add(ppos, vector.new(1.5, 0.5, 1.5)),
				minvel = vector.new(-1, 0.5, -1),
				maxvel = vector.new(1, 2, 1),
				minacc = vector.new(0, 0.5, 0),
				maxacc = vector.new(0, 1, 0),
				minexptime = 0.5,
				maxexptime = 1.2,
				minsize = 2,
				maxsize = 5,
				texture = "draconis_fire_particle.png",
				glow = 10,
			})
		end
	end,
})

-- ============================================================
-- Set boss stats based on level (called after spawn from enemy mod)
-- ============================================================
function boss.set_level(obj, level)
	if not obj then return end
	local lua = obj:get_luaentity()
	if not lua then return end

	local data = BOSSES[level] or BOSSES[1]

	lua._level = level
	lua._hp = data.hp
	lua._max_hp = data.hp
	lua._damage = data.dmg

	local scale = 1.2
	if level == 7 then scale = 1.5 end

	obj:set_properties({
		nametag = data.name .. " [" .. data.hp .. "/" .. data.hp .. "]",
		nametag_color = "#FFFFFF",
		visual_size = { x = scale, y = scale, z = scale },
		textures = { data.tex },
	})

	-- Hugo: initialize kung fu state
	if level == 2 then
		lua._enemy_boss_dragoncall_phase = "stalk"
		lua._enemy_boss_dragoncall_timer = 3.0 + math.random() * 2.0
		lua._enemy_boss_dragoncall_turned_black = false
		lua._summoned_dragon = nil
	end

	-- Vanessa: initialize drawing state
	if level == 5 then
		lua._vanessa_phase   = "normal"
		lua._vanessa_timer   = 5.0 + math.random() * 3.0
		lua._drawn_weapon    = nil
		lua._drawing_entity  = nil
		lua._drawing_spawned = false
		lua._weapon_entity   = nil
	end
	-- Jan Willem: initialize attacks
	if level == 6 then
		lua._jan_phase = "normal"
		lua._jan_timer = 6.0 + math.random() * 4.0
		lua._jan_speech_sound = nil
		lua._jan_next_attack = nil
		lua._speed_mult = 1.0
		lua._speed_timer = 0
	end

	gamelog.progress("BOSS_SPAWN", {
		boss  = data.name,
		level = level,
		hp    = data.hp,
		dmg   = data.dmg,
		at    = obj:get_pos(),
	})
end

-- ============================================================
-- Gladiator boss (boss:gladiator)
-- Latin case state machine — 5 Latin cases (no vocative).
-- Every ~12 seconds a transition occurs; each transition plays an audio clip
-- and applies a matching buff.
--
--   nominativus  → jump strength: randomly jumps 2 blocks high
--   accusativus  → +25 % speed
--   dativus      → heals 5 % of max HP on transition
--   genitivus    → +5 flat damage on top of base
--   ablativus    → 10 % damage reduction (takes 10 % less damage)
-- ============================================================

local GLAD_STATES   = { "nominativus", "accusativus", "dativus", "genitivus", "ablativus" }
local GLAD_COLORS   = {
	nominativus = "#FFD700",
	accusativus = "#FF8800",
	dativus     = "#44FF88",
	genitivus   = "#FF4455",
	ablativus   = "#5599FF",
}
local GLAD_LABELS   = {
	nominativus = "NOMINATIVUS [springkracht]",
	accusativus = "ACCUSATIVUS [snelheid +100%]",
	dativus     = "DATIVUS [genezing +20%]",
	genitivus   = "GENITIVUS [schade +20]",
	ablativus   = "ABLATIVUS [weerstand +30%]",
}
-- Base stats
local GLAD_BASE_HP  = 280
local GLAD_BASE_DMG = 7
local GLAD_BASE_SPD = 2.5

-- Index helper: find state index in GLAD_STATES
local function glad_state_index(s)
	for i, v in ipairs(GLAD_STATES) do if v == s then return i end end
	return 1
end

-- Apply immediate buff for the new state on entry
local function glad_apply_state(self, state)
	-- Reset modifiers to base first
	self._damage     = GLAD_BASE_DMG
	self._speed      = GLAD_BASE_SPD
	self._dmg_resist = 0.0

	if state == "nominativus" then
		-- Jump buff handled in on_step; nothing to apply here
	elseif state == "accusativus" then
		self._speed = GLAD_BASE_SPD * 2
	elseif state == "dativus" then
		local heal = math.floor(self._max_hp * 0.2)
		self._hp   = math.min(self._hp + heal, self._max_hp)
	elseif state == "genitivus" then
		self._damage = GLAD_BASE_DMG + 7
	elseif state == "ablativus" then
		self._dmg_resist = 0.30
	end
end

-- Transition to the next state in the cycle
local function glad_next_state(self)
	local idx              = glad_state_index(self._glad_state)
	local nidx             = (idx % #GLAD_STATES) + 1
	local new              = GLAD_STATES[nidx]
	self._glad_state       = new
	self._glad_state_timer = 10.0 + math.random() * 4.0
	glad_apply_state(self, new)

	gamelog.progress("GLADIATOR_STATE", {
		from = GLAD_STATES[idx],
		to   = new,
		hp   = math.max(0, self._hp),
	})

	-- Play transition sound
	local snd = "gladiator_" .. new
	local pos = self.object:get_pos()
	if pos then
		minetest.sound_play(snd, { pos = pos, gain = 1.0, max_hear_distance = 30 })
	end

	-- Update nametag
	self.object:set_properties({
		nametag       = "Joachim [" .. math.max(0, self._hp) .. "/" .. self._max_hp .. "] " ..
			GLAD_LABELS[new],
		nametag_color = GLAD_COLORS[new],
	})

	-- Visual flash to signal state change
	if pos then
		minetest.add_particlespawner({
			amount     = 20,
			time       = 0.4,
			minpos     = vector.add(pos, vector.new(-0.6, 0.3, -0.6)),
			maxpos     = vector.add(pos, vector.new(0.6, 2.0, 0.6)),
			minvel     = vector.new(-3, 1, -3),
			maxvel     = vector.new(3, 4, 3),
			minacc     = vector.new(0, -2, 0),
			maxacc     = vector.new(0, -1, 0),
			minexptime = 0.2,
			maxexptime = 0.6,
			minsize    = 2,
			maxsize    = 5,
			texture    = "aura_particle.png^[colorize:" .. GLAD_COLORS[new] .. ":210",
			glow       = 12,
		})
	end
end

minetest.register_entity("boss:gladiator", {
	initial_properties = {
		visual               = "mesh",
		mesh                 = "character.b3d",
		-- NOTE: replace with a dedicated gladiator texture when available
		textures             = { "boss_joachim.png" },
		physical             = true,
		collide_with_objects = true,
		collisionbox         = { -0.4, 0.0, -0.4, 0.4, 2.0, 0.4 },
		visual_size          = { x = 1.3, y = 1.3, z = 1.3 },
		makes_footstep_sound = true,
		static_save          = false,
		nametag              = "Joachim",
		nametag_color        = GLAD_COLORS["nominativus"],
	},

	_hp                = GLAD_BASE_HP,
	_max_hp            = GLAD_BASE_HP,
	_damage            = GLAD_BASE_DMG,
	_speed             = GLAD_BASE_SPD,
	_dmg_resist        = 0.0,
	_attack_cooldown   = 0,
	_level             = 3, -- used by drop / wave-clear logic

	-- State machine
	_glad_state        = "nominativus",
	_glad_state_timer  = 12.0,

	-- Nominativus jump
	_jump_timer        = 0,
	_air_time          = 100.0, -- large = on ground (y_vel clamped to -9.81)

	_frozen            = false,

	on_activate        = function(self, staticdata)
		self.object:set_animation({ x = 168, y = 187 }, 30, 0, true)
		self.object:set_armor_groups({ fleshy = 100 })

		-- Set initial state
		glad_apply_state(self, self._glad_state)
		self.object:set_properties({
			nametag       = "Joachim [" .. self._hp .. "/" .. self._max_hp .. "] " ..
				GLAD_LABELS[self._glad_state],
			nametag_color = GLAD_COLORS[self._glad_state],
		})

		-- Play spawn sound for the initial state (same logic as glad_next_state)
		local pos = self.object:get_pos()
		if pos then
			minetest.sound_play("gladiator_" .. self._glad_state,
				{ pos = pos, gain = 1.0, max_hear_distance = 30 })
		end
	end,

	on_punch           = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		if not puncher then return end
		local is_stunt     = puncher:get_luaentity() and
			puncher:get_luaentity().name == "trailer:stunt_double"
		local is_boomerang = puncher:get_luaentity() and
			puncher:get_luaentity().name == "registered:appelflap_boomerang_ent"
		if not puncher:is_player() and not is_stunt and not is_boomerang then return end

		local dmg = 1
		if tool_capabilities and tool_capabilities.damage_groups
			and tool_capabilities.damage_groups.fleshy then
			dmg = tool_capabilities.damage_groups.fleshy
		end

		-- Fire sword: particles
		if puncher:is_player() then
			local wielded = puncher:get_wielded_item()
			local itemdef = minetest.registered_items[wielded:get_name()]
			if itemdef and itemdef._fire_sword then
				local fpos = self.object:get_pos()
				if fpos then
					minetest.add_particlespawner({
						amount = 25,
						time = 0.6,
						minpos = vector.add(fpos, vector.new(-0.4, 0.5, -0.4)),
						maxpos = vector.add(fpos, vector.new(0.4, 2.0, 0.4)),
						minvel = vector.new(-1, 1, -1),
						maxvel = vector.new(1, 3, 1),
						minacc = vector.new(0, 1, 0),
						maxacc = vector.new(0, 2, 0),
						minexptime = 0.3,
						maxexptime = 0.8,
						minsize = 3,
						maxsize = 5,
						texture = "draconis_fire_particle.png",
						glow = 14,
					})
				end
			end
			-- Elements sword (ice / fire)
			if itemdef and itemdef._is_elements_sword then
				local estate = itemdef._elements_state or "ice"
				local fpos   = self.object:get_pos()
				if estate == "fire" and fpos then
					minetest.add_particlespawner({
						amount = 25,
						time = 0.6,
						minpos = vector.add(fpos, vector.new(-0.4, 0.5, -0.4)),
						maxpos = vector.add(fpos, vector.new(0.4, 2.0, 0.4)),
						minvel = vector.new(-1, 1, -1),
						maxvel = vector.new(1, 3, 1),
						minacc = vector.new(0, 1, 0),
						maxacc = vector.new(0, 2, 0),
						minexptime = 0.3,
						maxexptime = 0.8,
						minsize = 3,
						maxsize = 5,
						texture = "draconis_fire_particle.png",
						glow = 14,
					})
				elseif estate == "ice" then
					registered_apply_freeze(self.object)
				end
			end
		end

		-- Ablativus: 10 % damage reduction
		if self._dmg_resist > 0 then
			dmg = math.max(1, math.floor(dmg * (1.0 - self._dmg_resist)))
		end

		self._hp = self._hp - dmg
		gamelog.damage_dealt(puncher, "Joachim", dmg, {
			target_hp  = math.max(self._hp, 0),
			target_max = self._max_hp,
			state      = self._glad_state,
			resist     = self._dmg_resist,
		})

		-- Update nametag
		self.object:set_properties({
			nametag = "Joachim [" .. math.max(0, self._hp) .. "/" .. self._max_hp .. "] " ..
				GLAD_LABELS[self._glad_state],
		})

		if self._hp <= 0 then
			local pos = self.object:get_pos()
			gamelog.kill(puncher, "Joachim", {
				boss = true, level = 3, state = self._glad_state, at = pos,
			})
			-- Drop: use Joachim's drop (sword_diamond) for level 3
			if pos then
				minetest.add_item(pos, "registered:sword_diamond")
			end
			enemy.boss_alive = nil
			self.object:remove()
			enemy.check_wave_clear()
		end
		return true
	end,

	on_step            = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then return end

		if self._frozen then
			self.object:set_velocity(vector.new(0, 0, 0))
			return
		end

		local nearest, nearest_dist = find_nearest_player(pos)
		if not nearest then return end

		local ppos = nearest:get_pos()
		local dir  = vector.direction(pos, ppos)
		self.object:set_yaw(minetest.dir_to_yaw(dir))

		-- ── State machine timer ──────────────────────────────────────
		self._glad_state_timer = self._glad_state_timer - dtime
		if self._glad_state_timer <= 0 then
			glad_next_state(self)
		end

		-- ── State-specific movement / buff logic ─────────────────────
		local spd = self._speed

		if self._glad_state == "nominativus" then
			-- Random jump: every 3-5 seconds, leap 2 blocks high
			self._jump_timer = self._jump_timer - dtime
			if self._jump_timer <= 0 then
				self._jump_timer = 3.0 + math.random() * 2.0
				self._air_time = 0 -- begin jump arc
				minetest.add_particlespawner({
					amount = 10,
					time = 0.3,
					minpos = vector.add(pos, vector.new(-0.3, 0, -0.3)),
					maxpos = vector.add(pos, vector.new(0.3, 0.2, 0.3)),
					minvel = vector.new(-2, 0, -2),
					maxvel = vector.new(2, 1, 2),
					minacc = vector.new(0, -8, 0),
					maxacc = vector.new(0, -8, 0),
					minexptime = 0.2,
					maxexptime = 0.5,
					minsize = 1,
					maxsize = 3,
					texture = "aura_particle.png^[colorize:#FFD700:200",
					glow = 8,
				})
			end
			-- Manual gravity arc: y = v0 - g*t (v0=6.3, g=9.81)
			-- Matches every other boss which also sets Y manually each frame.
			self._air_time = self._air_time + dtime
			local y_vel = math.max(6.3 - 9.81 * self._air_time, -9.81)
			self.object:set_velocity(vector.new(dir.x * spd, y_vel, dir.z * spd))
		else
			-- Standard horizontal movement with gravity
			self.object:set_velocity(vector.new(dir.x * spd, -9.81, dir.z * spd))
		end

		self.object:set_animation({ x = 168, y = 187 }, 30 + spd * 6, 0, true)

		-- ── Melee attack ─────────────────────────────────────────────
		self._attack_cooldown = self._attack_cooldown - dtime
		if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
			local dmg = self._damage
			if nearest:is_player() then
				nearest:set_hp(math.max(0, nearest:get_hp() - dmg), { type = "punch" })
			else
				nearest:punch(self.object, 1.0,
					{ damage_groups = { fleshy = dmg } }, vector.new(0, 0, 0))
			end
			self._attack_cooldown = 1.2
			self.object:set_animation({ x = 189, y = 198 }, 35, 0, false)
			minetest.after(0.5, function()
				if self.object and self.object:get_pos() then
					self.object:set_animation({ x = 168, y = 187 }, 30, 0, true)
				end
			end)
		end
	end,
})

-- ============================================================
-- Companion Dragon (Sword of Dragon Power)
-- Spawns when a player wields sword_dragonpower.
-- Follows the owner and attacks nearby enemies.
-- Despawns when the owner drops/switches the sword or dies.
-- ============================================================

-- Track one companion Dragon per player: { [player_name] = objectref }
boss.companion_dragons = {}

-- Find the nearest enemy entity (student or boss teacher) within radius
local function find_nearest_enemy(pos, radius)
	local nearest, nearest_dist = nil, math.huge
	for _, obj in ipairs(minetest.get_objects_inside_radius(pos, radius)) do
		if not obj:is_player() then
			local ent = obj:get_luaentity()
			if ent and (ent.name == "enemy:student" or ent.name == "boss:teacher") then
				local d = vector.distance(pos, obj:get_pos())
				if d < nearest_dist then
					nearest = obj
					nearest_dist = d
				end
			end
		end
	end
	return nearest, nearest_dist
end

minetest.register_entity("boss:companion_dragon", {
	initial_properties = {
		visual               = "mesh",
		mesh                 = "draconis_fire_dragon.b3d",
		textures             = { "slate_dragon.png^slate_eyes.png^draconis_baked_in_shading.png" },
		physical             = false,
		collide_with_objects = false,
		collisionbox         = { -0.4, 0.0, -0.4, 0.4, 2.0, 0.4 },
		visual_size          = { x = 6, y = 6, z = 6 },
		makes_footstep_sound = false,
		static_save          = false,
		nametag              = "Caeltaroch",
		nametag_color        = "#1869db",
		glow                 = 10,
		backface_culling     = false,
	},

	_owner             = nil, -- player name string
	_attack_cooldown   = 0,
	_anim_timer        = 0,
	_current_anim      = "walk",
	_aura_timer        = 0,
	_roar_timer        = 5.0,
	_was_attacking     = false,

	on_activate        = function(self, staticdata)
		self.object:set_animation({ x = 321, y = 359 }, 35, 0, true) -- hover
		self.object:set_armor_groups({ immortal = 1 })         -- companion can't be killed by enemies
	end,

	on_step            = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then return end

		-- Verify owner is still online and still wields the sword
		local owner = self._owner and minetest.get_player_by_name(self._owner)
		if not owner or not owner:get_pos() then
			boss.companion_dragons[self._owner] = nil
			self.object:remove()
			return
		end

		local wielded = owner:get_wielded_item():get_name()
		if wielded ~= "registered:sword_dragonpower" then
			boss.companion_dragons[self._owner] = nil
			-- Farewell smoke burst
			minetest.add_particlespawner({
				amount = 20,
				time = 0.5,
				minpos = vector.add(pos, vector.new(-1, 0, -1)),
				maxpos = vector.add(pos, vector.new(1, 2, 1)),
				minvel = vector.new(-2, 1, -2),
				maxvel = vector.new(2, 4, 2),
				minacc = vector.new(0, -1, 0),
				maxacc = vector.new(0, 0, 0),
				minexptime = 0.4,
				maxexptime = 1.0,
				minsize = 3,
				maxsize = 6,
				texture = "aura_particle.png^[colorize:#b8ffed:160",
				glow = 8,
			})
			self.object:remove()
			return
		end

		-- Aura particles (always on)
		self._aura_timer = self._aura_timer - dtime
		if self._aura_timer <= 0 then
			self._aura_timer = 0.35
			minetest.add_particlespawner({
				amount = 4,
				time = 0.35,
				minpos = vector.add(pos, vector.new(-0.8, 0.2, -0.8)),
				maxpos = vector.add(pos, vector.new(0.8, 1.8, 0.8)),
				minvel = vector.new(-0.4, 0.3, -0.4),
				maxvel = vector.new(0.4, 1.0, 0.4),
				minacc = vector.new(0, 0.3, 0),
				maxacc = vector.new(0, 0.8, 0),
				minexptime = 0.5,
				maxexptime = 1.0,
				minsize = 1.5,
				maxsize = 3,
				texture = "aura_particle.png^[colorize:#b8ffed:150",
				glow = 10,
			})
		end

		-- Random roar
		self._roar_timer = self._roar_timer - dtime
		if self._roar_timer <= 0 then
			minetest.sound_play("dragon_roar" .. math.random(1, 2),
				{ pos = pos, gain = 1.5, max_hear_distance = 30 })
			self._roar_timer = 6.0 + math.random() * 4.0
		end

		self._attack_cooldown       = self._attack_cooldown - dtime
		self._anim_timer            = self._anim_timer - dtime

		local opos                  = owner:get_pos()
		local enemy_obj, enemy_dist = find_nearest_enemy(pos, 18)

		if enemy_obj and enemy_obj:get_pos() then
			self._was_attacking = true
			-- ── ATTACK MODE ──────────────────────────────────────────
			local epos          = enemy_obj:get_pos()
			local etarget       = vector.add(epos, vector.new(0, 2, 0)) -- 2 blocks above enemy
			local dir           = vector.direction(pos, etarget)
			self.object:set_yaw(minetest.dir_to_yaw(vector.direction(pos, epos)))

			if enemy_dist > 3.5 then
				-- Fly toward enemy (2 blocks above)
				self.object:set_velocity(vector.new(dir.x * 5, dir.y * 5, dir.z * 5))
				if self._current_anim ~= "fly" and self._anim_timer <= 0 then
					self._current_anim = "fly"
					self.object:set_animation({ x = 401, y = 439 }, 35, 0, true)
				end
			else
				-- Hover above enemy: drift toward target height
				local dy = etarget.y - pos.y
				self.object:set_velocity(vector.new(0, dy * 3, 0))
			end

			-- Fire breath damage on contact
			if enemy_dist < 3.5 and self._attack_cooldown <= 0 then
				local ent = enemy_obj:get_luaentity()
				if ent and ent._hp then
					ent._hp = ent._hp - 15
					if ent._hp <= 0 then
						-- student die
						if ent.name == "enemy:student" then
							for i, ref in ipairs(enemy.alive_students) do
								if ref == enemy_obj then
									table.remove(enemy.alive_students, i)
									break
								end
							end
							enemy_obj:remove()
							enemy.check_wave_clear()
						else
							-- boss die
							local bpos = enemy_obj:get_pos()
							local bdata = BOSSES[ent._level] or BOSSES[1]
							if bpos and bdata.drop then
								minetest.add_item(bpos, bdata.drop)
							end
							if ent._drumstick_entity and ent._drumstick_entity:get_pos() then
								ent._drumstick_entity:remove()
							end
							enemy.boss_alive = nil
							enemy_obj:remove()
							enemy.check_wave_clear()
						end
					end
				end
				-- Fire breath particles
				local breath_dir = vector.direction(pos, epos)
				local mouth = vector.add(pos, vector.new(breath_dir.x * 1.5, 1.5, breath_dir.z * 1.5))
				minetest.add_particlespawner({
					amount = 30,
					time = 0.5,
					minpos = mouth,
					maxpos = vector.add(mouth, vector.new(0.2, 0.2, 0.2)),
					minvel = vector.multiply(breath_dir, 5),
					maxvel = vector.add(vector.multiply(breath_dir, 8), vector.new(0, 1.5, 0)),
					minacc = vector.new(0, 0.5, 0),
					maxacc = vector.new(0, 2, 0),
					minexptime = 0.2,
					maxexptime = 0.6,
					minsize = 2,
					maxsize = 6,
					texture = "draconis_fire_particle.png",
					glow = 14,
				})
				minetest.sound_play("draconis_fire_breath",
					{ pos = pos, gain = 0.7, max_hear_distance = 20 })
				self._attack_cooldown = 1.8

				if self._anim_timer <= 0 then
					self._current_anim = "fly_fire"
					self._anim_timer   = 1.8
					self.object:set_animation({ x = 441, y = 479 }, 35, 0, true)
				end
			end
		else
			-- ── FOLLOW MODE ──────────────────────────────────────────
			if self._was_attacking then
				self._was_attacking = false
				minetest.sound_play("dragon_roar3",
					{ pos = pos, gain = 1.0, max_hear_distance = 30 })
			end
			local otarget = vector.add(opos, vector.new(0, 2, 0)) -- 2 blocks above owner
			local follow_dist = vector.distance(pos, otarget)
			local dir = vector.direction(pos, otarget)
			self.object:set_yaw(minetest.dir_to_yaw(vector.direction(pos, opos)))

			if follow_dist > 6 then
				-- Быстрый полёт к хозяину (2 блока выше)
				self.object:set_velocity(vector.new(dir.x * 6, dir.y * 6, dir.z * 6))
				if self._current_anim ~= "fly" and self._anim_timer <= 0 then
					self._current_anim = "fly"
					self.object:set_animation({ x = 401, y = 439 }, 35, 0, true)
				end
			elseif follow_dist > 3 then
				-- Медленный подлёт
				self.object:set_velocity(vector.new(dir.x * 2.5, dir.y * 2.5, dir.z * 2.5))
				if self._current_anim ~= "fly" and self._anim_timer <= 0 then
					self._current_anim = "fly"
					self.object:set_animation({ x = 401, y = 439 }, 30, 0, true)
				end
			else
				-- Зависание на 2 блока выше хозяина
				local dy = otarget.y - pos.y
				self.object:set_velocity(vector.new(0, dy * 3, 0))
				if self._current_anim ~= "hover" and self._anim_timer <= 0 then
					self._current_anim = "hover"
					self.object:set_animation({ x = 321, y = 359 }, 35, 0, true)
				end
			end
		end
	end,
})

-- ── Globalstep: spawn / clean up companion Dragons ──────────────
local _dragon_check_timer = 0

minetest.register_globalstep(function(dtime)
	_dragon_check_timer = _dragon_check_timer + dtime
	if _dragon_check_timer < 1.0 then return end
	_dragon_check_timer = 0

	for _, player in ipairs(minetest.get_connected_players()) do
		local pname   = player:get_player_name()
		local wielded = player:get_wielded_item():get_name()
		local dragon  = boss.companion_dragons[pname]

		if wielded == "registered:sword_dragonpower" then
			-- Spawn if not yet present (or the old one disappeared)
			if (not dragon or not dragon:get_pos())
				and not (boss._victory_dragon_obj and boss._victory_dragon_obj:get_pos()) then
				local ppos = player:get_pos()
				local spawn_pos = vector.add(ppos, vector.new(2, 1, 0))
				local obj = minetest.add_entity(spawn_pos, "boss:companion_dragon")
				if obj then
					local lua = obj:get_luaentity()
					if lua then lua._owner = pname end
					boss.companion_dragons[pname] = obj
					-- Summoning burst
					minetest.add_particlespawner({
						amount = 30,
						time = 0.5,
						minpos = vector.add(spawn_pos, vector.new(-1, -0.5, -1)),
						maxpos = vector.add(spawn_pos, vector.new(1, 1.5, 1)),
						minvel = vector.new(-3, 1, -3),
						maxvel = vector.new(3, 4, 3),
						minacc = vector.new(0, -2, 0),
						maxacc = vector.new(0, 0, 0),
						minexptime = 0.3,
						maxexptime = 0.8,
						minsize = 2,
						maxsize = 5,
						texture = "aura_particle.png^[colorize:#b8ffed:180",
						glow = 12,
					})
					minetest.sound_play("dragon_roar1",
						{ pos = spawn_pos, gain = 1.0, max_hear_distance = 25 })
					minetest.chat_send_player(pname,
						"De Draak ontwaakt en vecht aan jouw zijde...")
					gamelog.event("COMPANION_DRAGON_SPAWN",
						{ player = pname, at = spawn_pos }, player)
				end
			end
		else
			-- Player switched sword — Dragon will self-remove in its own on_step
			-- just nil the table entry if it's already gone
			if dragon and not dragon:get_pos() then
				boss.companion_dragons[pname] = nil
			end
		end
	end
end)

-- Clean up companion Dragon when a player leaves
minetest.register_on_leaveplayer(function(player)
	local pname = player:get_player_name()
	local dragon = boss.companion_dragons[pname]
	if dragon and dragon:get_pos() then
		dragon:remove()
	end
	boss.companion_dragons[pname] = nil
end)

-- ============================================================
-- /spawn <technical_name> — spawn a boss to fight the caller
-- ============================================================
local SPAWN_BY_NAME = {
	enemy_boss_dragoncall = 2,
	bram                  = 1,
	julian                = 4,
	vanessa               = 5,
	jan_willem            = 6,
	margriet              = 7,
}

-- Names that spawn a dedicated entity rather than boss:teacher
local SPAWN_CUSTOM = {
	enemy_boss_gladiator = "boss:gladiator",
}

minetest.register_chatcommand("spawn", {
	params      = "<boss_name> [count]",
	description = "Spawn one or more bosses at your position (server only). Names: " ..
		table.concat((function()
			local t = {}
			for k in pairs(SPAWN_BY_NAME) do t[#t + 1] = k end
			for k in pairs(SPAWN_CUSTOM) do t[#t + 1] = k end
			table.sort(t)
			return t
		end)(), ", "),
	privs       = { server = true },
	func        = function(name, param)
		gamelog.event("ADMIN_SPAWN", { player = name, params = param },
			minetest.get_player_by_name(name))
		-- Parse: <boss_name> [count]
		local pname, count_str = param:match("^%s*(%S+)%s*(%d*)%s*$")
		if not pname then pname = param:match("^%s*(.-)%s*$") end
		local count = math.min(math.max(tonumber(count_str) or 1, 1), 5)

		local player = minetest.get_player_by_name(name)
		if not player then return false, "Speler niet gevonden." end

		local pos = player:get_pos()
		local yaw = player:get_look_horizontal()

		-- ── Custom entity (e.g. gladiator) ───────────────────────────
		local custom_entity = SPAWN_CUSTOM[pname]
		if custom_entity then
			local spawned = 0
			for i = 1, count do
				local offset_x = (i - (count + 1) / 2) * 2.0
				local spawn_pos = vector.add(pos, vector.new(
					-math.sin(yaw) * 3 + math.cos(yaw) * offset_x,
					0,
					math.cos(yaw) * 3 + math.sin(yaw) * offset_x
				))
				local obj = minetest.add_entity(spawn_pos, custom_entity)
				if obj then
					enemy.boss_alive = obj
					spawned = spawned + 1
				end
			end
			local label = pname:gsub("_", " ")
			if spawned == 1 then
				return true, label .. " gespawnd."
			else
				return true, spawned .. "× " .. label .. " gespawnd."
			end
		end

		-- ── Standard teacher boss ─────────────────────────────────────
		local level = SPAWN_BY_NAME[pname]
		if not level then
			return false, "Onbekende baas. Gebruik: " ..
				table.concat((function()
					local t = {}
					for k in pairs(SPAWN_BY_NAME) do t[#t + 1] = k end
					for k in pairs(SPAWN_CUSTOM) do t[#t + 1] = k end
					table.sort(t)
					return t
				end)(), ", ")
		end

		-- Spread bosses in a horizontal line in front of the player.
		-- count=1 → directly 3 blocks ahead; count>1 → evenly spaced 2 blocks apart.
		local spawned = 0
		for i = 1, count do
			local offset_x = (i - (count + 1) / 2) * 2.0
			local spawn_pos = vector.add(pos, vector.new(
				-math.sin(yaw) * 3 + math.cos(yaw) * offset_x,
				0,
				math.cos(yaw) * 3 + math.sin(yaw) * offset_x
			))
			local obj = minetest.add_entity(spawn_pos, "boss:teacher")
			if obj then
				boss.set_level(obj, level)
				enemy.boss_alive = obj
				spawned = spawned + 1
			end
		end

		local data = BOSSES[level]
		if spawned == 1 then
			return true, "Baas gespawnd: " .. data.name .. " (level " .. level .. ")"
		else
			return true, spawned .. "× " .. data.name .. " gespawnd (level " .. level .. ")"
		end
	end,
})

-- ============================================================
-- Victory Dragon (Teinetarnagh) — spawns after all 7 waves are beaten.
-- Phases: intro → waiting → takeoff → flying → landing → landed
-- Carries the rider autonomously to ARENA2_POS.
-- Rider has no manual controls — just holds on.
-- Right-click to mount; right-click again or arrive = dismount.
-- ============================================================

local ARENA2_POS     = vector.new(-330, 177, -440) -- arena center (not used for flight)
local ARENA2_ENTRY   = vector.new(-303, 179, -439) -- entrance — dragon lands here

local VICTORY_LINES  = {
	"De strijd is gestreden. Beklim mijn rug.",
	"Uw vijanden liggen geveld. Ik zal u dragen door de lucht.",
	"Het vuur is geblust. Tijd om te vliegen.",
	"Moed overwint alles. Kom, laat ons de horizon zoeken.",
}

-- Mounted player data per player name
local victory_riders = {}

local function victory_attach(dragon_obj, player)
	local pname = player:get_player_name()
	if victory_riders[pname] then return end

	local props           = player:get_properties()
	local eye             = player:get_eye_offset()
	victory_riders[pname] = {
		collisionbox = table.copy(props.collisionbox),
		visual_size  = table.copy(props.visual_size or { x = 1, y = 1 }),
		eye_first    = eye.offset_first or vector.new(0, 0, 0),
		eye_third    = eye.offset_third or vector.new(0, 0, 0),
	}

	-- Hide player model while riding; zero collisionbox prevents clipping
	player:set_properties({
		collisionbox = { 0, 0, 0, 0, 0, 0 },
		visual_size  = { x = 0, y = 0 },
	})
	player:set_attach(dragon_obj, "Torso.2", vector.new(0, 0, 0), vector.new(0, 0, 0))

	-- Camera: 1/5 of waterdragon formula (scale=8): y=115*8/5=184, z=-280*8/5=-448
	local scale = 8
	player:set_eye_offset(
		vector.new(0, 115 * scale / 5, -270 * scale / 5),
		vector.new(0, 0, 0)
	)
	player:set_look_horizontal(dragon_obj:get_yaw() or 0)

	gamelog.event("DRAGON_MOUNT", { player = pname, at = dragon_obj:get_pos() }, player)
end

local function victory_detach(dragon_ent, player)
	local pname = player:get_player_name()
	local data  = victory_riders[pname]
	if not data then return end

	player:set_detach()
	player:set_properties({
		collisionbox = data.collisionbox,
		visual_size  = data.visual_size,
	})
	player:set_eye_offset(data.eye_first, data.eye_third)
	victory_riders[pname] = nil

	gamelog.event("DRAGON_DISMOUNT", { player = pname }, player)

	if dragon_ent and dragon_ent.rider == player then
		dragon_ent.rider = nil
	end
end

minetest.register_entity("boss:victory_dragon", {
	initial_properties = {
		visual               = "mesh",
		mesh                 = "draconis_fire_dragon.b3d",
		textures             = { "black_dragon.png^draconis_baked_in_shading.png" },
		physical             = false, -- manual velocity, no gravity
		collide_with_objects = false,
		collisionbox         = { -0.8, 0.0, -0.8, 0.8, 3.0, 0.8 },
		visual_size          = { x = 8, y = 8, z = 8 },
		makes_footstep_sound = false,
		static_save          = false,
		nametag              = "Teinetarnagh",
		nametag_color        = "#FFD700",
		glow                 = 8,
	},

	rider              = nil,
	_phase             = "intro", -- intro / waiting / takeoff / flying / landing / landed
	_phase_timer       = 3,  -- intro duration
	_anim_timer        = 0,
	_current_anim      = "hover",
	_flight_height     = 0, -- target y during flight

	on_activate        = function(self)
		self.object:set_armor_groups({ immortal = 1 })
		self.object:set_animation({ x = 321, y = 359 }, 30, 0, true) -- hover
		self.object:set_velocity(vector.new(0, 0, 0))
	end,

	on_rightclick      = function(self, clicker)
		if not clicker or not clicker:is_player() then return end
		local pname = clicker:get_player_name()

		if self.rider == clicker then
			victory_detach(self, clicker)
			self._phase = "waiting"
			self.object:set_velocity(vector.new(0, 0, 0))
			return
		end

		if self.rider then
			minetest.chat_send_player(pname, "Teinetarnagh heeft al een ruiter.")
			return
		end

		if self._phase ~= "waiting" and self._phase ~= "landed" then
			minetest.chat_send_player(pname, "Teinetarnagh is nog niet klaar om te rijden.")
			return
		end

		self.rider = clicker
		victory_attach(self.object, clicker)
		self._phase         = "flying"
		self._flight_height = (self.object:get_pos() or vector.new(0, 0, 0)).y + 22
		minetest.chat_send_player(pname, "Hou vast!")
	end,

	on_step            = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then return end

		self._phase_timer = (self._phase_timer or 0) - dtime
		self._anim_timer  = (self._anim_timer or 0) - dtime

		local function set_anim(name, frames, speed)
			if self._current_anim ~= name and self._anim_timer <= 0 then
				self._current_anim = name
				self._anim_timer   = 0.4
				self.object:set_animation(frames, speed, 0, true)
			end
		end

		-- ── INTRO: hover in place, say something ─────────────────────
		if self._phase == "intro" then
			self.object:set_velocity(vector.new(0, 0, 0))
			set_anim("hover", { x = 321, y = 359 }, 30)
			if self._phase_timer <= 0 then
				self._phase       = "waiting"
				self._phase_timer = 0

				local line        = VICTORY_LINES[math.random(#VICTORY_LINES)]
				for _, p in ipairs(minetest.get_connected_players()) do
					minetest.chat_send_player(p:get_player_name(), "[Teinetarnagh] " .. line)
				end
				minetest.sound_play("dragon_roar2",
					{ pos = pos, gain = 1.2, max_hear_distance = 60 })

				-- Descend to just above ground (~3 nodes)
				self._phase = "descend_wait"
				self._phase_timer = 999 -- no timer, descend until close to ground
			end
			return
		end

		-- ── DESCEND after intro: sink until near ground ───────────────
		if self._phase == "descend_wait" then
			-- Check ground below
			local below = minetest.get_node(vector.new(pos.x, pos.y - 2, pos.z))
			if below.name ~= "air" then
				self._phase = "waiting"
				self.object:set_velocity(vector.new(0, 0, 0))
				self.object:set_animation({ x = 481, y = 509 }, 25, 0, false) -- land
				minetest.after(1.0, function()
					if self.object and self.object:get_pos() then
						self.object:set_animation({ x = 321, y = 359 }, 25, 0, true) -- hover idle
					end
				end)
			else
				self.object:set_velocity(vector.new(0, -2.5, 0))
				set_anim("hover", { x = 321, y = 359 }, 25)
			end
			return
		end

		-- ── WAITING: hover gently, wait for rider ────────────────────
		if self._phase == "waiting" then
			self.object:set_velocity(vector.new(0, 0, 0))
			set_anim("hover", { x = 321, y = 359 }, 25)
			return
		end

		-- ── LANDED: stay still ───────────────────────────────────────
		if self._phase == "landed" then
			self.object:set_velocity(vector.new(0, 0, 0))
			set_anim("hover", { x = 321, y = 359 }, 20)
			return
		end

		-- ── RETURN_FLIGHT: carry offender back to arena 1 ────────────
		if self._phase == "return_flight" then
			local dest       = vector.new(3, 3, 3)
			local dir        = vector.direction(pos, dest)
			local hdist      = vector.distance(
				vector.new(pos.x, 0, pos.z),
				vector.new(dest.x, 0, dest.z)
			)

			-- Smooth yaw
			local target_yaw = minetest.dir_to_yaw(dir)
			local cur_yaw    = self.object:get_yaw() or 0
			local dyaw       = target_yaw - cur_yaw
			while dyaw > math.pi do dyaw = dyaw - 2 * math.pi end
			while dyaw < -math.pi do dyaw = dyaw + 2 * math.pi end
			self.object:set_yaw(cur_yaw + dyaw * math.min(dtime * 3, 1))

			if hdist < 8 then
				-- Drop the player at Arena 1 spawn and vanish
				if self.rider then
					local carried = self.rider
					victory_detach(self, carried)
					carried:set_pos(vector.new(dest.x, dest.y + 1, dest.z))
				end
				-- Kill any stale BGM that leaked through after wave completion
				if enemy and enemy.stop_bgm and not enemy.wave_active then
					enemy.stop_bgm()
				end
				self.object:remove()
				return
			end

			-- Fly toward arena 1, cruise high
			local cruise_y = self._flight_height or (pos.y + 20)
			local target_y = (pos.y < cruise_y - 1) and cruise_y or (dest.y + 20)
			local vel_y = (target_y - pos.y) * 0.15 * 12
			self.object:set_velocity(vector.new(dir.x * 14, vel_y, dir.z * 14))
			set_anim("fly", { x = 401, y = 439 }, 35)

			-- Gold aura
			self._aura_timer = (self._aura_timer or 0) - dtime
			if self._aura_timer <= 0 then
				self._aura_timer = 0.2
				minetest.add_particlespawner({
					amount = 6,
					time = 0.2,
					minpos = vector.add(pos, vector.new(-0.5, 0.5, -0.5)),
					maxpos = vector.add(pos, vector.new(0.5, 2.0, 0.5)),
					minvel = vector.new(-1, -1, -1),
					maxvel = vector.new(1, 0, 1),
					minacc = vector.new(0, -1, 0),
					maxacc = vector.new(0, 0, 0),
					minexptime = 0.3,
					maxexptime = 0.7,
					minsize = 2,
					maxsize = 5,
					texture = "aura_particle.png^[colorize:#FFD700:200",
					glow = 12,
				})
			end
			return
		end

		-- All phases below require rider
		local rider = self.rider
		if not rider or not rider:get_pos() then
			self.rider = nil
			self._phase = "waiting"
			self.object:set_velocity(vector.new(0, 0, 0))
			return
		end

		-- Face toward destination (entrance, not arena center)
		local dest       = ARENA2_ENTRY
		local dir        = vector.direction(pos, dest)
		local target_yaw = minetest.dir_to_yaw(dir)
		local cur_yaw    = self.object:get_yaw() or 0
		local dyaw       = target_yaw - cur_yaw
		while dyaw > math.pi do dyaw = dyaw - 2 * math.pi end
		while dyaw < -math.pi do dyaw = dyaw + 2 * math.pi end
		self.object:set_yaw(cur_yaw + dyaw * math.min(dtime * 3, 1))

		-- ── FLYING: diagonal autopilot toward entrance (waterdragon-style) ──
		if self._phase == "flying" then
			local hdist = vector.distance(
				vector.new(pos.x, 0, pos.z),
				vector.new(dest.x, 0, dest.z)
			)

			if hdist < 8 then
				-- Close enough horizontally — start descent
				self._phase = "landing"
				return
			end

			-- Obstacle avoidance: raycast 7 nodes ahead, climb if blocked
			local ahead = vector.add(pos, vector.multiply(dir, 7))
			local clear = minetest.line_of_sight(pos, ahead)
			if not clear then
				self._flight_height = math.max(self._flight_height, pos.y + 5)
			end

			-- Waterdragon-style diagonal flight: climb to cruise height, then level toward dest
			local target_y = (pos.y < self._flight_height - 1) and self._flight_height or (dest.y + 2)
			local vel_y = (target_y - pos.y) * 0.15 * 12
			local vx = dir.x * 28
			local vz = dir.z * 28
			self.object:set_velocity(vector.new(vx, vel_y, vz))
			set_anim("fly", { x = 401, y = 439 }, 35)

			-- Particles: wind/embers behind Dragon
			self._aura_timer = (self._aura_timer or 0) - dtime
			if self._aura_timer <= 0 then
				self._aura_timer = 0.25
				minetest.add_particlespawner({
					amount = 5,
					time = 0.25,
					minpos = vector.add(pos, vector.new(-0.5, 0.5, -0.5)),
					maxpos = vector.add(pos, vector.new(0.5, 2.0, 0.5)),
					minvel = vector.new(-1, -0.5, -1),
					maxvel = vector.new(1, 0.5, 1),
					minacc = vector.new(0, -0.5, 0),
					maxacc = vector.new(0, 0, 0),
					minexptime = 0.3,
					maxexptime = 0.8,
					minsize = 2,
					maxsize = 4,
					texture = "aura_particle.png^[colorize:#FFD700:160",
					glow = 8,
				})
			end
			return
		end

		-- ── LANDING at arena 2 ────────────────────────────────────────
		if self._phase == "landing" then
			local target_y = dest.y + 1
			local dy = target_y - pos.y

			if math.abs(dy) < 1.5 then
				-- Arrived
				self.object:set_velocity(vector.new(0, 0, 0))
				self.object:set_animation({ x = 481, y = 509 }, 25, 0, false) -- land
				self._phase = "landed"

				-- Roar and dismount rider
				minetest.sound_play("dragon_roar3",
					{ pos = pos, gain = 1.0, max_hear_distance = 40 })
				for _, p in ipairs(minetest.get_connected_players()) do
					minetest.chat_send_player(p:get_player_name(),
						"[Teinetarnagh] Wij zijn er. Ga.")
				end
				if self.rider then
					victory_detach(self, self.rider)
				end

				minetest.after(1.5, function()
					if self.object and self.object:get_pos() then
						self.object:set_animation({ x = 321, y = 359 }, 25, 0, true)
					end
				end)
			else
				set_anim("hover", { x = 321, y = 359 }, 25)
				self.object:set_velocity(vector.new(0, dy * 3, 0))
			end
			return
		end
	end,

	on_punch           = function(self, puncher)
		if puncher and puncher:is_player() then
			minetest.sound_play("dragon_roar1",
				{ pos = self.object:get_pos(), gain = 0.8, max_hear_distance = 30 })
		end
	end,

	on_deactivate      = function(self)
		-- Clear singleton so a new dragon can be spawned later
		if boss._victory_dragon_obj == self.object then
			boss._victory_dragon_obj = nil
		end
		-- Detach any rider
		if self.rider then
			victory_detach(self, self.rider)
		end
	end,
})

-- Detach rider when player dies or leaves
minetest.register_on_dieplayer(function(player)
	local pname = player:get_player_name()
	if victory_riders[pname] then
		player:set_detach()
		local data = victory_riders[pname]
		player:set_properties({ collisionbox = data.collisionbox })
		player:set_eye_offset(data.eye_first, data.eye_third)
		victory_riders[pname] = nil
	end
end)

minetest.register_on_leaveplayer(function(player)
	local pname = player:get_player_name()
	if victory_riders[pname] then
		player:set_detach()
		victory_riders[pname] = nil
	end
end)
-- Grab a player, fly them back to arena 1, then vanish.
-- Called from registered/init.lua when the schedule computer is edited.
function boss.return_player(player)
	if not boss._victory_dragon_obj then return end
	local vobj = boss._victory_dragon_obj
	if not vobj:get_pos() then return end
	local ent = vobj:get_luaentity()
	if not ent then return end
	-- Detach any existing rider first
	if ent.rider and ent.rider ~= player then
		victory_detach(ent, ent.rider)
	end
	victory_attach(vobj, player)
	ent.rider = player
	ent._phase = "return_flight"
	gamelog.progress("PLAYER_RETURNED_BY_DRAGON", { player = player:get_player_name() })
	ent._flight_height = vobj:get_pos().y + 20
end

function boss.spawn_victory_dragon(near_pos)
	if boss._victory_dragon_obj and boss._victory_dragon_obj:get_pos() then
		return
	end

	local center = near_pos or vector.new(42, 14, 31)

	minetest.after(2.5, function()
		-- Double-check: still no Dragon?
		if boss._victory_dragon_obj and boss._victory_dragon_obj:get_pos() then return end

		-- Dramatic entry: spawn 20 blocks above the given position
		local spawn_pos = vector.add(center, vector.new(0, 20, 0))
		local obj = minetest.add_entity(spawn_pos, "boss:victory_dragon")
		if not obj then return end
		boss._victory_dragon_obj = obj

		-- Entity handles its own descent via intro phase

		-- Announce
		for _, p in ipairs(minetest.get_connected_players()) do
			minetest.chat_send_player(p:get_player_name(),
				"*** Een schaduw daalt neer...***")
		end

		minetest.sound_play("dragon_roar2",
			{ pos = spawn_pos, gain = 1.0, max_hear_distance = 80 })
	end)
end

minetest.register_chatcommand("spawn_victory_dragon", {
	privs = { server = true },
	description = "Spawn de Overwinnings-Draak voor test (spawnt naast jou)",
	func = function(name)
		local player = minetest.get_player_by_name(name)
		gamelog.event("ADMIN_SPAWN_DRAGON", { player = name },
			minetest.get_player_by_name(name))
		if not player then return false, "Speler niet gevonden." end
		boss.spawn_victory_dragon(player:get_pos())
		return true, "De Draak is onderweg..."
	end,
})

minetest.register_chatcommand("floor", {
	privs       = { server = true },
	params      = "[<spelernaam>]",
	description = "Teleporteer speler 2 blokken omlaag en bouw een stenen kooi. Zonder naam: jijzelf zakt door de vloer.",
	func        = function(caller, param)
		gamelog.event("ADMIN_FLOOR", { player = caller, target = param ~= "" and param or caller },
			minetest.get_player_by_name(caller))
		local target_name = param ~= "" and param or nil

		if not target_name then
			target_name = caller
		end

		local target = minetest.get_player_by_name(target_name)
		if not target then return false, "Speler '" .. target_name .. "' niet gevonden." end

		local pos = target:get_pos()
		-- Floor position: 2 blocks below player feet
		local fx = math.floor(pos.x + 0.5)
		local fy = math.floor(pos.y) - 2
		local fz = math.floor(pos.z + 0.5)

		-- Place floor block
		minetest.set_node({ x = fx, y = fy, z = fz }, { name = "default:stone" })

		-- Place walls (3-block-high ring around 3×3 area, leaving only inside open)
		local stone = { name = "default:stone" }
		for dx = -1, 1 do
			for dz = -1, 1 do
				if dx == -1 or dx == 1 or dz == -1 or dz == 1 then
					for dy = 1, 3 do
						minetest.set_node({ x = fx + dx, y = fy + dy, z = fz + dz }, stone)
					end
				end
			end
		end

		-- Roof
		for dx = -1, 1 do
			for dz = -1, 1 do
				minetest.set_node({ x = fx + dx, y = fy + 4, z = fz + dz }, stone)
			end
		end

		-- Teleport player onto the floor block
		target:set_pos(vector.new(fx, fy + 1, fz))

		minetest.chat_send_player(target_name,
			"Je zit gevangen in de vloer!")
		return true, target_name .. " is opgesloten."
	end,
})
