# Flutter design system

Design foundation for `tourism-mobile`. Figma remains the source of truth.
The values below were aligned against comparison PNGs on 2026-07-24 because
the source Figma file and Dev Mode were unavailable. Treat screenshot-derived
geometry as approximate until it is verified against Figma tokens.

## Source layout

```text
lib/core/design/
  app_colors.dart
  app_iconography.dart
  app_motion.dart
  app_radii.dart
  app_shadows.dart
  app_spacing.dart
  app_typography.dart
  components/
    app_controls.dart
    app_glass.dart
```

`core/theme` wires these tokens into Material 3 and keeps compatibility
exports for older feature imports.

## Tokens

- Spacing scale: `4, 8, 12, 16, 20, 24, 32`; page inset is `16`.
- Radii: chip `22`, field `26`, card `26`, modal `28`, capsule/circle `999`.
- Motion: fast `120 ms`, normal `180 ms`, emphasized `260 ms`, nav droplet
  `360 ms`, reduced motion `150 ms`.
- Typography: bundled full Rubik variable font. UI styles explicitly set
  family, size, weight, height and zero/non-negative letter spacing.
- Semantic swipe colors: muted green for favorite, muted burgundy for
  send-to-end.

Raw colors and timing values belong in tokens. Feature widgets should not
create parallel palettes or motion constants.

The shared search/filter row has a stable `58 px` height. The outlined search
surface stretches to that full height; the filter uses the same square
dimension so text or icon loading cannot collapse the field.

## Iconography

The Figma-exported icon set is stored in `assets/icons/source/` as original
SVG files. Flutter uses transparent `128×128` PNG exports from
`assets/icons/raster/`; semantic white, ink and muted variants keep the
supplied paths, avoid runtime color-filter issues in Impeller and require no
SVG runtime dependency. `AppAssetIcon` selects the variant and applies only
animation opacity.

`AppIconography` is the central asset registry. Navigation, search/filter,
notification, profile, route actions and swipe indicators use these assets.
Material icons remain only where the supplied set has no corresponding glyph.
Golden tests precache the complete runtime icon list before capture.

## Glass

Reusable primitives:

- `AppGlassSurface`
- `AppGlassPill`
- `AppGlassCircle`
- `AppGlassIconButton`

They provide clipping, controlled backdrop blur, translucent fill, light
border, optional inner highlight and bounded shadow. Avoid nested
`BackdropFilter` chains: when a parent already blurs the backdrop, use
`blur: 0` on nested surfaces.

## Navigation and swipe

The five-destination nav keeps stable hit slots and renders:

```text
leading inactive segment | active droplet | trailing inactive segment
```

The droplet uses a local `CustomPainter`, a 360 ms interrupt-safe controller
and selection haptics. Reduced-motion mode removes bridge/stretch and uses a
150 ms slide/crossfade.

Route swipe progress is `horizontalDrag / threshold`, clamped to `-1...1`.
Rotation is limited to about 9 degrees. Raw drag drives threshold and visual
state, while pre-commit card translation is restrained to about `42 px`.
Swipe indicators stay at `42 px` and do not scale with progress. A committed
swipe triggers haptic feedback and fly-out; an uncommitted swipe springs back
without data changes.

The first-visit swipe coach is rendered inside the front route card. Its blur,
dark surface and border are clipped to card geometry; search, filters and the
floating navigation remain outside the overlay.

## Golden review

Primary deterministic frame: iOS `393×852`, device pixel ratio `1`,
text scale `1.0`, local images only. The golden suite covers Welcome, Home,
route list card, slider resting, onboarding, both swipe directions and three
nav states. It also checks `412×915`, a `360×740` frame at text scale `1.3`,
48 px nav targets and reduced motion.

Run:

```bash
flutter test test/golden/ui_golden_test.dart
```

Only update baselines after reviewing rendered PNGs:

```bash
flutter test --update-goldens test/golden/ui_golden_test.dart
```

Do not claim pixel-perfect parity from green goldens alone. Goldens prevent
regressions against the accepted Flutter rendering; they do not replace a
Figma-to-device screenshot diff.
