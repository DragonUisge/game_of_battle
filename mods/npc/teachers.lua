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
			"Le subjonctif s'utilise après 'bien que' et 'pour que'. Noteer dit!",
			"'Je suis allé' is passé composé. 'J'allais' is imparfait — twee verschillende tijden!",
			"Frans heeft twee geslachten: masculin en féminin. Er is geen neutrum, zoals in het Latijn.",
			"Le verbe 'être': je suis, tu es, il est, nous sommes, vous êtes, ils sont. Uit het hoofd.",
			"Une liaison: 'les amis' spreek je uit als 'lez-ami'. Klinkers verbinden met de vorige s.",
			"Gallicisme van de dag: 'il fait beau' — letterlijk 'het maakt mooi', maar het betekent 'het is mooi weer'.",
		},
	},
	{
		subject = "Wiskunde",
		teacher = "Dr. Grin",
		texture = "npc_teacher_grin.png",
		pos     = vector.new(-320, 179, -400),
		lines   = {
			"De stelling van Pythagoras: a² + b² = c². Geldt uitsluitend voor rechthoekige driehoeken.",
			"Een priemgetal heeft precies twee delers: 1 en zichzelf. 1 is géén priemgetal.",
			"log₂(8) = 3, want 2³ = 8. Logaritmen zijn de inverse van machtsverheffing.",
			"De afgeleide van x² is 2x. Dat is de helling van de raaklijn in elk punt.",
			"π ≈ 3.14159. Omtrek van een cirkel = 2πr. Oppervlakte = πr².",
			"Sinus, cosinus en tangens: in een rechthoekige driehoek is sin = overstaande / schuine zijde.",
		},
	},
	{
		subject = "Nederlands",
		teacher = "Mevr. Huiskamp",
		texture = "npc_teacher_huiskamp.png",
		pos     = vector.new(-320, 179, -387),
		lines   = {
			"De congruentieregel: een bijvoeglijk naamwoord krijgt een -e tenzij het een onzijdig woord is zonder lidwoord. 'Een groot huis', maar 'het grote huis'.",
			"Trappen van vergelijking: stellende trap, vergrotende trap op -er, overtreffende trap op -st. Uitzondering: 'veel → meer → meest', 'goed → beter → best'.",
			"Naamvallen zijn in het Nederlands vrijwel verdwenen, maar de genitief overleeft in vaste uitdrukkingen: 'des konings wil', 'iets van waarde'. Archaïsch, maar je herkent het in literatuur.",
			"Het verschil tussen 'die' en 'dat' hangt af van het lidwoord. 'De man die...', 'het kind dat...'. Bij meervoud altijd 'die', ongeacht het geslacht.",
			"Partikel of prefix? 'Opbellen' is scheidbaar: 'Ik bel hem op.' Maar 'ondervinden' is onscheidbaar: 'Ik ondervind problemen.' Controleer altijd de woordenboeknotatie.",
			"Stijlmiddelen: anafoor is herhaling aan het begin van zinnen voor nadruk — zie De Génestet. Chiasme keert de volgorde om: 'Leer niet voor de leraar, maar voor jezelf.' Herken ze in teksten.",
		},
	},
	-- ── RECHTER KANT (x=-289) ─────────────────────────────────────────────
	{
		subject = "Natuurkunde",
		teacher = "Dr. Aalberts",
		texture = "npc_teacher_aalberts.png",
		pos     = vector.new(-289, 179, -418),
		lines   = {
			"De wet van Newton: F = m·a. Kracht in Newton, massa in kg, versnelling in m/s².",
			"Ohm's wet: U = I·R. Spanning in Volt, stroom in Ampère, weerstand in Ohm.",
			"Lichtsnelheid in vacuüm: c ≈ 3·10⁸ m/s. Niets beweegt sneller.",
			"Wet van behoud van energie: energie kan niet ontstaan of verdwijnen, alleen van vorm veranderen.",
			"Golven hebben een golflengte λ en frequentie f. De relatie: v = f·λ.",
			"Dichtheid ρ = m / V. Een stof met ρ < 1000 kg/m³ drijft op water.",
		},
	},
	{
		subject = "Biologie",
		teacher = "Mevr. Klever",
		texture = "npc_teacher_klever.png",
		pos     = vector.new(-289, 179, -400),
		lines   = {
			"Fotosynthese: 6CO₂ + 6H₂O + licht → C₆H₁₂O₆ + 6O₂. Chlorofyl absorbeert het licht.",
			"DNA bestaat uit vier basen: adenine, thymine, cytosine en guanine. A paart altijd met T, C met G.",
			"De cel is de kleinste levende eenheid. Prokaryoten hebben geen celkern — eukaryoten wel.",
			"Mitose is celdeling voor groei. Meiose produceert geslachtscellen met de helft van het chromosomaantal.",
			"De bloedsomloop: zuurstofarm bloed → hart → longen → hart → lichaam. Twee kringen.",
			"Evolutie door natuurlijke selectie: individuen met voordelige eigenschappen overleven vaker en planten zich voort.",
		},
	},
	{
		subject = "Engels",
		teacher = "Mr. Daniel",
		texture = "npc_teacher_daniel.png",
		pos     = vector.new(-289, 179, -387),
		lines   = {
			"Present perfect: 'I have seen' — an action in the past with a connection to now. Not 'I have seen it yesterday'!",
			"'Their', 'there' and 'they're' are three different words. Mix them up and you look careless.",
			"Passive voice: 'The letter was written by her.' Use it when the action matters more than who did it.",
			"A subordinate clause needs a main clause. 'Although it was raining' is not a sentence on its own.",
			"'Fewer' is for countable things, 'less' is for uncountable. Fewer students, less noise.",
			"Apostrophes mark possession or contraction. 'It's' means 'it is'. 'Its' is possessive. No exceptions.",
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
