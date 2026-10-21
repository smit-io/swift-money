# Changelog

All notable changes to MoneyKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-10-21

One signed `Money` type plus `BigMoney` for calculations, modelled on
joda-money. See the migration table in `ARITHMETIC_GUIDE.md`.

### Changed
- **Breaking:** `Money` amounts are signed. Negative results from `-`, `*`,
  and decoding are valid values instead of throwing. `Int.min` is still
  rejected (`amountOverflow`) so negation and `abs()` never overflow.
- **Breaking:** `Money(decimalAmount:currency:)` is now
  `Money(decimalAmount:currency:rounding:)`; the old initializer rounded
  `.halfUp` implicitly.
- `allocate(by:)` and `distribute(into:)` split negative values by
  magnitude and give every part the sign, so parts still sum exactly.

### Added
- `BigMoney`: a signed `Decimal` amount in standard units, never rounded
  implicitly. `+` / `-` with `BigMoney` or `Money`, `*` / `/` by `Decimal`,
  prefix `-`, `abs()`, sign queries, `Comparable`, `tryCompare(_:)`,
  `sum(in:)`, and `rounded(_:)` back to `Money`. Codable encodes the amount
  as a string to keep full precision.
- `Money.zero(_:)`, `negated()`, prefix `-`, `abs()`, `isNegative`,
  `isPositiveOrZero`, `isNegativeOrZero`.
- `Money.multiplied(by:rounding:)` and `divided(by:rounding:)` taking
  `Decimal`, and `toBigMoney()`.
- `Double` and `Int` overloads of `Money(decimalAmount:currency:rounding:)`,
  `multiplied(by:rounding:)`, `divided(by:rounding:)`,
  `BigMoney(amount:currency:)`, and `BigMoney` `*` / `/`. A `Double` is
  converted through its shortest text, like joda-money's
  `BigDecimal.valueOf(double)`, so `0.07` is exactly 0.07 (`Decimal(0.07)`
  is `0.07000000000000001024`). NaN, infinity, and out-of-range values throw
  the new `MoneyError.invalidDecimal`.
- `MoneyError.negativeRatio` and `MoneyError.negativePartCount`, thrown by
  `allocate(by:)` for a negative ratio and `distribute(into:)` for a
  negative part count.

### Removed
- **Breaking:** `SignedMoney`, `Money.minus(_:)`, `Money.signed`, and the
  mixed `Money` / `SignedMoney` operators: plain `Money` covers them.
- **Breaking:** `MoneyCalculation` and the `Double` / `Float` operators
  that produced it: use `BigMoney`.
- **Breaking:** `Money * Decimal` and `Money / Int`, which rounded
  silently: use `multiplied(by:rounding:)` / `divided(by:rounding:)`.
- **Breaking:** `multiply(by:rounding:)`, `divide(by:rounding:)`,
  `percentage(_:)`, `withTax(rate:rounding:)`, `absolute`, and
  `tryAdd` / `trySubtract` / `tryMultiply` / `tryDivide` (use `try?`).
- **Breaking:** `MoneyError.negativeAmount`.

### Fixed
- `allocate(by:)` with a negative ratio threw `amountOverflow` ("share
  exceeds Int.max") or `divisionByZero` depending on the other ratios; it
  now throws `negativeRatio`. `distribute(into:)` with a negative count
  threw `divisionByZero`; it now throws `negativePartCount`.
- `allocate(by:)` trapped when the ratios summed beyond `Int.max`; it now
  throws `amountOverflow`.
- A NaN `Decimal` threw `amountOverflow` ("Amount NaN exceeds the range")
  when rounded. `Money(decimalAmount:)`, `multiplied(by:rounding:)`,
  `divided(by:rounding:)`, `BigMoney / Decimal`, and `BigMoney.rounded(_:)`
  now throw `invalidDecimal(.nan)`, as `Double` NaN already did.
  `BigMoney(amount:)` and `BigMoney * Decimal` still accept NaN, since they
  don't throw; the value fails when rounded.
- `Currency(code:)` accepted any three letters, including non-ASCII ones
  (`"日本円"`, `"ÄÖÜ"`). Codes must now be ASCII letters, as documented;
  others throw `CurrencyError.invalidFormat`.
- `RoundingMode.towardZero` and `.awayFromZero` rounded negative values
  as floor and ceiling. They now follow the magnitude.
- `numericString` and `formatted` rounded to about 15 significant digits
  at 16 or more decimal places (`NumberFormatter`): `Int.max` at 18 places
  printed `9.223372036854780000`. `numericString` is now built from the
  integer amount, and `formatted` uses `FormatStyle` on iOS 15 / macOS 12
  and later, so both keep every digit.
- `Money` Codable dropped a custom `decimalPlaces`: `Money(34590, USD at 4)`
  (`$3.4590`) decoded as `$345.90`. Payloads now carry `decimalPlaces` when
  it differs from the code's default; default-currency payloads are
  unchanged, and payloads without the key decode at the default.

## [2.0.0] - 2026-10-21

### Changed
- **Breaking:** `Currency` equality and hashing compare `decimalPlaces` as
  well as `code`. A `Money` amount is an integer in the smallest unit, so
  `USD` at 4 decimal places and `USD` at 2 give the same integer different
  values; they were equal before, so `Money(34590, USD at 4)` (`$3.4590`)
  equalled `Money(34590, .USD)` (`$345.90`) and adding them silently mixed
  scales. Such currencies are now different `Set` / `Dictionary` keys too.
  Currencies at their default decimal places are unaffected.

### Added
- **Breaking:** `MoneyError.decimalPlacesMismatch(code:lhs:rhs:)`, thrown
  when combining values whose currencies share a code but not decimal places
  (`+`, `-`, `minus(_:)`, `sum(in:)`, the mixed `Money` / `SignedMoney`
  operators, and `MoneyCalculation` `+` / `-`). Different codes still throw
  `currencyMismatch`. A new enum case breaks an exhaustive `switch` over
  `MoneyError` with no `default`. `Comparable`'s precondition message names
  the same two cases; `tryAdd` / `trySubtract` / `tryCompare` return `nil`.

## [1.4.0] - 2026-10-21

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
- `SignedMoney.allocate(by:)`: splits the magnitude with `Money.allocate(by:)`
  and gives every part the value's sign, so a negative value splits into
  negative parts that add up exactly (-$100.00 by `[1, 1, 1]` gives -$33.34,
  -$33.33, -$33.33).

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
