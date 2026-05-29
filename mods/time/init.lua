-- time: 24-hour day/night cycle with HUD clock
-- 5 real seconds = 5 game minutes → 1 real second = 1 game minute
-- Full day (1440 min) = 1440 real seconds = 24 real minutes

local TICK = 5          -- update interval in real seconds
local MINS_PER_TICK = 5 -- game minutes per tick

-- Global time API for other mods
game_time = {}

-- Game clock state (starts at 08:00)
local game_hour = 8
local game_minute = 0

function game_time.get_hour() return game_hour end

function game_time.get_minute() return game_minute end

-- Per-player HUD ids
local hud_ids = {}

-- Format time as HH:MM
local function format_time()
	return string.format("%02d:%02d", game_hour, game_minute)
end

-- Set engine timeofday (0.0–1.0) to match our clock
local function sync_engine_time()
	local total_minutes = game_hour * 60 + game_minute
	minetest.settings:set("time_speed", 0) -- disable built-in cycle
	minetest.set_timeofday(total_minutes / 1440)
end

-- Update all players' HUD text
local function update_all_huds()
	local timestr = format_time()
	for _, player in ipairs(minetest.get_connected_players()) do
		local pname = player:get_player_name()
		local ids = hud_ids[pname]
		if ids and ids.text then
			player:hud_change(ids.text, "text", timestr)
		end
	end
end

-- Reset clock to 08:00 (used on player death / restart)
function game_time.reset()
	game_hour = 8
	game_minute = 0
	sync_engine_time()
	update_all_huds()
end

-- Create HUD for a player
local function create_hud(player)
	local pname = player:get_player_name()

	-- Background bar
	local bg_id = player:hud_add({
		hud_elem_type = "image",
		position = { x = 1, y = 0 },
		offset = { x = -100, y = 24 },
		alignment = { x = 0, y = 0 },
		scale = { x = 1.4, y = 1.4 },
		text = "time_hud_bg.png",
		z_index = 0,
	})

	-- Clock text
	local text_id = player:hud_add({
		hud_elem_type = "text",
		position = { x = 1, y = 0 },
		offset = { x = -100, y = 24 },
		alignment = { x = 0, y = 0 },
		number = 0x5599FF, -- blue
		text = format_time(),
		z_index = 1,
		style = 1, -- bold
		size = { x = 2 },
	})

	hud_ids[pname] = { bg = bg_id, text = text_id }
end

-- Advance the clock
local elapsed = 0

minetest.register_globalstep(function(dtime)
	elapsed = elapsed + dtime
	if elapsed < TICK then return end
	elapsed = elapsed - TICK

	game_minute = game_minute + MINS_PER_TICK
	if game_minute >= 60 then
		game_hour = game_hour + math.floor(game_minute / 60)
		game_minute = game_minute % 60
	end
	if game_hour >= 24 then
		game_hour = game_hour % 24
	end

	sync_engine_time()
	update_all_huds()
end)

-- Attach HUD on join, sync time
minetest.register_on_joinplayer(function(player)
	sync_engine_time()
	-- Small delay so HUD attaches after player is fully loaded
	minetest.after(0.5, function()
		local p = minetest.get_player_by_name(player:get_player_name())
		if p then create_hud(p) end
	end)
end)

-- Clean up on leave
minetest.register_on_leaveplayer(function(player)
	hud_ids[player:get_player_name()] = nil
end)

-- Disable built-in time speed on startup
minetest.after(0, function()
	minetest.settings:set("time_speed", 0)
	sync_engine_time()
end)

-- /timestamp <HH:MM>  — set game clock and engine time-of-day
minetest.register_chatcommand("timestamp", {
	params      = "<HH:MM>",
	description = "Set the game clock (e.g. /timestamp 14:30)",
	privs       = { server = true },
	func        = function(name, param)
		local h, m = param:match("^(%d+):(%d+)$")
		if not h then
			-- accept bare hour ("9" → 09:00)
			h = param:match("^(%d+)$")
			m = "0"
		end
		if not h then
			return false, "Usage: /timestamp <HH:MM>"
		end
		h = tonumber(h)
		m = tonumber(m)
		if h > 23 or m > 59 then
			return false, "Invalid time. Hours 0-23, minutes 0-59."
		end
		game_hour   = h
		game_minute = m
		sync_engine_time()
		update_all_huds()
		return true, "Time set to " .. format_time()
	end,
})
