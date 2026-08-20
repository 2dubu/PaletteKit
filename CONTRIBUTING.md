# Contributing to PaletteKit

Thank you for considering a contribution to PaletteKit. Bug reports,
documentation improvements, tests, performance work, and code changes are all
welcome.

## Before You Start

- Search existing issues and pull requests before opening a new one.
- For significant public API changes, breaking changes, or broad refactors,
  open an issue first so the approach can be discussed.
- Keep each pull request focused on one logical change. Separate unrelated
  cleanup into another pull request.

## Development Requirements

- Xcode 16 or later
- Swift 6.0 or later
- macOS 14 or later for package development
- iOS 17 or later as the minimum supported deployment target

## Build and Test

Resolve dependencies and build the package:

```sh
swift package resolve
swift build -c debug
```

Run the same unit suites used by the macOS CI job:

```sh
swift test --filter PaletteKitTests --filter PaletteKitInsightsTests
```

During development, run the narrowest relevant suite or test first, then run
the complete unit suites before requesting review. The pull request CI also
runs the core suite on an iOS Simulator. Benchmarks are intentionally opt-in
and are not part of the default unit-test command.

## Testing Changes

Behavioral changes should include tests. A regression test should describe and
verify the behavior that must remain true, rather than only naming an issue or
checking that one reported attachment no longer crashes.

For bug fixes:

1. Identify the underlying failure mechanism or violated invariant.
2. Add the smallest practical input that reproduces that cause.
3. Assert meaningful outcomes such as returned values, population preservation,
   bounds, ordering, or compatibility—not merely completion without a crash.
4. Keep a large image or other reported attachment only when it provides useful
   additional end-to-end coverage.

Tests must be deterministic and self-contained. Do not depend on absolute local
paths, temporary files created outside the test, network access, or a specific
developer machine.

## Performance-Sensitive Changes

Palette extraction and quantization are hot paths. When changing their
algorithms, allocations, image processing, or Metal integration:

- explain the expected performance impact in the pull request;
- include reproducible before-and-after measurements when the impact is
  material;
- verify that performance improvements do not change output unexpectedly; and
- add coverage for any newly handled edge cases.

Avoid brittle wall-clock assertions in unit tests. Use benchmarks for timing
and unit tests for correctness and progress guarantees.

## Public API and Compatibility

- Preserve source compatibility unless a breaking change has been discussed
  and intentionally accepted.
- Document new or changed public APIs with DocC comments and examples where
  appropriate.
- Update `CHANGELOG.md` for user-visible API or behavior changes.
- Consider all supported platforms and Swift 6 strict concurrency when changing
  shared code.

Repository-process and documentation-only changes do not require a package
version bump or release by themselves.

## Pull Requests

Complete the pull request template with enough context for someone unfamiliar
with the issue to review the change. In particular, explain:

- what changed;
- the background and, for bug fixes, the root cause;
- why the proposed solution is appropriate;
- how the change was verified; and
- any public API, behavioral, platform, or performance impact.

All required CI checks and review conversations must be resolved before a pull
request is merged.
