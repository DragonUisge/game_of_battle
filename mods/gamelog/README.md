# gamelog

Centrale logging van speleractiviteit naar `minetest.log`, zodat je als
developer achteraf kunt zien wat spelers precies deden.

Elke regel heeft dezelfde vorm:

```
ACTION[Server]: [gamelog] EVENT key=value key=value | t=10:35 wave=3 online=2 pos=42.0,14.0,31.0 hp=15
```

Links van de `|` staat het event zelf, rechts de spelcontext op dat moment
(kloktijd, actieve golf, aantal spelers, en positie/hp van de betrokken speler).
Waarden met spaties staan tussen aanhalingstekens, posities als `x,y,z`.

## Zoeken in de log

```bash
grep '\[gamelog\]' ~/.minetest/debug.txt          # alles
grep '\[gamelog\] SHOP_BUY' ~/.minetest/debug.txt # alleen aankopen
grep 'player=Ege' ~/.minetest/debug.txt           # alles van één speler
grep -E '\[gamelog\] (DEATH|KILL)' ~/.minetest/debug.txt
```

## Events

| Categorie | Events |
|---|---|
| `session` | `JOIN`, `FIRST_JOIN`, `LEAVE` (met sessiesamenvatting), `RESPAWN`, `PLAYER_INIT`, `TELEPORT`, `PREJOIN` |
| `combat` | `HIT`, `HIT_BLOCKED`, `KILL`, `DAMAGE_TAKEN`, `HEAL`, `DEATH`, `DEATH_HANDLED` |
| `progress` | `WAVE_START`, `WAVE_CLEARED`, `WAVE_SKIPPED`, `BOSS_SPAWN`, `BOSS_PHASE`, `GLADIATOR_STATE`, `GAME_WON`, `GAME_RESET`, `VICTORY_DRAGON_SUMMONED`, `PLAYER_RETURNED_BY_DRAGON` |
| `economy` | `SHOP_BUY`, `SHOP_DENIED` |
| `items` | `WIELD`, `WEAPON_USE`, `WEAPON_BLOCKED`, `EAT`, `CRAFT`, `ELEMENT_SWITCH` |
| `world` | `NODE_PLACE`, `NODE_DIG`, `ARENA_PLACED` |
| `ui` | `FORM`, `NPC_TALK`, `SCHEDULE_OPEN`, `SCHEDULE_SAVED`, `SCHEDULE_REVERTED_BY_DRAGON` |
| `chat` | `CHAT`, `COMMAND` |
| `heartbeat` | `TICK` (elke 30 s per speler) |
| overig | `SERVER_START`, `SERVER_STOP`, `NPC_SPAWN`, `DRAGON_MOUNT`, `DRAGON_DISMOUNT`, `COMPANION_DRAGON_SPAWN`, `ADMIN_*`, `STATS_DUMP` |

`DAMAGE_TAKEN` wordt per 2 seconden samengevoegd — anders leveren tien
studenten die op je inhakken tien logregels per seconde op.

## Sessiesamenvatting

Bij `LEAVE` (en via `/stats`) krijg je in één regel wat iemand dat potje deed:
speeltijd, afgelegde afstand, uitgedeelde/geïncasseerde schade, kills,
boss-kills, doden, hoogste golf, aankopen, uitgegeven munten, geplaatste en
gesloopte blokken, afgevuurde schoten, chatregels en commando's.

```
/stats            # jezelf
/stats Ege        # iemand anders
```

## Instellen (`minetest.conf`)

Alles staat standaard aan. Uitzetten per categorie:

```
gamelog_world = false               # geen dig/place-ruis tijdens bouwmodus
gamelog_heartbeat = false           # geen periodieke TICK-regels
gamelog_heartbeat_interval = 60     # standaard 30 seconden
gamelog_damage_flush_interval = 2   # samenvoegvenster voor DAMAGE_TAKEN
gamelog_log_ip = true               # IP bij join loggen (standaard uit)
```

Verder: `gamelog_session`, `gamelog_combat`, `gamelog_progress`,
`gamelog_economy`, `gamelog_items`, `gamelog_ui`, `gamelog_chat`.

## Zelf logregels toevoegen

```lua
gamelog.event("MIJN_EVENT", { player = pname, iets = 42 }, player)
gamelog.progress("BOSS_PHASE", { boss = "Hugo", phase = "summon" })
gamelog.problem("SPAWN_MISLUKT", { npc = name })      -- niveau "error"
gamelog.damage_dealt(player, "Bram", 12, { target_hp = 88 })
gamelog.kill(player, "Bram", { boss = true, level = 1 })
gamelog.weapon_use(player, "fanta_bazooka", { ammo_left = 5 })
gamelog.purchase(player, item, price, true, "wapenwinkel")
```

`gamelog` laadt vóór de andere mods (die hebben `depends = gamelog`) en heeft
zelf bewust géén depends — een verwijzing terug zou een afhankelijkheidscyclus
opleveren.
