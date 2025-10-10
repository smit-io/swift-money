# MoneyKit

A type-safe Swift library for representing and manipulating monetary values with precision and safety.

## Features

- 💰 **Integer-based Representation**: Stores amounts as integers in the smallest currency unit (cents, pence, yen, etc.)
- 🌍 **ISO 4217 Support**: Built-in support for standard currency codes with correct decimal places
- 🔒 **Type Safety**: Prevents mixing different currencies and negative amounts at compile time
- ⚡ **Swift Concurrency**: Full `Sendable` conformance for safe concurrent usage
- 🧮 **Precise Arithmetic**: Uses `Decimal` internally to avoid floating-point precision issues
- 🎯 **Flexible Rounding**: Multiple rounding modes (up, down, banker's, half-up) for calculations
- 🛡️ **Overflow Protection**: Built-in overflow detection for all arithmetic operations
- 🌐 **Localization**: Automatic currency formatting based on locale
- 📊 **Rich API**: Arithmetic operations, splitting, allocation, and percentage calculations
- ✅ **Well Tested**: Comprehensive test suite with 102 tests

## Requirements

- Swift 6.0+
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+ / visionOS 1.0+

## Installation

### Swift Package Manager

Add MoneyKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/1amageek/swift-money.git", from: "1.0.0")
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

MoneyKit uses `Int` to store amounts in the smallest currency unit. The maximum representable amounts are:

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
let shipping = try Money(decimalAmount: 5.00, currency: .USD)

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

// From decimal amount (convenience)
let price = try Money(decimalAmount: 49.99, currency: .USD)

// From currency code string
let eur = try Money(amount: 5000, currencyCode: "EUR")
```

### Currency Support

MoneyKit includes built-in support for ISO 4217 currencies with automatic decimal place detection:

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

All arithmetic operations are type-safe and throw errors for currency mismatches:

```swift
let price = try Money(amount: 10000, currency: .USD)  // $100.00
let discount = try Money(amount: 1500, currency: .USD)  // $15.00

// Addition
let total = try price + discount  // $115.00

// Subtraction
let final = try price - discount  // $85.00

// Multiplication by integer
let bulk = try price * 5  // $500.00

// Multiplication by decimal (basic)
let withTax = try price * Decimal(1.08)  // $108.00

// Division
let half = try price / 2  // $50.00

// Percentage
let tax = try price.percentage(0.08)  // $8.00
```

### Flexible Rounding with MoneyCalculation

For operations requiring precise rounding control, use the operator-based calculation API:

```swift
let price = try Money(amount: 1234, currency: .JPY)  // ¥1234

// Multiply returns a MoneyCalculation
let calc = price * 1.1  // ¥1357.4 (not yet rounded)

// Choose your rounding mode
let roundedUp = try calc.roundedUp      // ¥1358
let roundedDown = try calc.roundedDown  // ¥1357
let halfUp = try calc.halfUp            // ¥1357
let bankers = try calc.bankers          // ¥1357 (banker's rounding)
let value = try calc.value              // ¥1357 (uses banker's rounding)
```

### Rounding Modes

MoneyKit supports multiple rounding strategies:

| Mode | Description | Example: 1357.4 → | Example: 1357.5 → |
|------|-------------|-------------------|-------------------|
| `.up` | Round toward positive infinity (ceiling) | 1358 | 1358 |
| `.down` | Round toward zero (floor) | 1357 | 1357 |
| `.halfUp` | Round 0.5 up (commercial rounding) | 1357 | 1358 |
| `.bankers` | Round to nearest even (default) | 1357 | 1358 |
| `.towardZero` | Truncate toward zero | 1357 | 1357 |
| `.awayFromZero` | Round away from zero | 1358 | 1358 |

```swift
// Convenience methods with explicit rounding
let price = try Money(amount: 1000, currency: .JPY)

let result1 = try price.multiply(by: 1.08, rounding: .up)    // ¥1080
let result2 = try price.multiply(by: 1.08, rounding: .down)  // ¥1080
let result3 = try price.divide(by: 3.0, rounding: .up)       // ¥334
let result4 = try price.divide(by: 3.0, rounding: .down)     // ¥333
```

### Tax Calculation (Japanese Consumption Tax Example)

```swift
// Product price: ¥1,234
let price = try Money(amount: 1234, currency: .JPY)

// Apply 10% consumption tax (消費税)
let calc = price * 1.1  // ¥1357.4

// Tax-inclusive price (round down per Japanese tax law)
let taxInclusive = try calc.roundedDown  // ¥1,357

// Alternative: Use convenience method
let taxInclusive2 = try price.withTax()  // ¥1,358 (default 10% tax, banker's rounding)
let taxInclusive3 = try price.withTax(rate: 1.08, rounding: .down)  // ¥1,332 (8% reduced rate)
```

### Advanced Calculations

Chain multiple operations before final rounding:

```swift
let basePrice = try Money(amount: 10000, currency: .JPY)  // ¥10,000

// Discount 20%, then add 10% tax
let discounted = basePrice * 0.8      // MoneyCalculation: ¥8,000
let withTax = discounted * 1.1        // MoneyCalculation: ¥8,800
let final = try withTax.roundedDown   // Money: ¥8,800

// Or combine calculations
let calc1 = basePrice * 0.8
let calc2 = try Money(amount: 500, currency: .JPY) * 1.0
let combined = try calc1 + calc2      // MoneyCalculation
let result = try combined.roundedUp   // Money
```

### Safe Arithmetic (No Throwing)

For situations where you want to handle mismatches gracefully:

```swift
let usd = try Money(amount: 100, currency: .USD)
let eur = try Money(amount: 100, currency: .EUR)

// Returns nil instead of throwing
if let result = usd.tryAdd(eur) {
    print(result)
} else {
    print("Currency mismatch")
}

// Also available: trySubtract, tryMultiply, tryDivide
```

### Distribution & Allocation

Split money while ensuring no value is lost to rounding:

```swift
let total = try Money(amount: 100, currency: .USD)

// Equal distribution
let parts = try total.distribute(into: 3)
// [Money(34), Money(33), Money(33)] - remainder distributed to first parts

// Verify sum is preserved
let sum = parts.reduce(0) { $0 + $1.amount }  // 100 ✓

// Weighted allocation
let allocation = try total.allocate(by: [70, 30])
// [Money(70), Money(30)]

// Complex ratios
let shares = try total.allocate(by: [1, 2, 3])
// Distributes proportionally: ~17%, ~33%, ~50%
```

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
    // Negative amounts are rejected
    let invalid = try Money(amount: -100, currency: .USD)
} catch MoneyError.negativeAmount(let amount) {
    print("Amount cannot be negative: \(amount)")
}

do {
    // Currency mismatch in operations
    let usd = try Money(amount: 100, currency: .USD)
    let eur = try Money(amount: 100, currency: .EUR)
    let total = try usd + eur
} catch MoneyError.currencyMismatch(let from, let to) {
    print("Cannot add \(from.code) to \(to.code)")
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
    let result = try money / 0
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
let taxRate = Decimal(0.085)
let tax = try subtotal.percentage(taxRate)  // $4.67

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
let withTax = subtotal * 1.1
let total = try withTax.roundedDown  // ¥1,907

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
let orderTotal = try Money(decimalAmount: 49.99, currency: .USD)

// Send to Payment API
let chargeParams = [
    "amount": orderTotal.amount,  // 4999
    "currency": orderTotal.currency.code.lowercased()  // "usd"
]

// Calculate processing fees (2.9% + $0.30)
let percentageFee = try orderTotal.percentage(0.029)  // $1.45
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

// Calculate prorated amount
let dailyRate = try monthlyPrice / daysInMonth  // $1.00 per day
let proratedAmount = try dailyRate * daysUsed   // $15.00

print("Prorated charge: \(proratedAmount.formatted)")
```

### 7. Discount Calculations

```swift
let originalPrice = try Money(amount: 10000, currency: .USD)  // $100.00

// 20% off discount
let discount = try originalPrice.percentage(0.20)  // $20.00
let salePrice = try originalPrice - discount       // $80.00

// Or directly
let salePrice2 = try originalPrice * Decimal(0.80)  // $80.00

// Black Friday: Additional 15% off sale price
let calc = salePrice * 0.85
let finalPrice = try calc.roundedDown  // $68.00
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

### Concurrency Safety

MoneyKit types are fully `Sendable` and safe to use across concurrency boundaries:

```swift
actor PriceCalculator {
    func calculateTotal(_ items: [Money]) async throws -> Money {
        guard let firstCurrency = items.first?.currency else {
            throw MoneyError.divisionByZero  // Or custom error
        }

        var total = try Money(amount: 0, currency: firstCurrency)
        for item in items {
            total = try total + item
        }
        return total
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
8. **Use MoneyCalculation**: For complex calculations, use operator-based API and defer rounding to the final step

## Zero-Decimal Currencies

Some currencies like JPY don't use decimal places:

```swift
let yen = try Money(amount: 1000, currency: .JPY)
print(yen.decimalAmount)  // 1000 (not 10.00)
print(yen.formatted)  // "¥1,000"

// Creating from decimal (no rounding needed)
let yen2 = try Money(decimalAmount: 5000, currency: .JPY)  // ¥5,000
```

Supported zero-decimal currencies: **BIF, CLP, DJF, GNF, JPY, KMF, KRW, MGA, PYG, RWF, UGX, VND, VUV, XAF, XOF, XPF**

## Three-Decimal Currencies

Some currencies use 3 decimal places:

```swift
let dinar = try Money(amount: 1234, currency: .KWD)
print(dinar.decimalAmount)  // 1.234
print(dinar.formatted)  // "KD 1.234" (depending on locale)

// 1 fils is the smallest unit
let fils = try Money(amount: 1, currency: .KWD)  // KD 0.001
```

Supported three-decimal currencies: **BHD, IQD, JOD, KWD, LYD, OMR, TND**

## Performance Considerations

- **NumberFormatter**: MoneyKit creates new `NumberFormatter` instances for each formatting operation to ensure thread safety. For high-frequency formatting, consider caching results at the application level.
- **Decimal arithmetic**: Internal calculations use `Decimal` for precision, which is slower than floating-point but necessary for financial accuracy.
- **Overflow checks**: All arithmetic operations include overflow detection with minimal performance impact.

## Testing

MoneyKit includes a comprehensive test suite built with Swift Testing:

```bash
swift test
```

Test coverage:
- ✅ 102 tests across 4 test suites
- ✅ Currency validation and equality
- ✅ Money arithmetic and overflow detection
- ✅ Rounding modes and calculations
- ✅ Distribution and allocation
- ✅ Edge cases and error handling

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

MIT License - See LICENSE file for details

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and updates.
