# poultry_pal_plus_app

Offline-friendly poultry farm management app.

### Production mobile UI

Placements expose labelled Place chicks and Record bird movement actions for
managers (movement applies to active placements). Production form fields use the
theme's compact body text, and scrollable popups clear both the keyboard and the
system navigation safe area. Hatch reports display summary, period trends and
individual result cards without horizontal tables.

### Domain icons

Use `AppIcons` in `lib/theme/app_icons.dart` for chicken, chick, hatch, egg,
incubation, transfer and chicken-house symbols. Keep Material icons for standard
actions such as edit, delete and navigation.

The three poultry glyphs are bundled from Microsoft's MIT-licensed
[Fluent UI Emoji High Contrast](https://github.com/microsoft/fluentui-emoji)
collection; source SVGs and the license are in `assets/icons/`. Unlike native
emoji, they inherit icon size/color and look consistent across devices offline.
Lucide and Hugeicons were considered, but did not provide the matching poultry
and hatching-chick symbols needed here. A three-glyph font avoids a full icon
package dependency and remains compatible with Flutter's `Icon` widgets.

To regenerate `assets/icons/poultry_icons.ttf`, install `fonttools==4.68.0` in a
Python environment and run `python3 tool/build_poultry_icons.py`.
