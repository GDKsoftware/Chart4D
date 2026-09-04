# Contributing to Chart4D

Thanks for looking at the code. This page covers what you need to build it, run the tests and
get a change merged.

## What you need

- **RAD Studio / Delphi 12 Athens (23.0) or Delphi 13 (37.0)**, Win32 and Win64. The library
  is plain Object Pascal and uses only the RTL, the VCL and FMX.
- Nothing else to install. Everything the sources need is in the repository.

## Building

Open the packages under `packages\RAD Studio 13.0\` or `packages\RAD Studio 12.0\` in the
IDE for day-to-day work, or the demo project under `Examples\VCL` or `Examples\FMX`.

For the full sweep, run from the repository root:

```bat
Build.bat
```

That builds the three runtime packages, builds and runs the DUnitX suite, and builds both
demos. The script looks for the newest installed Delphi; set `CHART4D_STUDIO` to `23.0` or
`37.0` to force a version. A build must finish with zero warnings and zero hints.

## Tests

One suite, `Tests\Chart4D.Tests.dpr`, covering the axis, plot, renderer, style, tooltip,
hover, value label and catalogue behaviour, plus a set of invariants every chart kind must
hold. It runs against the shared renderer, so nothing in it needs a window or a framework.

Every change needs tests. Name them `Subject_Scenario_Expectation`, the way the existing
fixtures do, for example `NiceBreaks_NegativeRange_ReturnsBreaksAcrossZero`. A bug fix starts with a
test that fails before the fix.

Four console tools under `Tools\` go beyond the unit tests: `CoreCheck` compiles every core
unit and renders every scenario, `VclCheck` and `FmxCheck` drive the real controls through
their mouse handling and export, and `Gallery` renders the whole catalogue to PNG. Run the
ones that touch your change before opening a pull request.

## Architecture rules

The layering is the load-bearing part of the design, so a change that breaks it will not be
merged:

- Everything in `Source\` outside `Source\VCL` and `Source\FMX` is framework-neutral. It must
  not reference `Vcl.*` or `FMX.*`, directly or indirectly.
- `Chart4D.VCL` and `Chart4D.FMX` are thin adapters over the shared renderer. Drawing logic,
  layout and hit testing belong in the core, not in the adapters.
- The public API is the one declared in `SPEC.md`. A change to a public type, property or
  method updates the spec in the same pull request.
- New features belong in the library, not in the demos. `Examples\Common\Chart4DDemo.Catalog.pas`
  demonstrates the library; it is not where behaviour lives.
- No new external dependencies without discussing it in an issue first.

## Code style

Follow what is already there, and section 8 of `SPEC.md` where it spells things out. In
short: descriptive names without abbreviations, `const` for parameters that are not written
to, guard clauses instead of deep nesting, one blank line between the logical steps of a
method, an explicit `else` on every `case` over an enum, and a comment only where it explains
*why*, never *what*.

## Pull requests

- One subject per pull request.
- Tests included, and the suite green with zero warnings and hints.
- Update `README.md` and `SPEC.md` when you change public behaviour.
