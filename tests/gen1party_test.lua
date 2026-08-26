-- Standalone: luajit mods/Gen1Party/tests/gen1party_test.lua
--
-- Loads the mod through the headless SDK harness against the ROM-free
-- fixture dataset and asserts its stated effect: the PartyMenu screen id is
-- taken over, every party member asks for its OWN species palette instead of
-- the one MEWMON column vanilla lays over all six, and nothing the screen
-- draws reaches the right edge any more.
--
-- The margin claim is checked by recording what the screen actually draws --
-- every string and its measured width -- rather than by reading the source,
-- because "does this touch the edge" is a question about pixels.
--
-- Run it from a Gen1Recomp checkout with this mod at mods/Gen1Party, or set
-- GEN1PARTY_DIR to wherever it lives.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Font = require("src.render.Font")
local PaletteFX = require("src.render.PaletteFX")
local PartyMenu = require("src.ui.PartyMenu")

local DIR = os.getenv("GEN1PARTY_DIR") or "mods/Gen1Party"
local Data = T.fixtures.fresh()
local run = T.sdk.loadMod(DIR, { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

local factory = Data.screens and Data.screens.PartyMenu
T.check(factory ~= nil, "the PartyMenu screen id is taken over")
T.eq(type(factory.new), "function", "and it is a screen factory")
local geometry = factory.geometry or {}
T.eq(type(geometry.BODY_TOP), "number", "and it publishes its geometry")

-- ------- a stub game and a stub party

local function newStack()
  local s = { states = {} }
  function s:push(v) table.insert(self.states, v) end
  function s:pop() return table.remove(self.states) end
  function s:top() return self.states[#self.states] end
  return s
end

local function mon(species, level, hp, maxHp, extra)
  local m = { species = species, level = level, hp = hp,
              stats = { hp = maxHp, attack = 10, defense = 10,
                        speed = 10, special = 10 },
              moves = {}, exp = 0 }
  for k, v in pairs(extra or {}) do m[k] = v end
  return m
end

local function fakeGame(party)
  local pressed = {}
  local game = {
    data = Data,
    save = { party = party or {}, pokedex = { seen = {}, owned = {} },
             player = { name = "RED", id = 1 }, flags = {}, boxes = {} },
    stack = newStack(),
    input = {
      wasPressed = function(_, key) return pressed[key] end,
      isDown = function(_, key) return pressed[key] end,
    },
  }
  game.press = function(key) pressed = {}; pressed[key] = true end
  return game
end

local FULL = {
  mon("FIXMON_A", 30, 45, 45),
  mon("FIXMON_B", 26, 0, 39),                       -- fainted
  mon("FIXMON_C", 27, 12, 44),
  mon("FIXMON_A", 100, 150, 150),                   -- three-digit level and HP
  mon("FIXMON_B", 5, 3, 20),
  mon("FIXMON_C", 50, 88, 90),
}

-- ------- every member asks for its own palette
--
-- Vanilla lays ONE MEWMON zone over tiles (1,0)-(2,11) -- the whole icon
-- column, all six at once.  Standing in for monPal is what shows whether this
-- screen asks per member instead; the fixture dataset carries no palette pack,
-- so what is asserted is WHICH species are asked about, not what comes back.

do
  local realMonPal = PaletteFX.monPal
  local asked = {}
  PaletteFX.monPal = function(_, species)
    asked[#asked + 1] = species
    return { { 255, 255, 255 }, { 200, 100, 100 }, { 100, 50, 50 }, { 0, 0, 0 } }
  end

  local game = fakeGame(FULL)
  local menu = factory.new(game)
  local zones = menu:sgbPalettes(game)
  PaletteFX.monPal = realMonPal

  T.eq(#asked, 6, "one species palette asked for per party member")
  T.eq(asked[1], "FIXMON_A", "the first member's own species")
  T.eq(asked[2], "FIXMON_B", "the second member's own species")
  T.eq(asked[4], "FIXMON_A", "and a repeat species asks again for its own slot")

  T.check(type(zones) == "table", "the screen answers with a zone list")
  -- a base, six icon zones, and a bar zone per member
  T.check(#zones >= 7, "a base palette plus one zone per member")

  -- the icon zones must land on the icon column, two tiles wide and two tall,
  -- one pair of tile rows per slot -- that is what makes them addressable
  local iconZones = {}
  for _, z in ipairs(zones) do
    if z and z.x == 8 and z.w == 16 then iconZones[#iconZones + 1] = z end
  end
  T.eq(#iconZones, 6, "six icon zones, on the icon column")
  for i, z in ipairs(iconZones) do
    -- on the slot's own rows IN THE BODY: the zones moved down with the rows
    -- when the header box went in, and a zone left at the old offset would
    -- paint the member above (or the header) in this one's colours
    T.eq(z.y, geometry.BODY_TOP + (i - 1) * 16,
         "icon zone " .. i .. " sits on its own slot")
    T.eq(z.h, 16, "and is two tile rows tall")
    T.eq(z.x % 8, 0, "on a tile boundary horizontally")
    T.eq(z.y % 8, 0, "and vertically")
  end
end

do
  -- A party of one asks once, and an empty party asks not at all rather than
  -- throwing on the way past.
  local realMonPal = PaletteFX.monPal
  local asked = 0
  PaletteFX.monPal = function() asked = asked + 1 return nil end

  local game = fakeGame({ mon("FIXMON_A", 5, 20, 20) })
  local one = factory.new(game)
  one:sgbPalettes(game)
  T.eq(asked, 1, "a party of one asks once")

  asked = 0
  local empty = fakeGame({})
  local none = factory.new(empty)
  local zones = none:sgbPalettes(empty)
  PaletteFX.monPal = realMonPal
  T.eq(asked, 0, "an empty party asks for no species palettes")
  T.check(type(zones) == "table", "and still answers with a base palette")
end

-- ------- nothing reaches the right edge
--
-- The vanilla row is packed to 160: its status column runs 136..160 and its
-- HP numbers 104..160.  Record what is actually drawn and measure it.

local function recordDraw(screen)
  local drawn = { boxes = {}, rules = {}, codes = {} }
  local realDraw, realBox = Font.draw, Font.drawBox
  Font.draw = function(text, x, y)
    local ok, w = pcall(Font.width, text)
    drawn[#drawn + 1] = { text = tostring(text), x = x, y = y,
                          w = ok and w or 0 }
    return realDraw(text, x, y)
  end
  Font.drawBox = function(tx, ty, tw, th)
    drawn.boxes[#drawn.boxes + 1] = { tx = tx, ty = ty, tw = tw, th = th }
    return realBox(tx, ty, tw, th)
  end
  -- the hairline goes through love.graphics.rectangle like the screen clear
  -- does, so record the thin ones and let the full-screen fill through
  local realRect = love.graphics.rectangle
  love.graphics.rectangle = function(mode, x, y, w, h, ...)
    if w == 1 and h and h > 1 then
      drawn.rules[#drawn.rules + 1] = { x = x, y = y, w = w, h = h }
    end
    return realRect(mode, x, y, w, h, ...)
  end
  -- the cursor and the <LV> tile go through drawCode, not draw
  local realCode = Font.drawCode
  Font.drawCode = function(code, x, y)
    drawn.codes[#drawn.codes + 1] = { code = code, x = x, y = y }
    return realCode(code, x, y)
  end
  local ok, err = pcall(screen.draw, screen)
  Font.draw, Font.drawBox, Font.drawCode = realDraw, realBox, realCode
  love.graphics.rectangle = realRect
  T.check(ok, "the screen draws (" .. tostring(err) .. ")")
  return drawn
end

local function hasBox(drawn, tx, ty, tw, th)
  for _, b in ipairs(drawn.boxes) do
    if b.tx == tx and b.ty == ty and b.tw == tw and b.th == th then
      return true
    end
  end
  return false
end

do
  local game = fakeGame(FULL)
  local menu = factory.new(game)
  local drawn = recordDraw(menu)
  T.check(#drawn > 0, "the screen printed something")

  local worst, worstText = 0, nil
  for _, d in ipairs(drawn) do
    local right = d.x + d.w
    if right > worst then worst, worstText = right, d.text end
  end
  T.check(worst <= 152,
          ("nothing is drawn past x=152 (worst was %d, %q)")
            :format(worst, tostring(worstText)))

  -- and the two columns the margin was bought for are actually there
  local sawFnt, sawHp = false, false
  for _, d in ipairs(drawn) do
    if d.text == "FNT" then
      sawFnt = true
      T.eq(d.x + d.w, 152, "FNT is right-aligned on the margin")
    end
    if d.text:find("/") and d.text:find("%d") then
      sawHp = true
      T.eq(d.x + d.w, 152, "the HP numbers are right-aligned on the margin")
    end
  end
  T.check(sawFnt, "the fainted member printed FNT")
  T.check(sawHp, "the healthy members printed their HP")
end

do
  -- What RULED ICONS costs, stated as a test rather than as a promise: the
  -- rule needs the names off the icon cell, and ten glyphs of name need every
  -- pixel from 24 to the level column, so the tenth is what pays for it.
  local party = { mon("FIXMON_A", 30, 45, 45, { nickname = "CHARMANDER" }) }
  local game = fakeGame(party)
  local menu = factory.new(game)
  local drawn = recordDraw(menu)
  local found
  for _, d in ipairs(drawn) do
    if d.x == geometry.NAME_X and d.text:find("CHARMAND", 1, true) then
      found = d
    end
  end
  T.check(found ~= nil, "the nickname is printed in the name column")
  T.eq(found.text, "CHARMANDE", "cut to nine glyphs, on a glyph boundary")
  T.eq(found.x, geometry.NAME_X, "at the ruled name column")
  T.check(found.x + found.w <= 104, "without running into the level column")

  -- and the hairline it was cut for, where the dex list draws its own
  local rules = {}
  for _, r in ipairs(drawn.rules) do rules[#rules + 1] = r end
  T.eq(#rules, 1, "one hairline, not one per row")
  T.eq(rules[1].x, geometry.RULE_X, "at the dex list's own column")
  T.eq(rules[1].y, geometry.BODY_TOP, "from the top of the body")
  T.eq(rules[1].y + rules[1].h - 1, geometry.BODY_BOTTOM, "to the bottom of it")
  T.check(rules[1].x > 23, "clear of the icon cell")
  T.check(rules[1].x + 1 < geometry.NAME_X, "and clear of the names")
end

do
  -- RULED ICONS off gives the tenth glyph back, and takes the rule away with
  -- it -- the two are the same eight pixels.
  local loader = run.loader
  if loader.modOptions then
    local saved = loader.modOptions.Gen1Party
    loader.modOptions.Gen1Party = { ruled_icons = false }
    local party = { mon("FIXMON_A", 30, 45, 45, { nickname = "CHARMANDER" }) }
    local menu = factory.new(fakeGame(party))
    local drawn = recordDraw(menu)
    loader.modOptions.Gen1Party = saved

    local whole
    for _, d in ipairs(drawn) do
      if d.text == "CHARMANDER" then whole = d end
    end
    T.check(whole ~= nil, "off, a ten-glyph nickname is printed whole")
    T.eq(whole and whole.x, geometry.NAME_X_WIDE, "at the vanilla name column")
    T.eq(#drawn.rules, 0, "and no hairline is drawn")
  end
end

-- ------- the HP bar keeps all six segments
--
-- The margin was bought by moving the bar one tile left, not by shortening
-- it: the bar is the at-a-glance read on this screen.

do
  local calls = {}
  local HudTiles = require("src.render.HudTiles")
  local realBar = HudTiles.drawHPBar
  HudTiles.drawHPBar = function(data, tx, ty, m, barType, gray, segments)
    calls[#calls + 1] = { tx = tx, ty = ty, segments = segments or 6 }
  end

  local game = fakeGame(FULL)
  local menu = factory.new(game)
  pcall(menu.draw, menu)
  HudTiles.drawHPBar = realBar

  -- Six, not five: a fainted member keeps its bar, drawn empty beside its
  -- "0/ 62".  That is what vanilla does and what the screen shows.
  T.eq(#calls, 6, "a bar for every member, fainted ones included")
  for _, c in ipairs(calls) do
    T.eq(c.segments, 6, "the bar keeps all six segments")
    T.eq(c.tx, 4, "drawn one tile left of vanilla's five")
  end
  -- tile 4 is x=32, which clears the icon's right edge at 24
  T.check(4 * 8 >= 8 + 16, "the bar starts clear of the icon column")
end

-- ------- the modes are untouched
--
-- PartyMenu is seven screens behind one id.  This mod replaces two methods
-- and must leave the rest exactly as the engine built them.

do
  local game = fakeGame(FULL)
  local vanilla = PartyMenu.new(game, {})
  local ours = factory.new(fakeGame(FULL), {})

  local skip = { draw = true, sgbPalettes = true, update = true }
  local missing = {}
  for key, value in pairs(vanilla) do
    if not skip[key] and ours[key] == nil and value ~= nil then
      missing[#missing + 1] = key
    end
  end
  T.eq(#missing, 0,
       "every field the vanilla constructor sets survives: "
         .. table.concat(missing, ", "))

  T.neq(ours.draw, vanilla.draw, "draw is replaced")
  T.neq(ours.sgbPalettes, vanilla.sgbPalettes, "and so is sgbPalettes")
  -- The third, and the only one that changes what a key does: MOVE.  It is a
  -- WRAPPER rather than a rewrite, and the section below drives it to show
  -- that every other key still reaches the engine's own update.
  T.neq(ours.update, vanilla.update, "and so is update, for the carry")
  T.eq(ours.bottomMessage, vanilla.bottomMessage,
       "bottomMessage is still the engine's, so the prompts are still its own")
  T.eq(ours.isOpaque, vanilla.isOpaque, "and the screen is still opaque")
end

do
  -- Every mode draws.  These are the branches that print something other than
  -- an HP bar, and the ones a naive port drops.
  local modes = {
    { label = "field", opts = {} },
    { label = "battle switch", opts = { battle = {}, onSwitch = function() end } },
    { label = "item target", opts = { pickOnly = true, onSwitch = function() end } },
  }
  for _, m in ipairs(modes) do
    local game = fakeGame(FULL)
    local menu = factory.new(game, m.opts)
    T.check(pcall(menu.draw, menu), "the " .. m.label .. " mode draws")
  end
end

do
  -- The TM/HM list prints ABLE / NOT ABLE where the bar would be, and asks
  -- for no bar palettes at all.
  local game = fakeGame(FULL)
  local menu = factory.new(game)
  menu.tmhm = { move = "FIX_CUT" }
  local drawn = recordDraw(menu)

  local able, notAble = 0, 0
  for _, d in ipairs(drawn) do
    if d.text == "ABLE" then able = able + 1 end
    if d.text == "NOT ABLE" then notAble = notAble + 1 end
    if d.text == "ABLE" or d.text == "NOT ABLE" then
      T.eq(d.x + d.w, 152, "the verdict is right-aligned on the margin")
    end
  end
  T.check(able > 0, "the members that can learn it say ABLE")
  T.check(notAble > 0, "and the ones that cannot say NOT ABLE")

  -- FIXMON_A and FIXMON_C carry FIX_CUT; FIXMON_B does not
  T.eq(able, 4, "four of the six can learn FIX CUT")
  T.eq(notAble, 2, "and two cannot")

  local realMonPal = PaletteFX.monPal
  PaletteFX.monPal = function() return nil end
  local zones = menu:sgbPalettes(game)
  PaletteFX.monPal = realMonPal
  for _, z in ipairs(zones) do
    T.check(not (z and z.x == 48),
            "the TM/HM list asks for no bar zones, having drawn no bars")
  end
end

do
  -- The evolution-stone list takes the same column.
  local game = fakeGame(FULL)
  local menu = factory.new(game)
  menu.evoStone = "FIX_STONE"
  local drawn = recordDraw(menu)
  local verdicts = 0
  for _, d in ipairs(drawn) do
    if d.text == "ABLE" or d.text == "NOT ABLE" then verdicts = verdicts + 1 end
  end
  T.eq(verdicts, 6, "one verdict per member")
end

do
  -- The bar zones moved down with the rows too.  Each one has to sit on its
  -- OWN slot's HP row: a zone left at the vanilla offset would colour the
  -- member above it, and slot 1's would land on the header box.  The fixture
  -- carries no palette pack, so stand in for the lookup and assert placement.
  local game = fakeGame(FULL)
  local menu = factory.new(game)
  local realPal = PaletteFX.pal
  PaletteFX.pal = function(_, name)
    if type(name) == "string" and name:find("BAR") then
      return { { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 }, { 0, 0, 0 } }
    end
    return nil
  end
  local zones = menu:sgbPalettes(game)
  PaletteFX.pal = realPal

  local bars = {}
  for _, z in ipairs(zones or {}) do
    if z and z.x == 48 then bars[#bars + 1] = z end
  end
  T.eq(#bars, 6, "one bar zone per member")
  for i, z in ipairs(bars) do
    T.eq(z.y, geometry.BODY_TOP + (i - 1) * geometry.ROW_H + 8,
         "bar zone " .. i .. " sits on its own slot's HP row")
    T.eq(z.h, 8, "and is one tile row tall")
  end
end

-- ------- MOVE: the member is in your hand
--
-- The one thing on this screen that is not the engine's.  The engine's
-- SWITCH is two picks over a list that never moves; this is Gen1BillsBox's
-- answer -- the member is lifted, it flashes, and it travels through the
-- list a row at a time with the party reordered under it as it goes.
--
-- Driven a press at a time through the real update, so what is asserted is
-- what a player's thumb does: nothing here reaches into the screen's state
-- to set up a carry.

local Strings = require("src.core.Strings")
local Theme = require("src.ui.Theme")

local function copyOf(list)
  local out = {}
  for i, value in ipairs(list) do out[i] = value end
  return out
end

-- one press, one update -- the loop the engine runs
local function driver(party, opts)
  local game = fakeGame(party)
  local menu = factory.new(game, opts)
  local function press(key)
    game.press(key or "none")
    menu:update(1 / 60)
  end
  return game, menu, press
end

local function rowOf(items, action)
  for i, entry in ipairs(items) do
    if entry.action == action then return i, entry end
  end
end

-- A over a member, then A over the row that moves it
local function lift(press, menu)
  press("a")
  local at = rowOf(menu.subItems or {}, "switch")
  for _ = 2, at or 1 do press("down") end
  press("a")
end

local function census(party)
  local seen = {}
  for _, mon in ipairs(party) do seen[mon] = (seen[mon] or 0) + 1 end
  return seen
end

do
  -- the popup's word
  local _, menu, press = driver(copyOf(FULL))
  press("a")
  T.check(menu.submenu == true, "A over a member opens the engine's popup")
  local at, row = rowOf(menu.subItems or {}, "switch")
  T.check(row ~= nil, "which still carries the engine's own switch row")
  T.eq(row and row.label, Strings("MOVE"), "relabelled MOVE")
  T.eq(at, #menu.subItems, "in the place the engine put it, under STATS")
  local saidSwitch = false
  for _, entry in ipairs(menu.subItems) do
    if entry.label == Strings("SWITCH") then saidSwitch = true end
  end
  T.check(not saidSwitch, "and nothing on the popup says SWITCH any more")
  -- the rest of the list is the engine's, untouched
  T.check(rowOf(menu.subItems, "stats") ~= nil, "STATS is still on it")
end

do
  -- the battle popup's SWITCH is a different verb -- "send this one out" --
  -- and keeps its own word
  local _, menu, press = driver(copyOf(FULL),
    { battle = {}, onSwitch = function() end })
  press("a")
  local _, row = rowOf(menu.subItems or {}, "battle_switch")
  T.check(row ~= nil, "the battle popup offers the battle switch")
  T.eq(row and row.label, Strings("SWITCH"), "and it is left saying SWITCH")
end

do
  -- picking one up
  local party = copyOf(FULL)
  local game, menu, press = driver(party)
  lift(press, menu)
  T.eq(menu.submenu, nil, "MOVE closes the popup")
  T.eq(menu.moveFrom, 1, "and lifts the member the cursor was on")
  T.eq(menu.swapFrom, 1,
       "the engine's own in-the-air flag says so, so the footer does too")
  T.eq(menu.index, 1, "the cursor has not moved yet")
  T.check(menu:bottomMessage():find("Move", 1, true) ~= nil,
          "and the prompt is the engine's swap prompt")

  -- and DOWN carries it, reordering the party as it goes
  local first, second = party[1], party[2]
  press("down")
  T.eq(menu.index, 2, "DOWN moves the cursor")
  T.eq(party[2], first, "and the member goes with it")
  T.eq(party[1], second, "the row it passed comes up behind it")
  T.eq(menu.swapFrom, 2, "the flag follows the member, not the row it left")
  T.eq(game.partyMenuSavedIndex, 2, "and the saved index follows the cursor")

  -- A lets go, and there is nothing to commit: the array already is the list
  press("a")
  T.eq(menu.moveFrom, nil, "A puts it down")
  T.eq(menu.swapFrom, nil, "and the screen is a plain list again")
  T.eq(party[2], first, "the member stayed where it was let go")
  T.eq(#party, 6, "with the party still six long")
end

do
  -- A RUN of steps is an insertion, not an exchange: carry the fourth member
  -- to the top and the three it passed keep the order they already had.
  -- Vanilla's SWITCH would have traded the first and the fourth and left the
  -- two between them alone.
  local party = copyOf(FULL)
  local before = copyOf(party)
  local _, menu, press = driver(party)
  press("down") press("down") press("down")     -- the cursor, on row 4
  T.eq(menu.index, 4, "the cursor walks the list before anything is lifted")
  lift(press, menu)
  press("up") press("up") press("up")

  T.eq(menu.index, 1, "the member is carried to the top")
  T.eq(party[1], before[4], "and it is the one that was fourth")
  T.eq(party[2], before[1], "the first is now second")
  T.eq(party[3], before[2], "the second third")
  T.eq(party[4], before[3], "and the third fourth -- their own order, kept")
  T.eq(party[5], before[5], "the rows it never reached are untouched")
  T.eq(party[6], before[6], "both of them")

  local was, now = census(before), census(party)
  local same = true
  for mon, n in pairs(was) do if now[mon] ~= n then same = false end end
  T.check(same and #party == #before,
          "and no POKéMON was created or lost on the way")
end

do
  -- B is BACK, not out: it walks the member home, and because every step
  -- leaves the others in their own order, home is the party it started as
  local party = copyOf(FULL)
  local before = copyOf(party)
  local game, menu, press = driver(party)
  press("down") press("down")
  lift(press, menu)
  press("up") press("up")                       -- to the top
  T.eq(party[1], before[3], "the member is carried to the top")

  press("b")
  T.eq(menu.moveFrom, nil, "B puts it down")
  T.eq(menu.index, 3, "back in the row it was picked up from")
  for i = 1, #before do
    T.eq(party[i], before[i], "slot " .. i .. " is exactly as it was")
  end
  T.eq(#game.stack.states, 0, "and B did not close the menu")
end

do
  -- B with nothing in hand still closes the menu, the way it always did
  local game = fakeGame(copyOf(FULL))
  local menu = factory.new(game)
  game.stack:push(menu)
  game.press("b")
  menu:update(1 / 60)
  T.eq(#game.stack.states, 0, "B with empty hands is still the way out")
end

do
  -- The wrap is the list's own: the cursor wraps, so the member does, and
  -- there it is a rotation -- every other member still keeps its order.
  local party = copyOf(FULL)
  local before = copyOf(party)
  local _, menu, press = driver(party)
  lift(press, menu)
  press("up")
  T.eq(menu.index, 6, "UP off the top lands on the last row")
  T.eq(party[6], before[1], "and the member is there")
  for i = 1, 5 do
    T.eq(party[i], before[i + 1], "the rest shifted up one, in their order")
  end
end

do
  -- A party of one has nowhere to go, and must not crash trying
  local party = { mon("FIXMON_A", 5, 20, 20) }
  local _, menu, press = driver(party)
  lift(press, menu)
  press("down") press("up")
  T.eq(menu.index, 1, "a party of one stays put")
  T.eq(#party, 1, "with its one member still in it")
  press("a")
  T.eq(menu.moveFrom, nil, "and it can still be put down")
end

do
  -- The one rule the engine has about moving a POKéMON: Yellow's starter
  -- Pikachu will not be moved while it is not following you.  Vanilla refuses
  -- the A press on either end of its swap; a carry presses A over neither of
  -- the rows it displaces, so the same question is asked of every row the
  -- step would move.
  local pika = mon("PIKACHU", 10, 20, 20, { ot = "RED", otId = 1 })
  local party = { FULL[1], pika, FULL[3] }
  local before = copyOf(party)
  local game, menu, press = driver(party)
  game.overworld = { pikachuBillsScene = true }
  lift(press, menu)
  press("down")
  T.eq(menu.index, 1, "the carry is refused rather than walking past it")
  for i = 1, #before do
    T.eq(party[i], before[i], "slot " .. i .. " did not move")
  end
  T.eq(menu.moveFrom, 1, "and the member is still in hand")
  T.check(#game.stack.states > 0, "the engine's own refusal is printed")

  -- with the scene over, the same press moves it
  game.overworld = nil
  game.stack:pop()
  press("down")
  T.eq(party[2], before[1], "once it is following again, the step lands")
end

do
  -- The flash: sixteen steps lit and eight dark, and it is the whole ROW that
  -- blinks, because on this screen the row is the member.  The cursor is not
  -- part of it -- it is where your thumb is -- and goes hollow instead.
  local party = copyOf(FULL)
  local _, menu, press = driver(party)
  lift(press, menu)

  local function names(drawn)
    local n = 0
    for _, d in ipairs(drawn) do
      if d.x == geometry.NAME_X then n = n + 1 end
    end
    return n
  end
  local function cursorAt(drawn, y)
    for _, c in ipairs(drawn.codes) do
      if c.x == 0 and c.y == y then return c.code end
    end
  end

  local cursorY = geometry.BODY_TOP + 8
  local lit = recordDraw(menu)
  T.eq(names(lit), 6, "the member is drawn on the lit stretch of the cycle")
  T.eq(cursorAt(lit, cursorY), Theme.cursorHollow,
       "with a hollow cursor beside it, the way the box marks a carried one")

  for _ = 1, geometry.FLASH_ON do press() end
  local dark = recordDraw(menu)
  T.eq(names(dark), 5, "and not drawn on the dark stretch")
  T.eq(cursorAt(dark, cursorY), Theme.cursorHollow,
       "while the cursor stays put -- one that blinked would read as dropped "
         .. "frames")

  for _ = 1, geometry.FLASH_PERIOD - geometry.FLASH_ON do press() end
  T.eq(names(recordDraw(menu)), 6, "and it comes back on the next cycle")

  -- put it down and the flashing stops, cursor filled again
  press("a")
  local still = recordDraw(menu)
  T.eq(names(still), 6, "a member let go is drawn on every frame")
  T.eq(cursorAt(still, cursorY), Theme.cursor, "under the filled cursor again")
end

do
  -- Nobody else flashes: only the member in your hand.
  local party = copyOf(FULL)
  local _, menu, press = driver(party)
  lift(press, menu)
  for _ = 1, geometry.FLASH_ON do press() end
  local drawn = recordDraw(menu)
  local rows = {}
  for _, d in ipairs(drawn) do
    if d.x == geometry.NAME_X then rows[d.y] = true end
  end
  T.check(not rows[geometry.BODY_TOP], "the carried row is the dark one")
  for i = 2, 6 do
    T.check(rows[geometry.BODY_TOP + (i - 1) * geometry.ROW_H],
            "slot " .. i .. " is drawn right through it")
  end
end

do
  -- MOVE NOT SWITCH off restores the engine's answer exactly: the row says
  -- SWITCH, and it is two picks and one exchange over a list that does not
  -- move.
  local loader = run.loader
  if loader.modOptions then
    local saved = loader.modOptions.Gen1Party
    loader.modOptions.Gen1Party = { live_move = false }

    local party = copyOf(FULL)
    local before = copyOf(party)
    local _, menu, press = driver(party)
    press("a")
    local _, row = rowOf(menu.subItems or {}, "switch")
    T.eq(row and row.label, Strings("SWITCH"), "off, the popup says SWITCH")
    for _ = 2, #menu.subItems do press("down") end
    press("a")
    T.eq(menu.moveFrom, nil, "nothing is lifted")
    T.eq(menu.swapFrom, 1, "the engine is waiting for a second pick")

    press("down") press("down")
    T.eq(party[1], before[1], "the list does not move while the cursor does")
    T.eq(menu.index, 3, "the cursor is on the second pick")
    press("a")
    T.eq(party[1], before[3], "and A exchanges the two")
    T.eq(party[3], before[1], "both ways")
    T.eq(party[2], before[2], "leaving the row between them alone")

    loader.modOptions.Gen1Party = saved
  end
end

-- ------- the frame

do
  -- The set's shape: a header box on 0-2, six party rows in the 96-pixel body
  -- between, a footer box on 15-17.  Asserted as boxes and pixel rows rather
  -- than described, because "does this fit" is a question about the screen.
  local game = fakeGame(FULL)
  local menu = factory.new(game)
  local drawn = recordDraw(menu)

  T.check(hasBox(drawn, 0, 0, 20, 3), "a header box on rows 0-2")
  T.check(hasBox(drawn, 0, 15, 20, 3), "a footer box on rows 15-17")

  local G = geometry
  T.eq(G.BODY_TOP, 24, "the body starts under the header box")
  T.eq(G.BODY_TOP + 6 * G.ROW_H - 1, G.BODY_BOTTOM,
       "and six rows of sixteen fill it exactly, to the last pixel")
  T.eq(G.FOOTER_TY * 8, G.BODY_BOTTOM + 1,
       "with the footer box starting on the row after")

  -- the title, where the dex list puts its own
  local sawTitle = false
  for _, d in ipairs(drawn) do
    if d.y == G.HEADER_TEXT_Y then
      sawTitle = true
      T.eq(d.x, G.LEFT, "the title sits at the header box's left margin")
    end
  end
  T.check(sawTitle, "the header box has a title in it")
  local titleDrawn
  for _, d in ipairs(drawn) do
    if d.y == G.HEADER_TEXT_Y then titleDrawn = d end
  end
  T.check(titleDrawn and titleDrawn.text:find("PARTY", 1, true) ~= nil,
          "and the title names the screen (got "
            .. tostring(titleDrawn and titleDrawn.text) .. ")")
  T.check(titleDrawn and titleDrawn.w <= G.LINE_W,
          "and fits the header box")

  -- nothing lands on the boxes' borders or outside the body
  for _, d in ipairs(drawn) do
    local onChrome = d.y == G.HEADER_TEXT_Y or d.y == G.FOOTER_TEXT_Y
    T.check(onChrome or (d.y >= G.BODY_TOP and d.y + 8 <= G.BODY_BOTTOM + 1),
            ("%q is inside the body or on a box line (y=%d)")
              :format(d.text, d.y))
  end
end

do
  -- Every member is in the body, and the six rows are where they should be.
  local game = fakeGame(FULL)
  local menu = factory.new(game)
  local drawn = recordDraw(menu)
  for i = 1, 6 do
    local want = geometry.BODY_TOP + (i - 1) * geometry.ROW_H
    local found = false
    for _, d in ipairs(drawn) do
      if d.x == geometry.NAME_X and d.y == want then found = true end
    end
    T.check(found, "slot " .. i .. "'s name is on its own row in the body")
  end
end

-- ------- one line under the body, and whose words it is

do
  -- The footer holds ONE line.  bottomMessage() still owns the words wherever
  -- the engine's words fit the box: hardcoding a prompt cost a red CI run once
  -- already (#1610 reworded the swap prompt), so what is asserted is that a
  -- fitting engine prompt is printed VERBATIM and that nothing printed there
  -- is ever wider than the box.
  local modes = {
    { label = "field", apply = function() end },
    { label = "swap", apply = function(m) m.swapFrom = 2 m.index = 4 end },
    { label = "TM/HM", apply = function(m) m.tmhm = { move = "FIX_CUT" } end },
    { label = "softboiled", apply = function(m) m.softboiledFrom = 1 end },
    { label = "battle", apply = function(m) m.battle = true end },
  }
  for _, mode in ipairs(modes) do
    local game = fakeGame(FULL)
    local menu = factory.new(game)
    mode.apply(menu)

    local engineText = menu:bottomMessage()
    local flat = (tostring(engineText):gsub("%s*\n%s*", " "))
    local drawn = recordDraw(menu)

    local footer
    for _, d in ipairs(drawn) do
      if d.y == geometry.FOOTER_TEXT_Y then
        T.check(footer == nil,
                "the " .. mode.label .. " footer is one line, not two")
        footer = d
      end
    end
    T.check(footer ~= nil, "the " .. mode.label .. " mode prints a prompt")
    if footer then
      T.eq(footer.x, geometry.LEFT,
           "the " .. mode.label .. " prompt sits at the box's left margin")
      T.check(footer.w <= geometry.LINE_W,
              ("the %s prompt fits the box (%q is %d wide, box is %d)")
                :format(mode.label, footer.text, footer.w, geometry.LINE_W))
      -- the engine's own words survive whenever they can
      local ok, engineWidth = pcall(Font.width, flat)
      if ok and engineWidth <= geometry.LINE_W then
        T.eq(footer.text, flat,
             "the " .. mode.label .. " prompt is the engine's own, verbatim")
      else
        T.check(footer.text ~= "",
                "the " .. mode.label .. " prompt falls back to a line that fits")
      end
    end
  end
end

do
  -- A prompt the engine SHORTENS is printed as-is without this mod being
  -- touched: the fallback is keyed on width, not on the mode.
  local game = fakeGame(FULL)
  game.data.text = game.data.text or {}
  local restore = game.data.text._PartyMenuUseTMText
  game.data.text._PartyMenuUseTMText = "Teach who?"
  local menu = factory.new(game)
  menu.tmhm = { move = "FIX_CUT" }
  local drawn = recordDraw(menu)
  local footer
  for _, d in ipairs(drawn) do
    if d.y == geometry.FOOTER_TEXT_Y then footer = d end
  end
  game.data.text._PartyMenuUseTMText = restore
  T.check(footer and footer.text == "Teach who?",
          "a reworded prompt that fits is printed verbatim (got "
            .. tostring(footer and footer.text) .. ")")
end

do
  -- An empty party still draws, and says so.
  local game = fakeGame({})
  local menu = factory.new(game)
  local drawn = recordDraw(menu)
  local sawEmpty = false
  for _, d in ipairs(drawn) do
    if d.text:find("No POK") then sawEmpty = true end
  end
  T.check(sawEmpty, "an empty party says No POKéMON!")
end

do
  -- A medicine's fill animation draws the HP it has reached, and never
  -- mutates the real mon (#252).
  local party = { mon("FIXMON_A", 30, 10, 45) }
  local game = fakeGame(party)
  local menu = factory.new(game)
  menu.heal = { mon = party[1], from = 10, shown = 22.6 }
  local drawn = recordDraw(menu)
  local sawShown = false
  for _, d in ipairs(drawn) do
    if d.text:find("22") then sawShown = true end
  end
  T.check(sawShown, "the row shows the HP the fill has reached")
  T.eq(party[1].hp, 10, "and the real mon is untouched")
end

-- ------- SPECIES COLOURS off restores the vanilla answer exactly

do
  local game = fakeGame(FULL)
  local menu = factory.new(game)
  local vanilla = PartyMenu.new(fakeGame(FULL), {})

  local ours = menu:sgbPalettes(game)
  local theirs = PartyMenu.sgbPalettes(vanilla, game)
  -- with a palette pack absent both come back nil or short; what matters is
  -- that the option is wired and the fallback is vanilla's own method
  T.check(ours == nil or type(ours) == "table",
          "the screen always answers with a palette or nothing")
  T.check(theirs == nil or type(theirs) == "table",
          "and so does the vanilla one it falls back to")
end

-- ------- the START menu's row
--
-- The one thing this mod changes outside its own screen.  Asserted through
-- the engine's own hook bus rather than by reading main.lua: what matters is
-- that the list the engine hands over comes back with every row it built,
-- one of them relabelled.

do
  local Strings = require("src.core.Strings")
  local loader = run.loader
  T.check(type(loader) == "table" and type(loader.hooks) == "table",
          "the suite can reach the hook bus the mod wrapped")

  local function freshItems()
    return {
      { label = Strings("POKéDEX") },
      { label = Strings("POKéMON"), keepOpen = false },
      { label = Strings("ITEM") },
      { label = "RED" },                       -- the player's own name
    }
  end
  local function vanilla(_, list) return list end
  local function fire()
    return loader.hooks:call("ui.start_menu.items", vanilla, {}, freshItems())
  end

  local out = fire()
  T.eq(type(out), "table", "the hook hands back a list")
  T.eq(#out, 4, "with every row the engine built still on it")
  T.eq(out[1].label, Strings("POKéDEX"), "the dex row is untouched")
  T.eq(out[2].label, Strings("PARTY"), "the POKéMON row says PARTY")
  T.eq(out[3].label, Strings("ITEM"), "the item row is untouched")
  T.eq(out[4].label, "RED", "and so is the player's own name")
  T.check(out[2].keepOpen == false,
          "the row is relabelled in place, not rebuilt")

  -- off leaves the engine's own word alone
  local saved = loader.modOptions and loader.modOptions.Gen1Party
  if loader.modOptions then
    loader.modOptions.Gen1Party = { start_says_party = false }
    local off = fire()
    loader.modOptions.Gen1Party = saved
    T.eq(off[2].label, Strings("POKéMON"),
         "START: PARTY off restores the engine's word")
  end

  -- a list with no POKéMON row on it is handed back untouched
  local none = loader.hooks:call("ui.start_menu.items", vanilla, {},
                                 { { label = Strings("ITEM") } })
  T.eq(#none, 1, "a list without the row is passed through")
  T.eq(none[1].label, Strings("ITEM"), "with nothing renamed")
end

-- ------- a mod that cannot draw the party says so
--
-- Every load-time bail-out here used to log and return, which leaves an
-- ENABLED mod that changes nothing on screen -- the same thing a player sees
-- when they never installed it, and the reason this section exists.  main.lua
-- raises now, so the loader marks the row broken and shows the reason
-- (src/mods/Loader.lua _fail).  It is called directly with a stub `mod`
-- rather than through the loader: the contract under test is what the entry
-- chunk DOES on a bad read, and that is one function call away.

local entry = assert(loadfile(DIR .. "/main.lua"))()

local function stubMod(sources)
  local registered = {}
  return {
    path = DIR,
    exports = {},
    registered = registered,
    options = { define = function() end, get = function() return nil end },
    content = { screens = {
      register = function(_, id, value) registered[id] = value end,
    } },
    log = { info = function() end, warn = function() end,
            error = function() end },
    read = function(_, name)
      local override = sources and sources[name]
      if override ~= nil then
        if override == false then return nil, "nofile" end
        return override
      end
      local handle = io.open(DIR .. "/" .. name, "rb")
      if not handle then return nil, "nofile" end
      local body = handle:read("*a")
      handle:close()
      return body
    end,
  }
end

do
  local mod = stubMod()
  local ok, err = pcall(entry, mod)
  T.check(ok, "the entry chunk runs clean on a whole install (" ..
              tostring(err) .. ")")
  T.check(mod.registered.PartyMenu ~= nil, "and registers the party screen")
end

for _, case in ipairs({
  { name = "chrome.lua", sources = { ["chrome.lua"] = false },
    what = "a missing chrome.lua" },
  { name = "screen.lua", sources = { ["screen.lua"] = false },
    what = "a missing screen.lua" },
  { name = "screen.lua", sources = { ["screen.lua"] = "return function( end" },
    what = "a screen.lua that will not compile" },
  { name = "screen.lua", sources = { ["screen.lua"] = "error('boom')" },
    what = "a screen.lua that throws on load" },
  { name = "screen.lua", sources = { ["screen.lua"] = "return 42" },
    what = "a screen.lua that returns no factory" },
  { name = "screen.lua", sources = { ["screen.lua"] = "return function() end" },
    what = "a factory that builds no screen" },
}) do
  local mod = stubMod(case.sources)
  local ok, err = pcall(entry, mod)
  T.check(not ok, case.what .. " fails the load rather than loading quiet")
  T.check(mod.registered.PartyMenu == nil,
          "and leaves the party screen unregistered")
  T.check(ok or tostring(err):find(case.name, 1, true) ~= nil,
          "and names " .. case.name .. " in the reason (" .. tostring(err) ..
          ")")
end

T.finish("Gen1Party")
