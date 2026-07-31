# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development

This is a HarmonyOS application built with **Hvigor** and managed by **OHPM** (OpenHarmony Package Manager). Development requires DevEco Studio.

**Build commands (run via DevEco Studio or Hvigor CLI):**
- Build: `hvigorw assembleHap` (debug) or `hvigorw assembleHap --mode release`
- Install dependencies: `ohpm install`
- Lint: configured via `code-linter.json5`, applies to all `**/*.ets` files

**Run tests:**
- Unit tests (local): `hvigorw test --module entry` — runs `LocalUnit.test.ets` via Hypium
- Device/integration tests: `hvigorw ohosTest --module entry` — runs `Ability.test.ets` on device

## Architecture

The app is a tab-based HarmonyOS app (Home / Record / Mine) targeting HarmonyOS 6.1.0 (API 23), written in **ETS** (ArkTS — a TypeScript superset).

**Entry points:**
- `entry/src/main/ets/entryability/EntryAbility.ets` — app lifecycle, window setup, dark/light theme sync via `AppStorage`
- `entry/src/main/ets/pages/Index.ets` — root page, renders the HdsTabs nav with dot-pattern canvas background

**Pages** live in `entry/src/main/ets/pages/`. Most are stubs; the implemented ones are `Index.ets` (navigation shell) and `HealthPage.ets`.

**Utilities** live in `entry/src/main/ets/utils/`:
- `HealthServiceHelper.ets` — wraps HarmonyOS Health Service Kit: handles authorization, queries daily steps/calories/distance, and caches results using `Preferences`.

**UI layer** uses ArkUI declarative syntax + the HDS (HarmonyOS Design System) component library (`@kit.UIDesignKit`). The app uses immersive full-screen layout with system bar safe-area handling and `IMMERSIVE_GRADIENT_BLUR` scroll effects.

**State management** uses ArkUI's built-in `AppStorage` (global reactive state) and `@State`/`@Prop` decorators — no external state library.

## Key conventions

- Language is ETS/ArkTS — use `@Component`, `@Entry`, `@State`, `@Prop`, `@StorageProp` decorators per ArkUI conventions.
- Lint rules enforce `@performance/recommended` and `@typescript-eslint/recommended`; cryptographic API usage is blocked by the security ruleset in `code-linter.json5`.
- Tests use the **Hypium** framework (`describe`/`it`/`expect` style) — see `entry/src/test/LocalUnit.test.ets` for the pattern.
- `entry/src/main/ets/model/` and `entry/src/main/ets/common/` directories exist but are empty — intended for data models and shared components.
