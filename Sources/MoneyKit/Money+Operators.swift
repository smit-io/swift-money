import Foundation

// MARK: - Decimal Arithmetic Operators

extension Money {
    /// Multiply Money by a Double, returning a MoneyCalculation for flexible rounding.
    ///
    /// - Parameters:
    ///   - lhs: The Money value
    ///   - rhs: The multiplier
    /// - Returns: A MoneyCalculation that can be rounded with different modes
    ///
    /// Example:
    /// ```swift
    /// let price = try Money(amount: 1234, currency: .JPY)
    /// let calc = price * 1.1
    /// let taxUp = try calc.roundedUp      // 1358
    /// let taxDown = try calc.roundedDown  // 1357
    /// ```
    public static func * (lhs: Money, rhs: Double) -> MoneyCalculation {
        MoneyCalculation(
            decimalAmount: lhs.decimalAmount * Decimal(rhs),
            currency: lhs.currency
        )
    }

    /// Multiply Money by a Float, returning a MoneyCalculation for flexible rounding.
    public static func * (lhs: Money, rhs: Float) -> MoneyCalculation {
        lhs * Double(rhs)
    }

    /// Divide Money by a Double, returning a MoneyCalculation for flexible rounding.
    ///
    /// - Parameters:
    ///   - lhs: The Money value
    ///   - rhs: The divisor
    /// - Returns: A MoneyCalculation that can be rounded with different modes
    /// - Throws: `MoneyError.divisionByZero` if divisor is zero
    ///
    /// Example:
    /// ```swift
    /// let total = try Money(amount: 1000, currency: .JPY)
    /// let calc = try total / 3.0
    /// let each = try calc.roundedDown  // 333
    /// ```
    public static func / (lhs: Money, rhs: Double) throws -> MoneyCalculation {
        guard rhs != 0 else {
            throw MoneyError.divisionByZero
        }
        return MoneyCalculation(
            decimalAmount: lhs.decimalAmount / Decimal(rhs),
            currency: lhs.currency
        )
    }

    /// Divide Money by a Float, returning a MoneyCalculation for flexible rounding.
    public static func / (lhs: Money, rhs: Float) throws -> MoneyCalculation {
        try lhs / Double(rhs)
    }
}

// MARK: - Convenience Methods

extension Money {
    /// Multiply with explicit rounding mode
    ///
    /// - Parameters:
    ///   - multiplier: The value to multiply by
    ///   - rounding: The rounding mode (default: banker's rounding)
    /// - Returns: A Money value with the specified rounding applied
    /// - Throws: `MoneyError.negativeAmount` if result is negative
    public func multiply(
        by multiplier: Double,
        rounding: RoundingMode = .default
    ) throws -> Money {
        try (self * multiplier).rounded(rounding)
    }

    /// Divide with explicit rounding mode
    ///
    /// - Parameters:
    ///   - divisor: The value to divide by
    ///   - rounding: The rounding mode (default: banker's rounding)
    /// - Returns: A Money value with the specified rounding applied
    /// - Throws:
    ///   - `MoneyError.divisionByZero` if divisor is zero
    ///   - `MoneyError.negativeAmount` if result is negative
    public func divide(
        by divisor: Double,
        rounding: RoundingMode = .default
    ) throws -> Money {
        try (self / divisor).rounded(rounding)
    }

    /// Calculate tax amount (convenience method)
    ///
    /// - Parameters:
    ///   - rate: Tax rate as multiplier (e.g., 1.1 for 10% tax)
    ///   - rounding: The rounding mode (default: round down)
    /// - Returns: A Money value with tax applied
    /// - Throws: `MoneyError.negativeAmount` if result is negative
    ///
    /// Example:
    /// ```swift
    /// let price = try Money(amount: 1000, currency: .JPY)
    /// let withTax = try price.withTax(rate: 1.1)  // 1100 (rounded down)
    /// ```
    public func withTax(
        rate: Double = 1.1,
        rounding: RoundingMode = .taxDefault
    ) throws -> Money {
        try multiply(by: rate, rounding: rounding)
    }
}
