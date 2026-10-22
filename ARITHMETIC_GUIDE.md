# MoneyKit Arithmetic Guide

## Overview

MoneyKit has two money types:

- **`Money`**: a signed integer amount in the currency's smallest unit (cents,
  yen, fils). Use it to store, transfer, and display amounts.
- **`BigMoney`**: a signed `Decimal` amount in standard units (dollars,
  yen, dinars) at any precision. Use it for calculations in progress.

Arithmetic that stays in whole minor units is exact. Anything that can
produce a fraction of a minor unit names its rounding mode: either directly
(`multiplied(by:rounding:)`, `divided(by:rounding:)`) or once at the end of a
`BigMoney` chain (`rounded(_:)`). Nothing rounds implicitly.

## Money

### Exact operations

```swift
let price = try Money(amount: 1000, currency: .JPY)
let coupon = try Money(amount: 1500, currency: .JPY)

try price + coupon        // ¥2500
try price - coupon        // -¥500 (amounts are signed)
try price * 3             // ¥3000
-price                    // -¥1000 (same as price.negated())
(-price).abs()            // ¥1000
try [price, coupon].sum(in: .JPY)  // ¥2500
```

These throw `currencyMismatch` / `decimalPlacesMismatch` on mixed currencies
and `amountOverflow` past `-Int.max...Int.max`.

### Rounded operations

```swift
let price = try Money(amount: 1234, currency: .JPY)

try price.multiplied(by: 1.1, rounding: .up)    // ¥1358 (1357.4)
try price.multiplied(by: 1.1, rounding: .down)  // ¥1357
try price.divided(by: 3, rounding: .halfUp)     // ¥411 (411.33…)
```

### Splitting without losing a unit

```swift
let bill = try Money(amount: 15273, currency: .JPY)

try bill.distribute(into: 4)       // [3819, 3818, 3818, 3818], sums to 15273
try bill.allocate(by: [70, 20, 10]) // proportional, sums to 15273

let refund = try Money(amount: -10000, currency: .USD)
try refund.allocate(by: [1, 1, 1])  // [-3334, -3333, -3333]
```

## BigMoney

Convert with `toBigMoney()`, chain, then round once:

```swift
let price = try Money(amount: 10000, currency: .JPY)

// 20% discount, then 10% tax, one rounding
let final = try (price.toBigMoney() * 0.8 * 1.1).rounded(.down)  // ¥8800

// Mix in Money values without rounding
let shipping = try Money(amount: 500, currency: .JPY)
let gross = try price.toBigMoney() * 1.1 + shipping  // 11500, unrounded
```

Rounding once can give a different answer from rounding every step:

```swift
let one = try Money(amount: 1, currency: .JPY)

try one.multiplied(by: 1.5, rounding: .down)
       .multiplied(by: 1.5, rounding: .down)          // ¥1
try (one.toBigMoney() * 1.5 * 1.5).rounded(.down)     // ¥2 (2.25)
```

`BigMoney` supports `+` / `-` with `BigMoney` or `Money`, `*` and `/` by
`Decimal`, `Double`, or `Int`, prefix `-`, `abs()`, `isZero` / `isPositive` / `isNegative`,
`Comparable`, `tryCompare(_:)`, and `sum(in:)`. Division throws on a zero
divisor, and `Double` operands throw `invalidDecimal` for NaN or infinity;
precision is `Decimal`'s 38 significant digits.

A division that doesn't terminate is cut to 38 digits toward zero, so
dividing and multiplying back lands just inside the original value. Rounding
to nearest hides this; rounding toward zero does not:

```swift
let third = try Money(amount: 1, currency: .JPY).toBigMoney() / 3 * 3  // 0.99999…

try third.rounded(.halfUp)      // ¥1 (also .bankers, .awayFromZero)
try third.rounded(.towardZero)  // ¥0 (also .down here; .up for a negative value)
```

joda-money avoids the residue by rounding every division to the amount's
scale, which loses the precision earlier instead: USD 1.00 ÷ 3 is 0.33 or
0.34 depending on the mode, so × 3 gives 0.99 or 1.02.

## Rounding Modes

| Mode | Description | 1357.4 → | 1357.5 → | -1357.5 → |
|------|-------------|----------|----------|-----------|
| `.up` | Toward positive infinity (ceiling) | 1358 | 1358 | -1357 |
| `.down` | Toward negative infinity (floor) | 1357 | 1357 | -1358 |
| `.halfUp` | Nearest, ties away from zero | 1357 | 1358 | -1358 |
| `.bankers` | Nearest, ties to even | 1357 | 1358 | -1358 |
| `.towardZero` | Truncate | 1357 | 1357 | -1357 |
| `.awayFromZero` | Away from zero | 1358 | 1358 | -1358 |

`.up` / `.down` follow the number line; `.towardZero` / `.awayFromZero`
follow the magnitude. They differ only for negative values.

## Currency-Specific Behavior

Rounding always lands on the currency's decimal places:

```swift
let usd = try Money(amount: 1999, currency: .USD)          // $19.99
try usd.multiplied(by: 1.08, rounding: .up)                 // $21.59 (21.5892)

let kwd = try Money(amount: 1234, currency: .KWD)          // 1.234 KWD
try kwd.multiplied(by: 1.1, rounding: .down)                // 1.357 KWD (1.3574)
```

## Real-World Examples

### E-commerce checkout

```swift
let subtotal = try Money(amount: 4999, currency: .USD) + Money(amount: 500, currency: .USD)
let total = try subtotal.multiplied(by: 1.08, rounding: .up)  // $59.39
```

### Payment processing fee (2.9% + $0.30)

```swift
let order = try Money(amount: 4999, currency: .USD)
let fee = try order.multiplied(by: 0.029, rounding: .up) + Money(amount: 30, currency: .USD)
let net = try order - fee  // $48.24
```

### Tiered discounts with tax

```swift
let price = try Money(amount: 10000, currency: .JPY)

for rate: Decimal in [0.9, 0.8, 0.7] {
    let final = try (price.toBigMoney() * rate * 1.1).rounded(.down)  // ¥9900, ¥8800, ¥7700
}
```

## Error Handling

```swift
do {
    _ = try price.divided(by: 0, rounding: .down)
} catch MoneyError.divisionByZero {
    print("Cannot divide by zero")
}

do {
    _ = try Money(amount: 1000, currency: .JPY).toBigMoney() + Money(amount: 1000, currency: .USD)
} catch MoneyError.currencyMismatch(let from, let to) {
    print("Cannot add \(from.code) and \(to.code)")
}
```

The same code at different decimal places is a mismatch too, reported as
`MoneyError.decimalPlacesMismatch(code:lhs:rhs:)` (a `Currency` built with a
custom `decimalPlaces` is a different scale, and equality compares both).

Use `try?` where a `nil` result is the right fallback:

```swift
let total = try? usd + eur  // nil on mismatch
```

## Best Practices

1. **Round once.** Chain multi-step calculations in `BigMoney` and call
   `rounded(_:)` at the end.
2. **Document rounding choices.** Tax rules often mandate a mode, e.g.
   Japanese consumption tax rounds down.
3. **Pass rates as `Double` or `Int` literals, or `Decimal(string:)`.**
   A `Double` argument is converted through its shortest text (joda-money's
   `BigDecimal.valueOf(double)`), so `0.07` is exactly 0.07. A `Decimal`
   *literal* is not: `let r: Decimal = 0.07` goes through `Double` and is
   `0.07000000000000001024`, which can round `.up` one unit too far.
4. **Split with `distribute` / `allocate`**, not division, when the parts must
   add back up to the total.
5. **Round to nearest after an inexact division.** `.towardZero` (and `.down`
   / `.up` on the side toward zero) can land one unit short after dividing
   by 3 or 7 and multiplying back.

## Migrating from 2.x

| 2.x | 3.0 |
|-----|-----|
| `SignedMoney` | `Money` (amounts are signed) |
| `a.minus(b)` | `a - b` |
| `money.signed` | `money` |
| `signed.money` | `signed.isNegative ? nil : signed` |
| `signed.magnitude` / `money.absolute` | `abs()` |
| `MoneyError.negativeAmount` | removed: negative amounts are valid |
| `Money(decimalAmount:currency:)` | `Money(decimalAmount:currency:rounding:)` (2.x rounded `.halfUp`) |
| `money * Decimal(1.5)` | `money.multiplied(by: 1.5, rounding: .halfUp)` |
| `money.percentage(0.15)` | `money.multiplied(by: 0.15, rounding: .halfUp)` |
| `money / 4` | `money.divided(by: 4, rounding: .towardZero)` |
| `money * 1.1` → `MoneyCalculation` | `money.toBigMoney() * 1.1` → `BigMoney` |
| `calc.roundedUp` / `.roundedDown` / `.halfUp` / `.bankers` / `.value` | `big.rounded(.up)` / `(.down)` / `(.halfUp)` / `(.bankers)` / `(.bankers)` |
| `money.multiply(by:rounding:)` | `money.multiplied(by:rounding:)` |
| `money.divide(by:rounding:)` | `money.divided(by:rounding:)` |
| `money.withTax(rate: 1.1)` | `money.multiplied(by: 1.1, rounding: .down)` |
| `tryAdd` / `trySubtract` / `tryMultiply` / `tryDivide` | `try?` with `+` / `-` / `*` / `divided(by:rounding:)` |
