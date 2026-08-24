-- Gen1Party: the drawing kit.
--
-- Returns a factory: factory(mod) -> a table of helpers.  The same kit
-- Gen1Dex carries, trimmed to the parts this screen uses -- copied rather
-- than depended on, because a UI mod that refuses to load until you also
-- install a Pokédex mod is a worse trade than sixty lines of duplication.
-- Anything changed here should be changed there.
--
-- ------- everything here is shade 3
--
-- Which is {0,0,0} in the grey ramp and in all 151 species palettes alike, so
-- the chrome stays black under any zone and a species palette laid over a
-- POKeMON reaches the POKeMON and nothing else.  Shade 1 is the trap: MEWMON
-- paints it {239,156,107}, which is how a grey rule comes out orange.

return function(mod)
  local Font = require("src.render.Font")

  local C = {}

  C.BLACK = { 0, 0, 0 }

  -- The right margin every screen in the set keeps.  The vanilla party row
  -- has none -- its status column and its HP numbers both end on 160, the
  -- last pixel of the screen -- which is what makes an "FNT" look clipped
  -- rather than placed.
  C.LEFT, C.RIGHT = 8, 152

  function C.ink(shade)
    love.graphics.setColor(shade[1], shade[2], shade[3], 1)
  end

  function C.black() C.ink(C.BLACK) end

  function C.white() love.graphics.setColor(1, 1, 1, 1) end

  function C.option(key, fallback)
    local ok, value = pcall(function() return mod.options:get(key) end)
    if not ok or value == nil then return fallback end
    return value
  end

  function C.rule(x, y, w, h)
    love.graphics.rectangle("fill", x, y, w, h or 1)
  end

  -- Cut on a GLYPH boundary, not a byte one: Font.split hands back a span per
  -- glyph with its byte range, and NIDORAN's ♂/♀ is one glyph across several
  -- bytes, so a plain sub() can slice a character in half.
  function C.truncate(text, glyphs)
    local ok, spans = pcall(Font.split, text)
    if not ok or #spans <= glyphs then return text end
    return text:sub(1, spans[glyphs].to)
  end

  -- Right-align a string to a pixel column, and hand back where it starts so
  -- the caller can check what it is about to collide with.
  function C.rightAlign(text, endX)
    local ok, w = pcall(Font.width, text)
    return endX - (ok and w or 0)
  end

  function C.clear()
    C.white()
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    C.black()
  end

  return C
end
