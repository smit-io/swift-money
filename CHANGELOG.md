# Changelog

All notable changes to MoneyKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `SignedMoney`: a signed wrapper over `Money` (sign + magnitude) for values
  that legitimately go negative. `Money.minus(_:)` subtracts without throwing
  on negative results; full arithmetic (`+`, `-`, `*`, `/`, prefix `-`),
  `Comparable`, `Codable`, and conversion back via `money`/`absolute`.
- First-class `SignedMoney` ergonomics for balance-style code: mixed
  `Money`/`SignedMoney` `+`/`-` operators (a signed operand promotes the
  result to `SignedMoney`), `SignedMoney.zero(_:)`, prefix `-` on `Money`
  returning `SignedMoney`, locale-aware `SignedMoney.formatted(locale:)`,
  machine-parseable `SignedMoney.numericString`, and `sum(in:)` on
  sequences of `Money` and `SignedMoney`.

### Fixed
- `Money.allocate(by:)` no longer gives a leftover smallest unit to a zero
  ratio. The remainder went round-robin over every index, so `5¢` split by
  `[0, 1, 1]` returned `[1, 2, 2]`; it now returns `[0, 3, 2]`. Results for
  ratio lists with no zeros are unchanged.

## [1.3.1] - 2026-07-23

### Changed
- `Scripts/generate_iso4217.py` now downloads the ISO 4217 registry from SIX
  on every run and updates `Resources/iso4217/list-one.xml` only when the
  published content changed. The response is validated before the committed
  copy is overwritten (an HTML error page or truncated download never
  clobbers the registry), and the script falls back to the committed copy
  when offline. Tooling-only change; the library itself is unaffected.

## [1.3.0] - 2026-07-23

### Changed
- Default decimal places are now derived from the official ISO 4217 registry
  (generated table) instead of hand-typed sets. **Breaking for persisted
  `Money` amounts** in the corrected currencies: ISK and UYI are now 0 decimal
  places (were 2), CLF and UYW are 4 (were 2), MGA is 2 (was 0). Integer
  amounts stored under the old defaults are reinterpreted at the new scale.
- Registry rows with "N.A." minor units (XAU, XDR, XXX, XTS, ...) are excluded
  from the table and keep the lenient 2-decimal default; `isISO` reports
  `false` for them.
- `Currency` now validates on decode: `Codable` round-trips `{code,
  decimalPlaces}` through `init(code:decimalPlaces:)`, re-deriving `divisor`
  instead of trusting persisted JSON.
- `Currency(code:decimalPlaces:)` rejects decimal places outside 0...30 with
  `CurrencyError.invalidDecimalPlaces`.
- `numericString` is pinned to a machine-parseable dot-decimal format
  (en_US_POSIX, no grouping) on every host locale, matching its documented
  examples; use `formatted(locale:)` for display.

### Added
- Initial release of MoneyKit
- `Money` value type with integer-based smallest unit representation
- `Currency` type with ISO 4217 support
- Automatic decimal place detection for currencies
- Zero-decimal currency support (JPY, KRW, etc.)
- Three-decimal currency support (KWD, BHD, etc.)
- Type-safe arithmetic operations (+, -, *, /)
- Safe arithmetic methods (tryAdd, trySubtract, etc.)
- Money distribution and allocation algorithms
- Percentage calculations
- Localized currency formatting
- NumberFormatter caching for performance
- Comprehensive error handling with typed errors
- Full Sendable conformance for Swift Concurrency
- Codable conformance for JSON encoding/decoding
- Comparable conformance for sorting and comparison
- 54+ comprehensive tests with Swift Testing
- GitHub Actions CI/CD workflow
- SwiftLint configuration
- Comprehensive documentation and examples

### Security
- Input validation for currency codes
- Negative amount rejection
- Currency mismatch prevention
- Type-safe operations

## [1.0.0] - TBD

Initial release.
