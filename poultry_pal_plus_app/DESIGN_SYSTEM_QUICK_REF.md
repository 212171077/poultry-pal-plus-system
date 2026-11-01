# 🎨 Design System Quick Reference

## Quick Links

- **Main File**: `lib/theme/app_theme.dart`
- **Integration**: `lib/main.dart`
- **Full Documentation**: `DESIGN_SYSTEM.md`

---

## 🎯 Most Used Constants

### Colors
```dart
AppColors.primary                    // Main brand green: #2D5016
AppColors.secondary                  // Warm brown: #8B6F47
AppColors.success                    // Green: #4CAF50
AppColors.error                      // Red: #D32F2F
AppColors.textPrimaryLight           // Dark text: #1D1D1D
AppColors.textSecondaryLight         // Gray text: #666666
AppColors.surfaceLight               // White: #FFFFFF
AppColors.backgroundLight            // Light bg: #FAFAFA
```

### Typography
```dart
AppTypography.displayLarge(color: AppColors.textPrimaryLight)
AppTypography.titleLarge(color: AppColors.textPrimaryLight)
AppTypography.titleMedium(color: AppColors.textPrimaryLight)
AppTypography.bodyLarge(color: AppColors.textSecondaryLight)
AppTypography.bodyMedium(color: AppColors.textSecondaryLight)
AppTypography.labelLarge(color: AppColors.textPrimaryLight)
```

### Spacing
```dart
AppSpacing.sm      // 8px
AppSpacing.md      // 16px (most common)
AppSpacing.lg      // 24px
AppSpacing.xl      // 32px
```

### Border Radius
```dart
AppBorderRadius.radiusMd   // 12px (most common)
AppBorderRadius.radiusLg   // 16px (dialogs)
AppBorderRadius.radiusSm   // 8px (small components)
```

### Elevation/Shadow
```dart
AppElevation.shadowMd      // Standard elevation
AppElevation.shadowLg      // Modal/AppBar elevation
```

---

## 📝 Common Patterns

### Styled Button
```dart
ElevatedButton(
  onPressed: () {},
  child: const Text('Submit'),
)
// Automatically styled via AppTheme
```

### Styled Card
```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Text(
      'Content',
      style: AppTypography.bodyMedium(
        color: AppColors.textSecondaryLight,
      ),
    ),
  ),
)
// Automatically styled via AppTheme
```

### Styled TextField
```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Email',
    hintText: 'Enter email',
  ),
)
// Automatically styled via AppTheme
```

### Custom Styled Text
```dart
Text(
  'Heading',
  style: AppTypography.titleLarge(
    color: AppColors.textPrimaryLight,
  ),
)
```

### Consistent Padding
```dart
Padding(
  padding: const EdgeInsets.all(AppSpacing.md),
  child: child,
)

// Or specific sides
Padding(
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  ),
  child: child,
)
```

---

## 🌓 Dark Mode

The app automatically supports dark mode. No extra code needed!

```dart
// In main.dart (already configured)
darkTheme: AppTheme.darkTheme,
themeMode: ThemeMode.system,
```

Test dark mode:
- On Android: Settings > Display > Dark Theme
- On iOS: Settings > Display & Brightness > Dark

---

## 🔍 Theme Breakdown

### AppTheme Class
- `lightTheme` → Complete light theme
- `darkTheme` → Complete dark theme

### AppColors Class (25+ colors)
- Primary, Secondary, Semantic (success/error/warning/info)
- Background, Surface, Text colors for both modes

### AppSpacing Class (6 constants)
- xs, sm, md, lg, xl, xxl
- Consistent 4px-based grid

### AppBorderRadius Class (7 constants)
- xs, sm, md, lg, xl, circle
- Pre-built BorderRadius objects

### AppElevation Class (5 levels + shadows)
- xs, sm, md, lg, xl
- Pre-built shadow lists for depth

### AppTypography Class (12+ styles)
- Display, Title, Body, Label, Caption
- Using Poppins (headings) and Inter (body)

---

## ✅ Checklist for New Screens

When creating a new screen:

- [ ] Use `AppTheme` colors (no hardcoded colors)
- [ ] Use `AppTypography` for text styles
- [ ] Use `AppSpacing` for padding/margins
- [ ] Use `AppBorderRadius` for rounded corners
- [ ] Use `AppElevation` for shadows
- [ ] Test in both light and dark modes
- [ ] Ensure buttons are pre-styled by theme
- [ ] Check text contrast for accessibility

---

## 🎨 Color Palette Visualization

### Light Mode
- **Background**: `#FAFAFA` (soft neutral)
- **Surface**: `#FFFFFF` (white)
- **Primary**: `#2D5016` (deep green)
- **Secondary**: `#8B6F47` (warm brown)
- **Text**: `#1D1D1D` (near-black)

### Dark Mode
- **Background**: `#121212` (dark surface)
- **Surface**: `#1E1E1E` (slightly lighter)
- **Primary**: `#3D6B1F` (lighter green)
- **Secondary**: `#A0845F` (lighter brown)
- **Text**: `#FFFFFF` (white)

---

## 📐 Spacing Quick Guide

Most common spacing usage:

```
Content Padding:           AppSpacing.md (16px)
Section Gaps:              AppSpacing.lg (24px)
Component Gaps:            AppSpacing.sm (8px)
Card Internal Padding:     AppSpacing.md (16px)
Dialog Content Padding:    AppSpacing.lg (24px)
```

---

## 🔧 Customization Workflow

### To change primary brand color:
1. Edit `AppColors.primary` in `app_theme.dart`
2. Edit `AppColors.primaryLight` (lighter variant)
3. Edit `AppColors.primaryDark` (darker variant)
4. Rebuild app (`flutter clean && flutter pub get`)

### To add a new semantic color:
1. Add constant to `AppColors` class
2. Use throughout app
3. Rebuild app

---

## 📚 Files Reference

| File | Purpose |
|------|---------|
| `lib/theme/app_theme.dart` | Complete design system implementation |
| `lib/main.dart` | App entry point with theme setup |
| `DESIGN_SYSTEM.md` | Full documentation |
| `DESIGN_SYSTEM_QUICK_REF.md` | This file |

---

## 🚀 Performance Notes

- All theme values are constants (compiled at build time)
- No runtime theme recalculation
- Material Design 3 is highly optimized
- Google Fonts are cached locally after first load

---

## ❓ FAQ

**Q: Can I override theme colors per screen?**  
A: Yes, pass custom `style` parameter to individual widgets. But try to use the provided theme first.

**Q: How do I use theme colors in custom widgets?**  
A: Access via `AppColors.primary`, `AppColors.secondary`, etc.

**Q: Does dark mode work automatically?**  
A: Yes! Just use the theme colors and text styles. The system handles light/dark automatically.

**Q: Can I change typography?**  
A: Modify `AppTypography` class methods. All apps will automatically update.

**Q: How do I add new spacings?**  
A: Add constant to `AppSpacing` class (maintain 4px grid).

---

## 🎯 Remember

- ✅ Use constants, never hardcode
- ✅ Use AppTypography for all text
- ✅ Use AppSpacing for all padding
- ✅ Test in both light and dark modes
- ✅ Check accessibility and contrast
- ✅ Follow the Material Design 3 patterns

---

**Version**: 1.0  
**Date**: April 5, 2026  
**Status**: Ready to Use ✅

