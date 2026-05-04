-- boss: Teacher boss entity
-- Each wave has one boss (teacher). Higher levels = more HP and damage.
-- Level 7 boss is the "Directeur" (principal) — final boss.
-- Hugo (level 2) has kung fu abilities and summons a dragon at low HP.

boss = {}

-- Boss data per level: name, HP, damage, texture
local BOSSES = {
	[1] = {name = "Bram",        hp = 100, dmg = 2,  tex = "boss_bram.png",       drop = "registered:sword_bronze"},
	[2] = {name = "Hugo",        hp = 150, dmg = 3,  tex = "boss_hugo.png"},
	[3] = {name = "Joachim",     hp = 200, dmg = 4,  tex = "boss_joachim.png",    drop = "registered:sword_diamond"},
	[4] = {name = "Julian",      hp = 250, dmg = 5,  tex = "boss_julian.png",     drop = "registered:sword_ancient"},
	[5] = {name = "Rosanne",     hp = 300, dmg = 6,  tex = "boss_rosanne.png"},
	[6] = {name = "Jan Willem",  hp = 350, dmg = 7,  tex = "boss_janwillem.png",  drop = "registered:sword_dragonpower"},
	[7] = {name = "Margriet",    hp = 450, dmg = 8,  tex = "boss_margriet.png",   drop = "registered:sword_elements"},
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
-- "dash"    : explosive rush with dragon cry
-- "recover" : brief pause after dash
-- "summon"  : retreating + channeling dragon at low HP
-- "linked"  : invulnerable while dragon lives
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
	self.object:set_animation({x = 0, y = 79}, 15, 0, true)

	-- Transition to dash after timer expires
	if self._enemy_boss_dragoncall_timer <= 0 then
		self._enemy_boss_dragoncall_phase = "dash"
		self._enemy_boss_dragoncall_timer = 0.6 -- dash duration

		-- Dragon cry sound
		local cry = "enemy_boss_dragoncall_cry" .. math.random(1, 2)
		minetest.sound_play(cry, {pos = pos, gain = 1.2, max_hear_distance = 30})

		-- Sprint animation
		self.object:set_animation({x = 168, y = 187}, 60, 0, true)
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
			nearest:set_hp(nearest:get_hp() - self._damage * 2, {type = "punch"})
		else
			nearest:punch(self.object, 1.0, {damage_groups = {fleshy = self._damage * 2}}, vector.new(0,0,0))
		end
		self._attack_cooldown = 0.4
		self.object:set_animation({x = 189, y = 198}, 50, 0, false)
	end

	if self._enemy_boss_dragoncall_timer <= 0 then
		self._enemy_boss_dragoncall_phase = "recover"
		self._enemy_boss_dragoncall_timer = 1.0
		self.object:set_velocity(vector.new(0, -9.81, 0))
		self.object:set_animation({x = 0, y = 79}, 15, 0, true)
	end
end

-- Hugo recover: brief pause after dash
local function enemy_boss_dragoncall_recover(self, dtime)
	self._enemy_boss_dragoncall_timer = self._enemy_boss_dragoncall_timer - dtime
	self.object:set_velocity(vector.new(0, -9.81, 0))

	if self._enemy_boss_dragoncall_timer <= 0 then
		self._enemy_boss_dragoncall_phase = "stalk"
		self._enemy_boss_dragoncall_timer = 2.0 + math.random() * 2.0 -- 2-4 sec before next dash
	end
end

-- Hugo summon: retreat + channel dragon
local function enemy_boss_dragoncall_summon(self, dtime, pos, nearest)
	self._enemy_boss_dragoncall_timer = self._enemy_boss_dragoncall_timer - dtime

	-- Retreat from player
	local ppos = nearest:get_pos()
	local away = vector.direction(ppos, pos)
	self.object:set_velocity(vector.new(away.x * 3, -9.81, away.z * 3))
	self.object:set_yaw(minetest.dir_to_yaw(vector.direction(pos, ppos)))

	-- Glow effect intensifies
	local glow = math.floor(14 - self._enemy_boss_dragoncall_timer * 4)
	self.object:set_properties({glow = math.min(glow, 14)})

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
		texture = "draconis_fire_particle.png^[colorize:#AA00FF:200",
		glow = 12,
	})

	-- Turn black at halfway
	if self._enemy_boss_dragoncall_timer < 1.5 and not self._enemy_boss_dragoncall_turned_black then
		self._enemy_boss_dragoncall_turned_black = true
		self.object:set_properties({
			textures = {"boss_hugo.png^[colorize:#000000:200"},
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
			texture = "draconis_fire_particle.png^[colorize:#220044:200",
			glow = 10,
		})
	end

	if self._enemy_boss_dragoncall_timer <= 0 then
		-- Summon the Dragon!
		self.object:set_velocity(vector.new(0, -9.81, 0))
		local spawn_pos = vector.add(pos, vector.new(0, 2, 3))
		local dragon = minetest.add_entity(spawn_pos, "boss:summoned_dragon")
		if dragon then
			self._summoned_dragon = dragon
			local dlua = dragon:get_luaentity()
			if dlua then
				dlua._master = self.object
			end
			minetest.sound_play("dragon_roar1", {pos = spawn_pos, gain = 1.5, max_hear_distance = 50})

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
				texture = "draconis_fire_particle.png^[colorize:#CC88FF:120",
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

-- Hugo linked: invulnerable while dragon lives, stands still
local function enemy_boss_dragoncall_linked(self, dtime, pos, nearest)
	-- Check if dragon is still alive
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
	self.object:set_animation({x = 0, y = 79}, 10, 0, true)
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
	self.object:set_animation({x = 168, y = 187}, 30, 0, true)

	self._attack_cooldown = self._attack_cooldown - dtime
	if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
		if nearest:is_player() then
			nearest:set_hp(nearest:get_hp() - self._damage, {type = "punch"})
		else
			nearest:punch(self.object, 1.0, {damage_groups = {fleshy = self._damage}}, vector.new(0,0,0))
		end
		self._attack_cooldown = 1.5
		self.object:set_animation({x = 189, y = 198}, 30, 0, false)
	end
end

local function bram_pullout_step(self, dtime, pos)
	self.object:set_velocity(vector.new(0, -9.81, 0))
	self._bram_timer = self._bram_timer - dtime

	-- Idle "rummaging" animation
	self.object:set_animation({x = 0, y = 79}, 10, 0, true)

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
	self.object:set_animation({x = 168, y = 187}, 55, 0, true)

	self._attack_cooldown = self._attack_cooldown - dtime
	if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
		local dmg = math.ceil(self._damage * 1.5)
		if nearest:is_player() then
			nearest:set_hp(nearest:get_hp() - dmg, {type = "punch"})
		else
			nearest:punch(self.object, 1.0, {damage_groups = {fleshy = dmg}}, vector.new(0,0,0))
		end
		self._attack_cooldown = 0.5 -- rapid drumstick cadence
		self.object:set_animation({x = 189, y = 198}, 65, 0, false)
	end
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
			nearest:set_hp(nearest:get_hp() - self._damage, {type = "punch"})
		else
			nearest:punch(self.object, 1.0, {damage_groups = {fleshy = self._damage}}, vector.new(0,0,0))
		end
		self._attack_cooldown = 1.5
		self.object:set_animation({x = 189, y = 198}, 30, 0, false)
		minetest.after(0.5, function()
			if self.object and self.object:get_pos() then
				self.object:set_animation({x = 168, y = 187}, 30, 0, true)
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
		self.object:set_animation({x = 168, y = 187}, 30, 0, true)

		-- Melee
		self._attack_cooldown = self._attack_cooldown - dtime
		if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
			if nearest:is_player() then
				nearest:set_hp(math.max(0, nearest:get_hp() - self._damage), {type = "punch"})
			else
				nearest:punch(self.object, 1.0, {damage_groups = {fleshy = self._damage}}, vector.new(0,0,0))
			end
			self._attack_cooldown = 1.5
			self.object:set_animation({x = 189, y = 198}, 30, 0, false)
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
		self.object:set_animation({x = 189, y = 198}, 20, 0, true)

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
				maxpos = vector.add(shoulder_pos, vector.new( 0.08, 0.1,  0.08)),
				minvel = vector.new(dir.x * 3 - 0.4, -0.5, dir.z * 3 - 0.4),
				maxvel = vector.new(dir.x * 5 + 0.4,  0.5, dir.z * 5 + 0.4),
				minacc = vector.new(-0.2, -9, -0.2),
				maxacc = vector.new( 0.2, -6,  0.2),
				minexptime = 0.35,
				maxexptime = 0.75,
				minsize = 2.5,
				maxsize = 5,
				texture = "draconis_fire_particle.png^[colorize:#3b1200:210",
				glow = 0,
			})
		end

		-- Damage players in forward splash cone every 0.45 s
		self._attack_cooldown = self._attack_cooldown - dtime
		if self._attack_cooldown <= 0 then
			for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 4.5)) do
				if obj:is_player() then
					local to_obj = vector.direction(pos, obj:get_pos())
					local dot = to_obj.x * dir.x + to_obj.z * dir.z
					if dot > 0.25 then
						obj:set_hp(math.max(0, obj:get_hp() - self._damage), {type = "punch"})
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
				obj:set_hp(math.max(0, obj:get_hp() - 8), {type = "punch"})
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
		maxpos = vector.add(pos, vector.new( 0.4,  0.4,  0.4)),
		minvel = vector.new(-6, -4, -6),
		maxvel = vector.new( 6,  5,  6),
		minacc = vector.new(0, -6, 0),
		maxacc = vector.new(0, -3, 0),
		minexptime = 0.15,
		maxexptime = 0.45,
		minsize = 2,
		maxsize = 5,
		texture = "draconis_fire_particle.png^[colorize:#111111:220",
		glow = 2,
	})
	minetest.sound_play("default_explode", {pos = pos, gain = 0.5, max_hear_distance = 20})
end

minetest.register_entity("boss:raisin", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 0.15, y = 0.15, z = 0.15},
		textures = {
			"draconis_fire_particle.png^[colorize:#111111:255",
			"draconis_fire_particle.png^[colorize:#111111:255",
			"draconis_fire_particle.png^[colorize:#111111:255",
			"draconis_fire_particle.png^[colorize:#111111:255",
			"draconis_fire_particle.png^[colorize:#111111:255",
			"draconis_fire_particle.png^[colorize:#111111:255",
		},
		physical = true,
		collide_with_objects = false,
		collisionbox = {-0.07, -0.07, -0.07, 0.07, 0.07, 0.07},
		static_save = false,
	},

	_bounces = 0,
	_prev_vel = nil,
	_bounce_cd = 0,
	_exploded = false,
	_owner = nil,
	_lifetime = 0,

	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
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
			local nv = {x = vel.x, y = vel.y, z = vel.z}
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
-- Rosanne (level 5): artist boss — draws weapons from thin air
-- Phases: "normal" → "drawing" → "armed" → (redraw after timer)
-- Allowed weapons (blacklist: diamond, ancient, dragonpower, elements)
-- ============================================================

local ROSANNE_WEAPONS = {
	{item = "registered:sword_wood",   dmg = 4,  name = "Houten Zwaard"},
	{item = "registered:sword_steel",  dmg = 7,  name = "Stalen Zwaard"},
	{item = "registered:sword_bronze", dmg = 9,  name = "Bronzen Zwaard"},
}

-- Unfinished weapon entity: floats and spins while Rosanne draws
minetest.register_entity("boss:unfinished_weapon", {
	initial_properties = {
		visual = "sprite",
		textures = {"drawing_item_ent.png"},
		visual_size = {x = 1.0, y = 1.0},
		physical = false,
		collisionbox = {0, 0, 0, 0, 0, 0},
		static_save = false,
		pointable = false,
		glow = 10,
	},
	_spin = 0,
	_bob  = 0,
	_particle_timer = 0,
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
	end,
	on_step = function(self, dtime)
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
				amount = 3, time = 0.15,
				minpos = vector.add(pos, vector.new(-0.4, -0.4, -0.4)),
				maxpos = vector.add(pos, vector.new(0.4, 0.4, 0.4)),
				minvel = vector.new(-0.5, 0.5, -0.5),
				maxvel = vector.new(0.5, 1.5, 0.5),
				minacc = vector.new(0, -0.5, 0), maxacc = vector.new(0, 0, 0),
				minexptime = 0.3, maxexptime = 0.7,
				minsize = 1, maxsize = 2.5,
				texture = "boss_rosanne_sketch.png",
				glow = 4,
			})
		end
	end,
})

-- Rosanne drawing logic
local function rosanne_step(self, dtime, pos, nearest, nearest_dist)
	self._rosanne_timer = self._rosanne_timer - dtime

	if self._rosanne_phase == "normal" then
		-- Walk + melee, then trigger drawing phase
		local ppos = nearest:get_pos()
		local dir = vector.direction(pos, ppos)
		self.object:set_yaw(minetest.dir_to_yaw(dir))
		self.object:set_velocity(vector.new(dir.x * 2.0, -9.81, dir.z * 2.0))
		self.object:set_animation({x = 168, y = 187}, 30, 0, true)

		self._attack_cooldown = self._attack_cooldown - dtime
		if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
			if nearest:is_player() then
				nearest:set_hp(math.max(0, nearest:get_hp() - self._damage), {type = "punch"})
			else
				nearest:punch(self.object, 1.0, {damage_groups = {fleshy = self._damage}}, vector.new(0,0,0))
			end
			self._attack_cooldown = 1.5
			self.object:set_animation({x = 189, y = 198}, 30, 0, false)
		end

		if self._rosanne_timer <= 0 then
			self._rosanne_phase = "drawing"
			self._rosanne_timer  = 3.5
			self._drawing_spawned = false
			-- Remove old weapon visual
			if self._weapon_entity and self._weapon_entity:get_pos() then
				self._weapon_entity:remove()
				self._weapon_entity = nil
			end
			-- Jump/float up
			self.object:set_velocity(vector.new(0, 5, 0))
			for _, p in ipairs(minetest.get_connected_players()) do
				minetest.chat_send_player(p:get_player_name(),
					"Rosanne pakt haar potlood... ze tekent iets!")
			end
		end

	elseif self._rosanne_phase == "drawing" then
		-- Float in place, run mine animation
		self.object:set_velocity(vector.new(0, 0.2, 0))
		self.object:set_animation({x = 189, y = 198}, 20, 0, true)
		local ppos = nearest:get_pos()
		self.object:set_yaw(minetest.dir_to_yaw(vector.direction(pos, ppos)))

		-- Spawn the unfinished weapon entity once, shortly after entry
		if not self._drawing_spawned and self._rosanne_timer < 3.0 then
			self._drawing_spawned = true
			local spawn_pos = vector.add(pos, vector.new(0, 1.8, 0))
			local ent = minetest.add_entity(spawn_pos, "boss:unfinished_weapon")
			self._drawing_entity = ent
			minetest.add_particlespawner({
				amount = 20, time = 0.3,
				minpos = vector.add(spawn_pos, vector.new(-0.5, -0.5, -0.5)),
				maxpos = vector.add(spawn_pos, vector.new(0.5, 0.5, 0.5)),
				minvel = vector.new(-2, 1, -2), maxvel = vector.new(2, 3, 2),
				minacc = vector.new(0, -1, 0), maxacc = vector.new(0, 0, 0),
				minexptime = 0.3, maxexptime = 0.8,
				minsize = 1, maxsize = 3,
				texture = "boss_rosanne_sketch.png",
				glow = 6,
			})
			minetest.sound_play("default_place_node_hard",
				{pos = pos, gain = 0.5, max_hear_distance = 15})
		end

		-- Keep unfinished weapon hovering near her hand
		if self._drawing_entity and self._drawing_entity:get_pos() then
			self._drawing_entity:set_pos(vector.add(pos, vector.new(0.5, 1.8, 0)))
		end

		-- Drawing done — pick weapon and enter armed phase
		if self._rosanne_timer <= 0 then
			if self._drawing_entity and self._drawing_entity:get_pos() then
				self._drawing_entity:remove()
				self._drawing_entity = nil
			end

			-- Pick random allowed weapon
			local wdata = ROSANNE_WEAPONS[math.random(1, #ROSANNE_WEAPONS)]
			self._drawn_weapon = wdata
			self._damage = wdata.dmg

			-- Attach weapon visual to right arm
			local wobj = minetest.add_entity(pos, "boss:drumstick_visual")
			if wobj then
				wobj:set_properties({wield_item = wdata.item})
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
				amount = 25, time = 0.3,
				minpos = vector.add(pos, vector.new(-0.5, 0.5, -0.5)),
				maxpos = vector.add(pos, vector.new(0.5, 2.0, 0.5)),
				minvel = vector.new(-3, 1, -3), maxvel = vector.new(3, 4, 3),
				minacc = vector.new(0, -2, 0), maxacc = vector.new(0, 0, 0),
				minexptime = 0.2, maxexptime = 0.6,
				minsize = 2, maxsize = 4,
				texture = "draconis_fire_particle.png^[colorize:#FFAACC:200",
				glow = 8,
			})
			minetest.sound_play("default_place_node_hard",
				{pos = pos, gain = 0.8, max_hear_distance = 20})

			self._rosanne_phase = "armed"
			self._rosanne_timer  = 12.0 + math.random() * 8.0  -- redraw after 12–20 sec
		end

	elseif self._rosanne_phase == "armed" then
		-- Fight with drawn weapon
		local ppos = nearest:get_pos()
		local dir = vector.direction(pos, ppos)
		self.object:set_yaw(minetest.dir_to_yaw(dir))
		self.object:set_velocity(vector.new(dir.x * 2.2, -9.81, dir.z * 2.2))
		self.object:set_animation({x = 168, y = 187}, 35, 0, true)

		self._attack_cooldown = self._attack_cooldown - dtime
		if nearest_dist < 2.5 and self._attack_cooldown <= 0 then
			if nearest:is_player() then
				nearest:set_hp(math.max(0, nearest:get_hp() - self._damage), {type = "punch"})
			else
				nearest:punch(self.object, 1.0, {damage_groups = {fleshy = self._damage}}, vector.new(0,0,0))
			end
			self._attack_cooldown = 1.2
			self.object:set_animation({x = 189, y = 198}, 40, 0, false)
		end

		-- Redraw timer expired → go draw again
		if self._rosanne_timer <= 0 then
			self._rosanne_phase = "normal"
			self._rosanne_timer  = 0.1
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
		visual_size = {x = 0.5, y = 0.5},
		physical = false,
		collisionbox = {0, 0, 0, 0, 0, 0},
		static_save = false,
		pointable = false,
	},
	on_activate = function(self)
		self.object:set_armor_groups({immortal = 1})
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
	initial_properties = {
		visual = "mesh",
		mesh = "character.b3d",
		textures = {"boss_bram.png"},
		physical = true,
		collide_with_objects = true,
		collisionbox = {-0.4, 0.0, -0.4, 0.4, 2.0, 0.4},
		visual_size = {x = 1.2, y = 1.2, z = 1.2},
		makes_footstep_sound = true,
		static_save = false,
		nametag = "",
		nametag_color = "#FF3333",
	},

	_hp = 100,
	_max_hp = 100,
	_damage = 2,
	_attack_cooldown = 0,
	_level = 1,

	-- Bram-specific state
	_bram_phase = "normal",
	_bram_timer = 0,
	_drumstick_entity = nil,

	-- Hugo-specific state
	_enemy_boss_dragoncall_phase = "stalk",
	_enemy_boss_dragoncall_timer = 3.0,
	_enemy_boss_dragoncall_turned_black = false,
	_summoned_dragon = nil,

	-- Julian-specific state
	_julian_phase = "normal",
	_julian_timer = 8.0,
	_julian_pour_tick = 0,

	-- Rosanne-specific state
	_rosanne_phase   = "normal",
	_rosanne_timer   = 5.0,
	_drawn_weapon    = nil,
	_drawing_entity  = nil,
	_drawing_spawned = false,
	_weapon_entity   = nil,

	on_activate = function(self, staticdata)
		self.object:set_animation({x = 168, y = 187}, 30, 0, true)
		self.object:set_armor_groups({fleshy = 100})
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		if not puncher then return end
		-- Accept hits from players or stunt double
		local is_stunt = puncher:get_luaentity() and puncher:get_luaentity().name == "trailer:stunt_double"
		if not puncher:is_player() and not is_stunt then return end

		-- Hugo linked phase: invulnerable while dragon lives
		if self._level == 2 and self._enemy_boss_dragoncall_phase == "linked" then
			minetest.chat_send_player(puncher:get_player_name(),
				"Hugo is beschermd! Versla eerst de draak!")
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

		-- Hugo: trigger dragon summon at 25% HP
		if self._level == 2 and self._enemy_boss_dragoncall_phase ~= "summon" and self._enemy_boss_dragoncall_phase ~= "linked"
		   and self._hp > 0 and self._hp <= self._max_hp * 0.25 then
			self._enemy_boss_dragoncall_phase = "summon"
			self._enemy_boss_dragoncall_timer = 3.0  -- 3 second channeling
		end

		if self._hp <= 0 then
			local pos = self.object:get_pos()
			local data = BOSSES[self._level] or BOSSES[1]
			if pos and data.drop then
				minetest.add_item(pos, data.drop)
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

	on_step = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then return end

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
			if self._enemy_boss_dragoncall_phase == "stalk" then
				enemy_boss_dragoncall_stalk(self, dtime, pos, nearest, nearest_dist)
			elseif self._enemy_boss_dragoncall_phase == "dash" then
				enemy_boss_dragoncall_dash(self, dtime, pos, nearest, nearest_dist)
			elseif self._enemy_boss_dragoncall_phase == "recover" then
				enemy_boss_dragoncall_recover(self, dtime)
			elseif self._enemy_boss_dragoncall_phase == "summon" then
				enemy_boss_dragoncall_summon(self, dtime, pos, nearest)
			elseif self._enemy_boss_dragoncall_phase == "linked" then
				enemy_boss_dragoncall_linked(self, dtime, pos, nearest)
			end
			return
		end

		-- Julian (level 4): hot chocolate pour attack
		if self._level == 4 then
			julian_step(self, dtime, pos, nearest, nearest_dist)
			return
		end

		-- Rosanne (level 5): drawing ability
		if self._level == 5 then
			rosanne_step(self, dtime, pos, nearest, nearest_dist)
			return
		end

		-- Generic boss behavior for other levels
		generic_on_step(self, dtime, pos, nearest, nearest_dist)
	end,
})

-- ============================================================
-- Summoned Dragon entity (Hugo's dragon)
-- ============================================================
minetest.register_entity("boss:summoned_dragon", {
	initial_properties = {
		visual = "mesh",
		mesh = "draconis_fire_dragon.b3d",
		textures = {"draconis_fire_dragon_black.png^draconis_baked_in_shading.png"},
		physical = true,
		collide_with_objects = false,
		collisionbox = {-0.5, 0.0, -0.5, 0.5, 2.5, 0.5},
		visual_size = {x = 6, y = 6, z = 6},
		makes_footstep_sound = false,
		static_save = false,
		nametag = "Duistere Draak",
		nametag_color = "#ff7700",
		glow = 8,
		backface_culling = false,
	},

	_hp = 100,
	_max_hp = 20,
	_damage = 5,
	_attack_cooldown = 0,
	_roar_timer = 3.0,
	_breath_timer = 0,
	_anim_timer = 0,  -- prevent animation restart mid-play
	_current_anim = "walk",
	_master = nil,  -- Hugo objectref
	_aura_timer = 0,
	_smoke_timer = 0,
	_glow_phase = 0,

	on_activate = function(self, staticdata)
		self.object:set_animation({x = 211, y = 249}, 30, 0, true) -- walk
		self.object:set_armor_groups({fleshy = 100})

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
				texture = "draconis_fire_particle.png^[colorize:#AA00FF:200",
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
				texture = "draconis_fire_particle.png^[colorize:#AA00FF:200",
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
					texture = "draconis_fire_particle.png",
					glow = 14,
				})
			end
		end
		end -- puncher:is_player()

		self._hp = self._hp - dmg

		self.object:set_properties({
			nametag = "Duistere Draak",
		})

		-- Roar when hit
		if math.random() < 0.4 then
			local pos = self.object:get_pos()
			minetest.sound_play("dragon_roar" .. math.random(1, 2),
				{pos = pos, gain = 5.0, max_hear_distance = 50})
		end

		if self._hp <= 0 then
			-- Dragon dies — kill Hugo too
			local pos = self.object:get_pos()
			if pos then
				minetest.sound_play("dragon_roar2", {pos = pos, gain = 7.0, max_hear_distance = 60})
			end

			-- Drop fire sword
			if pos then
				minetest.add_item(pos, "registered:sword_fire")
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

		local nearest, nearest_dist = find_nearest_player(pos)
		if not nearest then return end

		local ppos = nearest:get_pos()
		local dir = vector.direction(pos, ppos)

		self.object:set_yaw(minetest.dir_to_yaw(dir))

		-- Pulsating glow effect
		self._glow_phase = self._glow_phase + dtime * 2.0
		local glow = math.floor(8 + math.sin(self._glow_phase) * 4)
		self.object:set_properties({glow = glow})

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
				texture = "draconis_fire_particle.png^[colorize:#6600AA:180",
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
				texture = "draconis_fire_particle.png^[colorize:#1a0033:200",
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
			self.object:set_animation({x = 211, y = 249}, 30, 0, true)
		end

		-- Random roar
		self._roar_timer = self._roar_timer - dtime
		if self._roar_timer <= 0 then
			minetest.sound_play("dragon_roar" .. math.random(1, 2),
			{pos = pos, gain = 3.2, max_hear_distance = 50})
			self._roar_timer = 4.0 + math.random() * 4.0
		end

		-- Fire breath attack (enhanced cinematic version)
		self._attack_cooldown = self._attack_cooldown - dtime
		if nearest_dist < 5.0 and self._attack_cooldown <= 0 and self._anim_timer <= 0 then
			-- Fire breath animation (plays ~2 sec, don't interrupt)
			self._current_anim = "walk_fire"
			self._anim_timer = 2.0
			self.object:set_animation({x = 61, y = 119}, 30, 0, false)
			minetest.sound_play("draconis_fire_breath",
				{pos = pos, gain = 1.0, max_hear_distance = 30})

			-- Damage target
			if nearest:is_player() then
				nearest:set_hp(nearest:get_hp() - self._damage, {type = "punch"})
			else
				nearest:punch(self.object, 1.0, {damage_groups = {fleshy = self._damage}}, vector.new(0,0,0))
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
				texture = "draconis_fire_particle.png",
				glow = 14,
			})
			-- Outer flame spray (wider, softer)
			minetest.add_particlespawner({
				amount = 30,
				time = 0.8,
				minpos = mouth,
				maxpos = vector.add(mouth, vector.new(0.5, 0.5, 0.5)),
				minvel = vector.add(vector.multiply(breath_dir, 4), vector.new(-2, 0, -2)),
				maxvel = vector.add(vector.multiply(breath_dir, 8), vector.new(2, 3, 2)),
				minacc = vector.new(0, 0.5, 0),
				maxacc = vector.new(0, 2, 0),
				minexptime = 0.4,
				maxexptime = 1.0,
				minsize = 4,
				maxsize = 9,
				texture = "draconis_fire_particle.png^[colorize:#FF4400:80",
				glow = 12,
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
		visual_size = {x = scale, y = scale, z = scale},
		textures = {data.tex},
	})

	-- Hugo: initialize kung fu state
	if level == 2 then
		lua._enemy_boss_dragoncall_phase = "stalk"
		lua._enemy_boss_dragoncall_timer = 3.0 + math.random() * 2.0
		lua._enemy_boss_dragoncall_turned_black = false
		lua._summoned_dragon = nil
	end

	-- Rosanne: initialize drawing state
	if level == 5 then
		lua._rosanne_phase   = "normal"
		lua._rosanne_timer   = 5.0 + math.random() * 3.0
		lua._drawn_weapon    = nil
		lua._drawing_entity  = nil
		lua._drawing_spawned = false
		lua._weapon_entity   = nil
	end
end

-- ============================================================
-- Companion Dragon (Zwaard van Drakenkracht)
-- Spawns when a player wields sword_dragonpower.
-- Follows the owner and attacks nearby enemies.
-- Despawns when the owner drops/switches the sword or dies.
-- ============================================================

-- Track one companion dragon per player: { [player_name] = objectref }
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
		visual        = "mesh",
		mesh          = "draconis_fire_dragon.b3d",
		textures      = {"draconis_fire_dragon_black.png^draconis_baked_in_shading.png"},
		physical      = false,
		collide_with_objects = false,
		collisionbox  = {-0.4, 0.0, -0.4, 0.4, 2.0, 0.4},
		visual_size   = {x = 6, y = 6, z = 6},
		makes_footstep_sound = false,
		static_save   = false,
		nametag       = "Duistere Draak",
		nametag_color = "#FF8800",
		glow          = 10,
		backface_culling = false,
	},

	_owner          = nil,   -- player name string
	_attack_cooldown = 0,
	_anim_timer     = 0,
	_current_anim   = "walk",
	_aura_timer     = 0,
	_roar_timer     = 5.0,

	on_activate = function(self, staticdata)
		self.object:set_animation({x = 321, y = 359}, 35, 0, true) -- hover
		self.object:set_armor_groups({immortal = 1}) -- companion can't be killed by enemies
	end,

	on_step = function(self, dtime)
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
				amount = 20, time = 0.5,
				minpos = vector.add(pos, vector.new(-1, 0, -1)),
				maxpos = vector.add(pos, vector.new(1, 2, 1)),
				minvel = vector.new(-2, 1, -2), maxvel = vector.new(2, 4, 2),
				minacc = vector.new(0, -1, 0),  maxacc = vector.new(0, 0, 0),
				minexptime = 0.4, maxexptime = 1.0,
				minsize = 3, maxsize = 6,
				texture = "draconis_fire_particle.png^[colorize:#FF6600:160",
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
				amount = 4, time = 0.35,
				minpos = vector.add(pos, vector.new(-0.8, 0.2, -0.8)),
				maxpos = vector.add(pos, vector.new(0.8, 1.8, 0.8)),
				minvel = vector.new(-0.4, 0.3, -0.4),
				maxvel = vector.new(0.4, 1.0, 0.4),
				minacc = vector.new(0, 0.3, 0), maxacc = vector.new(0, 0.8, 0),
				minexptime = 0.5, maxexptime = 1.0,
				minsize = 1.5, maxsize = 3,
				texture = "draconis_fire_particle.png^[colorize:#FF6600:150",
				glow = 10,
			})
		end

		-- Random roar
		self._roar_timer = self._roar_timer - dtime
		if self._roar_timer <= 0 then
			minetest.sound_play("dragon_roar" .. math.random(1, 2),
				{pos = pos, gain = 1.5, max_hear_distance = 30})
			self._roar_timer = 6.0 + math.random() * 4.0
		end

		self._attack_cooldown = self._attack_cooldown - dtime
		self._anim_timer      = self._anim_timer - dtime

		local opos  = owner:get_pos()
		local enemy_obj, enemy_dist = find_nearest_enemy(pos, 18)

		if enemy_obj and enemy_obj:get_pos() then
			-- ── ATTACK MODE ──────────────────────────────────────────
			local epos = enemy_obj:get_pos()
			local etarget = vector.add(epos, vector.new(0, 2, 0)) -- 2 blocks above enemy
			local dir  = vector.direction(pos, etarget)
			self.object:set_yaw(minetest.dir_to_yaw(vector.direction(pos, epos)))

			if enemy_dist > 3.5 then
				-- Fly toward enemy (2 blocks above)
				self.object:set_velocity(vector.new(dir.x * 5, dir.y * 5, dir.z * 5))
				if self._current_anim ~= "fly" and self._anim_timer <= 0 then
					self._current_anim = "fly"
					self.object:set_animation({x = 401, y = 439}, 35, 0, true)
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
					amount = 30, time = 0.5,
					minpos = mouth,
					maxpos = vector.add(mouth, vector.new(0.2, 0.2, 0.2)),
					minvel = vector.multiply(breath_dir, 5),
					maxvel = vector.add(vector.multiply(breath_dir, 8), vector.new(0, 1.5, 0)),
					minacc = vector.new(0, 0.5, 0), maxacc = vector.new(0, 2, 0),
					minexptime = 0.2, maxexptime = 0.6,
					minsize = 2, maxsize = 6,
					texture = "draconis_fire_particle.png",
					glow = 14,
				})
				minetest.sound_play("draconis_fire_breath",
					{pos = pos, gain = 0.7, max_hear_distance = 20})
				self._attack_cooldown = 1.8

				if self._anim_timer <= 0 then
					self._current_anim = "fly_fire"
					self._anim_timer   = 1.8
					self.object:set_animation({x = 441, y = 479}, 35, 0, true)
				end
			end
		else
			-- ── FOLLOW MODE ──────────────────────────────────────────
			local otarget = vector.add(opos, vector.new(0, 2, 0)) -- 2 blocks above owner
			local follow_dist = vector.distance(pos, otarget)
			local dir = vector.direction(pos, otarget)
			self.object:set_yaw(minetest.dir_to_yaw(vector.direction(pos, opos)))

			if follow_dist > 6 then
				-- Быстрый полёт к хозяину (2 блока выше)
				self.object:set_velocity(vector.new(dir.x * 6, dir.y * 6, dir.z * 6))
				if self._current_anim ~= "fly" and self._anim_timer <= 0 then
					self._current_anim = "fly"
					self.object:set_animation({x = 401, y = 439}, 35, 0, true)
				end
			elseif follow_dist > 3 then
				-- Медленный подлёт
				self.object:set_velocity(vector.new(dir.x * 2.5, dir.y * 2.5, dir.z * 2.5))
				if self._current_anim ~= "fly" and self._anim_timer <= 0 then
					self._current_anim = "fly"
					self.object:set_animation({x = 401, y = 439}, 30, 0, true)
				end
			else
				-- Зависание на 2 блока выше хозяина
				local dy = otarget.y - pos.y
				self.object:set_velocity(vector.new(0, dy * 3, 0))
				if self._current_anim ~= "hover" and self._anim_timer <= 0 then
					self._current_anim = "hover"
					self.object:set_animation({x = 321, y = 359}, 35, 0, true)
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
		local pname  = player:get_player_name()
		local wielded = player:get_wielded_item():get_name()
		local dragon  = boss.companion_dragons[pname]

		if wielded == "registered:sword_dragonpower" then
			-- Spawn if not yet present (or the old one disappeared)
			if not dragon or not dragon:get_pos() then
				local ppos = player:get_pos()
				local spawn_pos = vector.add(ppos, vector.new(2, 1, 0))
				local obj = minetest.add_entity(spawn_pos, "boss:companion_dragon")
				if obj then
					local lua = obj:get_luaentity()
					if lua then lua._owner = pname end
					boss.companion_dragons[pname] = obj
					-- Summoning burst
					minetest.add_particlespawner({
						amount = 30, time = 0.5,
						minpos = vector.add(spawn_pos, vector.new(-1, -0.5, -1)),
						maxpos = vector.add(spawn_pos, vector.new(1, 1.5, 1)),
						minvel = vector.new(-3, 1, -3), maxvel = vector.new(3, 4, 3),
						minacc = vector.new(0, -2, 0), maxacc = vector.new(0, 0, 0),
						minexptime = 0.3, maxexptime = 0.8,
						minsize = 2, maxsize = 5,
						texture = "draconis_fire_particle.png^[colorize:#FF6600:180",
						glow = 12,
					})
					minetest.sound_play("dragon_roar1",
						{pos = spawn_pos, gain = 1.0, max_hear_distance = 25})
					minetest.chat_send_player(pname,
						"De Draak ontwaakt en vecht aan jouw zijde...")
				end
			end
		else
			-- Player switched sword — dragon will self-remove in its own on_step
			-- just nil the table entry if it's already gone
			if dragon and not dragon:get_pos() then
				boss.companion_dragons[pname] = nil
			end
		end
	end
end)

-- Clean up companion dragon when a player leaves
minetest.register_on_leaveplayer(function(player)
	local pname = player:get_player_name()
	local dragon = boss.companion_dragons[pname]
	if dragon and dragon:get_pos() then
		dragon:remove()
	end
	boss.companion_dragons[pname] = nil
end)