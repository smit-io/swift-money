import Foundation

// MARK: - Exact Arithmetic

extension Money {
    /// Adds two Money values.
    ///
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if the currencies don't match.
    ///   - `MoneyError.decimalPlacesMismatch` if the codes match but the decimal places differ.
    ///   - `MoneyError.amountOverflow` if the sum overflows.
    public static func + (lhs: Money, rhs: Money) throws -> Money {
        try lhs.currency.requireSame(as: rhs.currency)

        let (result, overflow) = lhs.amount.addingReportingOverflow(rhs.amount)
        guard !overflow else {
            throw MoneyError.amountOverflow(
                description: "Addition overflow: \(lhs.amount) + \(rhs.amount)"
            )
        }

        return try Money(amount: result, currency: lhs.currency)
    }

    /// Subtracts one Money value from another. The result may be negative.
    ///
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if the currencies don't match.
    ///   - `MoneyError.decimalPlacesMismatch` if the codes match but the decimal places differ.
    ///   - `MoneyError.amountOverflow` if the difference overflows.
    public static func - (lhs: Money, rhs: Money) throws -> Money {
        try lhs + -rhs
    }

    /// Multiplies a Money value by an integer. Negative multipliers flip the sign.
    ///
    /// - Throws: `MoneyError.amountOverflow` if the product overflows.
    public static func * (lhs: Money, rhs: Int) throws -> Money {
        let (result, overflow) = lhs.amount.multipliedReportingOverflow(by: rhs)
        guard !overflow else {
            throw MoneyError.amountOverflow(
                description: "Multiplication overflow: \(lhs.amount) * \(rhs)"
            )
        }

        return try Money(amount: result, currency: lhs.currency)
    }

    /// Negates the value. Never throws; zero stays zero.
    public static prefix func - (value: Money) -> Money {
        value.negated()
    }

    /// The value with its sign flipped. Never throws; zero stays zero.
    public func negated() -> Money {
        // amount is never Int.min, so its negation is representable.
        Money(unchecked: -amount, currency: currency)
    }

    /// The value without its sign.
    public func abs() -> Money {
        isNegative ? negated() : self
    }
}

// MARK: - Rounded Arithmetic

extension Money {
    /// Multiplies by a decimal, rounding the result to the currency's decimal places.
    ///
    /// - Parameters:
    ///   - multiplier: The value to multiply by (e.g., 1.1 for +10%).
    ///   - rounding: How to round the result.
    /// - Throws:
    ///   - `MoneyError.invalidDecimal` if the multiplier is NaN.
    ///   - `MoneyError.amountOverflow` if the result is out of range.
    ///
    /// Example:
    /// ```swift
    /// let price = try Money(amount: 1234, currency: .JPY)
    /// let withTax = try price.multiplied(by: 1.1, rounding: .down) // ¥1357
    /// ```
    public func multiplied(by multiplier: Decimal, rounding: RoundingMode) throws -> Money {
        try (toBigMoney() * multiplier).rounded(rounding)
    }

    /// Divides by a decimal, rounding the result to the currency's decimal places.
    ///
    /// - Parameters:
    ///   - divisor: The value to divide by.
    ///   - rounding: How to round the result.
    /// - Throws:
    ///   - `MoneyError.invalidDecimal` if the divisor is NaN.
    ///   - `MoneyError.divisionByZero` if the divisor is zero.
    ///   - `MoneyError.amountOverflow` if the result is out of range.
    public func divided(by divisor: Decimal, rounding: RoundingMode) throws -> Money {
        try (toBigMoney() / divisor).rounded(rounding)
    }

    /// Multiplies by a `Double`, converted through its shortest text (so
    /// `0.07` is exactly 0.07), rounding the result.
    ///
    /// - Throws:
    ///   - `MoneyError.invalidDecimal` for NaN, infinity, or an out-of-range multiplier.
    ///   - `MoneyError.amountOverflow` if the result is out of range.
    public func multiplied(by multiplier: Double, rounding: RoundingMode) throws -> Money {
        try multiplied(by: Decimal(shortestRepresentationOf: multiplier), rounding: rounding)
    }

    /// Multiplies by an integer, rounding the result. Exact for whole-unit
    /// results; prefer `*` when no rounding mode is needed.
    ///
    /// - Throws: `MoneyError.amountOverflow` if the result is out of range.
    public func multiplied(by multiplier: Int, rounding: RoundingMode) throws -> Money {
        try multiplied(by: Decimal(multiplier), rounding: rounding)
    }

    /// Divides by a `Double`, converted through its shortest text, rounding the result.
    ///
    /// - Throws:
    ///   - `MoneyError.invalidDecimal` for NaN, infinity, or an out-of-range divisor.
    ///   - `MoneyError.divisionByZero` if the divisor is zero.
    ///   - `MoneyError.amountOverflow` if the result is out of range.
    public func divided(by divisor: Double, rounding: RoundingMode) throws -> Money {
        try divided(by: Decimal(shortestRepresentationOf: divisor), rounding: rounding)
    }

    /// Divides by an integer, rounding the result.
    ///
    /// - Throws:
    ///   - `MoneyError.divisionByZero` if the divisor is zero.
    ///   - `MoneyError.amountOverflow` if the result is out of range.
    public func divided(by divisor: Int, rounding: RoundingMode) throws -> Money {
        try divided(by: Decimal(divisor), rounding: rounding)
    }

    /// This value as a `BigMoney`, for chained calculations that round once at the end.
    public func toBigMoney() -> BigMoney {
        BigMoney(amount: decimalAmount, currency: currency)
    }
}

// MARK: - Splitting

extension Money {
    /// Distributes the value into equal parts that sum exactly to it.
    ///
    /// Leftover smallest units go one each to the first parts. A negative
    /// value gives negative parts.
    ///
    /// - Parameter parts: The number of parts (must be > 0).
    /// - Throws:
    ///   - `MoneyError.divisionByZero` if parts is zero.
    ///   - `MoneyError.negativePartCount` if parts is negative.
    ///
    /// Example:
    /// ```swift
    /// let total = try Money(amount: 100, currency: .USD)
    /// let split = try total.distribute(into: 3)
    /// // [34, 33, 33] cents
    /// ```
    public func distribute(into parts: Int) throws -> [Money] {
        guard parts >= 0 else {
            throw MoneyError.negativePartCount(parts)
        }
        guard parts > 0 else {
            throw MoneyError.divisionByZero
        }
        return try allocate(by: Array(repeating: 1, count: parts))
    }

    /// Allocates the value according to ratios, keeping the exact sum.
    ///
    /// The magnitude is split proportionally: each share is rounded down,
    /// then the leftover smallest units go one each to the non-zero ratios,
    /// in order from the first. Every part takes this value's sign, so
    /// -$100.00 by `[1, 1, 1]` gives -$33.34, -$33.33, -$33.33. A zero ratio
    /// always receives zero.
    ///
    /// - Parameter ratios: Non-negative integers giving each part's weight.
    /// - Returns: The parts, in the order of `ratios`.
    /// - Throws:
    ///   - `MoneyError.negativeRatio` if any ratio is negative.
    ///   - `MoneyError.amountOverflow` if the ratios sum beyond `Int.max`.
    ///   - `MoneyError.divisionByZero` if ratios is empty or contains only zeros.
    ///
    /// Example:
    /// ```swift
    /// let total = try Money(amount: 100, currency: .USD)
    /// let weighted = try total.allocate(by: [70, 30])
    /// // [70, 30] cents
    /// ```
    public func allocate(by ratios: [Int]) throws -> [Money] {
        var total = 0
        for ratio in ratios {
            guard ratio >= 0 else {
                throw MoneyError.negativeRatio(ratio)
            }
            let (sum, overflow) = total.addingReportingOverflow(ratio)
            guard !overflow else {
                throw MoneyError.amountOverflow(description: "Allocation ratios sum beyond Int.max")
            }
            total = sum
        }
        guard total > 0 else {
            throw MoneyError.divisionByZero
        }

        let magnitude = Swift.abs(amount)
        var shares: [Int] = []
        var remainder = magnitude

        for ratio in ratios {
            var share = Decimal(magnitude) * Decimal(ratio) / Decimal(total)
            var rounded = Decimal()
            NSDecimalRound(&rounded, &share, 0, .down)

            // Check for overflow BEFORE conversion (int64Value saturates at Int64.max)
            guard rounded >= 0 && rounded <= Decimal(Int.max) else {
                throw MoneyError.amountOverflow(
                    description: "Allocation overflow: share exceeds Int.max"
                )
            }

            let shareInt = Int(NSDecimalNumber(decimal: rounded).int64Value)
            shares.append(shareInt)
            remainder -= shareInt
        }

        // Distribute remainder to maintain exact sum. Only non-zero ratios take
        // part: a zero ratio's share is exactly zero, so it lost nothing to rounding.
        let eligible = ratios.indices.filter { ratios[$0] > 0 }
        for i in 0..<remainder {
            shares[eligible[i % eligible.count]] += 1
        }

        // Each share is within 0...magnitude, so it and its negation are valid amounts.
        return shares.map { Money(unchecked: isNegative ? -$0 : $0, currency: currency) }
    }

}

// MARK: - Summation

extension Sequence where Element == Money {
    /// Sums a sequence of Money values. The explicit currency defines the
    /// result for an empty sequence.
    ///
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if any element differs from `currency`.
    ///   - `MoneyError.decimalPlacesMismatch` if the codes match but the decimal places differ.
    ///   - `MoneyError.amountOverflow` if the running total overflows.
    public func sum(in currency: Currency) throws -> Money {
        try reduce(Money.zero(currency), +)
    }
}
