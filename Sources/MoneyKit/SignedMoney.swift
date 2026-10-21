import Foundation

/// A signed monetary value: a sign plus a non-negative `Money` magnitude.
///
/// `Money` enforces `amount >= 0`, so subtraction that would go negative
/// throws. `SignedMoney` is the escape hatch for values that legitimately
/// carry a sign — net balances, refunds, deltas — while reusing `Money`'s
/// invariants for the magnitude. Get one from `Money.minus(_:)` or
/// `Money.signed`, and convert back via `money` once the sign is resolved.
public struct SignedMoney: Sendable, Hashable {
    /// The absolute value. Its non-negative invariant comes from `Money`.
    public let magnitude: Money

    /// Whether the value is below zero. Normalized: always `false` when the
    /// magnitude is zero, so `-0 == +0` under `Equatable`/`Hashable`.
    public let isNegative: Bool

    /// Wraps a Money value as a non-negative SignedMoney.
    public init(_ money: Money) {
        self.magnitude = money
        self.isNegative = false
    }

    /// Creates a signed value from a signed amount in the smallest currency unit.
    ///
    /// - Throws: `MoneyError.amountOverflow` if `amount == Int.min` (its
    ///   magnitude is not representable).
    public init(amount: Int, currency: Currency) throws {
        guard amount != Int.min else {
            throw MoneyError.amountOverflow(
                description: "Signed amount \(amount) has no representable magnitude"
            )
        }
        self.magnitude = try Money(amount: abs(amount), currency: currency)
        self.isNegative = amount < 0
    }

    private init(magnitude: Money, isNegative: Bool) {
        self.magnitude = magnitude
        self.isNegative = isNegative && !magnitude.isZero
    }

    /// The signed amount in the smallest currency unit.
    public var amount: Int {
        isNegative ? -magnitude.amount : magnitude.amount
    }

    /// The currency of the value.
    public var currency: Currency {
        magnitude.currency
    }

    /// The signed decimal amount in standard units (e.g. -19.99 for -1999 cents).
    public var decimalAmount: Decimal {
        isNegative ? -magnitude.decimalAmount : magnitude.decimalAmount
    }

    /// The value as `Money`, or `nil` if it is negative.
    public var money: Money? {
        isNegative ? nil : magnitude
    }

    /// The absolute value, dropping the sign.
    public var absolute: Money {
        magnitude
    }

    /// Whether the value is zero.
    public var isZero: Bool {
        magnitude.isZero
    }

    /// Whether the value is greater than zero.
    public var isPositive: Bool {
        !isNegative && !magnitude.isZero
    }

    /// A zero value in the given currency — the natural starting point for
    /// running balances.
    public static func zero(_ currency: Currency) -> SignedMoney {
        // Zero can never violate Money's non-negative invariant.
        SignedMoney(try! Money(amount: 0, currency: currency))
    }
}

// MARK: - Arithmetic

extension SignedMoney {
    /// Negates the value. Never throws; zero stays zero.
    public static prefix func - (value: SignedMoney) -> SignedMoney {
        SignedMoney(magnitude: value.magnitude, isNegative: !value.isNegative)
    }

    /// Adds two SignedMoney values.
    ///
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if the currencies don't match.
    ///   - `MoneyError.decimalPlacesMismatch` if the codes match but the decimal places differ.
    ///   - `MoneyError.amountOverflow` if the sum overflows.
    public static func + (lhs: SignedMoney, rhs: SignedMoney) throws -> SignedMoney {
        try lhs.currency.requireSame(as: rhs.currency)

        let (result, overflow) = lhs.amount.addingReportingOverflow(rhs.amount)
        guard !overflow else {
            throw MoneyError.amountOverflow(
                description: "Addition overflow: \(lhs.amount) + \(rhs.amount)"
            )
        }

        return try SignedMoney(amount: result, currency: lhs.currency)
    }

    /// Subtracts one SignedMoney value from another. Never throws on a
    /// negative result — that is the point of this type.
    ///
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if the currencies don't match.
    ///   - `MoneyError.decimalPlacesMismatch` if the codes match but the decimal places differ.
    ///   - `MoneyError.amountOverflow` if the difference overflows.
    public static func - (lhs: SignedMoney, rhs: SignedMoney) throws -> SignedMoney {
        try lhs + -rhs
    }

    /// Multiplies a SignedMoney value by a scalar. Negative scalars flip the sign.
    ///
    /// - Throws: `MoneyError.amountOverflow` if the product overflows.
    public static func * (lhs: SignedMoney, rhs: Int) throws -> SignedMoney {
        let (result, overflow) = lhs.amount.multipliedReportingOverflow(by: rhs)
        guard !overflow else {
            throw MoneyError.amountOverflow(
                description: "Multiplication overflow: \(lhs.amount) * \(rhs)"
            )
        }

        return try SignedMoney(amount: result, currency: lhs.currency)
    }

    /// Divides a SignedMoney value by a scalar, truncating toward zero
    /// (matching `Money`'s integer division).
    ///
    /// - Throws: `MoneyError.divisionByZero` if the divisor is zero.
    public static func / (lhs: SignedMoney, rhs: Int) throws -> SignedMoney {
        guard rhs != 0 else {
            throw MoneyError.divisionByZero
        }

        return try SignedMoney(amount: lhs.amount / rhs, currency: lhs.currency)
    }
}

// MARK: - Allocation

extension SignedMoney {
    /// Allocates this value according to ratios, keeping the exact sum.
    ///
    /// The magnitude is split with `Money.allocate(by:)` and every part takes
    /// this value's sign, so the parts always add up to this value: -$100.00
    /// by `[1, 1, 1]` gives -$33.34, -$33.33, -$33.33. A zero ratio always
    /// receives zero, which is never negative.
    ///
    /// - Parameter ratios: An array of non-negative integers representing the allocation ratios.
    /// - Returns: The parts, in the order of `ratios`.
    /// - Throws: `MoneyError.divisionByZero` if ratios is empty or contains only zeros.
    public func allocate(by ratios: [Int]) throws -> [SignedMoney] {
        try magnitude.allocate(by: ratios).map { isNegative ? -$0 : $0.signed }
    }
}

// MARK: - Mixed Money/SignedMoney Arithmetic

// Promotion rule: once a signed value enters an expression, the result stays
// signed. Lets balance-style code read naturally: `balance = try balance - rent`.
extension SignedMoney {
    /// Adds a `Money` value to a signed value.
    ///
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if the currencies don't match.
    ///   - `MoneyError.decimalPlacesMismatch` if the codes match but the decimal places differ.
    ///   - `MoneyError.amountOverflow` if the sum overflows.
    public static func + (lhs: SignedMoney, rhs: Money) throws -> SignedMoney {
        try lhs + rhs.signed
    }

    /// Subtracts a `Money` value from a signed value.
    ///
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if the currencies don't match.
    ///   - `MoneyError.decimalPlacesMismatch` if the codes match but the decimal places differ.
    ///   - `MoneyError.amountOverflow` if the difference overflows.
    public static func - (lhs: SignedMoney, rhs: Money) throws -> SignedMoney {
        try lhs - rhs.signed
    }

    /// Adds a signed value to a `Money` value.
    ///
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if the currencies don't match.
    ///   - `MoneyError.decimalPlacesMismatch` if the codes match but the decimal places differ.
    ///   - `MoneyError.amountOverflow` if the sum overflows.
    public static func + (lhs: Money, rhs: SignedMoney) throws -> SignedMoney {
        try lhs.signed + rhs
    }

    /// Subtracts a signed value from a `Money` value.
    ///
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if the currencies don't match.
    ///   - `MoneyError.decimalPlacesMismatch` if the codes match but the decimal places differ.
    ///   - `MoneyError.amountOverflow` if the difference overflows.
    public static func - (lhs: Money, rhs: SignedMoney) throws -> SignedMoney {
        try lhs.signed - rhs
    }

}

// The remaining bridge, `prefix -(Money) -> SignedMoney`, lives in
// Money+Arithmetic.swift: a member operator must take its enclosing type as
// an argument, so it cannot be declared in this extension.

// MARK: - Comparable

extension SignedMoney: Comparable {
    /// Compares two SignedMoney values of the same currency.
    ///
    /// - Precondition: Both values must have the same currency.
    public static func < (lhs: SignedMoney, rhs: SignedMoney) -> Bool {
        if let mismatch = lhs.currency.mismatch(with: rhs.currency) {
            preconditionFailure("Cannot compare SignedMoney values. \(mismatch.errorDescription ?? "")")
        }
        return lhs.amount < rhs.amount
    }
}

// MARK: - Formatting

extension SignedMoney {
    /// Returns a locale-aware formatted string, letting the formatter place
    /// the negative sign (e.g. "-$10.00", "-10,00 €").
    public var formatted: String {
        formatted(locale: .current)
    }

    /// Returns a formatted string using a specific locale.
    public func formatted(locale: Locale) -> String {
        Money.formatCurrency(decimalAmount, currency: currency, locale: locale)
    }

    /// Returns a numeric string representation without currency symbols,
    /// pinned to a machine-parseable dot-decimal format on every host locale.
    ///
    /// Example: "-19.99" for -$19.99
    public var numericString: String {
        Money.formatNumeric(decimalAmount, currency: currency)
    }
}

// MARK: - CustomStringConvertible

extension SignedMoney: CustomStringConvertible {
    public var description: String {
        formatted
    }
}

// MARK: - Codable

extension SignedMoney: Codable {
    private enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            amount: container.decode(Int.self, forKey: .amount),
            currency: Currency(code: container.decode(String.self, forKey: .currencyCode))
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amount, forKey: .amount)
        try container.encode(currency.code, forKey: .currencyCode)
    }
}
