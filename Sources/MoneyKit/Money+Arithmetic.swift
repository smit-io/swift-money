import Foundation

// MARK: - Arithmetic Operations

extension Money {
    /// Adds two Money values.
    ///
    /// - Parameters:
    ///   - lhs: The first Money value.
    ///   - rhs: The second Money value.
    /// - Returns: A new Money value representing the sum.
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if the currencies don't match.
    ///   - `MoneyError.amountOverflow` if the sum overflows.
    public static func + (lhs: Money, rhs: Money) throws -> Money {
        guard lhs.currency == rhs.currency else {
            throw MoneyError.currencyMismatch(from: lhs.currency, to: rhs.currency)
        }

        let (result, overflow) = lhs.amount.addingReportingOverflow(rhs.amount)
        guard !overflow else {
            throw MoneyError.amountOverflow(
                description: "Addition overflow: \(lhs.amount) + \(rhs.amount)"
            )
        }

        return try Money(amount: result, currency: lhs.currency)
    }

    /// Subtracts one Money value from another.
    ///
    /// - Parameters:
    ///   - lhs: The Money value to subtract from.
    ///   - rhs: The Money value to subtract.
    /// - Returns: A new Money value representing the difference.
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if the currencies don't match.
    ///   - `MoneyError.negativeAmount` if the result would be negative.
    public static func - (lhs: Money, rhs: Money) throws -> Money {
        guard lhs.currency == rhs.currency else {
            throw MoneyError.currencyMismatch(from: lhs.currency, to: rhs.currency)
        }
        let result = lhs.amount - rhs.amount
        return try Money(amount: result, currency: lhs.currency)
    }

    /// Multiplies a Money value by a scalar.
    ///
    /// - Parameters:
    ///   - lhs: The Money value.
    ///   - rhs: The scalar multiplier.
    /// - Returns: A new Money value representing the product.
    /// - Throws:
    ///   - `MoneyError.negativeAmount` if the multiplier is negative.
    ///   - `MoneyError.amountOverflow` if the product overflows.
    public static func * (lhs: Money, rhs: Int) throws -> Money {
        guard rhs >= 0 else {
            throw MoneyError.negativeAmount(rhs)
        }

        let (result, overflow) = lhs.amount.multipliedReportingOverflow(by: rhs)
        guard !overflow else {
            throw MoneyError.amountOverflow(
                description: "Multiplication overflow: \(lhs.amount) * \(rhs)"
            )
        }

        return try Money(amount: result, currency: lhs.currency)
    }

    /// Multiplies a Money value by a decimal scalar (with rounding).
    ///
    /// - Parameters:
    ///   - lhs: The Money value.
    ///   - rhs: The decimal multiplier.
    /// - Returns: A new Money value representing the product (rounded).
    /// - Throws:
    ///   - `MoneyError.negativeAmount` if the result is negative.
    ///   - `MoneyError.amountOverflow` if the result exceeds Int.max.
    public static func * (lhs: Money, rhs: Decimal) throws -> Money {
        var result = Decimal(lhs.amount) * rhs
        var rounded = Decimal()
        NSDecimalRound(&rounded, &result, 0, .plain)

        // Check for negative BEFORE conversion (int64Value saturates)
        guard rounded >= 0 else {
            throw MoneyError.negativeAmount(Int(clamping: NSDecimalNumber(decimal: rounded).int64Value))
        }

        // Check for overflow BEFORE conversion (int64Value saturates at Int64.max)
        guard rounded <= Decimal(Int.max) else {
            throw MoneyError.amountOverflow(
                description: "Multiplication overflow: \(lhs.amount) * \(rhs) exceeds Int.max"
            )
        }

        let intResult = Int(NSDecimalNumber(decimal: rounded).int64Value)
        return try Money(amount: intResult, currency: lhs.currency)
    }

    /// Divides a Money value by a scalar.
    ///
    /// - Parameters:
    ///   - lhs: The Money value.
    ///   - rhs: The scalar divisor.
    /// - Returns: A new Money value representing the quotient (rounded down).
    /// - Throws:
    ///   - `MoneyError.divisionByZero` if the divisor is zero.
    ///   - `MoneyError.negativeAmount` if the result is negative.
    public static func / (lhs: Money, rhs: Int) throws -> Money {
        guard rhs != 0 else {
            throw MoneyError.divisionByZero
        }
        return try Money(amount: lhs.amount / rhs, currency: lhs.currency)
    }

    /// Distributes a Money value into equal parts.
    ///
    /// This method ensures that the sum of all parts equals the original amount
    /// by distributing any remainder across the first parts.
    ///
    /// - Parameter parts: The number of parts to distribute into (must be > 0).
    /// - Returns: An array of Money values representing the distribution.
    /// - Throws: `MoneyError.divisionByZero` if parts is zero or negative.
    ///
    /// Example:
    /// ```swift
    /// let total = try Money(amount: 100, currency: .USD)
    /// let split = try total.distribute(into: 3)
    /// // Returns [Money(34), Money(33), Money(33)]
    /// ```
    public func distribute(into parts: Int) throws -> [Money] {
        guard parts > 0 else {
            throw MoneyError.divisionByZero
        }

        let baseAmount = amount / parts
        let remainder = amount % parts

        var distribution: [Money] = []
        for i in 0..<parts {
            let extra = i < remainder ? 1 : 0
            let partAmount = baseAmount + extra
            distribution.append(try Money(amount: partAmount, currency: currency))
        }

        return distribution
    }

    /// Allocates a Money value according to specified ratios.
    ///
    /// This method distributes the amount proportionally while ensuring
    /// no money is lost to rounding errors.
    ///
    /// - Parameter ratios: An array of positive integers representing the allocation ratios.
    /// - Returns: An array of Money values representing the allocation.
    /// - Throws: `MoneyError.divisionByZero` if ratios is empty or contains only zeros.
    ///
    /// Example:
    /// ```swift
    /// let total = try Money(amount: 100, currency: .USD)
    /// let allocation = try total.allocate(by: [1, 1, 1])
    /// // Returns [Money(34), Money(33), Money(33)]
    ///
    /// let weighted = try total.allocate(by: [70, 30])
    /// // Returns [Money(70), Money(30)]
    /// ```
    public func allocate(by ratios: [Int]) throws -> [Money] {
        guard !ratios.isEmpty else {
            throw MoneyError.divisionByZero
        }

        let total = ratios.reduce(0, +)
        guard total > 0 else {
            throw MoneyError.divisionByZero
        }

        var allocated: [Money] = []
        var remainder = amount

        for ratio in ratios {
            var share = Decimal(amount) * Decimal(ratio)
            share = share / Decimal(total)
            var rounded = Decimal()
            NSDecimalRound(&rounded, &share, 0, .down)

            // Check for overflow BEFORE conversion (int64Value saturates at Int64.max)
            guard rounded >= 0 && rounded <= Decimal(Int.max) else {
                throw MoneyError.amountOverflow(
                    description: "Allocation overflow: share exceeds Int.max"
                )
            }

            let shareInt = Int(NSDecimalNumber(decimal: rounded).int64Value)
            allocated.append(try Money(amount: shareInt, currency: currency))
            remainder -= shareInt
        }

        // Distribute remainder to maintain exact sum
        for i in 0..<remainder {
            let index = i % allocated.count
            allocated[index] = try Money(amount: allocated[index].amount + 1, currency: currency)
        }

        return allocated
    }

    /// Calculates a percentage of this Money value.
    ///
    /// - Parameter percentage: The percentage as a decimal (e.g., 0.15 for 15%).
    /// - Returns: A new Money value representing the percentage.
    /// - Throws: `MoneyError.negativeAmount` if the result is negative.
    ///
    /// Example:
    /// ```swift
    /// let price = try Money(amount: 10000, currency: .USD) // $100.00
    /// let tax = try price.percentage(0.15) // $15.00
    /// ```
    public func percentage(_ percentage: Decimal) throws -> Money {
        try self * percentage
    }

    /// Checks if this Money value is zero.
    public var isZero: Bool {
        amount == 0
    }

    /// Checks if this Money value is positive (greater than zero).
    public var isPositive: Bool {
        amount > 0
    }

    /// Returns the absolute value (Money amounts are always non-negative, so returns self).
    public var absolute: Money {
        self
    }
}

// MARK: - Signed Arithmetic

extension Money {
    /// This value as a non-negative `SignedMoney`.
    public var signed: SignedMoney {
        SignedMoney(self)
    }

    /// Subtracts another Money value, allowing a negative result.
    ///
    /// Unlike `-`, this never throws `MoneyError.negativeAmount` — the sign
    /// lands in the returned `SignedMoney`.
    ///
    /// - Throws: `MoneyError.currencyMismatch` if the currencies don't match.
    public func minus(_ other: Money) throws -> SignedMoney {
        guard currency == other.currency else {
            throw MoneyError.currencyMismatch(from: currency, to: other.currency)
        }

        return try SignedMoney(amount: amount - other.amount, currency: currency)
    }
}

// MARK: - Safe Arithmetic Methods

extension Money {
    /// Safely adds another Money value, returning nil if currencies don't match or overflow occurs.
    ///
    /// - Parameter other: The Money value to add.
    /// - Returns: The sum, or nil if currencies don't match or overflow occurs.
    public func tryAdd(_ other: Money) -> Money? {
        guard currency == other.currency else { return nil }
        let (result, overflow) = amount.addingReportingOverflow(other.amount)
        guard !overflow else { return nil }
        return try? Money(amount: result, currency: currency)
    }

    /// Safely subtracts another Money value, returning nil if currencies don't match or result is negative.
    ///
    /// - Parameter other: The Money value to subtract.
    /// - Returns: The difference, or nil if currencies don't match or result would be negative.
    public func trySubtract(_ other: Money) -> Money? {
        guard currency == other.currency else { return nil }
        let result = amount - other.amount
        guard result >= 0 else { return nil }
        return try? Money(amount: result, currency: currency)
    }

    /// Safely multiplies by a scalar, returning nil if the result is negative or overflow occurs.
    ///
    /// - Parameter scalar: The multiplier.
    /// - Returns: The product, or nil if the result would be negative or overflow occurs.
    public func tryMultiply(by scalar: Int) -> Money? {
        let (result, overflow) = amount.multipliedReportingOverflow(by: scalar)
        guard !overflow else { return nil }
        guard result >= 0 else { return nil }
        return try? Money(amount: result, currency: currency)
    }

    /// Safely divides by a scalar, returning nil if divisor is zero, overflow occurs, or result is negative.
    ///
    /// - Parameter scalar: The divisor.
    /// - Returns: The quotient, or nil if divisor is zero, overflow occurs, or result would be negative.
    public func tryDivide(by scalar: Int) -> Money? {
        guard scalar != 0 else { return nil }
        let (result, overflow) = amount.dividedReportingOverflow(by: scalar)
        guard !overflow else { return nil }
        guard result >= 0 else { return nil }
        return try? Money(amount: result, currency: currency)
    }
}
