-- gamelog: centrale logging van speleractiviteit naar minetest.log
--
-- Doel: als developer wil je in minetest.log kunnen terugzien wat spelers
-- precies deden — waar ze waren, wat ze kochten, waar ze stierven, welk
-- wapen ze gebruikten, hoe ver ze in de golven kwamen.
--
-- Alle regels hebben dezelfde vorm, zodat je ze kunt grep'pen/parsen:
--
--   ACTION[Server]: [gamelog] SHOP_BUY player=Ege item=registered:sword_steel
--                   price=15 coins_left=7 | t=10:35 wave=3 pos=42.0,14.0,31.0
--
-- Handig:
--   grep '\[gamelog\]' minetest.log
--   grep '\[gamelog\] SHOP_BUY' minetest.log
--   grep 'player=Ege' minetest.log
--
-- Uitzetten van categorieen kan in minetest.conf, bv:
--   gamelog_world = false        (geen dig/place spam tijdens bouwmodus)
--   gamelog_heartbeat = false    (geen periodieke positie-snapshots)
--   gamelog_heartbeat_interval = 60
--   gamelog_log_ip = true        (IP-adres bij join loggen; standaard uit)

-- Let op: deze mod heeft bewust GEEN depends op time/enemy/boss.
-- Die mods hangen zelf van gamelog af; een (optional_)depends terug zou een
-- afhankelijkheidscyclus opleveren. De globals game_time/enemy/boss worden
-- alleen tijdens callbacks gelezen, dus na het laden van alle mods.
gamelog = {}

-- ── Instellingen ────────────────────────────────────────────────────────────

local function setting_bool(key, default)
	local v = minetest.settings:get_bool("gamelog_" .. key)
	if v == nil then return default end
	return v
end

local function setting_num(key, default)
	return tonumber(minetest.settings:get("gamelog_" .. key)) or default
end

gamelog.on = {
	session   = setting_bool("session", true),   -- join / leave / sessiesamenvatting
	combat    = setting_bool("combat", true),    -- schade, kills, sterfgevallen
	progress  = setting_bool("progress", true),  -- golven, bosses, spelvoortgang
	economy   = setting_bool("economy", true),   -- munten, winkel
	items     = setting_bool("items", true),     -- wapengebruik, eten, wield-wissel
	world     = setting_bool("world", true),     -- blokken plaatsen/slopen
	ui        = setting_bool("ui", true),        -- formspecs
	chat      = setting_bool("chat", true),      -- chat en commando's
	heartbeat = setting_bool("heartbeat", true), -- periodieke snapshot per speler
}

local HEARTBEAT_INTERVAL = setting_num("heartbeat_interval", 30)
local DAMAGE_FLUSH       = setting_num("damage_flush_interval", 2)
local LOG_IP             = setting_bool("log_ip", false)

-- ── Formattering ────────────────────────────────────────────────────────────

local function fmt_num(v)
	if v ~= v then return "nan" end                  -- NaN
	if v % 1 == 0 and math.abs(v) < 1e15 then
		return string.format("%d", v)
	end
	return string.format("%.2f", v)
end

local function fmt_value(v)
	local t = type(v)
	if t == "number" then return fmt_num(v) end
	if t == "boolean" then return v and "true" or "false" end
	if t == "nil" then return "nil" end
	if t == "table" then
		-- vector-achtig
		if v.x and v.y and v.z then
			return fmt_num(v.x) .. "," .. fmt_num(v.y) .. "," .. fmt_num(v.z)
		end
		return "{table}"
	end
	local s = tostring(v)
	-- lege of spatie-/=-houdende waarden quoten zodat parsen mogelijk blijft
	if s == "" or s:find("[%s=]") then
		return '"' .. s:gsub('"', "'") .. '"'
	end
	return s
end

-- player komt altijd eerst, de rest alfabetisch: stabiele, greppable regels
local function fmt_fields(fields)
	if not fields then return "" end
	local keys = {}
	for k in pairs(fields) do
		if k ~= "player" then keys[#keys + 1] = k end
	end
	table.sort(keys)

	local parts = {}
	if fields.player ~= nil then
		parts[#parts + 1] = "player=" .. fmt_value(fields.player)
	end
	for _, k in ipairs(keys) do
		parts[#parts + 1] = k .. "=" .. fmt_value(fields[k])
	end
	return table.concat(parts, " ")
end

-- ── Spelcontext (achter elke regel geplakt) ─────────────────────────────────

-- Geeft "t=10:35 wave=3 online=2" — zo weet je bij elk event waar in het
-- spelverloop het gebeurde, zonder terug te hoeven zoeken in de log.
local function context(player)
	local parts = {}

	if game_time and game_time.get_hour then
		parts[#parts + 1] = string.format("t=%02d:%02d",
			game_time.get_hour(), game_time.get_minute())
	end

	if enemy then
		parts[#parts + 1] = "wave=" .. tostring(enemy.current_level or 0)
		if enemy.wave_active then parts[#parts + 1] = "wave_active=true" end
		if enemy.build_mode then parts[#parts + 1] = "build_mode=true" end
	end

	parts[#parts + 1] = "online=" .. #minetest.get_connected_players()

	if player and player.get_pos then
		local pos = player:get_pos()
		if pos then parts[#parts + 1] = "pos=" .. fmt_value(pos) end
		if player.get_hp then parts[#parts + 1] = "hp=" .. player:get_hp() end
	end

	return table.concat(parts, " ")
end

-- ── Kern-API ────────────────────────────────────────────────────────────────

--- Schrijf een gestructureerde regel naar minetest.log.
-- @param event   string: EVENT_NAAM in hoofdletters
-- @param fields  table:  key/value paren (optioneel)
-- @param player  ObjectRef: speler voor pos/hp-context (optioneel)
-- @param level   string: minetest.log niveau, standaard "action"
function gamelog.event(event, fields, player, level)
	local line = "[gamelog] " .. event
	local kv = fmt_fields(fields)
	if kv ~= "" then line = line .. " " .. kv end

	local ctx = context(player)
	if ctx ~= "" then line = line .. " | " .. ctx end

	minetest.log(level or "action", line)
end

--- Zelfde als gamelog.event, maar op niveau "error" (springt eruit in de log).
function gamelog.problem(event, fields, player)
	gamelog.event(event, fields, player, "error")
end

--- Veilige naam-helper: werkt voor spelers, entities en nil.
-- @return string zoals "Ege", "entity:boss:teacher" of "unknown"
function gamelog.who(obj)
	if not obj then return "unknown" end
	if obj.is_player and obj:is_player() then
		return obj:get_player_name()
	end
	local lua = obj.get_luaentity and obj:get_luaentity()
	if lua then
		-- bosses/NPC's hebben vaak een leesbare naam in hun nametag/state
		local props = obj.get_properties and obj:get_properties()
		if props and props.nametag and props.nametag ~= "" then
			return (props.nametag:gsub("%s*%[.*%]%s*$", ""))
		end
		return lua.name or "entity"
	end
	return "unknown"
end

--- Munten van een speler (0 als onbekend).
function gamelog.coins(player)
	if not player or not player.get_meta then return 0 end
	return player:get_meta():get_int("coins")
end

-- ── Sessiestatistiek per speler ─────────────────────────────────────────────
-- Bij vertrek loggen we een samenvatting: dat is de snelste manier om te zien
-- wat iemand in een potje eigenlijk heeft gedaan.

local sessions = {} -- [pname] = stats

-- Wie sloeg wie het laatst: nodig omdat set_hp() lang niet altijd een
-- aanvaller meestuurt, en we bij een dood wél willen weten wie het deed.
local last_attacker = {} -- [pname] = { name = ..., at = minetest.get_gametime() }

local function new_session(player)
	local pos = player:get_pos()
	return {
		joined_at     = os.time(),
		start_pos     = pos,
		last_pos      = pos,
		last_wield    = player:get_wielded_item():get_name(),
		distance      = 0,
		damage_taken  = 0,
		damage_dealt  = 0,
		hits_taken    = 0,
		heals         = 0,
		deaths        = 0,
		kills         = 0,
		boss_kills    = 0,
		purchases     = 0,
		coins_spent   = 0,
		nodes_placed  = 0,
		nodes_dug     = 0,
		shots_fired   = 0,
		max_wave      = 0,
		chat_lines    = 0,
		commands      = 0,
		-- schade-aggregatie (anders 10 studenten = 10 logregels per seconde)
		pending_dmg   = 0,
		pending_hits  = 0,
		pending_src   = nil,
	}
end

--- Haal (of maak) de sessiestats van een speler op.
function gamelog.session(pname)
	return sessions[pname]
end

--- Tel iets op bij de sessiestats; veilig als de speler onbekend is.
function gamelog.bump(pname, key, amount)
	local s = sessions[pname]
	if not s then return end
	s[key] = (s[key] or 0) + (amount or 1)
end

-- ── Join / leave ────────────────────────────────────────────────────────────

if LOG_IP then
	minetest.register_on_prejoinplayer(function(name, ip)
		gamelog.event("PREJOIN", { player = name, ip = ip })
	end)
end

minetest.register_on_newplayer(function(player)
	if not gamelog.on.session then return end
	gamelog.event("FIRST_JOIN", { player = player:get_player_name() }, player)
end)

minetest.register_on_joinplayer(function(player, last_login)
	local pname = player:get_player_name()
	sessions[pname] = new_session(player)

	if not gamelog.on.session then return end
	gamelog.event("JOIN", {
		player     = pname,
		coins      = gamelog.coins(player),
		hp         = player:get_hp(),
		last_login = last_login and os.date("!%Y-%m-%dT%H:%M:%SZ", last_login) or "never",
	}, player)
end)

minetest.register_on_leaveplayer(function(player, timed_out)
	local pname = player:get_player_name()
	local s = sessions[pname]
	sessions[pname] = nil
	last_attacker[pname] = nil

	if not gamelog.on.session then return end

	local fields = { player = pname, timed_out = timed_out and true or false }
	if s then
		fields.playtime_s   = os.time() - s.joined_at
		fields.distance     = s.distance
		fields.damage_taken = s.damage_taken
		fields.damage_dealt = s.damage_dealt
		fields.deaths       = s.deaths
		fields.kills        = s.kills
		fields.boss_kills   = s.boss_kills
		fields.max_wave     = s.max_wave
		fields.purchases    = s.purchases
		fields.coins_spent  = s.coins_spent
		fields.coins_left   = gamelog.coins(player)
		fields.nodes_placed = s.nodes_placed
		fields.nodes_dug    = s.nodes_dug
		fields.shots_fired  = s.shots_fired
		fields.chat_lines   = s.chat_lines
		fields.commands     = s.commands
	end
	gamelog.event("LEAVE", fields, player)
end)

-- ── Schade en dood ──────────────────────────────────────────────────────────

minetest.register_on_punchplayer(function(player, hitter, _, tool_caps, dir, damage)
	if not gamelog.on.combat then return end
	local pname = player:get_player_name()
	last_attacker[pname] = { name = gamelog.who(hitter), at = minetest.get_gametime() }
	-- de schade zelf wordt geaggregeerd in on_player_hpchange
end)

--- Registreer expliciet dat een speler schade uitdeelde (aan te roepen vanuit
--- boss/enemy on_punch, waar de engine geen globale callback voor heeft).
-- @param player ObjectRef  de speler die sloeg
-- @param target string     leesbare naam van het doelwit
-- @param dmg    number     uitgedeelde schade
-- @param extra  table      optionele extra velden (weapon, target_hp, ...)
function gamelog.damage_dealt(player, target, dmg, extra)
	if not gamelog.on.combat then return end
	if not player or not player.is_player or not player:is_player() then return end
	local pname = player:get_player_name()
	gamelog.bump(pname, "damage_dealt", dmg or 0)

	local fields = {
		player = pname,
		target = target,
		dmg    = dmg or 0,
		weapon = player:get_wielded_item():get_name(),
	}
	for k, v in pairs(extra or {}) do fields[k] = v end
	gamelog.event("HIT", fields, player)
end

--- Registreer dat een speler een vijand doodde.
function gamelog.kill(player, target, extra)
	if not gamelog.on.combat then return end
	local pname = (player and player.is_player and player:is_player())
		and player:get_player_name() or nil
	if pname then
		gamelog.bump(pname, "kills", 1)
		if extra and extra.boss then gamelog.bump(pname, "boss_kills", 1) end
	end

	local fields = { player = pname or "unknown", target = target }
	for k, v in pairs(extra or {}) do fields[k] = v end
	gamelog.event("KILL", fields, player)
end

-- Schade-aggregatie: hits binnen DAMAGE_FLUSH seconden worden samengevoegd.
local function flush_damage(pname, player)
	local s = sessions[pname]
	if not s or s.pending_hits == 0 then return end
	gamelog.event("DAMAGE_TAKEN", {
		player = pname,
		dmg    = s.pending_dmg,
		hits   = s.pending_hits,
		src    = s.pending_src or "unknown",
	}, player)
	s.pending_dmg  = 0
	s.pending_hits = 0
	s.pending_src  = nil
end

minetest.register_on_player_hpchange(function(player, hp_change, reason)
	if not gamelog.on.combat then return end
	if hp_change == 0 then return end

	local pname = player:get_player_name()
	local s = sessions[pname]
	if not s then return end

	if hp_change > 0 then
		s.heals = s.heals + hp_change
		gamelog.event("HEAL", {
			player = pname,
			amount = hp_change,
			cause  = reason and reason.type or "unknown",
		}, player)
		return
	end

	local dmg = -hp_change
	s.damage_taken = s.damage_taken + dmg

	-- Bron bepalen: expliciet meegestuurd object > recente puncher > reason.type
	local src
	if reason and reason.object then
		src = gamelog.who(reason.object)
	else
		local la = last_attacker[pname]
		if la and (minetest.get_gametime() - la.at) <= 2 then
			src = la.name
		end
	end
	src = src or (reason and reason.type) or "unknown"

	-- Bij wisselende bron eerst de vorige batch wegschrijven
	if s.pending_hits > 0 and s.pending_src ~= src then
		flush_damage(pname, player)
	end
	s.pending_dmg  = s.pending_dmg + dmg
	s.pending_hits = s.pending_hits + 1
	s.pending_src  = src
end, false)

minetest.register_on_dieplayer(function(player, reason)
	local pname = player:get_player_name()
	flush_damage(pname, player)
	gamelog.bump(pname, "deaths", 1)

	if not gamelog.on.combat then return end

	local killer
	if reason and reason.object then
		killer = gamelog.who(reason.object)
	else
		local la = last_attacker[pname]
		if la and (minetest.get_gametime() - la.at) <= 5 then killer = la.name end
	end

	local s = sessions[pname]
	gamelog.event("DEATH", {
		player       = pname,
		killer       = killer or (reason and reason.type) or "unknown",
		cause        = reason and reason.type or "unknown",
		coins        = gamelog.coins(player),
		wield        = player:get_wielded_item():get_name(),
		deaths       = s and s.deaths or 1,
		damage_taken = s and s.damage_taken or 0,
	}, player)
end)

minetest.register_on_respawnplayer(function(player)
	if not gamelog.on.session then return end
	-- 0.1s wachten: map-mod verplaatst de speler pas na deze callback
	local pname = player:get_player_name()
	minetest.after(0.1, function()
		local p = minetest.get_player_by_name(pname)
		if p then gamelog.event("RESPAWN", { player = pname }, p) end
	end)
end)

-- ── Chat en commando's ──────────────────────────────────────────────────────

minetest.register_on_chat_message(function(name, message)
	if not gamelog.on.chat then return end
	gamelog.bump(name, "chat_lines", 1)
	gamelog.event("CHAT", { player = name, msg = message },
		minetest.get_player_by_name(name))
	-- niets teruggeven: de normale chatafhandeling moet doorgaan
end)

minetest.register_on_chatcommand(function(name, command, params)
	if not gamelog.on.chat then return end
	gamelog.bump(name, "commands", 1)
	gamelog.event("COMMAND", { player = name, cmd = command, params = params },
		minetest.get_player_by_name(name))
end)

-- ── Wereld: blokken plaatsen en slopen ──────────────────────────────────────

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack)
	if not gamelog.on.world then return end
	if not placer or not placer.is_player or not placer:is_player() then return end
	local pname = placer:get_player_name()
	gamelog.bump(pname, "nodes_placed", 1)
	gamelog.event("NODE_PLACE", { player = pname, node = newnode.name, at = pos }, placer)
end)

minetest.register_on_dignode(function(pos, oldnode, digger)
	if not gamelog.on.world then return end
	if not digger or not digger.is_player or not digger:is_player() then return end
	local pname = digger:get_player_name()
	gamelog.bump(pname, "nodes_dug", 1)
	gamelog.event("NODE_DIG", {
		player = pname,
		node   = oldnode.name,
		at     = pos,
		tool   = digger:get_wielded_item():get_name(),
	}, digger)
end)

-- ── Items ───────────────────────────────────────────────────────────────────

minetest.register_on_item_eat(function(hp_change, replace_with_item, itemstack, user)
	if not gamelog.on.items then return end
	if not user or not user:is_player() then return end
	gamelog.event("EAT", {
		player = user:get_player_name(),
		item   = itemstack:get_name(),
		heal   = hp_change,
	}, user)
	-- géén returnwaarde: anders wordt het opeten geannuleerd
end)

minetest.register_on_craft(function(itemstack, player)
	if not gamelog.on.items then return end
	if not player or not player:is_player() then return end
	gamelog.event("CRAFT", {
		player = player:get_player_name(),
		item   = itemstack:get_name(),
		count  = itemstack:get_count(),
	}, player)
end)

--- Log wapengebruik (aan te roepen vanuit on_use/on_place van wapens).
-- @param what string: korte naam van de actie, bv. "fanta_bazooka"
function gamelog.weapon_use(player, what, extra)
	if not gamelog.on.items then return end
	if not player or not player.is_player or not player:is_player() then return end
	local pname = player:get_player_name()
	gamelog.bump(pname, "shots_fired", 1)

	local fields = { player = pname, weapon = what }
	for k, v in pairs(extra or {}) do fields[k] = v end
	gamelog.event("WEAPON_USE", fields, player)
end

-- ── Economie ────────────────────────────────────────────────────────────────

--- Log een (poging tot) aankoop.
-- @param ok boolean: gelukt of niet
function gamelog.purchase(player, item, price, ok, why)
	if not gamelog.on.economy then return end
	local pname = player:get_player_name()
	if ok then
		gamelog.bump(pname, "purchases", 1)
		gamelog.bump(pname, "coins_spent", price)
	end
	gamelog.event(ok and "SHOP_BUY" or "SHOP_DENIED", {
		player     = pname,
		item       = item,
		price      = price,
		coins_left = gamelog.coins(player),
		reason     = why,
	}, player)
end

-- ── UI ──────────────────────────────────────────────────────────────────────

-- Let op: deze mod moet vóór npc/registered laden, anders zien we de velden
-- niet meer (die handlers geven `true` terug en stoppen de keten).
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if not gamelog.on.ui then return end
	if formname == "" then return end -- inventaris-formspec: te veel ruis

	-- alleen de ingedrukte knop loggen, niet de hele veldtabel
	local pressed = {}
	for k, v in pairs(fields) do
		if k ~= "quit" and v ~= "" then pressed[#pressed + 1] = k end
	end
	table.sort(pressed)

	gamelog.event("FORM", {
		player  = player:get_player_name(),
		form    = formname,
		pressed = #pressed > 0 and table.concat(pressed, ",") or "none",
		quit    = fields.quit and true or false,
	}, player)
	-- geen return: andere handlers moeten hun werk nog kunnen doen
end)

-- ── Voortgang ───────────────────────────────────────────────────────────────

--- Log een spelvoortgang-event (golf gestart, boss dood, spel uitgespeeld...).
function gamelog.progress(event, fields)
	if not gamelog.on.progress then return end
	gamelog.event(event, fields)
end

-- ── Periodieke snapshot ─────────────────────────────────────────────────────
-- Elke HEARTBEAT_INTERVAL seconden: waar staat iedereen, hoe gaat het met ze.
-- Zo kun je achteraf een potje reconstrueren, ook zonder losse events.

local hb_timer  = 0
local dmg_timer = 0

minetest.register_globalstep(function(dtime)
	-- schade-batches wegschrijven
	dmg_timer = dmg_timer + dtime
	if dmg_timer >= DAMAGE_FLUSH then
		dmg_timer = 0
		for pname in pairs(sessions) do
			local p = minetest.get_player_by_name(pname)
			if p then flush_damage(pname, p) end
		end
	end

	hb_timer = hb_timer + dtime
	if hb_timer < HEARTBEAT_INTERVAL then return end
	hb_timer = 0

	for _, player in ipairs(minetest.get_connected_players()) do
		local pname = player:get_player_name()
		local s = sessions[pname]
		if s then
			local pos = player:get_pos()

			-- afgelegde afstand bijhouden (grote sprongen = teleport, niet meetellen)
			if s.last_pos and pos then
				local d = vector.distance(s.last_pos, pos)
				if d < 500 then s.distance = s.distance + d end
			end
			s.last_pos = pos

			-- hoogst bereikte golf onthouden
			if enemy and (enemy.current_level or 0) > s.max_wave then
				s.max_wave = enemy.current_level
			end

			if gamelog.on.heartbeat then
				gamelog.event("TICK", {
					player     = pname,
					coins      = gamelog.coins(player),
					wield      = player:get_wielded_item():get_name(),
					distance   = s.distance,
					playtime_s = os.time() - s.joined_at,
					attached   = player:get_attach() and true or false,
					kills      = s.kills,
					deaths     = s.deaths,
				}, player)
			end
		end
	end
end)

-- ── Wield-wissel ────────────────────────────────────────────────────────────
-- Aparte, snellere poll: welk wapen iemand kiest is precies wat je wilt weten
-- bij balans-vragen ("gebruikt iemand die boomerang eigenlijk?").

local wield_timer = 0
minetest.register_globalstep(function(dtime)
	if not gamelog.on.items then return end
	wield_timer = wield_timer + dtime
	if wield_timer < 1.0 then return end
	wield_timer = 0

	for _, player in ipairs(minetest.get_connected_players()) do
		local pname = player:get_player_name()
		local s = sessions[pname]
		if s then
			local cur = player:get_wielded_item():get_name()
			if cur ~= s.last_wield then
				gamelog.event("WIELD", {
					player = pname,
					from   = s.last_wield ~= "" and s.last_wield or "hand",
					to     = cur ~= "" and cur or "hand",
				}, player)
				s.last_wield = cur
			end
		end
	end
end)

-- ── /stats commando ─────────────────────────────────────────────────────────

minetest.register_chatcommand("stats", {
	params      = "[<spelernaam>]",
	description = "Toon de sessiestatistiek van een speler (en schrijf die naar de log)",
	func        = function(caller, param)
		local target = (param ~= "" and param) or caller
		local s = sessions[target]
		if not s then return false, "Geen actieve sessie voor '" .. target .. "'." end

		local player = minetest.get_player_by_name(target)
		gamelog.event("STATS_DUMP", {
			player       = target,
			requested_by = caller,
			playtime_s   = os.time() - s.joined_at,
			distance     = s.distance,
			damage_taken = s.damage_taken,
			damage_dealt = s.damage_dealt,
			kills        = s.kills,
			boss_kills   = s.boss_kills,
			deaths       = s.deaths,
			max_wave     = s.max_wave,
			purchases    = s.purchases,
			coins_spent  = s.coins_spent,
			nodes_placed = s.nodes_placed,
			nodes_dug    = s.nodes_dug,
			shots_fired  = s.shots_fired,
		}, player)

		return true, string.format(
			"%s — %ds gespeeld, %.0fm gelopen, %d kills (%d bosses), %d doden, " ..
			"golf %d, %d schade uitgedeeld, %d geincasseerd, %d aankopen.",
			target, os.time() - s.joined_at, s.distance, s.kills, s.boss_kills,
			s.deaths, s.max_wave, s.damage_dealt, s.damage_taken, s.purchases)
	end,
})

-- ── Serverstart ─────────────────────────────────────────────────────────────

minetest.register_on_mods_loaded(function()
	local on = {}
	for k, v in pairs(gamelog.on) do
		if v then on[#on + 1] = k end
	end
	table.sort(on)
	-- after(0): tijdens script-init mag get_connected_players() (in context())
	-- nog niet worden aangeroepen
	minetest.after(0, function()
		gamelog.event("SERVER_START", {
			categories = table.concat(on, ","),
			heartbeat  = HEARTBEAT_INTERVAL,
		})
	end)
end)

minetest.register_on_shutdown(function()
	gamelog.event("SERVER_STOP", { online = #minetest.get_connected_players() })
end)
