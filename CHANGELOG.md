# Changelog

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
