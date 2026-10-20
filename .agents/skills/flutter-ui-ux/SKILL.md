---
name: flutter-ui-ux
description: Design, implement, and refine premium modern Flutter application interfaces with strong visual hierarchy, responsive mobile and web layouts, reusable design systems, and polished interaction states. Use when building or improving Flutter UI/UX, screens, navigation, widgets, themes, or responsive layouts.
---

# Flutter UI/UX Design

Create Flutter experiences that feel intentional, polished, accessible, and production ready. Preserve the app's existing behavior and architecture while improving its visual quality.

## Start with the project

- Read the repository's `AGENTS.md` files, `pubspec.yaml`, and the relevant app entry point, routes, screens, themes, and shared widgets before editing.
- Identify the supported platforms, existing design conventions, state management, navigation, assets, and functionality that must remain intact.
- Run the app before making significant visual changes when the project can be launched. Capture a baseline screenshot for the affected flow and viewport sizes.
- Prefer extending the current architecture and shared components over introducing new dependencies or duplicating patterns.

## Design quality

- Establish a clear visual hierarchy: make the primary task and its next action immediately recognizable, group related content, and keep secondary details visually quiet.
- Use a deliberate spacing scale and consistent alignment. Give sections room to breathe and avoid arbitrary one-off padding values.
- Define and reuse a cohesive design system for color, typography, spacing, radii, elevation, borders, icon sizing, and motion. Prefer the existing theme or centralize new tokens in theme extensions or shared theme files.
- Use a restrained, purposeful palette with adequate contrast. Pair typefaces and text styles consistently; use readable line lengths, clear size and weight steps, and appropriate emphasis.
- Build reusable components for repeated patterns. Keep widgets focused, configurable where useful, and aligned with existing naming and file organization.
- Use high-quality assets and icons that fit the product. Avoid decorative clutter, inconsistent icon styles, unnecessary gradients, and default-looking component arrangements.
- Make interactive elements feel finished: provide coherent default, pressed, focused, hovered, selected, disabled, loading, success, and error states where applicable. Add subtle transitions only when they clarify feedback or state change.
- Respect accessibility: support text scaling, semantic labels, keyboard focus and navigation on web, adequate touch targets, and color contrast. Do not communicate state through color alone.

## Responsive layouts

- Design for narrow phones, larger phones, tablets, and desktop/web widths that the app supports. Use `LayoutBuilder`, `MediaQuery`, breakpoints, flexible constraints, and adaptive navigation where appropriate.
- Keep content readable and actions reachable at small widths. Prevent overflow, clipped controls, tiny tap targets, and awkward wrapping.
- On wide screens, use intentional max-widths, balanced columns, and appropriate navigation patterns instead of simply stretching a phone layout across the viewport.
- Check portrait and landscape when the affected flow is likely to be used in both orientations. Account for safe areas, system insets, and on-screen keyboards.

## Screenshot and design-reference replication

When the user provides a screenshot or design reference, treat it as the visual target and follow this loop:

1. Inspect the entire reference image before coding. Note its layout, visual hierarchy, colors, typography, spacing, icons, imagery, borders, radii, and component dimensions. Record the reference viewport and visible application state when available.
2. Inspect the existing app flow and implementation, then reuse its architecture, dependencies, assets, and native Flutter widgets. Preserve navigation, API calls, state management, validation, and business logic.
3. Implement the design with responsive Flutter layouts, matching the reference at its intended viewport while keeping mobile, tablet, and web behavior usable.
4. Run the app on the closest available target device or browser. Capture a screenshot of the actual rendered Flutter screen at the same viewport dimensions and application state as the reference.
5. Inspect both images and list the most important visual differences. Check spacing and alignment, font sizes and weights, colors and component dimensions, missing images or icons, overflow or clipping, and mobile or tablet responsiveness.
6. Fix the differences, capture a new actual-app screenshot, and compare again. Repeat until the main layout and styling closely match the reference. Continue to preserve existing functionality throughout.
7. Run `flutter analyze` and the relevant `flutter test` suite; address issues caused by the implementation and report the actual results.

Never say a screenshot was captured, inspected, or compared unless that action was actually completed. If a target cannot be launched or screenshot capture is unavailable, clearly explain the limitation and use the best available alternative verification method. Do not imply pixel-level comparison when viewport dimensions, app state, or actual screenshots differ.

## Implementation workflow

1. Map the existing screen flow and identify the visual problems to solve. Preserve routes, validation, data behavior, state, and user-facing actions unless the request explicitly changes them.
2. Make a concise design plan for hierarchy, layout, design tokens, responsive behavior, and component reuse. Then implement the smallest coherent set of changes.
3. Launch the app on an appropriate simulator, emulator, or browser target. Exercise the affected flows and capture screenshots at representative mobile and web sizes.
4. Inspect the screenshots visually. Look for hierarchy, alignment, spacing, typography, contrast, clipping, overflow, inconsistent components, awkward responsive transitions, and incomplete interaction states. Fix the problems and repeat the screenshot inspection until the UI is polished.
5. Run Flutter static analysis (`flutter analyze`) and the relevant tests (`flutter test`; include targeted tests when available). Resolve regressions caused by the changes. Do not claim these checks passed unless they were actually run successfully.
6. Summarize the changes, platforms or flows inspected, and analysis/test results. Mention any environment limitation that prevented launching a target or completing visual inspection.

## Flutter implementation guidance

- Prefer Material 3 and the project's established widget library and theme conventions; customize them to fit the product rather than accepting generic defaults.
- Use `const` constructors where practical, stable keys for important repeated or tested elements, and semantic widgets for controls.
- Avoid fixed dimensions for content that should adapt. Use constraints and scrollable layouts safely, particularly with dynamic text and keyboard insets.
- Keep state changes and asynchronous work predictable. Loading and error visuals should reflect the actual state rather than being decorative placeholders.
- Do not remove or silently alter existing functionality while restyling. Check the relevant user journey after edits and keep or update tests to protect behavior.

---

# Extended guidance

The sections below extend the workflow above. They add a structured way to read design images, a token scaffold, component recipes, motion, and a final checklist.

## Reading a design image (spec extraction)

Before writing any widget code for a screenshot, mockup, or Figma export, write a short design spec from the image. Work from the whole image down to the details, and label every value as **measured** (read from the image or exported specs) or **estimated** (judged by eye). Do not present estimates as exact.

1. **Frame**: device type and approximate logical size (for example 390x844 for a modern phone), status bar and home indicator, light or dark mode, and which app state is shown (empty, loaded, error, selected tab).
2. **Structure**: list the regions top to bottom (app bar, hero, sections, bottom bar or nav) and decide for each whether it scrolls, is pinned, or floats. Name the layout primitive that fits: `Column`, `ListView`, `CustomScrollView` with slivers, `Stack`, `Row` with `Expanded`, `Wrap`, `GridView`.
3. **Color**: sample the background, surface, primary, accent, text (primary, secondary, disabled), border, divider, and status colors. Give hex values. If the image is compressed or blurry, say the values are approximate and map them to the nearest sensible token. Check whether the same color repeats across elements, and if so create one token.
4. **Type**: estimate font family, size, weight, line height, and letter spacing for each text role (display, title, body, caption, button, label). Identify the closest available font; prefer the project's existing font, otherwise a close Google Fonts match, and say which one you chose and why. Map roles to `TextTheme` slots instead of styling inline.
5. **Spacing and sizing**: infer the base unit (usually 4 or 8) and express gaps, paddings, and component heights as multiples of it. Note the screen's horizontal margin, card padding, list item height, button height, and input height.
6. **Shape and depth**: corner radii per component family, border widths and colors, shadows (offset, blur, opacity) or flat tonal elevation, and any blur, glass, or gradient effects with their direction and stops.
7. **Icons and imagery**: icon style (outlined, filled, rounded), size, and stroke weight; avatars, illustrations, photos, and their aspect ratios and crop. Decide per item whether it comes from the project's assets, an exported design asset, an icon set already in the project, or a placeholder.
8. **Interaction hints**: anything implying states or behavior (selected tab, pressed button, focused field with error text, skeleton, toast, bottom sheet, swipe affordance). Implement these states, not only the static frame.

If several images are provided, treat them as a flow. Find the shared components and tokens first, build those once, then build each screen from them. If images conflict (different spacing or colors for the same component), ask the user which is canonical, or follow the most recent one and say so.

When the image is ambiguous (cut-off content, unreadable text, unknown font), make a reasonable choice, state the assumption in the summary, and keep the code easy to adjust through tokens.

### Fidelity rules

- Match the reference first on structure, hierarchy, spacing rhythm, and color, then on small details. A layout that is correct but slightly off in color is better than one with exact colors and a wrong structure.
- Do not hardcode the reference's pixel positions. Reproduce its intent with flexible layout so it survives other screen sizes, text scaling, and localization.
- Use the real content from the image for text, labels, and numbers when building a static screen, but keep strings out of deeply nested widgets so they can be moved into data models or localization later.
- Use real exported assets when they exist. Do not redraw complex illustrations or logos by hand with `CustomPainter`; use SVG (`flutter_svg` if already in the project) or an image asset. Draw simple shapes, dividers, and gradients in code.
- Do not replace a custom icon from the design with a close-looking built-in `Icons.*` glyph unless the asset is missing, and tell the user when you do.

## Design tokens scaffold

If the project has no centralized tokens, add them in one place (for example `lib/core/theme/`) and make widgets read from the theme, not from literals. Adapt names to the project's conventions.

```dart
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.space,
    required this.radius,
    required this.surfaceMuted,
    required this.success,
    required this.warning,
    required this.cardShadow,
  });

  final AppSpace space;
  final AppRadius radius;
  final Color surfaceMuted;
  final Color success;
  final Color warning;
  final List<BoxShadow> cardShadow;

  @override
  AppTokens copyWith({
    AppSpace? space,
    AppRadius? radius,
    Color? surfaceMuted,
    Color? success,
    Color? warning,
    List<BoxShadow>? cardShadow,
  }) =>
      AppTokens(
        space: space ?? this.space,
        radius: radius ?? this.radius,
        surfaceMuted: surfaceMuted ?? this.surfaceMuted,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        cardShadow: cardShadow ?? this.cardShadow,
      );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      space: space,
      radius: radius,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
    );
  }
}

class AppSpace {
  const AppSpace();
  final double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32, xxxl = 48;
}

class AppRadius {
  const AppRadius();
  final double sm = 8, md = 12, lg = 16, xl = 24, pill = 999;
}

extension TokenContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
```

Guidelines for tokens:

- Build the `ColorScheme` from the reference colors (`ColorScheme.fromSeed` is a starting point; override the roles the design defines, such as `primary`, `surface`, `onSurface`, `outline`).
- Put typography in `TextTheme` and component looks in the component themes (`FilledButtonThemeData`, `InputDecorationTheme`, `CardThemeData`, `NavigationBarThemeData`, `AppBarTheme`, `ChipThemeData`, `BottomSheetThemeData`, `DialogThemeData`). Screens should rarely need `copyWith` styling.
- Provide both light and dark themes when the app supports both; check the same screen in each. Do not just invert colors.
- Fonts: declare them in `pubspec.yaml` or use the font package already in the project. Do not fetch fonts at runtime unless the project already does.

## Component recipes

Match these patterns to the project's existing widgets before creating new ones.

- **Screens**: wrap in `Scaffold` with `SafeArea` where needed; use `CustomScrollView` with slivers when there are collapsing headers, mixed lists and grids, or sticky sections. Add bottom padding so the last item clears the nav bar and keyboard.
- **Cards and surfaces**: one shared card component with consistent padding, radius, and border or shadow. Use `InkWell` inside a `Material` so ripples respect the radius and clip behavior.
- **Buttons**: primary, secondary, tertiary, destructive, and icon buttons from the theme. Minimum 48x48 tap target. Show a loading state that keeps the button width stable and blocks double taps.
- **Inputs**: label, hint, helper, and error text from `InputDecoration`; consistent field height; correct `keyboardType`, `textInputAction`, autofill hints, and obscure toggle for passwords; focus moves to the next field; inline validation messages that do not shift the layout abruptly.
- **Lists**: `ListView.builder` or slivers for long or unbounded lists, never a `Column` inside `SingleChildScrollView` for large data. Use consistent item height and dividers, and `RefreshIndicator` where pull-to-refresh makes sense.
- **Navigation**: `NavigationBar` for 3 to 5 top-level destinations on phones, `NavigationRail` on medium widths, and a drawer or extended rail on large screens. Preserve tab state with `IndexedStack` or the router's shell route.
- **Bottom sheets and dialogs**: use `showModalBottomSheet` with `isScrollControlled` and keyboard-aware padding for forms; add a drag handle; keep actions anchored at the bottom.
- **Empty, loading, and error states**: every data-driven screen needs all three. Use skeleton shimmers or progress indicators that match the final layout, an empty state with a clear explanation and one action, and an error state with a retry. Do not leave a blank screen.
- **Images**: set `fit`, aspect ratio, a placeholder, and an error fallback; use `cached_network_image` or the project's image solution for remote images; size images to their display size to save memory.
- **Feedback**: `SnackBar` for transient messages, inline text for field errors, and dialogs only for decisions that need confirmation.

## Motion

- Use motion to explain change: a screen entering, an item being added or removed, a value updating, a state toggling. Skip it when it only decorates.
- Typical durations: 150 to 200 ms for micro-interactions, 250 to 350 ms for transitions and expansions. Use `Curves.easeOutCubic`, `easeInOutCubic`, or the Material emphasized curves, not linear.
- Prefer implicit animations (`AnimatedContainer`, `AnimatedSwitcher`, `AnimatedOpacity`, `TweenAnimationBuilder`) for simple cases. Use explicit controllers only when sequencing or interaction needs it, and always dispose them.
- Use `Hero` for shared elements between screens, and staggered list entrances sparingly.
- Respect reduced-motion settings: check `MediaQuery.of(context).disableAnimations` and shorten or skip non-essential animation.
- Keep animation off the critical path: do not animate heavy subtrees, wrap frequently repainting animated areas in `RepaintBoundary`, and avoid `Opacity` or `ClipPath` over large trees when a cheaper alternative exists.

## Performance and robustness

- Target mid-range and older Android devices and variable network speeds, not only a flagship phone. Avoid large unoptimized images, deep unnecessary widget nesting, expensive `BackdropFilter` blur over large areas, and rebuilding large subtrees on every state change.
- Split large `build` methods into small widget classes (not helper methods returning widgets) so rebuilds stay scoped and `const` can apply.
- Test with long text, large font scale (at least 1.5x), small screens (around 320 to 360 dp wide), RTL if localized, and no-data or slow-data states.
- Format currency, dates, and numbers with `intl` and the correct locale; do not concatenate symbols by hand. Keep amounts readable with tabular figures or right alignment where columns of numbers appear.

## Visual quality bar

Aim for UI that looks designed, not templated. Check for these failure patterns and fix them:

- Everything is the same size and weight, so nothing leads the eye.
- Inconsistent corner radii, paddings, or icon sizes between similar components.
- Default-blue or default-purple Material colors left over from scaffolding.
- Heavy borders and shadows used together; too many competing accent colors.
- Low-contrast gray text on tinted backgrounds; tiny captions that fail text scaling.
- Edge-to-edge content hugging the screen edge with no margin, or cramped cards with no internal padding.
- Text that truncates important information, or buttons that wrap their labels.
- Lists and tables stretched across wide web layouts with no max width.
- Placeholder content, lorem ipsum, or broken image icons left in the final screen.

## Final checklist

Before reporting completion, confirm only what was actually done:

- [ ] Existing behavior, routes, validation, and data flow are unchanged unless the request said otherwise.
- [ ] Colors, text styles, spacing, and radii come from the theme or tokens, not scattered literals.
- [ ] Loading, empty, error, disabled, pressed, focused, and selected states exist where relevant.
- [ ] No overflow, clipping, or keyboard occlusion at small, large, and wide viewports, and at larger text scales.
- [ ] Touch targets are at least 48x48 and interactive elements have semantic labels.
- [ ] For reference-based work: the real app screenshot was compared against the reference at the same viewport and state, remaining differences are listed, and assumptions are stated.
- [ ] `flutter analyze` and relevant `flutter test` were run, and the actual results are reported, or the reason they could not run is stated.
- [ ] The summary lists what changed, what was verified, and what could not be verified.