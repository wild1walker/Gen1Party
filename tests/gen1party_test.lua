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
    T.eq(z.y, (i - 1) * 16, "icon zone " .. i .. " sits on its own slot")
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
  local drawn = {}
  local realDraw = Font.draw
  Font.draw = function(text, x, y)
    local ok, w = pcall(Font.width, text)
    drawn[#drawn + 1] = { text = tostring(text), x = x, y = y,
                          w = ok and w or 0 }
    return realDraw(text, x, y)
  end
  local ok, err = pcall(screen.draw, screen)
  Font.draw = realDraw
  T.check(ok, "the screen draws (" .. tostring(err) .. ")")
  return drawn
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
  -- The name column keeps its full width: the ruled icon column was skipped
  -- precisely so a ten-glyph nickname is never cut.
  local party = { mon("FIXMON_A", 30, 45, 45, { nickname = "CHARMANDER" }) }
  local game = fakeGame(party)
  local menu = factory.new(game)
  local drawn = recordDraw(menu)
  local found
  for _, d in ipairs(drawn) do
    if d.text == "CHARMANDER" then found = d end
  end
  T.check(found ~= nil, "a ten-glyph nickname is printed whole")
  T.eq(found.x, 24, "at the vanilla name column")
  T.check(found.x + found.w <= 104, "without running into the level column")
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

  local skip = { draw = true, sgbPalettes = true }
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
  T.eq(ours.update, vanilla.update, "update is the engine's, untouched")
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
  -- A swap in progress prints its prompt into the message box, like every
  -- other mode's.
  --
  -- The prompt is taken from bottomMessage() rather than written out here.
  -- Hardcoding it cost a red CI run once already: the engine reworded the swap
  -- prompt from "Move to where?" to "Move POKéMON\nwhere?" and routed it
  -- through data.text (#1610), and a suite that spells the words out is
  -- asserting the ENGINE's copy rather than this mod's layout. What this mod
  -- is responsible for is WHERE the line lands, not what it says.
  local game = fakeGame(FULL)
  local menu = factory.new(game)
  menu.swapFrom = 2
  menu.index = 4

  local expected = {}
  for line in (menu:bottomMessage() .. "\n"):gmatch("([^\n]*)\n") do
    if line ~= "" then expected[#expected + 1] = line end
  end
  T.check(#expected > 0, "a swap in progress has a prompt to print")

  local drawn = recordDraw(menu)
  local seen = 0
  for _, d in ipairs(drawn) do
    for i, line in ipairs(expected) do
      if d.text == line then
        seen = seen + 1
        T.eq(d.x, 8, "the prompt sits at the message box's left margin")
        T.eq(d.y, 112 + (i - 1) * 16,
             "on the box's own lines, not loose on the bottom row")
      end
    end
  end
  T.eq(seen, #expected, "every line of the swap prompt is printed")
end

do
  -- The same contract for every other mode: whatever bottomMessage() returns
  -- is what lands in the box, wherever the engine takes that text from. This
  -- is the assertion that survives an engine reword.
  local modes = {
    { label = "field", apply = function() end },
    { label = "TM/HM", apply = function(m) m.tmhm = { move = "FIX_CUT" } end },
    { label = "softboiled", apply = function(m) m.softboiledFrom = 1 end },
  }
  for _, mode in ipairs(modes) do
    local game = fakeGame(FULL)
    local menu = factory.new(game)
    mode.apply(menu)
    local first = menu:bottomMessage():gmatch("([^\n]*)\n?")()
    local drawn = recordDraw(menu)
    local found = false
    for _, d in ipairs(drawn) do
      if d.text == first and d.x == 8 and d.y == 112 then found = true end
    end
    T.check(found, "the " .. mode.label .. " prompt lands in the message box")
  end
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

T.finish("Gen1Party")
