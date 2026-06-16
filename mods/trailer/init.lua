-- trailer: Cinematic trailer mode
-- /trailer start  — hide player, spawn camera + stunt double, start wave
-- /trailer stop   — restore player, remove camera + stunt double
-- /trailer wave N — start specific wave in trailer mode

trailer = {}
trailer.active = false
trailer.camera = nil     -- camera entity objectref
trailer.stunt = nil      -- stunt double objectref
trailer.player_pos = nil -- saved player position

-- Arena interior bounds (camera must stay inside the schematic)
local ARENA_MIN = vector.new(0, 1.5, 0)
local ARENA_MAX = vector.new(15, 10, 10)

local function clamp_to_arena(pos)
	return vector.new(
		math.max(ARENA_MIN.x + 1, math.min(ARENA_MAX.x - 1, pos.x)),
		math.max(ARENA_MIN.y + 0.5, math.min(ARENA_MAX.y - 0.5, pos.y)),
		math.max(ARENA_MIN.z + 1, math.min(ARENA_MAX.z - 1, pos.z))
	)
end

-- ============================================================
-- Wall collision / obstacle avoidance for entities
-- ============================================================
local function is_solid(npos)
	local node = minetest.get_node(vector.round(npos))
	local def = minetest.registered_nodes[node.name]
	return def and def.walkable
end

-- Check if an entity-sized area around pos is clear (not inside wall)
local function pos_is_blocked(pos)
	-- Check at feet, middle, and head
	if is_solid(vector.new(pos.x, pos.y + 0.3, pos.z)) then return true end
	if is_solid(vector.new(pos.x, pos.y + 1.0, pos.z)) then return true end
	return false
end

-- Find the nearest open position by searching in a small radius
local function find_open_pos(pos)
	if not pos_is_blocked(pos) then return pos end
	-- Try nearby positions in a spiral
	for _, offset in ipairs({
		{ 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
		{ 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 },
		{ 2, 0 }, { -2, 0 }, { 0, 2 }, { 0, -2 },
	}) do
		local test = vector.new(pos.x + offset[1], pos.y, pos.z + offset[2])
		if not pos_is_blocked(test) then return test end
	end
	return pos -- give up, return original
end

-- Adjust velocity to avoid walking into walls.
-- Probes multiple distances ahead and to the sides.
local function avoid_walls(pos, vel, dtime)
	local hvel = vector.new(vel.x, 0, vel.z)
	local speed = vector.length(hvel)
	if speed < 0.1 then return vel end

	local hdir = vector.normalize(hvel)

	-- Probe at 0.6 and 1.2 nodes ahead (feet + head)
	local blocked = false
	for _, dist in ipairs({ 0.6, 1.2 }) do
		local ahead = vector.add(pos, vector.multiply(hdir, dist))
		if is_solid(vector.new(ahead.x, pos.y + 0.3, ahead.z)) or
			is_solid(vector.new(ahead.x, pos.y + 1.2, ahead.z)) then
			blocked = true
			break
		end
	end

	if blocked then
		-- Try sliding: zero out the axis pointing into the wall
		local bx = is_solid(vector.new(pos.x + hdir.x * 0.8, pos.y + 0.5, pos.z)) or
			is_solid(vector.new(pos.x + hdir.x * 0.8, pos.y + 1.2, pos.z))
		local bz = is_solid(vector.new(pos.x, pos.y + 0.5, pos.z + hdir.z * 0.8)) or
			is_solid(vector.new(pos.x, pos.y + 1.2, pos.z + hdir.z * 0.8))
		if bx then vel.x = 0 end
		if bz then vel.z = 0 end
		-- Both blocked → full stop
		if bx and bz then
			vel.x = 0
			vel.z = 0
		end
		-- If still pointing into a wall, try perpendicular
		if vel.x == 0 and vel.z == 0 then
			local perp = vector.new(-hdir.z, 0, hdir.x)
			local test = vector.add(pos, vector.multiply(perp, 0.8))
			if not is_solid(vector.new(test.x, pos.y + 0.5, test.z)) then
				vel.x = perp.x * speed * 0.5
				vel.z = perp.z * speed * 0.5
			end
		end
	end

	-- Hard clamp to arena boundaries
	if pos.x < ARENA_MIN.x + 0.6 and vel.x < 0 then vel.x = 0 end
	if pos.x > ARENA_MAX.x - 0.6 and vel.x > 0 then vel.x = 0 end
	if pos.z < ARENA_MIN.z + 0.6 and vel.z < 0 then vel.z = 0 end
	if pos.z > ARENA_MAX.z - 0.6 and vel.z > 0 then vel.z = 0 end

	return vel
end

-- Set velocity with wall avoidance
local function safe_set_velocity(obj, pos, vel, dtime)
	vel = avoid_walls(pos, vel, dtime or 0.05)
	obj:set_velocity(vel)
end

-- ============================================================
-- Globalstep: during trailer, clamp ALL battle entities out of walls
-- ============================================================
local _last_good_pos = {} -- entity ID → last known good position

minetest.register_globalstep(function(dtime)
	if not trailer.active then
		_last_good_pos = {}
		return
	end

	-- Collect all battle entities
	local entities = {}
	if trailer.stunt and trailer.stunt:get_pos() then
		table.insert(entities, trailer.stunt)
	end
	if enemy.boss_alive and enemy.boss_alive:get_pos() then
		table.insert(entities, enemy.boss_alive)
	end
	-- Dragon (if Hugo summoned it)
	if enemy.boss_alive then
		local blua = enemy.boss_alive:get_luaentity()
		if blua and blua._summoned_dragon and blua._summoned_dragon:get_pos() then
			table.insert(entities, blua._summoned_dragon)
		end
	end
	for _, ref in ipairs(enemy.alive_students or {}) do
		if ref and ref:get_pos() then
			table.insert(entities, ref)
		end
	end

	for _, ent in ipairs(entities) do
		local pos = ent:get_pos()
		if pos then
			local id = tostring(ent)
			if pos_is_blocked(pos) then
				-- Push back to last good position
				if _last_good_pos[id] then
					ent:set_pos(_last_good_pos[id])
					ent:set_velocity(vector.new(0, -9.81, 0))
				else
					-- No last good pos: search for open spot
					local open = find_open_pos(pos)
					ent:set_pos(open)
					ent:set_velocity(vector.new(0, -9.81, 0))
				end
			else
				_last_good_pos[id] = vector.new(pos.x, pos.y, pos.z)
			end
		end
	end
end)

-- ============================================================
-- Camera entity — orbits around battle, player attached in 1st person
-- ============================================================
minetest.register_entity("trailer:camera", {
	initial_properties = {
		visual = "sprite",
		textures = { "blank.png" },
		physical = false,
		collide_with_objects = false,
		collisionbox = { 0, 0, 0, 0, 0, 0 },
		pointable = false,
		static_save = false,
		visual_size = { x = 0, y = 0 },
	},

	_orbit_angle = 0,
	_orbit_radius = 2,
	_orbit_height = 1.8,
	_orbit_speed = 0.25, -- radians per second
	_orbit_center = nil,
	_smooth_center = nil, -- smoothed tracking center
	_mode = "orbit",   -- orbit, sweep, dramatic
	_mode_timer = 0,
	_shake_timer = 0,
	_shake_intensity = 0,
	_target = nil, -- entity to focus on

	on_activate = function(self, staticdata)
		self._orbit_center = self.object:get_pos()
		self._mode_timer = 8.0 + math.random() * 4.0
	end,

	on_step = function(self, dtime)
		if not trailer.active then
			self.object:remove()
			return
		end

		local center = self._orbit_center
		if not center then return end

		-- Find a focus target: stunt double or nearest enemy
		local focus_pos = nil
		if trailer.stunt and trailer.stunt:get_pos() then
			focus_pos = trailer.stunt:get_pos()
		end

		-- Check if there's an active boss for dramatic moments
		local boss_pos = nil
		if enemy.boss_alive and enemy.boss_alive:get_pos() then
			boss_pos = enemy.boss_alive:get_pos()
		end

		-- Smooth center: lerp toward midpoint between stunt and boss
		local target_center = center
		if focus_pos and boss_pos then
			target_center = vector.multiply(vector.add(focus_pos, boss_pos), 0.5)
			target_center.y = target_center.y + 1.0
		elseif focus_pos then
			target_center = vector.new(focus_pos.x, focus_pos.y + 1.0, focus_pos.z)
		end
		if not self._smooth_center then
			self._smooth_center = vector.new(target_center.x, target_center.y, target_center.z)
		end
		-- Lerp smoothly (factor 0.03 = very smooth)
		local lerp = math.min(dtime * 2.0, 0.15)
		self._smooth_center = vector.add(
			vector.multiply(self._smooth_center, 1 - lerp),
			vector.multiply(target_center, lerp)
		)
		center = self._smooth_center

		-- Switch camera modes periodically
		self._mode_timer = self._mode_timer - dtime
		if self._mode_timer <= 0 then
			local modes = { "orbit", "sweep", "dramatic", "low_angle", "tracking" }
			self._mode = modes[math.random(#modes)]
			self._mode_timer = 6.0 + math.random() * 6.0

			-- If boss exists, prefer dramatic angles
			if boss_pos and math.random() < 0.4 then
				self._mode = "dramatic"
			end
		end

		-- Camera shake on nearby combat (gentle)
		self._shake_timer = self._shake_timer - dtime
		local shake_x, shake_y = 0, 0
		if self._shake_intensity > 0 then
			shake_x = (math.random() - 0.5) * self._shake_intensity * 0.3
			shake_y = (math.random() - 0.5) * self._shake_intensity * 0.3
			self._shake_intensity = self._shake_intensity * 0.9
			if self._shake_intensity < 0.01 then
				self._shake_intensity = 0
			end
		end

		local cam_pos
		if self._mode == "orbit" then
			-- Classic orbit around action
			self._orbit_angle = self._orbit_angle + self._orbit_speed * dtime
			local radius = self._orbit_radius + math.sin(self._orbit_angle * 0.7) * 0.3
			cam_pos = vector.new(
				center.x + math.cos(self._orbit_angle) * radius,
				center.y + self._orbit_height + math.sin(self._orbit_angle * 0.5) * 0.3,
				center.z + math.sin(self._orbit_angle) * radius
			)
		elseif self._mode == "sweep" then
			-- Low sweeping pass
			self._orbit_angle = self._orbit_angle + self._orbit_speed * 1.2 * dtime
			cam_pos = vector.new(
				center.x + math.cos(self._orbit_angle) * 1.5,
				center.y + 1.5,
				center.z + math.sin(self._orbit_angle) * 1.5
			)
		elseif self._mode == "dramatic" then
			-- Close-up from slightly above, slow drift
			self._orbit_angle = self._orbit_angle + self._orbit_speed * 0.15 * dtime
			cam_pos = vector.new(
				center.x + math.cos(self._orbit_angle) * 1.2,
				center.y + 1.5,
				center.z + math.sin(self._orbit_angle) * 1.2
			)
		elseif self._mode == "low_angle" then
			-- Epic low angle looking up at the fight
			self._orbit_angle = self._orbit_angle + self._orbit_speed * 0.3 * dtime
			cam_pos = vector.new(
				center.x + math.cos(self._orbit_angle) * 1.5,
				center.y + 0.6,
				center.z + math.sin(self._orbit_angle) * 1.5
			)
		elseif self._mode == "tracking" then
			-- Follow stunt double from behind
			if focus_pos then
				local stunt_lua = trailer.stunt:get_luaentity()
				local yaw = self.object:get_yaw() or 0
				if stunt_lua then
					yaw = trailer.stunt:get_yaw() or yaw
				end
				cam_pos = vector.new(
					focus_pos.x - math.cos(yaw) * 1.2,
					focus_pos.y + 1.2,
					focus_pos.z - math.sin(yaw) * 1.2
				)
			else
				-- Fallback to orbit
				self._orbit_angle = self._orbit_angle + self._orbit_speed * dtime
				cam_pos = vector.new(
					center.x + math.cos(self._orbit_angle) * self._orbit_radius,
					center.y + self._orbit_height,
					center.z + math.sin(self._orbit_angle) * self._orbit_radius
				)
			end
		end

		-- Apply camera shake
		cam_pos.x = cam_pos.x + shake_x
		cam_pos.y = cam_pos.y + shake_y

		-- Clamp to arena interior
		cam_pos = clamp_to_arena(cam_pos)

		self.object:set_pos(cam_pos)

		-- Look at center of action
		local look_target = center
		if focus_pos then
			look_target = vector.new(focus_pos.x, focus_pos.y + 1.0, focus_pos.z)
		end
		local look_dir = vector.direction(cam_pos, look_target)
		self.object:set_yaw(minetest.dir_to_yaw(look_dir))
	end,
})

-- Trigger camera shake from outside (e.g. on big hits)
function trailer.camera_shake(intensity)
	if trailer.camera then
		local lua = trailer.camera:get_luaentity()
		if lua then
			lua._shake_intensity = intensity
		end
	end
end

-- ============================================================
-- Stunt double entity — fights bosses with epic attack patterns
-- Uses character.b3d and player texture, autonomous AI
-- Attack patterns:
--   "approach"  : walk toward nearest enemy
--   "combo"     : rapid 3-hit melee combo
--   "spin"      : spinning attack hitting all nearby
--   "leap"      : jump toward enemy, slam down
--   "parry"     : block + counter after getting hit
--   "retreat"   : dodge backward, then re-engage
-- ============================================================
minetest.register_entity("trailer:stunt_double", {
	initial_properties = {
		visual = "mesh",
		mesh = "character.b3d",
		textures = { "character.png" },
		physical = true,
		collide_with_objects = false,
		collisionbox = { -0.3, 0.0, -0.3, 0.3, 1.7, 0.3 },
		visual_size = { x = 1, y = 1, z = 1 },
		makes_footstep_sound = true,
		static_save = false,
		nametag = "",
	},

	_phase = "approach",
	_phase_timer = 0,
	_attack_cooldown = 0,
	_combo_count = 0,
	_hp = 9999, -- effectively immortal for trailer
	_target = nil, -- current enemy target
	_target_timer = 0,
	_leap_start_y = 0,
	_was_hit = false,
	_parry_timer = 0,
	_idle_timer = 0,
	_sword_name = "registered:sword_fire", -- equipped weapon visually

	on_activate = function(self, staticdata)
		self.object:set_animation({ x = 0, y = 79 }, 15, 0, true) -- idle
		self.object:set_armor_groups({ fleshy = 100 })
		-- Equip fire sword in hand
		self.object:set_wielded_item(ItemStack(self._sword_name))
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		-- Stunt double gets "hit" by enemies — triggers parry/dodge reaction
		if self._phase ~= "parry" and self._phase ~= "leap" and self._phase ~= "spin" then
			if math.random() < 0.35 then
				self._phase = "parry"
				self._phase_timer = 0.4
				self._was_hit = true
			else
				-- Take it and keep fighting
				self._phase = "retreat"
				self._phase_timer = 0.8
			end
			-- Camera shake on hit
			trailer.camera_shake(0.15)
		end
		return true
	end,

	on_step = function(self, dtime)
		if not trailer.active then
			self.object:remove()
			return
		end

		local pos = self.object:get_pos()
		if not pos then return end

		-- During showcase/finale, don't fight — just hold position
		if self._phase == "showcase_idle" then
			self.object:set_velocity(vector.new(0, -9.81, 0))
			self.object:set_animation({ x = 0, y = 79 }, 15, 0, true)
			return
		elseif self._phase == "finale_jump" then
			-- Gravity only, no AI
			return
		end

		-- Find target enemy (dragon if Hugo is linked, then boss, then students)
		self._target_timer = self._target_timer - dtime
		if self._target_timer <= 0 or not self._target or not self._target:get_pos() then
			self._target_timer = 1.0
			self._target = nil
			if enemy.boss_alive and enemy.boss_alive:get_pos() then
				local blua = enemy.boss_alive:get_luaentity()
				-- Hugo in "linked" phase = invulnerable. Target dragon instead.
				if blua and blua._hugo_phase == "linked"
					and blua._summoned_dragon and blua._summoned_dragon:get_pos() then
					self._target = blua._summoned_dragon
				else
					self._target = enemy.boss_alive
				end
			else
				local best_dist = math.huge
				for _, ref in ipairs(enemy.alive_students) do
					if ref and ref:get_pos() then
						local d = vector.distance(pos, ref:get_pos())
						if d < best_dist then
							best_dist = d
							self._target = ref
						end
					end
				end
			end
		end

		-- No target — idle animation
		if not self._target or not self._target:get_pos() then
			self._idle_timer = self._idle_timer + dtime
			safe_set_velocity(self.object, pos, vector.new(0, -9.81, 0), dtime)
			if self._idle_timer > 1.0 then
				self.object:set_animation({ x = 0, y = 79 }, 15, 0, true)
			end
			return
		end
		self._idle_timer = 0

		local tpos = self._target:get_pos()
		local tdir = vector.direction(pos, tpos)
		local tdist = vector.distance(pos, tpos)
		self.object:set_yaw(minetest.dir_to_yaw(tdir))

		-- Dragon is large: consider ourselves closer than center-to-center
		local tlua = self._target:get_luaentity()
		if tlua and tlua.name == "boss:summoned_dragon" then
			tdist = tdist - 1.5 -- compensate for dragon visual size
			if tdist < 0 then tdist = 0 end
		end

		-- If Hugo is summoning, back off and watch (give him time for dragon)
		if enemy.boss_alive and enemy.boss_alive:get_pos() then
			local blua = enemy.boss_alive:get_luaentity()
			if blua and blua._hugo_phase == "summon" then
				-- Retreat to ~6 blocks away and watch
				if tdist < 5.0 then
					local away = vector.multiply(tdir, -2.5)
					safe_set_velocity(self.object, pos, vector.new(away.x, -9.81, away.z), dtime)
					self.object:set_animation({ x = 168, y = 187 }, 20, 0, true) -- walk back
				else
					safe_set_velocity(self.object, pos, vector.new(0, -9.81, 0), dtime)
					self.object:set_animation({ x = 0, y = 79 }, 15, 0, true) -- idle watch
				end
				self._phase = "approach"
				self._attack_cooldown = 1.0
				return
			end
		end

		self._attack_cooldown = self._attack_cooldown - dtime
		self._phase_timer = self._phase_timer - dtime

		-- Phase machine
		if self._phase == "approach" then
			stunt_approach(self, dtime, pos, tpos, tdir, tdist)
		elseif self._phase == "combo" then
			stunt_combo(self, dtime, pos, tpos, tdir, tdist)
		elseif self._phase == "spin" then
			stunt_spin(self, dtime, pos, tpos, tdir, tdist)
		elseif self._phase == "leap" then
			stunt_leap(self, dtime, pos, tpos, tdir, tdist)
		elseif self._phase == "parry" then
			stunt_parry(self, dtime, pos, tpos, tdir, tdist)
		elseif self._phase == "retreat" then
			stunt_retreat(self, dtime, pos, tpos, tdir, tdist)
		end
	end,
})

-- ============================================================
-- Stunt double attack patterns
-- ============================================================

-- Deal damage to target and add visual flair
local function stunt_hit_target(self, target, dmg)
	if not target or not target:get_pos() then return end
	local lua = target:get_luaentity()
	if lua and lua.on_punch then
		-- Create a fake tool capability for damage
		local tool_caps = {
			damage_groups = { fleshy = dmg },
		}
		-- Simulate being hit by fire sword
		local item = ItemStack("registered:sword_fire")
		target:punch(self.object, 1.0, tool_caps, vector.new(0, 0, 0))
	end

	-- Camera shake on hit
	trailer.camera_shake(0.08 + dmg * 0.01)
end

-- Approach: walk toward target, switch to attack when close
function stunt_approach(self, dtime, pos, tpos, tdir, tdist)
	local speed = 3.5
	safe_set_velocity(self.object, pos, vector.new(tdir.x * speed, -9.81, tdir.z * speed), dtime)
	self.object:set_animation({ x = 168, y = 187 }, 30, 0, true) -- walk

	if tdist < 3.0 and self._attack_cooldown <= 0 then
		-- Choose attack pattern
		local roll = math.random()
		if roll < 0.40 then
			self._phase = "combo"
			self._phase_timer = 0.3
			self._combo_count = 0
		elseif roll < 0.65 then
			self._phase = "spin"
			self._phase_timer = 1.0
		elseif roll < 0.85 then
			self._phase = "leap"
			self._phase_timer = 0.5
			self._leap_start_y = pos.y
		else
			-- Quick single hit then retreat
			stunt_hit_target(self, self._target, 8)
			self.object:set_animation({ x = 189, y = 198 }, 40, 0, false) -- mine/attack
			self._phase = "retreat"
			self._phase_timer = 1.0
			self._attack_cooldown = 0.5
		end
	elseif tdist > 10.0 and math.random() < 0.02 then
		-- Far away — do a leap to close distance
		self._phase = "leap"
		self._phase_timer = 0.6
		self._leap_start_y = pos.y
	end
end

-- Combo: rapid 3-hit melee combo
function stunt_combo(self, dtime, pos, tpos, tdir, tdist)
	-- Stand close and punch
	local speed = 1.5
	if tdist > 2.5 then
		safe_set_velocity(self.object, pos, vector.new(tdir.x * speed, -9.81, tdir.z * speed), dtime)
	else
		safe_set_velocity(self.object, pos, vector.new(0, -9.81, 0), dtime)
	end

	if self._phase_timer <= 0 and self._combo_count < 3 then
		self._combo_count = self._combo_count + 1
		self.object:set_animation({ x = 189, y = 198 }, 50, 0, false) -- attack

		if tdist < 3.5 then
			local dmg = 5 + self._combo_count * 3 -- 8, 11, 14 escalating
			stunt_hit_target(self, self._target, dmg)
		end

		if self._combo_count < 3 then
			self._phase_timer = 0.25 -- fast gap between hits
		else
			-- Combo done — brief pause then approach
			trailer.camera_shake(0.2)
			self._phase = "approach"
			self._attack_cooldown = 0.8
			self.object:set_animation({ x = 168, y = 187 }, 30, 0, true)
		end
	end
end

-- Spin: spinning attack hitting all nearby enemies
function stunt_spin(self, dtime, pos, tpos, tdir, tdist)
	-- Rotate fast (visual: walk_mine animation for aggressive look)
	self.object:set_animation({ x = 200, y = 219 }, 60, 0, true)

	-- Rotate the yaw rapidly
	local yaw = (self.object:get_yaw() or 0) + dtime * 12
	self.object:set_yaw(yaw)

	-- Slight forward movement
	safe_set_velocity(self.object, pos, vector.new(tdir.x * 1.5, -9.81, tdir.z * 1.5), dtime)

	-- Hit everything nearby periodically
	if self._attack_cooldown <= 0 then
		self._attack_cooldown = 0.3
		-- Hit all entities within range
		for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 3.5)) do
			if obj ~= self.object then
				local lua = obj:get_luaentity()
				if lua and (lua.name == "enemy:student" or lua.name == "boss:teacher"
						or lua.name == "boss:summoned_dragon") then
					stunt_hit_target(self, obj, 6)
				end
			end
		end
	end

	if self._phase_timer <= 0 then
		self._phase = "retreat"
		self._phase_timer = 0.6
		self._attack_cooldown = 0.5
	end
end

-- Leap: jump toward enemy, slam down with big AoE
function stunt_leap(self, dtime, pos, tpos, tdir, tdist)
	if self._phase_timer > 0.2 then
		-- Rising phase — jump toward target
		local speed = 7
		safe_set_velocity(self.object, pos, vector.new(tdir.x * speed, 6, tdir.z * speed), dtime)
		self.object:set_animation({ x = 189, y = 198 }, 30, 0, false)
	elseif self._phase_timer > 0 then
		-- Falling/slam phase
		safe_set_velocity(self.object, pos, vector.new(tdir.x * 2, -12, tdir.z * 2), dtime)
	else
		-- Impact!
		safe_set_velocity(self.object, pos, vector.new(0, -9.81, 0), dtime)

		trailer.camera_shake(0.3)

		-- Damage all enemies in AoE
		for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 4.0)) do
			if obj ~= self.object then
				local lua = obj:get_luaentity()
				if lua and (lua.name == "enemy:student" or lua.name == "boss:teacher"
						or lua.name == "boss:summoned_dragon") then
					stunt_hit_target(self, obj, 12)
				end
			end
		end

		self._phase = "approach"
		self._attack_cooldown = 1.0
	end
end

-- Parry: block + counter-attack
function stunt_parry(self, dtime, pos, tpos, tdir, tdist)
	-- Stand still, guard stance
	safe_set_velocity(self.object, pos, vector.new(0, -9.81, 0), dtime)
	self.object:set_animation({ x = 0, y = 79 }, 5, 0, true) -- slow idle = guard pose

	if self._phase_timer <= 0 then
		-- Counter-attack! Quick strike back
		if tdist < 4.0 then
			stunt_hit_target(self, self._target, 15) -- big counter damage
			self.object:set_animation({ x = 189, y = 198 }, 60, 0, false)
			trailer.camera_shake(0.15)
		end
		self._phase = "approach"
		self._attack_cooldown = 0.6
	end
end

-- Retreat: dodge backward, then re-engage
function stunt_retreat(self, dtime, pos, tpos, tdir, tdist)
	-- Jump backward
	local away = vector.multiply(tdir, -4)
	safe_set_velocity(self.object, pos, vector.new(away.x, 2, away.z), dtime)
	self.object:set_animation({ x = 168, y = 187 }, 40, 0, true)

	if self._phase_timer <= 0 then
		-- Re-engage: possibly with a leap
		if tdist > 5.0 and math.random() < 0.5 then
			self._phase = "leap"
			self._phase_timer = 0.5
			self._leap_start_y = pos.y
		else
			self._phase = "approach"
		end
		self._attack_cooldown = 0.3
	end
end

-- ============================================================
-- Trailer mode start/stop
-- ============================================================
-- Boss data for the showcase (mirrors boss mod's BOSSES table)
local TRAILER_BOSSES = {
	[1] = { name = "Bram", tex = "boss_bram.png" },
	[2] = { name = "Hugo", tex = "boss_hugo.png" },
	[3] = { name = "Joachim", tex = "boss_joachim.png" },
	[4] = { name = "Julian", tex = "boss_julian.png" },
	[5] = { name = "Rosanne", tex = "boss_rosanne.png" },
	[6] = { name = "Jan Willem", tex = "boss_janwillem.png" },
	[7] = { name = "Margriet", tex = "boss_margriet.png" },
}

trailer._showcase_timers = {} -- minetest.after handles for cleanup
trailer._phase = "fight"      -- fight, showcase, finale

function trailer.start(player, level)
	if trailer.active then
		minetest.chat_send_player(player:get_player_name(), "Trailer is al actief!")
		return
	end

	level = level or 2
	trailer.active = true
	trailer._phase = "fight"
	trailer.player_pos = player:get_pos()
	trailer._showcase_timers = {}
	trailer._showcase_boss = nil

	-- Make player invisible + disable controls
	player:set_properties({
		visual_size = { x = 0, y = 0, z = 0 },
		makes_footstep_sound = false,
		pointable = false,
	})

	-- Spawn stunt double at player position
	local spos = vector.new(trailer.player_pos.x, trailer.player_pos.y, trailer.player_pos.z)
	trailer.stunt = minetest.add_entity(spos, "trailer:stunt_double")

	-- Spawn camera above the arena
	local cam_pos = vector.add(spos, vector.new(0, 4, -5))
	trailer.camera = minetest.add_entity(cam_pos, "trailer:camera")

	if trailer.camera then
		-- Attach player to camera to ride along
		player:set_attach(trailer.camera, "", vector.new(0, 0, 0), vector.new(0, 0, 0))
		player:set_eye_offset(vector.new(0, 0, 0), vector.new(0, 0, 0))
	end

	-- Spawn the wave (default level 2 = Hugo with Dragon summon)
	enemy.spawn_wave(level)

	-- Replace normal BGM with trailer music (Dark Army Resurrection)
	enemy.stop_bgm()
	trailer._bgm_handle = minetest.sound_play("trailer_bgm", {
		gain = 0.9,
		loop = true,
	})

	-- Poll every 0.5s: when boss (+ Dragon) are dead → go to showcase
	local function check_fight_done()
		if not trailer.active or trailer._phase ~= "fight" then return end

		-- Boss must be dead
		if enemy.boss_alive and enemy.boss_alive:get_pos() then
			minetest.after(0.5, check_fight_done)
			return
		end

		-- Boss dead: transition to showcase
		trailer._start_showcase(player)
	end
	-- Start checking after 3 seconds (give Hugo time to spawn in)
	local t = minetest.after(3, check_fight_done)
	table.insert(trailer._showcase_timers, t)

	minetest.chat_send_player(player:get_player_name(),
		"🎬 Trailer modus gestart! (/trailer stop om te stoppen)")
end

-- Showcase phase: stunt + display boss face each other, cycle through all bosses
function trailer._start_showcase(player)
	if not trailer.active then return end
	trailer._phase = "showcase"

	-- Kill all remaining students
	for _, ref in ipairs(enemy.alive_students) do
		if ref and ref:get_pos() then ref:remove() end
	end
	enemy.alive_students = {}

	-- Position stunt and spawn a display boss facing each other
	local stunt_pos      = vector.new(5, 2, 5)
	local boss_pos       = vector.new(9, 2, 5)

	if trailer.stunt and trailer.stunt:get_pos() then
		trailer.stunt:set_pos(stunt_pos)
		trailer.stunt:set_velocity(vector.new(0, -9.81, 0))
		local dir = vector.direction(stunt_pos, boss_pos)
		trailer.stunt:set_yaw(minetest.dir_to_yaw(dir))
		trailer.stunt:set_animation({ x = 0, y = 79 }, 15, 0, true) -- idle
		local lua = trailer.stunt:get_luaentity()
		if lua then
			lua._phase = "showcase_idle"
			lua._target = nil
		end
	end

	-- Spawn a fresh boss entity for display (won't fight, we freeze it)
	local display_boss = minetest.add_entity(boss_pos, "boss:teacher")
	trailer._showcase_boss = display_boss

	if display_boss and display_boss:get_pos() then
		display_boss:set_velocity(vector.new(0, -9.81, 0))
		local dir = vector.direction(boss_pos, stunt_pos)
		display_boss:set_yaw(minetest.dir_to_yaw(dir))
		display_boss:set_animation({ x = 0, y = 79 }, 15, 0, true)
		-- Set as boss_alive so its on_step finds the stunt double
		-- but give it huge cooldown so it never attacks
		enemy.boss_alive = display_boss
		local blua = display_boss:get_luaentity()
		if blua then
			blua._attack_cooldown = 999
			blua._hp = 99999
		end
	end

	-- Switch camera to dramatic mode focused between them
	if trailer.camera then
		local clua = trailer.camera:get_luaentity()
		if clua then
			clua._mode = "dramatic"
			clua._orbit_center = vector.new(7, 2, 5) -- midpoint
			clua._orbit_speed = 0.15
		end
	end

	-- Cycle through all 7 bosses, 1 per second
	for i = 1, 7 do
		local t = minetest.after(i, function()
			if not trailer.active or trailer._phase ~= "showcase" then return end
			if not trailer._showcase_boss or not trailer._showcase_boss:get_pos() then return end

			local data = TRAILER_BOSSES[i]
			if not data then return end

			local scale = 1.2
			if i == 7 then scale = 1.5 end

			trailer._showcase_boss:set_properties({
				nametag = data.name,
				nametag_color = "#FFFFFF",
				visual_size = { x = scale, y = scale, z = scale },
				textures = { data.tex },
			})

			-- Keep boss in place and facing stunt
			trailer._showcase_boss:set_pos(boss_pos)
			trailer._showcase_boss:set_velocity(vector.new(0, -9.81, 0))
			local dir = vector.direction(boss_pos, stunt_pos)
			trailer._showcase_boss:set_yaw(minetest.dir_to_yaw(dir))
			trailer._showcase_boss:set_animation({ x = 0, y = 79 }, 15, 0, true)

			-- Keep it frozen
			local blua = trailer._showcase_boss:get_luaentity()
			if blua then
				blua._attack_cooldown = 999
			end
		end)
		table.insert(trailer._showcase_timers, t)
	end

	-- After all 7 bosses shown (7s) + 1s pause → finale
	local finale_timer = minetest.after(8, function()
		if not trailer.active then return end
		trailer._start_finale(player)
	end)
	table.insert(trailer._showcase_timers, finale_timer)
end

-- Finale: stunt double jumps, then trailer ends
function trailer._start_finale(player)
	if not trailer.active then return end
	trailer._phase = "finale"

	-- Stunt double jumps up
	if trailer.stunt and trailer.stunt:get_pos() then
		local lua = trailer.stunt:get_luaentity()
		if lua then
			lua._phase = "finale_jump"
		end
		trailer.stunt:set_velocity(vector.new(0, 8, 0))
		trailer.stunt:set_animation({ x = 189, y = 198 }, 30, 0, false) -- attack pose mid-air
	end

	-- Auto-stop after 1.5 seconds
	local stop_timer = minetest.after(1.5, function()
		if not trailer.active then return end
		local p = minetest.get_player_by_name(player:get_player_name())
		if p then
			trailer.stop(p)
		end
	end)
	table.insert(trailer._showcase_timers, stop_timer)
end

function trailer.stop(player)
	if not trailer.active then
		minetest.chat_send_player(player:get_player_name(), "Trailer is niet actief.")
		return
	end

	trailer.active = false
	trailer._phase = "stopped"
	trailer._showcase_timers = {}

	-- Stop trailer BGM
	if trailer._bgm_handle then
		minetest.sound_stop(trailer._bgm_handle)
		trailer._bgm_handle = nil
	end

	-- Detach player from camera
	player:set_detach()

	-- Restore player visibility
	player:set_properties({
		visual_size = { x = 1, y = 1, z = 1 },
		makes_footstep_sound = true,
		pointable = true,
	})

	-- Restore position
	if trailer.player_pos then
		player:set_pos(trailer.player_pos)
	end

	-- Remove camera and stunt double
	if trailer.camera and trailer.camera:get_pos() then
		trailer.camera:remove()
	end
	if trailer.stunt and trailer.stunt:get_pos() then
		trailer.stunt:remove()
	end
	if trailer._showcase_boss and trailer._showcase_boss:get_pos() then
		trailer._showcase_boss:remove()
	end
	trailer.camera = nil
	trailer.stunt = nil
	trailer._showcase_boss = nil

	-- Clean up wave
	enemy.reset_all()

	minetest.chat_send_player(player:get_player_name(), "🎬 Trailer modus gestopt.")
end

-- ============================================================
-- Chat command
-- ============================================================
minetest.register_chatcommand("trailer", {
	params = "start [level] | stop",
	description = "Cinematische trailermodus starten/stoppen",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Speler niet gevonden." end
		minetest.log("action", "/trailer was casted by " .. name .. " with param " .. param)

		local parts = param:split(" ")
		local cmd = parts[1] or ""

		if cmd == "start" then
			local level = tonumber(parts[2]) or 2
			if level < 1 then level = 1 end
			if level > 7 then level = 7 end
			trailer.start(player, level)
			return true
		elseif cmd == "stop" then
			trailer.stop(player)
			return true
		else
			return false, "Gebruik: /trailer start [level] | stop"
		end
	end,
})
