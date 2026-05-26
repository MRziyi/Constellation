# Constellation · 星座 — brand assets

> **Constellation · 星座** · *A constellation of senses, one mind.* / 「万象皆星，一念至此」
> by Zack 紫意 · companion to Halo Ring

## Name

| | Value |
|---|---|
| English | **Constellation** |
| 中文 | **星座** |
| Slogan (en) | **A constellation of senses, one mind.** |
| Slogan (zh) | 「万象皆星，一念至此」 |
| Author byline | by Zack 紫意 |
| Package ID (glass client) | `com.constellation.glass` |
| Open-source repo (planned) | `constellation` |

## Palette (inherited from Halo Ring — same glasses, same brand family)

| Token | Hex | Use |
|---|---|---|
| `c_black` | `#000000` | Background — every surface |
| `c_accent` | `#5EE08C` | The one and only chrome color — same green as the ring's LED |
| `c_accent_bright` | `#B8FFD4` | Light variant — used only as the brand-mark star cores |
| `c_accent_dim` | `#2A5A36` | Disabled / mute-accent state |
| `c_fg` | `#FFFFFF` | Primary text |
| `c_mute` | `#8A8A8A` | Secondary text |
| `c_warn` | `#FFB84D` | Yellow indicator |
| `c_bad` | `#FF7C7C` | Red indicator |
| `c_line` | `#2A2A2A` | Dividers / card borders |
| `c_focus_tint` | `#125EE08C` (7 % accent) | Tint over rows under focus |

**No other color** may ship in user-visible chrome. Per [DESIGN.md §2](../../docs/constitution/DESIGN.md) and
[UI-UX.md §2](../../docs/glass/UI-UX.md): one green, no exceptions. The Constellation mark and Halo Ring's
mark share `c_accent` so the wearer sees them as siblings, not strangers — single brand language
across both apps on the same glasses.

## Type

System sans-serif (Roboto on Android). 16 sp floor for all chrome (RayNeo design-guide alignment,
inherited from Halo Ring). HUD card body uses 15 sp because the overlay panel has its own spatial
discipline. Full type tokens in
[`Doc/ui-mockup.html §1`](../ui-mockup.html) (type-scale section) and will mirror
`HaloRingTheme.kt` when ported.

## Icon files

| Path | What | Notes |
|---|---|---|
| [`v1-constellation.svg`](v1-constellation.svg) | **Master design** at 1024 × 1024 | Eight stars in an irregular asterism (real constellations are irregular, and that irregularity is what reads as "constellation" rather than "logo geometry"), connected by faint heavy lines. 9× scale-up from the small inline mark in [`Doc/ui-mockup.html`](../ui-mockup.html), with thicker lines (stroke-width 20 vs an equivalent ~10 in the mockup) so the constellation reads at any size. Brightest star is the near-centre one (the mind); the other seven are senses reaching out in unequal directions. |
| (future) `app/src/main/res/drawable/ic_launcher_foreground.xml` | Android adaptive icon foreground | VectorDrawable port of v1 at 75 % scale with boosted halo alpha — same convention as Halo Ring |
| (future) `app/src/main/res/drawable/ic_notification.xml` | Monochrome status-bar icon | Single white star-cluster on transparent; Android tints automatically |
| (future) `app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` | Adaptive-icon descriptor | `background = c_black`, `foreground = v1 port`, `monochrome` for Android 13+ themed icons |

## Design principles (carry forward from Halo Ring + Constellation-specific)

1. **Pure black canvas, single green accent.** Same as Halo Ring. Any temptation to add a
   secondary color = visual noise on a small AR display.
2. **OLED-first.** Black pixels are off. Don't paint backgrounds you don't need.
3. **Glow is the design language.** Every star sits inside a radial halo (no bare circles).
   This is shared with Halo Ring's "the green ring is always rendered with at least one radial
   halo behind it".
4. **No text in the icon, no text in the brand mark.** "Constellation" / "星座" is set in
   system type in the About panel, never baked into an image.
5. **Asymmetric on purpose.** Unlike Halo Ring's strict 120° rotational symmetry, the
   constellation is irregular — that's how it reads as "a sky pattern" not "a corporate
   logo". The stars don't follow any rational geometry.
6. **Hierarchy via star size + halo.** The brightest star is the near-centre one (visual
   anchor); seven others vary in size and halo intensity. The eye lands on the centre
   first, then traces the connecting lines outward.

## Why "stars + lines" instead of "arcs" (vs Halo Ring v10a)

Halo Ring's mark = **three swept blade-arcs at 12/4/8**, strict rotational symmetry. Reads as
*motion* — the ring sweeps input gestures into the glasses.

Constellation's mark = **eight stars in an irregular asterism, bound by faint heavy lines**.
Reads as *coherence* — many sensing points held together as one pattern.

The two marks at small sizes:
- **Halo Ring** silhouette: three rotational blades → reads as a ring.
- **Constellation** silhouette: scattered dots connected by lines → reads as a star pattern.

Both share the same color palette, the same atmospheric halo + rim glow backdrop, the same
mint-bright bright-head treatment — the wearer recognises them as a brand family. Different
*shape language* (symmetric arcs vs irregular asterism), same *visual family*.

## When to edit the icon

Major palette / geometry changes: edit `v1-constellation.svg` first (the master), preview in a
browser, then port to the VectorDrawable when implementation begins. The SVG → VectorDrawable
conversion math (same as Halo Ring's):

| SVG (1024 viewport) | VectorDrawable (108 dp viewport) |
|---|---|
| coordinate × 0.10547 | coordinate |
| radius × 0.10547 | radius |
| 75 % shrink applied at port time | n/a |
| Opacity 0.55 = `#8C` ARGB byte | matches |

Keep the VectorDrawable in sync manually — Android Studio's SVG importer doesn't preserve
radial gradients cleanly enough to round-trip.

## Where the brand mark appears

- Constellation app launcher icon (Android adaptive)
- Status-bar notification icon (monochrome variant)
- About screen (full 56 × 56 rendered) — see
  [`Doc/ui-mockup.html §2.5`](../ui-mockup.html)
- This mockup's brand header — currently embedded inline; should swap to a reference of
  `v1-constellation.svg` at implementation time

## Author note

— Zack 紫意, 2026-05-24

*Where your senses go, your mind follows.*
