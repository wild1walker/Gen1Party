<p align="center">
  <a href="https://wild1walker.github.io/Gen1Wild/"><img src="docs/banner.png" alt="Gen1Wild" width="400"></a>
</p>

<h1 align="center">Gen1Party</h1>

<p align="center">
  <a href="https://wild1walker.github.io/Gen1Wild/"><img src="docs/lineup.png" alt="Check out my other mods!" width="880"></a>
</p>

The party menu, drawn like the rest of the set.

A mod for [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp).

---

## What it does

### The set's frame

A header box on rows 0–2 titled **`POKéMON PARTY`**, the six party members in
the 96-pixel body between, a footer box on rows 15–17 — the same shape Gen1Dex
draws, in the same places. A party opened next to the Pokédex stops looking
like a different game.

That body is **exactly** six rows of sixteen pixels, to the last pixel, so no
slot was given up for it. The footer paid instead: three tile rows hold one
line of text, and four of the five prompts the engine hands back are two.
Three rows of header plus five of footer plus twelve of party is twenty
against the eighteen a Game Boy has.

So every prompt prints on one line — and the engine keeps the words wherever
the engine's words fit. `bottomMessage()` is flattened onto one line and
printed verbatim when it is no wider than the box; `Choose a POKéMON.` is
seventeen glyphs against a box that holds eighteen, so the field menu says
exactly what the engine says, and a reword or a translation that *shortens* a
prompt is picked up with nothing in this mod touched. Only a prompt too wide
falls back to this mod's own line:

| Mode | Engine | Here |
| --- | --- | --- |
| Field | `Choose a POKéMON.` | unchanged |
| Swap | `Move POKéMON\nwhere?` | `Move it where?` |
| TM/HM | `Use TM on which\nPOKéMON?` | `Use TM on which?` |
| Item | `Use item on which\nPOKéMON?` | `Use item on which?` |
| Battle | `Bring out which\nPOKéMON?` | `Bring out which?` |

### `SWITCH` is `MOVE`, and the POKéMON travels

The engine's `SWITCH` is two picks over a list that never moves: press A on
one member, press A on a second, and the two change places. Between the two
presses the only sign of what you are doing is a hollow arrow beside a row you
have already left.

Gen1BillsBox answers the same question by putting the POKéMON in your **hand**.
This is that answer, on the party list:

| Key | What it does |
| --- | --- |
| **A**, on the popup's `MOVE` row | Lifts the member the cursor is on. It **flashes** — sixteen frames lit, eight dark, the box's own blink to the frame. |
| **UP** / **DOWN** | Carries it, a row at a time. The list reorders under it as it goes. |
| **A** | Lets go. |
| **B** | Walks it home, and leaves the party exactly as it was. |

The popup row says `MOVE` because `MOVE` is what it now does — `SWITCH`
describes an exchange, and this is not one. A run of steps is an
**insertion**: carry the fourth member to the top and the three it passed keep
the order they already had, where the vanilla swap would have traded the first
and the fourth and left the two between them alone.

The party array is reordered on **every step**, not once at the end. That is
the load-bearing part, and it is the same rule Gen1BillsBox's party pane
keeps: party order *is* battle order — `party[1]` is who you send out — so a
list drawn in one order over an array stored in another has a lead POKéMON
nobody on screen can see. There is no such window here. It is also why letting
go costs nothing: there is nothing left to commit.

`B` is *back* rather than *out*, again as it is in the box: it walks the
member home instead of closing the menu, and because every step leaves the
other members in their own order, putting this one back in the row it started
in restores the party exactly, however far it travelled. There is no way to
leave this screen holding a POKéMON.

Two things are deliberately kept from the engine. The footer still prints the
engine's own swap prompt, because the engine's `swapFrom` is still what says a
member is in the air — so a reworded or translated prompt is still the one you
read. And the battle popup's `SWITCH` is left saying `SWITCH`: that one means
*send this one out*, which is a different verb wearing the same six letters.

`MOVE NOT SWITCH` turns the whole thing off and gives the engine's two-pick
swap back.

### The icon column is ruled off

A hairline at x=26 down the whole body with the names at 32 — the same column
and the same rule Gen1Dex draws, so the two screens line up. Without it the
names start at 24, the pixel after the icon cell ends, and art that fills its
cell touches the first letter.

### The START menu says PARTY

`POKéMON` is the word the cart uses for that row, and it is also most of the
word on the row above it. `PARTY` names the screen it opens.

Done through `ui.start_menu.items` — the engine's own seam for this — rather
than by replacing `StartMenu`, which is seven submenus and a save-confirmation
flow this mod has no opinion about. The row is found by the string the engine
built it from, so it works under any translation, and a list this mod does not
recognise is handed back untouched.

### Every POKéMON in its own colours

Vanilla lays **one** `MEWMON` palette zone over tiles (1,0)–(2,11) — the whole
icon column, all six members at once — so every POKéMON in your party wears the
same salmon.

This replaces that single zone with **one per member**, so each wears its own
species colours: the same thing the Pokédex list does for its rows and
Gen1BillsBox does for its grid. A party opened next to either of them stops
looking like a different game.

The base palette becomes the plain grey ramp too, so the names, numbers and
boxes read as black line art rather than sitting under a bar palette standing
in for a screen palette.

### Nothing runs off the edge

The vanilla row is packed to the last pixel of the screen: the status column
runs 136–160 and the HP numbers 104–160. That is authentic, and it is why an
`FNT` reads as clipped rather than placed.

Both now stop at **152**, the same right margin every other screen in the set
keeps. Measured, not asserted — the suite records what the screen actually
draws and fails if anything reaches past it.

Nothing was given up to pay for it:

- **The status** moves from a fixed `x=136` to right-aligned on 152. Free —
  the level always ends at 128 (`PrintLevel` overwrites the `<LV>` tile with
  the third digit at L100, so two digits and three end in the same place),
  which leaves 128–136 already empty.
- **The HP bar** moves one tile left, from tile 5 to tile 4, and the numbers
  right-align on 152. The bar keeps **all six segments** — it is the
  at-a-glance read on this screen, and shortening it to buy the margin would
  have been the wrong trade. The gap it moves into is the one between the icon
  and the bar, which nothing was using.
- **The numbers** keep their `%3d/%3d` padding rather than becoming variable
  width, because that padding is load-bearing: the bar's right cap sits under
  the first glyph, and a *space* over that cap is what stops the two colliding.

### One footer

Every mode prints into the standard text box — the same `Font.drawBox` chrome
the rest of the set frames with.

This is **not** a difference from current Gen1Recomp. When this screen was
written, three of the seven modes printed a bare line on the bottom row while
the other four used the box, and unifying them was a change. The engine landed
the same unification in [#1610](https://github.com/bryanthaboi/gen1recomp) at
about the same time, so on a current build this mod simply matches it. It is
kept here so the mod behaves the same on either engine.

---

## Options

| Option | Default | What it does |
| --- | --- | --- |
| `SPECIES COLOURS` | ON | Every member in its own species colours over the grey ramp. Off restores the vanilla answer exactly — the `GREENBAR` base and the single `MEWMON` column — for anyone who wants the 1996 screen with nothing changed but the margins. |
| `START: PARTY` | ON | The START menu's row for this screen says `PARTY` rather than `POKéMON`. Off leaves the engine's own word alone. |
| `RULED ICONS` | ON | A hairline between the icons and the names, the one the dex list draws, with the names moved off the icon cell to make room. Costs the tenth name glyph — `CHARMANDER` reads `CHARMANDE`. Off restores the full-width column, and the icons touch the names again. |
| `MOVE NOT SWITCH` | ON | The popup row says `MOVE`, and A lifts that member: it flashes, UP and DOWN carry it through the list, and the party is reordered under it as it goes. Off restores the engine's own `SWITCH` — two picks over a list that does not move, and one exchange when the second lands. |

---

## Install

Download `Gen1Party-<version>.zip` from
[Releases](https://github.com/wild1walker/Gen1Party/releases) and install it
from the game: **MODS → Import mod .zip**.

---

## Installed, and nothing changed

This mod replaces how the party menu is **drawn** and nothing else, so there
are a few ways for a working install to read as no install at all.

**The popup says `MOVE`.** From 1.4.0, A over a member opens a popup whose
bottom row says `MOVE` rather than `SWITCH`, and pressing it picks the POKéMON
up. If it says `SWITCH`, either this mod is not drawing or `MOVE NOT SWITCH` is
off.

**Check for the boxes, not the icons.** From 1.1.0 the answer is obvious at a
glance: a header box across the top saying `POKéMON` and a boxed footer across
the bottom, with the party in the band between. If the list starts at the very
top of the screen, this mod is not drawing. (On 1.0.x the only tell was the
right margin — an `FNT` ending at 152 with a clear tile of white after it,
rather than running to 160.)

**The icons may already have been colourful.** If you run an icon mod whose
art carries colour a grey ramp cannot, every POKéMON in the party looks
different from its neighbours whether or not this mod is loaded: that art is
re-blit unshaded over the colourised pass, so it sits out this mod's palette
work by design. Per-species colour is only visible on the built-in icons.

**`SPECIES COLOURS` off is supposed to look vanilla.** It restores the
GREENBAR base and the single MEWMON column exactly. The margins still move.

**Otherwise, look at the mod's row in MODS.** From 1.0.2 a mod that cannot
build its screen fails the load and the row says why. Up to 1.0.1 those
failures were logged to a file and swallowed, which left the mod enabled and
drawing nothing of its own — so on 1.0.1 or earlier, a silent row is not
proof that it loaded.

---

## How it works

One registered screen replacement — it replaces **three methods**, `draw`,
`sgbPalettes` and `update` — plus one relabelled row on the START menu, through
the engine's own hook. Everything else is the engine's.

That restraint is the whole design. `PartyMenu` is not one screen but seven
behind a single id — the field menu, the battle switch, the forced switch after
a faint, the item target, the TM/HM teach list with its `ABLE` / `NOT ABLE`
column, the `SOFTBOILED` donor, and the evolution-stone list. Each has its own
input rules, its own bottom message and its own idea of what A does. This mod
has an opinion about how the party *looks*, and exactly one verb's worth of
opinion about what it does, so the vanilla constructor builds the screen and
everything else is left where it was.

`update` is a **wrapper**, not a rewrite: it hands the frame to the engine's
own update, which reads every key on this screen — including the A that opens
the popup and the A that picks a row on it. The only frames it keeps for itself
are the ones with a POKéMON in your hand, which is a state the engine has no
rules about because vanilla never had one. When the engine's `SWITCH` sets
`swapFrom` and settles in to wait for a second pick, the wrapper takes the
member out of the list's hands and into the player's instead, and the engine's
own swap branch is simply never reached.

The suite checks that directly: it diffs every field the vanilla constructor
sets against the one this mod hands back, and fails if any of them went missing.

### What the header box cost

Nothing on this screen is free. The set's frame spends 3 tile rows at the top
and 3 at the bottom, and 3 + 3 + 12 is exactly 18 — so all six members fit,
and the bill lands on the footer, which drops from two lines to one.

The alternative was a 5-row footer keeping both lines, which leaves 80 pixels
of body: five visible slots and a scroll, on a screen whose whole job is
showing you the party at once. The words were the cheaper thing to spend.

### The ruled icon column, and what it cost

The same eight pixels, twice over. The Pokédex list rules a hairline between
its icons and its rows; that rule needs the names off the icon cell, and ten
glyphs of name need every pixel from 24 to the level column at 104 — so the
tenth glyph is what buys it.

This was left undone for two versions on the grounds that a nickname is the
player's own text. What settled it was measuring a real party: the name column
starts at 24, which is the pixel *after* the icon cell ends, so art that fills
its sixteen pixels sits flush against the first letter with **zero** air. Three
of five icons, at 0px. That costs more than the tenth glyph does.

A name that fills its column still ends 2px from the level — a full column is
a full column, and vanilla did the same with ten glyphs in a ten-glyph column.

### Full-colour icons sit out the palette pass

An icon mod's authored art is re-blit *unshaded* over the colourised pass, so a
species palette under it is paint nobody ever sees — and running it through the
shade remap instead would destroy it, because that remap keys off the **red**
channel and an orange pixel lands on the palette's white. Those icons are
detected per *mon* (not per species, so a shiny tells itself apart), marked
true-colour, and left exactly as their author drew them.

---

## Testing

The suite runs headlessly against a Gen1Recomp checkout, with no ROM.

```sh
# from a Gen1Recomp checkout, with this mod at mods/Gen1Party
luajit mods/Gen1Party/tests/gen1party_test.lua
```

`GEN1PARTY_DIR` overrides where the mod is read from. CI runs the same command
on every push and pull request.

## Releasing

Push to `main` and `.github/workflows/release.yml` packs the mod into an
installable `.zip` and publishes it as a GitHub Release, once per push. The
version is the first rule that applies: a manual **Run workflow** input,
`[release X.Y.Z]` in the commit message, `manifest.json`'s own version when it
is ahead of every tag, otherwise a patch bump. The job refuses to clobber an
existing tag.

## Credits

By **Wild**.

Built on the party-screen and palette seams of [Pokemon Gen1Recomp](https://github.com/bryanthaboi/gen1recomp), and on the [pret](https://github.com/pret)
disassembly of Pokemon Red, Blue and Yellow: `engine/menus/party_menu.asm` is
the screen this mod re-dresses, and its `.teachMoveMenu` path is why some rows
have no HP bar to colour.

## Licence

MIT — see [LICENSE](LICENSE).
