-- Gen1Party: the party menu, drawn like the rest of the set.
--
-- One registered screen replacement and nothing else.  Screens.resolve
-- prefers the screens registry over the builtin module (src/ui/Screens.lua),
-- so a mod-free boot is untouched, and a factory that throws when the screen
-- is PUSHED degrades to the builtin -- Screens.build already pcalls a
-- mod-owned `new` and falls back, which is why nothing here has to.
--
-- What this file does not do is swallow a LOAD-time failure.  Nothing is at
-- risk while the game boots: if the screen cannot be built the party menu
-- stays vanilla either way, and the only question left is whether the player
-- is told.  A mod.log:error goes to a log file nobody opens, and what is left
-- on screen is an enabled mod that changes nothing -- indistinguishable from
-- one that was never installed, which is exactly the bug report it produces.
-- Raising instead puts the reason on the loader's boot error feed and marks
-- the row enabled-but-broken in MODS (src/mods/Loader.lua _fail), which is
-- where a player looks.
--
-- The two sibling files are loaded rather than required because a mod cannot
-- put itself on package.path: mod:read hands back the file's source from
-- wherever the mod actually lives (an installed directory, or inside an
-- imported .zip), and load() names the chunk after that path so a syntax
-- error in screen.lua reports as screen.lua and not as a line in this file.

local function loadSibling(mod, name)
  local source, readErr = mod:read(name)
  if not source then
    error(("%s is missing (%s); reinstall the mod")
      :format(name, tostring(readErr or "unknown read error")), 0)
  end
  -- mod.path is the install directory, and it is decoration on the chunk name
  -- rather than something to concatenate blind: a host that does not hand one
  -- over would otherwise fail here, on the string, with nothing to say.
  local chunkName = "@" .. (mod.path and (mod.path .. "/") or "") .. name
  local chunk, compileErr = load(source, chunkName)
  if not chunk then
    error(("%s did not compile: %s"):format(name, tostring(compileErr)), 0)
  end
  local ok, value = pcall(chunk)
  if not ok then
    error(("%s failed to run: %s"):format(name, tostring(value)), 0)
  end
  if type(value) ~= "function" then
    error(("%s did not return a factory (got %s)"):format(name, type(value)), 0)
  end
  return value
end

return function(mod)
  mod.options:define({
    -- Every POKeMON in the party in its own species colours, over the plain
    -- grey ramp.  Off restores the vanilla answer exactly -- the GREENBAR
    -- base and the single MEWMON zone laid over all six icons at once -- for
    -- anyone who wants the 1996 screen with nothing changed but the margins.
    { key = "species_colours", type = "toggle", label = "SPECIES COLOURS",
      default = true },
  })

  local makeChrome = loadSibling(mod, "chrome.lua")
  local makeScreen = loadSibling(mod, "screen.lua")

  local C = makeChrome(mod)
  if type(C) ~= "table" then
    error(("chrome.lua did not build the drawing kit (got %s)"):format(type(C)),
          0)
  end

  local screen = makeScreen(mod, C)
  if not (type(screen) == "table" and type(screen.new) == "function") then
    error("screen.lua did not build the party screen", 0)
  end

  mod.content.screens:register("PartyMenu", screen)
  mod.exports.geometry = screen.geometry

  mod.log:info("the party wears its own colours")
end
