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
