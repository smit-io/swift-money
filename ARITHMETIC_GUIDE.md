# MoneyKit Arithmetic Guide

## Overview

MoneyKit provides type-safe arithmetic operations with precise rounding control. All operations involving floating-point multipliers return a `MoneyCalculation` object that allows you to choose the rounding mode.

## Basic Concepts

### Money Representation
- Amounts are stored as integers in the smallest currency unit (cents, yen, fils, etc.)
- Avoids floating-point precision issues
- Compatible with payment processors

### Rounding Modes

| Mode | Description | Example (1357.4) |
|------|-------------|-----------------|
| `roundedUp` | Round up (ceiling) | 1358 |
| `roundedDown` | Round down (floor) | 1357 |
| `halfUp` | Round 0.5 up | 1357 |
| `bankers` | Round to nearest even | 1357 |
| `value` | Default (banker's) | 1357 |

## Usage Examples

### Basic Multiplication

```swift
let price = try Money(amount: 1234, currency: .JPY)

// Get calculation object
let calc = price * 1.1

// Choose rounding mode
let taxUp = try calc.roundedUp      // 1358 yen
let taxDown = try calc.roundedDown  // 1357 yen
let taxHalf = try calc.halfUp       // 1357 yen
let taxBanker = try calc.bankers    // 1357 yen (default)
let taxDefault = try calc.value     // 1357 yen (same as bankers)
```

### Division

```swift
let total = try Money(amount: 1000, currency: .JPY)

let calc = try total / 3.0

let each = try calc.roundedDown  // 333 yen per person
let eachUp = try calc.roundedUp  // 334 yen per person
```

### Chained Operations

```swift
let originalPrice = try Money(amount: 10000, currency: .JPY)

// 20% discount, then 10% tax
let finalCalc = originalPrice * 0.8 * 1.1

let final = try finalCalc.roundedDown  // 8800 yen
```

### Tax Calculations

```swift
let subtotal = try Money(amount: 1000, currency: .JPY)

// Method 1: Using operators
let withTax = try (subtotal * 1.1).roundedDown

// Method 2: Using convenience method
let withTax2 = try subtotal.withTax()  // Default: 10% tax, round down

// Method 3: Custom tax rate and rounding
let withTax3 = try subtotal.withTax(rate: 1.08, rounding: .up)
```

### Multiple Rounding Options

```swift
let price = try Money(amount: 1234, currency: .JPY)
let calc = price * 1.08

// Compare different rounding modes
print("Round Up:     \(try calc.roundedUp.formatted)")     // ¥1,333
print("Round Down:   \(try calc.roundedDown.formatted)")   // ¥1,332
print("Half Up:      \(try calc.halfUp.formatted)")        // ¥1,333
print("Banker's:     \(try calc.bankers.formatted)")       // ¥1,333
```

## Advanced Usage

### Combining Calculations

```swift
let item1 = try Money(amount: 1000, currency: .JPY)
let item2 = try Money(amount: 500, currency: .JPY)

let calc1 = item1 * 1.1
let calc2 = item2 * 1.1

// Add calculations before rounding
let totalCalc = try calc1 + calc2
let total = try totalCalc.roundedDown  // 1650 yen
```

### Currency-Specific Behavior

```swift
// JPY (0 decimal places)
let yen = try Money(amount: 1000, currency: .JPY)
let yenCalc = yen * 1.08
let yenResult = try yenCalc.roundedDown  // 1080 yen

// USD (2 decimal places)
let usd = try Money(amount: 1999, currency: .USD)  // $19.99
let usdCalc = usd * 1.08
let usdResult = try usdCalc.roundedUp    // $21.59 (2159 cents)

// KWD (3 decimal places)
let kwd = try Money(amount: 1234, currency: .KWD)  // 1.234 KWD
let kwdCalc = kwd * 1.1
let kwdResult = try kwdCalc.roundedDown  // 1.357 KWD (1357 fils)
```

### Explicit Rounding Method

```swift
let price = try Money(amount: 1234, currency: .JPY)

// Using multiply with rounding parameter
let result = try price.multiply(by: 1.1, rounding: .down)

// Using divide with rounding parameter
let divided = try price.divide(by: 3.0, rounding: .up)
```

## Real-World Examples

### E-commerce Checkout

```swift
// Product pricing
let productPrice = try Money(amount: 4999, currency: .USD)  // $49.99
let shipping = try Money(amount: 500, currency: .USD)        // $5.00
let subtotal = try productPrice + shipping                   // $54.99

// Calculate tax (8%)
let taxCalc = subtotal * 1.08
let total = try taxCalc.roundedUp  // $59.39

print("Subtotal: \(subtotal.formatted)")
print("Total with tax: \(total.formatted)")
```

### Bill Splitting

```swift
let billTotal = try Money(amount: 15273, currency: .JPY)

// Split among 4 people
let perPersonCalc = try billTotal / 4.0

let perPersonDown = try perPersonCalc.roundedDown  // 3818 yen
let perPersonUp = try perPersonCalc.roundedUp      // 3819 yen

// Use distribute for exact splitting (no money lost)
let exactSplit = try billTotal.distribute(into: 4)
// [3819, 3818, 3818, 3818] - sum equals exactly 15273
```

### Payment API Integration

```swift
let orderAmount = try Money(amount: 4999, currency: .USD)  // $49.99

// Calculate processing fee (2.9% + $0.30)
let percentageFee = try (orderAmount * 0.029).roundedUp
let fixedFee = try Money(amount: 30, currency: .USD)
let totalFee = try percentageFee + fixedFee

// Net amount after fees
let netAmount = try orderAmount - totalFee

// Send to Payment API
let chargeParams = [
    "amount": orderAmount.amount,
    "currency": orderAmount.currency.code.lowercased()
]
```

### Discount Scenarios

```swift
let originalPrice = try Money(amount: 10000, currency: .JPY)

// Simple 20% off
let discountCalc = originalPrice * 0.8
let salePrice = try discountCalc.roundedDown  // 8000 yen

// Tiered discount with tax
let tier1 = originalPrice * 0.9        // 10% off
let tier2 = originalPrice * 0.8        // 20% off
let tier3 = originalPrice * 0.7        // 30% off

let tier1WithTax = try (tier1 * 1.1).roundedDown
let tier2WithTax = try (tier2 * 1.1).roundedDown
let tier3WithTax = try (tier3 * 1.1).roundedDown
```

## Error Handling

### Division by Zero

```swift
let money = try Money(amount: 1000, currency: .JPY)

do {
    let calc = try money / 0.0
} catch MoneyError.divisionByZero {
    print("Cannot divide by zero")
}
```

### Currency Mismatch

```swift
let jpy = try Money(amount: 1000, currency: .JPY)
let usd = try Money(amount: 1000, currency: .USD)

let calc1 = jpy * 1.1
let calc2 = usd * 1.1

do {
    let combined = try calc1 + calc2
} catch MoneyError.currencyMismatch(let from, let to) {
    print("Cannot add \(from.code) and \(to.code)")
}
```

### Negative Amounts

```swift
let calc = try Money(amount: 100, currency: .JPY) * -1.5

do {
    let result = try calc.roundedDown
} catch MoneyError.negativeAmount(let amount) {
    print("Negative amount not allowed: \(amount)")
}
```

## Best Practices

1. **Always Choose Rounding Explicitly**
   ```swift
   // Good
   let tax = try (price * 1.1).roundedDown

   // Avoid using .value without understanding it's banker's rounding
   let tax = try (price * 1.1).value
   ```

2. **Use Tax-Specific Defaults**
   ```swift
   // In Japan, tax calculations typically round down
   let taxed = try price.withTax()  // Uses .taxDefault (.down)
   ```

3. **Combine Operations Before Rounding**
   ```swift
   // Good - single rounding at the end
   let final = try (price * 0.8 * 1.1).roundedDown

   // Less precise - multiple roundings
   let discount = try (price * 0.8).roundedDown
   let final = try (discount * 1.1).roundedDown
   ```

4. **Handle Errors Gracefully**
   ```swift
   func calculateTax(_ amount: Money, rate: Double) -> Money? {
       try? (amount * rate).roundedDown
   }
   ```

5. **Document Rounding Decisions**
   ```swift
   // Always document why you chose a specific rounding mode
   // Japan's consumption tax law requires rounding down
   let taxAmount = try (subtotal * 1.1).roundedDown
   ```

## Supported Types

- `Double`: Most common, sufficient precision for monetary calculations
- `Float`: Supported but Double is recommended
- `Int`: Exact multiplication (no rounding needed)
- `Decimal`: Supported through `Money * Decimal` in existing operations

## Performance Notes

- `MoneyCalculation` is lightweight and efficient
- Rounding is performed only when calling `.roundedUp`, `.roundedDown`, etc.
- Multiple rounding modes can be obtained from the same calculation without re-computing
- No memory allocations for intermediate calculations

## Migration from Older APIs

If you were using:
```swift
// Old
let result = try money * 1.1  // Error: requires explicit rounding
```

Update to:
```swift
// New
let result = try (money * 1.1).roundedDown
// or
let result = try money.multiply(by: 1.1, rounding: .down)
```
