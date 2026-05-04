-- teachers.lua: Arena 2 classroom teacher NPCs
-- Loaded from npc/init.lua via dofile().
--
-- Positions berekend vanuit barlaeus_arena.mts (schematic 51x9x62):
--   ORIGIN2 = (-330, 177, -440)
--   6 lokalen: x-center = schematic 12 → world -318
--              y standing = schematic 2  → world 179
--              z-centers  = schematic 4,13,22,31,40,49 → world -436,-427,-418,-409,-400,-391
--   (Elke 9 nodes in Z-richting, links in het gebouw)
--
-- Om een leraar handmatig te herplaatsen: /set_teacher_pos <vak>
-- (server-priv vereist; posities zijn alleen in-memory tenzij je ze hier hardcodet)

npc._teacher_refs = {}
local _teacher_wave_state = nil

-- ── Leraar definities ────────────────────────────────────────────────────────
-- Plattegrond barlaeus_arena.mts (51x9x62, ORIGIN2=(-330,177,-440)):
--   Corridor: x_schem=20..32 (world x=-310..-298)
--   Linker kamers: x_schem=1..18 → center world x=-320
--   Rechter kamers: x_schem=34..49 → center world x=-289
--   Klas 1 sectie: z_schem=17..36, leraar bij z=22 → world z=-418
--   Klas 2 sectie: z_schem=38..49, leraar bij z=40 → world z=-400
--   Klas 3 sectie: z_schem=51..60, leraar bij z=53 → world z=-387
--   (z_schem=1..15 = ingang/lobby, geen klas)
local CLASSROOM_DEFS = {
	-- ── LINKER KANT (x=-320) ──────────────────────────────────────────────
	{
		subject = "Frans",
		teacher = "Mevr. Schaapherder",
		texture = "npc_teacher_schaapherder.png",
		pos     = vector.new(-320, 179, -418),
		lines   = {
			"Bonjour, classe! Répétez après moi.",
			"La prononciation, c'est très important!",
			"Ouvrez vos livres.",
			"Avez-vous fait vos devoirs?",
		},
	},
	{
		subject = "Wiskunde",
		teacher = "Dr. Grin",
		texture = "npc_teacher_grin.png",
		pos     = vector.new(-320, 179, -400),
		lines   = {
			"Los de vergelijking op.",
			"X is gelijk aan hoeveel? Denk na.",
			"Gebruik de formule die we hebben geleerd.",
			"Zonder bewijs is het geen antwoord.",
		},
	},
	{
		subject = "Nederlands",
		teacher = "Mevr. Huiskamp",
		texture = "npc_teacher_huiskamp.png",
		pos     = vector.new(-320, 179, -387),
		lines   = {
			"Lees de tekst op pagina 42.",
			"Spelling is belangrijk, let op de dt-regels!",
			"Schrijf altijd een volledige zin.",
			"Begrijp je de opdracht?",
		},
	},
	-- ── RECHTER KANT (x=-289) ─────────────────────────────────────────────
	{
		subject = "Natuurkunde",
		teacher = "Dr. Aalberts",
		texture = "npc_teacher_aalberts.png",
		pos     = vector.new(-289, 179, -418),
		lines   = {
			"F is gelijk aan m maal a.",
			"Energie blijft altijd behouden.",
			"Wat is de snelheid in meter per seconde?",
			"Lees de meetschaal nauwkeurig af.",
		},
	},
	{
		subject = "Biologie",
		teacher = "Mevr. Klever",
		texture = "npc_teacher_klever.png",
		pos     = vector.new(-289, 179, -400),
		lines   = {
			"Bekijk de cel goed onder de microscoop.",
			"Fotosynthese is de basis van het leven.",
			"Noem drie organellen van een celkern.",
			"Wat is de functie van het mitochondrion?",
		},
	},
	{
		subject = "Engels",
		teacher = "Mr. Daniel",
		texture = "npc_teacher_daniel.png",
		pos     = vector.new(-289, 179, -387),
		lines   = {
			"Good morning, everyone. Open your books.",
			"Repeat after me, please.",
			"Can anyone tell me the answer?",
			"Spelling counts — double-check your work.",
		},
	},
}

-- ── Entiteit ─────────────────────────────────────────────────────────────────
minetest.register_entity("npc:classroom_teacher", {
	initial_properties = {
		visual               = "mesh",
		mesh                 = "character.b3d",
		textures             = {"npc_wapenverkoper.png"},
		physical             = true,
		collide_with_objects = false,
		collisionbox         = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
		visual_size          = {x = 1, y = 1, z = 1},
		makes_footstep_sound = false,
		nametag              = "",
		nametag_color        = "#FFFF55",
		static_save          = false,
	},

	_subject      = "",
	_teacher_name = "",
	_lines        = {},
	_line_idx     = 1,

	on_activate = function(self, staticdata)
		self.object:set_animation({x = 0, y = 79}, 30, 0, true)
	end,

	on_rightclick = function(self, clicker)
		if not clicker or not clicker:is_player() then return end
		local pname = clicker:get_player_name()
		if #self._lines == 0 then return end
		local line = self._lines[self._line_idx]
		self._line_idx = (self._line_idx % #self._lines) + 1
		minetest.chat_send_player(pname,
			minetest.colorize("#FFFF55", "[" .. self._teacher_name .. "] ") .. line)
	end,

	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
		return true  -- onkwetsbaar
	end,

	on_step = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then return end
		local nearest, nearest_dist = nil, math.huge
		for _, player in ipairs(minetest.get_connected_players()) do
			local d = vector.distance(pos, player:get_pos())
			if d < nearest_dist then
				nearest = player:get_pos()
				nearest_dist = d
			end
		end
		if nearest then
			self.object:set_yaw(minetest.dir_to_yaw(vector.direction(pos, nearest)))
		end
	end,
})

-- ── Spawn/despawn helpers ─────────────────────────────────────────────────────
local function spawn_teacher(def)
	local obj = minetest.add_entity(def.pos, "npc:classroom_teacher")
	if not obj then return end
	obj:set_properties({
		nametag  = def.teacher .. " (" .. def.subject .. ")",
		textures = {def.texture},
	})
	local lua = obj:get_luaentity()
	if lua then
		lua._subject      = def.subject
		lua._teacher_name = def.teacher
		lua._lines        = def.lines
		lua._line_idx     = 1
	end
	npc._teacher_refs[def.subject] = obj
end

local function despawn_teachers()
	for subject, obj in pairs(npc._teacher_refs) do
		if obj and obj:get_pos() then obj:remove() end
	end
	npc._teacher_refs = {}
end

local function spawn_teachers()
	for _, def in ipairs(CLASSROOM_DEFS) do
		spawn_teacher(def)
	end
end

local function update_classroom_teachers()
	local wave_now = enemy and enemy.wave_active
	if wave_now then
		-- Wave active: despawn all (only once)
		if _teacher_wave_state ~= true then
			_teacher_wave_state = true
			despawn_teachers()
		end
		return
	end
	-- No wave: ensure every teacher has a living entity
	_teacher_wave_state = false
	for _, def in ipairs(CLASSROOM_DEFS) do
		local ref = npc._teacher_refs[def.subject]
		if not ref or not ref:get_pos() then
			spawn_teacher(def)
		end
	end
end

-- ── Globalstep ───────────────────────────────────────────────────────────────
local _teacher_check_timer = 0
minetest.register_globalstep(function(dtime)
	_teacher_check_timer = _teacher_check_timer + dtime
	if _teacher_check_timer < 3.0 then return end
	_teacher_check_timer = 0
	update_classroom_teachers()
end)

minetest.register_on_mods_loaded(function()
	minetest.after(2, function()
		update_classroom_teachers()
	end)
end)

-- ── /set_teacher_pos <vak> ────────────────────────────────────────────────────
minetest.register_chatcommand("set_teacher_pos", {
	params      = "<vak>",
	description = "Herplaats leraar op jouw positie (server). Vakken: Frans/Wiskunde/Nederlands/Natuurkunde/Biologie/Engels",
	privs       = {server = true},
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Speler niet gevonden." end
		local subject = param:match("^%s*(.-)%s*$")
		for _, def in ipairs(CLASSROOM_DEFS) do
			if def.subject:lower() == subject:lower() then
				local p = player:get_pos()
				def.pos = vector.new(
					math.floor(p.x + 0.5),
					math.floor(p.y + 0.5),
					math.floor(p.z + 0.5))
				if npc._teacher_refs[def.subject] then
					local old = npc._teacher_refs[def.subject]
					if old and old:get_pos() then old:remove() end
					npc._teacher_refs[def.subject] = nil
				end
				if not enemy or not enemy.wave_active then
					spawn_teacher(def)
				end
				return true, def.teacher .. " (" .. def.subject .. ") → "
					.. minetest.pos_to_string(def.pos)
			end
		end
		return false, "Onbekend vak '" .. subject
			.. "'. Kies: Frans, Wiskunde, Nederlands, Natuurkunde, Biologie, Tekenen"
	end,
})
