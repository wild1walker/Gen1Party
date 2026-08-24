-- Gen1Party: the party menu, drawn like the rest of the set.
--
-- One registered screen replacement and nothing else.  Screens.resolve
-- prefers the screens registry over the builtin module (src/ui/Screens.lua),
-- so a mod-free boot is untouched and a factory that throws degrades to the
-- builtin -- which is why every entry point here is guarded rather than
-- trusted.  A party menu that fails to open is worse than a vanilla one, and
-- this screen is reached from the START menu, from a battle switch, from a
-- forced switch after a faint and from every item that targets a POKeMON.
--
-- The two sibling files are loaded rather than required because a mod cannot
-- put itself on package.path: mod:read hands back the file's source from
-- wherever the mod actually lives (an installed directory, or inside an
-- imported .zip), and load() names the chunk after that path so a syntax
-- error in screen.lua reports as screen.lua and not as a line in this file.

local function loadSibling(mod, name)
  local source, readErr = mod:read(name)
  if not source then
    mod.log:error("%s is missing (%s); reinstall the mod", name,
                  tostring(readErr or "unknown read error"))
    return nil
  end
  local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. name)
  if not chunk then
    mod.log:error("%s did not compile: %s", name, tostring(compileErr))
    return nil
  end
  local ok, value = pcall(chunk)
  if not ok then
    mod.log:error("%s failed to run: %s", name, tostring(value))
    return nil
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

  local C
  if type(makeChrome) == "function" then
    local ok, built = pcall(makeChrome, mod)
    if ok and type(built) == "table" then C = built end
  end
  if not C then
    mod.log:error("the drawing kit did not build; leaving the vanilla party")
    return
  end

  if type(makeScreen) ~= "function" then return end
  local ok, screen = pcall(makeScreen, mod, C)
  if not (ok and type(screen) == "table" and type(screen.new) == "function") then
    mod.log:error("the party screen did not build: %s", tostring(screen))
    return
  end

  mod.content.screens:register("PartyMenu", screen)
  mod.exports.geometry = screen.geometry

  mod.log:info("the party wears its own colours")
end
