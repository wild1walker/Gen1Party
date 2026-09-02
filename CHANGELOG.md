# Changelog

## 1.8.1

- **No inverted square behind the party sprites while the message box is up.**
  Picking the POKeMON you are already using puts a message box over the party
  list, and the icon underneath kept both its matte and its `trueColor` mark.
  A mark re-blits its region **raw** once the pass composes -- after the box
  was drawn over it -- so the icon came back on top of the box as a hard
  inverted block.

  An icon that the box covers now drops the matte and the mark together. They
  go as a pair on purpose: the mark without the matte would re-blit bare
  ground, which is the same bug pointed the other way.


## 1.8.0

Gen1WildUI carried this as an overlay while it was ahead of a release here; it
shipped in the bundle's 1.22.0. Same code, in the mod that owns it.

- The page under a full-colour icon is painted before the art goes in.
  `PaletteFX.markTrueColor` blits the rectangle raw so a coloured icon keeps
  its own colours instead of being read as four shades — and raw means raw, so
  the white page under it stayed white when everything around it went black.
  That was the white box behind every icon on a dark screen.

It asks `mod.theme` for the colour, and only a bundle installs one. **With no
theme provider this is inert**, so a standalone Gen1Party draws exactly as it
did — the change is here so the code lives with the feature rather than in a
bundle's overlay.

## 1.7.0

The status tint is removed, at the author's request. Icons are drawn as they
always were, and the palette zone under them is the species colours again.
Nothing else changed -- the source is byte-identical to what it was before the
tint went in.

## 1.6.0

The status tint now reaches **full-colour icon art**.

It rode a palette zone, and a palette zone only reaches art that goes through
the shade-remap pass -- which full-colour art sits out by design, since this
mod marks its rect trueColor precisely so the pass does not repaint it off its
red channel. So the tint coloured nothing at all for anyone running a
full-colour icon pack.

The icon is now drawn in the condition's colour instead: LÖVE multiplies an
image by the current colour, so white is the untouched icon and the tint shifts
its hue while keeping its own light and dark. That reaches both kinds of art.
The palette zone stays as well, for the species colours underneath.

The colour comes from `drawColour` in **STATUS COLOURS**
([Gen1WildQOL](https://github.com/wild1walker/Gen1WildQOL) 1.8.0), so the party,
the box and the world keep agreeing. Without that mod there is no tint, exactly
as before.

## 1.5.0

A POKéMON's icon wears its condition. Poisoned is purple, fainted is grey, and
the rest of the statuses have their own colour -- over the species colours the
icons already wear, so a poisoned CHARMANDER still reads as a CHARMANDER.

The colours are not defined here. They come from **STATUS COLOURS** in
[Gen1WildQOL](https://github.com/wild1walker/Gen1WildQOL) 1.6.0, which is the
mod that turns the overworld purple while you walk poisoned, and which owns one
table of what each condition looks like so the party, the box and the dex agree
instead of drifting apart. This asks it; without that mod installed there is no
tint and the zones are the species colours exactly as before.

It rides the same per-POKéMON zone this mod already builds, so it costs nothing
extra to draw and full-colour icon art still sits out the pass untouched.

## 1.4.0

The popup's `SWITCH` becomes `MOVE`, and moving a POKéMON is Gen1BillsBox's
answer rather than the engine's: the member is in your hand.

- **It flashes, and it travels.** A on the `MOVE` row lifts the member the
  cursor is on — sixteen frames lit and eight dark, the box's own blink to the
  frame — and UP and DOWN carry it through the list a row at a time, with the
  party reordered under it as it goes. A lets go; B walks it home.
- **The row says what it does.** `SWITCH` describes an exchange between two
  picks, and this is not one, so the row is relabelled `MOVE`. The *battle*
  popup's `SWITCH` is left alone: that one means *send this one out*, a
  different verb wearing the same six letters.
- **A run of steps is an insertion, not an exchange.** Carry the fourth member
  to the top and the three it passed keep the order they already had. Vanilla's
  swap would have traded the first and the fourth and left the two between them
  alone.
- **The array is reordered on every step, not at the end.** Party order *is*
  battle order — `party[1]` is who you send out — so a list drawn in one order
  over an array stored in another has a lead POKéMON nobody on screen can see.
  There is no such window here, and nothing left to commit when you let go.
- **B is back, not out.** It walks the member home rather than closing the
  menu, and since every step leaves the others in their own order, home is the
  party exactly as it was. There is no way to leave the screen holding one.
- Yellow's sleeping starter Pikachu still will not be moved. The engine refuses
  the A press on either end of its swap, which a carry never presses, so the
  same question is asked of every row a step would displace — otherwise the one
  rule the engine has about moving a POKéMON is walked around by moving the one
  beside it.
- New option `MOVE NOT SWITCH`, default on — off restores the engine's two
  picks and one exchange exactly, hollow arrow and all.
- This is the first release that changes what the party menu *does*. `update`
  is replaced as a **wrapper**: it hands every frame to the engine's own update
  and keeps only the ones with a POKéMON in hand, so every other key, mode and
  callback is still the engine's.
- Suite is 308 checks, up from 222 — the carry driven a press at a time through
  the real update, asserting the reorder, the insertion, the wrap, B's restore,
  the refusal, the flash's lit and dark stretches, and the option's off state
  running the engine's swap.

## 1.3.0

The icon column is ruled off from the names, the way the dex list's is.

- **The icons were touching the names.** Not nearly — *touching*. The name
  column starts at 24, which is the pixel after the icon cell ends, so art
  that fills its 16 pixels leaves zero air before the first letter. Measured
  on a real party: three of five icons at 0px, the other two at 2px. Gen1Dex
  keeps 3px to its rule and 5px more to its text.
- **Now: a hairline at x=26 down the whole body, names at 32.** The same
  column and the same rule the dex list draws, so the two screens line up.
- **It costs the tenth name glyph.** Ten glyphs need every pixel from 24 to
  the level column at 104, so the air can only come from there: `CHARMANDER`
  reads `CHARMANDE`. That is roughly fourteen species and any ten-character
  nickname. New option `RULED ICONS`, default on — off restores the
  full-width name column, and the icons touch again.
- Cuts land on a glyph boundary, never a byte one: a nickname can carry
  NIDORAN's ♂/♀, which is one glyph across several bytes.
- Unchanged, and worth knowing: a name that *fills* its column still ends 2px
  from the level, because a full column is a full column. Vanilla did exactly
  the same with a ten-glyph name in a ten-glyph column.
- Suite is 222 checks, up from 211 — the rule's column and its span asserted
  against the body, the cut asserted as `CHARMANDE`, and the option's off
  state asserted to give the tenth glyph back and take the rule with it.

## 1.2.0

Names the screen, in both places you meet it.

- **The header says `POKéMON PARTY`.** Thirteen glyphs against a box that
  holds eighteen, so it sits well inside the margin.
- **The START menu's row says `PARTY`.** POKéMON is the word the cart uses and
  also most of the word on the row above it; PARTY names the screen it opens.
  New option `START: PARTY`, default on -- off leaves the engine's own word
  alone.
- Done through `ui.start_menu.items`, the engine's own seam for this
  (`src/ui/StartMenu.lua`), rather than by replacing `StartMenu` -- a screen
  with seven submenus and a save-confirmation flow this mod has no opinion
  about. `next()` runs first and its list is decorated, so another mod's row
  survives and no vanilla row is rebuilt by hand.
- The row is found by the string the engine built it from, not by position:
  `Strings` keys on its English source, so `Strings("POKéMON")` here is the
  same value `StartMenu`'s own call produced under every translation. A row
  this does not find is left exactly as it was.
- No hook bus to wrap warns rather than raises. Unlike a screen that will not
  build, losing this does not leave an enabled mod doing nothing.
- Suite is 211 checks, up from 198.

## 1.1.0

The party menu gets the set's frame. A header box on rows 0-2, the six
members in the 96-pixel body between, a footer box on rows 15-17 -- the same
shape Gen1Dex draws, in the same places.

- **The body is exactly six party rows.** 96 pixels, six rows of sixteen, to
  the last pixel. The slots were never what stood in the way.
- **The footer was.** Three tile rows hold one line of text, and four of the
  five prompts the engine hands back are two lines. Three of header plus five
  of footer plus twelve of party is twenty rows against the eighteen a Game
  Boy has, so two had to come from somewhere, and they came from the words:
  every prompt now prints on one line.
- **The engine still owns the words wherever they fit.** `bottomMessage()` is
  flattened onto one line and printed verbatim when it is no wider than the
  box -- `"Choose a POKéMON."` is seventeen glyphs against a box that holds
  eighteen, so the field menu says exactly what the engine says, and a reword
  or a translation that SHORTENS a prompt is picked up with nothing here
  touched. Only a prompt too wide falls back to this mod's own line, and only
  for that mode.
- The four that fall back: `Move it where?`, `Use TM on which?`,
  `Use item on which?`, `Bring out which?`.
- Every palette zone moved down with its row. An icon zone left at the old
  offset would have painted the member above it, and slot 1's would have
  landed on the header box.
- Suite is 198 checks, up from 129. The frame is asserted as boxes and pixel
  rows -- six rows of sixteen filling the body to `BODY_BOTTOM` exactly,
  nothing drawn on a box border, one footer line per mode and never wider
  than the box.

### Still not here

- **The ruled icon column** the dex list draws. It needs the names to start at
  32 and they start at 24, and the eight pixels can only come out of a column
  holding a nickname.
- **A gap between the level and the status.** Right-aligning `FNT` on 152
  puts it at 128, where the level ends -- that 8-pixel gap is what the right
  margin was bought with. Unchanged since 1.0.0; the frame only makes it
  easier to notice.

## 1.0.2

Makes a mod that cannot draw the party say so. No change to what the screen
draws when it does.

- **A load-time failure was swallowed.** Every bail-out in `main.lua` -- a
  sibling file that would not read, would not compile, would not run, or
  handed back something that was not a factory -- logged to a file nobody
  opens and then returned as if all was well. What that left on screen was an
  *enabled* mod drawing nothing of its own, which is indistinguishable from a
  mod that was never installed. One of those paths logged nothing at all.
  They all raise now, so the loader marks the row enabled-but-broken in MODS
  and shows the reason (`src/mods/Loader.lua` `_fail`).
- This is only about the boot. A screen factory that throws when the party is
  *pushed* still degrades to the vanilla menu, because the engine already
  pcalls a mod-owned `new` and falls back (`src/ui/Screens.lua` `build`) --
  nothing here had to, and nothing here does.
- `mod.path` is no longer concatenated blind into the chunk name. It is
  decoration on an error message, and a host that hands back none would have
  failed on the string with nothing to say.
- Suite is 129 checks, up from 109. The six bail-outs are asserted against
  directly -- each one has to fail the load, leave `PartyMenu` unregistered,
  and name the file at fault.

## 1.0.1

Fixes the test suite against a current Gen1Recomp, and corrects a claim in the
docs. No change to what the screen draws.

- **CI was red on 1.0.0.** The suite spelled out the swap prompt ("Move to
  where?"), and the engine had reworded it to "Move POKeMON where?" and routed
  it through data.text (#1610). The suite now takes every prompt from
  bottomMessage() and asserts only WHERE the lines land -- the words belong to
  the engine, the layout is this mod's. Three more modes are covered the same
  way, so the next reword cannot break the build.
- The "one footer, not three" line in the README, CHANGELOG and mod.card
  claimed as a difference something the engine itself now does: #1610 unified
  the bare bottom-row prompts into the text box at about the same time this was
  written. The mod still does it, so it behaves the same on either engine, but
  it is no longer a difference from a current build and no longer described as
  one.
- Suite is 110 checks, up from 100, and now runs against the engine commit CI
  actually checks out.

## 1.0.0

First release.

### The icons

- **Every POKeMON in its own species colours.** Vanilla lays one MEWMON zone
  over tiles (1,0)-(2,11) -- the whole icon column, all six members at once --
  so the whole party wears the same salmon. That single zone is replaced with
  one per member, tile-addressed to each slot's own two rows.
- The base palette becomes the plain grey ramp rather than GREENBAR, so
  everything the screen draws itself reads as black line art.
- An icon mod's authored full-colour art is detected per mon (so a shiny tells
  itself apart from an ordinary one of its species), marked true-colour, and
  left alone -- a species palette under it would be paint nobody ever sees, and
  the shade remap would destroy it.

### The margins

- **Nothing is drawn past x=152 any more.** The vanilla row is packed to the
  last pixel of the screen: the status column runs 136-160 and the HP numbers
  104-160, which is why an FNT reads as clipped rather than placed.
- The status moved from a fixed x=136 to right-aligned on 152. Free: the level
  always ends at 128, so 128-136 was already empty.
- The HP bar moved one tile left, from tile 5 to tile 4, and the numbers
  right-align on 152. The bar keeps all six segments -- it is the at-a-glance
  read on this screen -- and the gap it moved into was unused.
- The numbers keep their "%3d/%3d" padding rather than becoming variable width:
  the bar's right cap sits under the first glyph, and a SPACE over that cap is
  what stops the two colliding.
- The TM/HM and evolution-stone verdicts (ABLE / NOT ABLE) right-align on 152
  too, instead of trailing off 160.

### The footer

- All seven modes print into the standard text box, so the footer is one shape
  rather than three. On an engine from before #1610 that is a change (three
  modes printed a bare bottom-row line); on a current one it matches what the
  engine now does, and is kept so the mod behaves the same on either.

### Elsewhere

- SPECIES COLOURS in the mod manager, which restores the vanilla palette answer
  exactly when off.
- Only `draw` and `sgbPalettes` are replaced; the vanilla constructor builds the
  screen, so every mode, key and callback stays the engine's. The suite diffs
  the vanilla instance against this one and fails if any field went missing.
- A headless test suite (100 checks) and a CI workflow that runs it against a
  real Gen1Recomp checkout with no ROM.
