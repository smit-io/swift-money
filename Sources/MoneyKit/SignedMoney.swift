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
    ///   - `MoneyError.amountOverflow` if the sum overflows.
    public static func + (lhs: SignedMoney, rhs: SignedMoney) throws -> SignedMoney {
        guard lhs.currency == rhs.currency else {
            throw MoneyError.currencyMismatch(from: lhs.currency, to: rhs.currency)
        }

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

// MARK: - Comparable

extension SignedMoney: Comparable {
    /// Compares two SignedMoney values of the same currency.
    ///
    /// - Precondition: Both values must have the same currency.
    public static func < (lhs: SignedMoney, rhs: SignedMoney) -> Bool {
        precondition(
            lhs.currency == rhs.currency,
            "Cannot compare SignedMoney with different currencies: \(lhs.currency.code) vs \(rhs.currency.code)"
        )
        return lhs.amount < rhs.amount
    }
}

// MARK: - CustomStringConvertible

extension SignedMoney: CustomStringConvertible {
    public var description: String {
        isNegative ? "-\(magnitude.description)" : magnitude.description
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
