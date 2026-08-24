# Changelog

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

- All seven modes print into the standard text box. Three of them used to print
  a bare line on the bottom row instead, so the footer was three shapes rather
  than one.

### Elsewhere

- SPECIES COLOURS in the mod manager, which restores the vanilla palette answer
  exactly when off.
- Only `draw` and `sgbPalettes` are replaced; the vanilla constructor builds the
  screen, so every mode, key and callback stays the engine's. The suite diffs
  the vanilla instance against this one and fails if any field went missing.
- A headless test suite (100 checks) and a CI workflow that runs it against a
  real Gen1Recomp checkout with no ROM.
