# MoneyKit

A type-safe Swift library for representing and manipulating monetary values with precision and safety.

## Features

- 💰 **Integer-based Representation**: Stores amounts as integers in the smallest currency unit (cents, pence, yen, etc.)
- 🌍 **ISO 4217 Support**: Decimal places for 165 currency codes generated straight from the official ISO 4217 registry (SIX Financial Services)
- 🔒 **Type Safety**: Throws instead of silently mixing currencies or scales
- ⚡ **Swift Concurrency**: Full `Sendable` conformance for safe concurrent usage
- 🧮 **Precise Arithmetic**: Uses `Decimal` internally to avoid floating-point precision issues
- 🎯 **Explicit Rounding**: Every inexact operation names its rounding mode; `BigMoney` chains calculations and rounds once
- 🛡️ **Overflow Protection**: Built-in overflow detection for all arithmetic operations
- 🌐 **Localization**: Automatic currency formatting based on locale
- ➖ **Signed Amounts**: Balances, refunds, and deltas are plain `Money`
- 📊 **Rich API**: Arithmetic, splitting, allocation, and summation
- ✅ **Well Tested**: Comprehensive Swift Testing suite

## Requirements

- Swift 6.0+
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+ / visionOS 1.0+

## Installation

### Swift Package Manager

Add MoneyKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/smit-io/swift-money.git", from: "3.0.0")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "MoneyKit", package: "swift-money")
    ]
)
```

## Maximum Amount Limits

MoneyKit uses `Int` to store amounts in the smallest currency unit. Amounts range over `-Int.max...Int.max` (`Int.min` is rejected so negation never overflows). The maximum representable amounts are:

| Currency | Maximum Amount | Decimal Representation |
|----------|----------------|------------------------|
| **USD** (2 decimals) | 9,223,372,036,854,775,807 cents | $92,233,720,368,547,758.07 |
| **EUR** (2 decimals) | 9,223,372,036,854,775,807 cents | €92,233,720,368,547,758.07 |
| **JPY** (0 decimals) | 9,223,372,036,854,775,807 yen | ¥9,223,372,036,854,775,807 |
| **KWD** (3 decimals) | 9,223,372,036,854,775,807 fils | KD 9,223,372,036,854,775.807 |

**Note**: These limits (approximately 92 quadrillion dollars or 922 quadrillion yen) are far beyond any practical financial application. All arithmetic operations include overflow detection and will throw `MoneyError.amountOverflow` if exceeded.

## Quick Start

```swift
import MoneyKit

// Create money values
let price = try Money(amount: 1999, currency: .USD)  // $19.99
let tax = try Money(amount: 159, currencyCode: "USD") // $1.59

// Or from decimal amounts
let shipping = try Money(decimalAmount: 5.00, currency: .USD, rounding: .halfUp)

// Arithmetic operations
let subtotal = try price + tax
let total = try subtotal + shipping

// Display
print(total.formatted)  // "$25.58"
print(total.numericString)  // "25.58"
```

## Usage Guide

### Creating Money Values

```swift
// From smallest unit (recommended for payment APIs)
let usd = try Money(amount: 2500, currency: .USD)  // $25.00
let jpy = try Money(amount: 1000, currency: .JPY)  // ¥1000

// From decimal amount, rounded to the currency's decimal places
let price = try Money(decimalAmount: 49.99, currency: .USD, rounding: .halfUp)

// From currency code string
let eur = try Money(amount: 5000, currencyCode: "EUR")
```

### Currency Support

MoneyKit includes built-in support for ISO 4217 currencies with automatic decimal place detection. The decimal places are not hand-maintained: they are generated from the official ISO 4217 registry published by SIX Financial Services (see `Scripts/generate_iso4217.py`, which re-downloads the registry on each run and regenerates the table only when SIX publishes a change). Registry rows with no applicable minor unit (XAU, XDR, XXX, test codes) fall back to a lenient 2-decimal default and report `isISO == false`.

```swift
// Standard currencies (2 decimal places)
Currency.USD  // US Dollar
Currency.EUR  // Euro
Currency.GBP  // British Pound
Currency.CAD  // Canadian Dollar
Currency.AUD  // Australian Dollar
Currency.CHF  // Swiss Franc
Currency.CNY  // Chinese Yuan

// Zero-decimal currencies
Currency.JPY  // Japanese Yen

// Three-decimal currencies
Currency.KWD  // Kuwaiti Dinar
Currency.BHD  // Bahraini Dinar

// Custom currencies
let custom = try Currency(code: "XXX", decimalPlaces: 4)
```

### Arithmetic Operations

`Money` amounts are signed: balances, refunds, and deltas can go below zero.
Arithmetic that stays in whole minor units is exact and throws only on a
currency mismatch or overflow:

```swift
let price = try Money(amount: 10000, currency: .USD)  // $100.00
let discount = try Money(amount: 1500, currency: .USD)  // $15.00

let total = try price + discount  // $115.00
let final = try price - discount  // $85.00
let owed = try discount - price   // -$85.00 (negative is fine)
let bulk = try price * 5          // $500.00
let refund = -price               // -$100.00 (also price.negated())
let magnitude = owed.abs()        // $85.00

owed.isNegative        // true
owed.isPositiveOrZero  // false
Money.zero(.USD)       // $0.00
```

Anything that can produce a fraction of a minor unit takes an explicit
rounding mode, so no rounding happens behind your back:

```swift
let price = try Money(amount: 1234, currency: .JPY)  // ¥1234

let withTax = try price.multiplied(by: 1.1, rounding: .down)  // ¥1357
let third = try price.divided(by: 3, rounding: .halfUp)       // ¥411
let fromDecimal = try Money(decimalAmount: 19.99, currency: .USD, rounding: .halfUp)
```

Rates and amounts can be `Double`, `Int`, or `Decimal`. A `Double` is converted
through its shortest text, like joda-money's `BigDecimal.valueOf(double)`, so
`0.07` is exactly 0.07. Watch for one trap: a `Decimal` *literal* goes through
`Double` first and keeps the binary error, so `let rate: Decimal = 0.07` is
`0.07000000000000001024`. Pass the literal straight in, or use
`Decimal(string: "0.07")`:

```swift
let money = try Money(amount: 100, currency: .JPY)
try money.multiplied(by: 0.07, rounding: .up)  // ¥7, exact

let rate: Decimal = 0.07                        // 0.07000000000000001024
try money.multiplied(by: rate, rounding: .up)  // ¥8, wrong
```

### Chained Calculations with BigMoney

`BigMoney` holds an unrounded `Decimal` amount in standard units (dollars,
not cents). Chain steps on it and round once at the end with `rounded(_:)`,
the only way back to `Money`:

```swift
let price = try Money(amount: 1234, currency: .JPY)
let coupon = try Money(amount: 100, currency: .JPY)

let gross = try price.toBigMoney() * 1.1 - coupon  // 1257.4, not rounded
let total = try gross.rounded(.down)               // ¥1257

// Several steps, one rounding
let once = try (price.toBigMoney() * 0.8 * 1.1).rounded(.down)  // ¥1085 (1085.92)
```

`BigMoney` supports `+` / `-` with `BigMoney` or `Money`, `*` / `/` by
`Decimal`, `Double`, or `Int`, prefix `-`, `abs()`, `isZero` / `isPositive` / `isNegative`,
`Comparable`, `tryCompare(_:)`, and `sum(in:)`.

### Rounding Modes

| Mode | Description | 1357.4 → | 1357.5 → | -1357.5 → |
|------|-------------|----------|----------|-----------|
| `.up` | Toward positive infinity (ceiling) | 1358 | 1358 | -1357 |
| `.down` | Toward negative infinity (floor) | 1357 | 1357 | -1358 |
| `.halfUp` | Nearest, ties away from zero | 1357 | 1358 | -1358 |
| `.bankers` | Nearest, ties to even | 1357 | 1358 | -1358 |
| `.towardZero` | Truncate | 1357 | 1357 | -1357 |
| `.awayFromZero` | Away from zero | 1358 | 1358 | -1358 |

### Tax Calculation (Japanese Consumption Tax Example)

```swift
// Product price: ¥1,234
let price = try Money(amount: 1234, currency: .JPY)

// Apply 10% consumption tax (消費税), rounding down per common practice
let taxInclusive = try price.multiplied(by: 1.1, rounding: .down)   // ¥1,357

// 8% reduced rate
let reduced = try price.multiplied(by: 1.08, rounding: .down)       // ¥1,332
```

### Distribution & Allocation

Split money while ensuring no value is lost to rounding:

```swift
let total = try Money(amount: 100, currency: .USD)

// Equal distribution
let parts = try total.distribute(into: 3)
// [Money(34), Money(33), Money(33)] - remainder distributed to first parts

// Verify sum is preserved
let sum = try parts.sum(in: .USD)  // Money(100) ✓

// Weighted allocation
let allocation = try total.allocate(by: [70, 30])
// [Money(70), Money(30)]

// Complex ratios
let shares = try total.allocate(by: [1, 2, 3])
// Distributes proportionally: ~17%, ~33%, ~50%

// A zero ratio always gets zero
let withZero = try Money(amount: 5, currency: .USD).allocate(by: [0, 1, 1])
// [Money(0), Money(3), Money(2)]

// Negative values split by magnitude; every part takes the sign
let refund = try Money(amount: -10000, currency: .USD)
let refundParts = try refund.allocate(by: [1, 1, 1])
// [-3334, -3333, -3333] - sums to -10000
```

### Balances and Summation

```swift
// Bank account: $20 in, $30 spent -> -$10
var balance = Money.zero(.USD)
balance = try balance + Money(amount: 2000, currency: .USD)
balance = try balance - Money(amount: 3000, currency: .USD)

balance.amount        // -1000
balance.isNegative    // true
balance.formatted(locale: Locale(identifier: "en_US"))  // "-$10.00"

// Budget: net income and expenses
let entries = [
    try Money(amount: 500_000, currency: .USD),   // salary
    try -Money(amount: 180_000, currency: .USD),  // rent
    try -Money(amount: 65_000, currency: .USD),   // groceries
]
let net = try entries.sum(in: .USD)  // Money(255_000)
```

The explicit currency in `sum(in:)` defines the empty-sequence result.

### Formatting & Display

```swift
let money = try Money(amount: 123456, currency: .USD)  // $1,234.56

// Localized formatting
print(money.formatted)  // "$1,234.56" (in US locale)

// Custom locale
print(money.formatted(locale: Locale(identifier: "ja_JP")))  // "$1,234.56"
print(money.formatted(locale: Locale(identifier: "de_DE")))  // "1.234,56 $"

// Numeric string (no symbols)
print(money.numericString)  // "1234.56"

// Decimal value for calculations
let decimal = money.decimalAmount  // Decimal(1234.56)
```

### Comparison

```swift
let small = try Money(amount: 100, currency: .USD)
let large = try Money(amount: 200, currency: .USD)

small < large   // true
small <= large  // true
large > small   // true

// Safe comparison across currencies
let usd = try Money(amount: 100, currency: .USD)
let eur = try Money(amount: 100, currency: .EUR)

if let comparison = usd.tryCompare(eur) {
    // Will not execute - returns nil for different currencies
} else {
    print("Cannot compare different currencies")
}
```

### Error Handling

MoneyKit uses typed errors for clear error handling:

```swift
do {
    // Currency mismatch in operations
    let usd = try Money(amount: 100, currency: .USD)
    let eur = try Money(amount: 100, currency: .EUR)
    let total = try usd + eur
} catch MoneyError.currencyMismatch(let from, let to) {
    print("Cannot add \(from.code) to \(to.code)")
}

do {
    // Same code, different decimal places: a Currency built with a custom
    // decimalPlaces is a different scale, so 34590 means $3.4590, not $345.90
    let custom = try Currency(code: "USD", decimalPlaces: 4)
    let fuelPrice = try Money(amount: 34590, currency: custom)
    let total = try fuelPrice + Money(amount: 100, currency: .USD)
} catch MoneyError.decimalPlacesMismatch(let code, let lhs, let rhs) {
    print("\(code) is configured with \(lhs) and \(rhs) decimal places")
}

do {
    // Overflow detection
    let large = try Money(amount: Int.max - 100, currency: .JPY)
    let overflow = try large + try Money(amount: 200, currency: .JPY)
} catch MoneyError.amountOverflow(let description) {
    print("Overflow: \(description)")
}

do {
    // Division by zero
    let money = try Money(amount: 100, currency: .USD)
    let result = try money.divided(by: 0, rounding: .down)
} catch MoneyError.divisionByZero {
    print("Cannot divide by zero")
}

do {
    // Invalid currency code
    let invalid = try Currency(code: "INVALID")
} catch CurrencyError.invalidFormat(let code) {
    print("Invalid currency code: \(code)")
}
```

## Use Cases

### 1. E-commerce Checkout Flow

```swift
// Product pricing
let productPrice = try Money(amount: 4999, currency: .USD)  // $49.99
let shipping = try Money(amount: 500, currency: .USD)       // $5.00
let subtotal = try productPrice + shipping                  // $54.99

// Tax calculation (8.5%)
let tax = try subtotal.multiplied(by: 0.085, rounding: .halfUp)  // $4.67

// Final total
let total = try subtotal + tax  // $59.66
print("Order total: \(total.formatted)")
```

### 2. Japanese E-commerce with Consumption Tax

```swift
// 商品価格: ¥1,234
let productPrice = try Money(amount: 1234, currency: .JPY)

// 送料: ¥500
let shipping = try Money(amount: 500, currency: .JPY)

// 小計
let subtotal = try productPrice + shipping  // ¥1,734

// 消費税10%適用（切り捨て）
let total = try subtotal.multiplied(by: 1.1, rounding: .down)  // ¥1,907

print("お支払い金額: \(total.formatted)")  // "¥1,907"
```

### 3. Bill Splitting

```swift
let billTotal = try Money(amount: 15000, currency: .USD)  // $150.00
let numberOfPeople = 4

// Equal split with fair remainder distribution
let perPerson = try billTotal.distribute(into: numberOfPeople)
// [Money(3750), Money(3750), Money(3750), Money(3750)]
// Each person pays $37.50

print("Each person pays:")
for (index, amount) in perPerson.enumerated() {
    print("Person \(index + 1): \(amount.formatted)")
}

// If amount doesn't divide evenly
let oddBill = try Money(amount: 10000, currency: .USD)  // $100.00
let split3 = try oddBill.distribute(into: 3)
// [Money(3334), Money(3333), Money(3333)]
// First person pays $33.34, others pay $33.33 (total preserved)
```

### 4. Revenue Sharing / Commission Splits

```swift
let revenue = try Money(amount: 100000, currency: .USD)  // $1,000.00

// Split: 70% to company, 20% to partner, 10% to affiliate
let shares = try revenue.allocate(by: [70, 20, 10])

print("Company: \(shares[0].formatted)")    // $700.00
print("Partner: \(shares[1].formatted)")    // $200.00
print("Affiliate: \(shares[2].formatted)")  // $100.00

// More complex ratios
let complexRevenue = try Money(amount: 50000, currency: .USD)
let allocation = try complexRevenue.allocate(by: [5, 3, 2])
// Splits proportionally: 50%, 30%, 20%
```

### 5. Payment API Integration

```swift
import MoneyKit

// Create charge amount (payment APIs expect smallest unit)
let orderTotal = try Money(amount: 4999, currency: .USD)

// Send to Payment API
let chargeParams = [
    "amount": orderTotal.amount,  // 4999
    "currency": orderTotal.currency.code.lowercased()  // "usd"
]

// Calculate processing fees (2.9% + $0.30)
let percentageFee = try orderTotal.multiplied(by: 0.029, rounding: .halfUp)  // $1.45
let fixedFee = try Money(amount: 30, currency: .USD)  // $0.30
let totalFee = try percentageFee + fixedFee           // $1.75

let netAmount = try orderTotal - totalFee  // $48.24
print("You receive: \(netAmount.formatted)")
```

### 6. Subscription Proration

```swift
// Monthly subscription: $29.99
let monthlyPrice = try Money(amount: 2999, currency: .USD)
let daysInMonth = 30
let daysUsed = 15

// Prorate without rounding the daily rate: $29.99 * 15 / 30 = $14.995
let prorated = try monthlyPrice.toBigMoney() * Decimal(daysUsed) / Decimal(daysInMonth)
let proratedAmount = try prorated.rounded(.halfUp)  // $15.00

print("Prorated charge: \(proratedAmount.formatted)")
```

### 7. Discount Calculations

```swift
let originalPrice = try Money(amount: 10000, currency: .USD)  // $100.00

// 20% off discount
let discount = try originalPrice.multiplied(by: 0.20, rounding: .halfUp)  // $20.00
let salePrice = try originalPrice - discount                              // $80.00

// Black Friday: an additional 15% off the sale price, rounded once
let finalPrice = try (originalPrice.toBigMoney() * 0.80 * 0.85).rounded(.down)  // $68.00
```

### 8. Multi-Currency Price Lists (No Conversion)

```swift
struct Product {
    let name: String
    let prices: [Money]
}

let product = Product(
    name: "Premium Widget",
    prices: [
        try Money(amount: 4999, currency: .USD),    // $49.99
        try Money(amount: 4499, currency: .EUR),    // €44.99
        try Money(amount: 5500, currency: .JPY),    // ¥5,500
        try Money(amount: 3999, currency: .GBP)     // £39.99
    ]
)

// Display localized price
func displayPrice(for currency: Currency) -> String? {
    product.prices.first { $0.currency == currency }?.formatted
}
```

## Advanced Usage

### Codable Support

Money values can be encoded/decoded automatically:

```swift
struct Product: Codable {
    let name: String
    let price: Money
}

let product = Product(
    name: "Widget",
    price: try Money(amount: 2999, currency: .USD)
)

// JSON encoding
let encoder = JSONEncoder()
let data = try encoder.encode(product)
// {"name":"Widget","price":{"amount":2999,"currencyCode":"USD"}}

// JSON decoding
let decoder = JSONDecoder()
let decoded = try decoder.decode(Product.self, from: data)
```

A currency built with a custom `decimalPlaces` adds the key, e.g.
`{"amount":34590,"currencyCode":"USD","decimalPlaces":4}`, so the scale
survives a round trip.

`BigMoney` encodes its amount as a decimal string so no precision is lost to
JSON numbers: `{"amount":"12.3456","currencyCode":"USD"}`.

### Concurrency Safety

MoneyKit types are fully `Sendable` and safe to use across concurrency boundaries:

```swift
actor PriceCalculator {
    func calculateTotal(_ items: [Money]) async throws -> Money {
        guard let firstCurrency = items.first?.currency else {
            throw MoneyError.divisionByZero  // Or custom error
        }

        return try items.sum(in: firstCurrency)
    }
}

// Usage
let calculator = PriceCalculator()
let items = [
    try Money(amount: 1000, currency: .USD),
    try Money(amount: 2000, currency: .USD),
    try Money(amount: 1500, currency: .USD)
]
let total = try await calculator.calculateTotal(items)  // $45.00
```

## Best Practices

1. **Always use the smallest unit**: Store amounts as integers in the smallest currency unit (cents, not dollars)
2. **Validate input**: Use throwing initializers to validate amounts and currencies at creation time
3. **Handle errors explicitly**: Don't ignore errors - they indicate invalid operations
4. **Choose rounding carefully**: Use `.down` for tax-inclusive pricing, `.up` for customer charges, `.bankers` for general calculations
5. **Test with real currencies**: Different currencies have different decimal places - test with JPY, KWD, etc.
6. **Preserve totals**: Use `distribute()` or `allocate()` for splitting to ensure sum preservation
7. **Watch for overflow**: While limits are high, validate inputs if accepting user-provided amounts
8. **Round once**: For multi-step calculations, work in `BigMoney` and call `rounded(_:)` at the final step

## Zero-Decimal Currencies

Some currencies like JPY don't use decimal places:

```swift
let yen = try Money(amount: 1000, currency: .JPY)
print(yen.decimalAmount)  // 1000 (not 10.00)
print(yen.formatted)  // "¥1,000"

// Creating from decimal (no rounding needed)
let yen2 = try Money(decimalAmount: 5000, currency: .JPY, rounding: .halfUp)  // ¥5,000
```

Zero-decimal currencies (per the ISO 4217 registry): **BIF, CLP, DJF, GNF, ISK, JPY, KMF, KRW, PYG, RWF, UGX, UYI, VND, VUV, XAF, XOF, XPF**

> Note: MGA (Malagasy ariary) is a 2-decimal currency in the registry, despite being listed as zero-decimal by some payment providers.

## Three-Decimal Currencies

Some currencies use 3 decimal places:

```swift
let dinar = try Money(amount: 1234, currency: .KWD)
print(dinar.decimalAmount)  // 1.234
print(dinar.formatted)  // "KD 1.234" (depending on locale)

// 1 fils is the smallest unit
let fils = try Money(amount: 1, currency: .KWD)  // KD 0.001
```

Three-decimal currencies (per the ISO 4217 registry): **BHD, IQD, JOD, KWD, LYD, OMR, TND**

Two currencies use 4 decimal places: **CLF** (Unidad de Fomento) and **UYW** (Unidad Previsional).

## Performance Considerations

- **NumberFormatter**: MoneyKit creates new `NumberFormatter` instances for each formatting operation to ensure thread safety. For high-frequency formatting, consider caching results at the application level.
- **Decimal arithmetic**: Internal calculations use `Decimal` for precision, which is slower than floating-point but necessary for financial accuracy.
- **Overflow checks**: All arithmetic operations include overflow detection with minimal performance impact.

## Testing

MoneyKit includes a comprehensive test suite built with Swift Testing:

```bash
swift test
```

Every `Money` and `BigMoney` test runs against a shared set of currency
fixtures (`Tests/MoneyKitTests/CurrencyFixture.swift`): ISO currencies at
0, 2, 3, and 4 decimal places, an ISO code without a minor unit (XAU), a
known code at a custom scale (USD at 4), a new code (ZZZ) at 0, 2, and 3,
and extreme scales (1, 8, and 18). Expectations are stated in minor units,
so the same assertions hold for every fixture.

Test coverage:
- ✅ Currency validation and equality
- ✅ Money arithmetic and overflow detection
- ✅ Rounding modes and calculations
- ✅ Distribution and allocation
- ✅ ISO 4217 table snapshot verified against the checked-in registry XML
- ✅ Edge cases and error handling

### Updating the ISO 4217 registry

```bash
python3 Scripts/generate_iso4217.py
```

The script downloads the latest registry from SIX Financial Services, updates
`Resources/iso4217/list-one.xml` only if the published content changed, and
regenerates `Sources/MoneyKit/Currency+ISO4217.generated.swift`. It falls back
to the committed registry copy when offline.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT License - See LICENSE file for details

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and updates.
