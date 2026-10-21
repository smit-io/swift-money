import Foundation

/// A monetary amount at any precision, for calculations in progress.
///
/// `BigMoney` holds a signed `Decimal` in standard units (e.g., 12.3456 for
/// $12.3456) and is never rounded implicitly. Chain multiplications,
/// divisions, and sums on it, then convert back to `Money` with
/// `rounded(_:)` — the one place a rounding decision is made.
///
/// Example:
/// ```swift
/// let price = try Money(amount: 1234, currency: .JPY)
/// let discount = try Money(amount: 100, currency: .JPY)
/// let gross = try price.toBigMoney() * 1.1 - discount // 1257.4, unrounded
/// let total = try gross.rounded(.down)                // ¥1257
/// ```
public struct BigMoney: Sendable, Hashable {
    /// The signed amount in standard currency units (e.g., dollars, not cents).
    public let amount: Decimal

    /// The currency for this monetary amount.
    public let currency: Currency

    /// Creates a BigMoney value with the specified amount and currency.
    ///
    /// - Parameters:
    ///   - amount: The signed amount in standard currency units. A NaN amount
    ///     is kept, and `rounded(_:)` throws `MoneyError.invalidDecimal` for it.
    ///   - currency: The currency for this amount.
    public init(amount: Decimal, currency: Currency) {
        self.amount = amount
        self.currency = currency
    }

    /// Creates a BigMoney value from a `Double` in standard units, converted
    /// through its shortest text (so `12.34` is exactly 12.34).
    ///
    /// - Throws: `MoneyError.invalidDecimal` for NaN, infinity, or an out-of-range value.
    public init(amount: Double, currency: Currency) throws {
        self.init(amount: try Decimal(shortestRepresentationOf: amount), currency: currency)
    }

    /// Creates a BigMoney value from a whole number of standard units.
    public init(amount: Int, currency: Currency) {
        self.init(amount: Decimal(amount), currency: currency)
    }

    /// A zero amount in the given currency.
    public static func zero(_ currency: Currency) -> BigMoney {
        BigMoney(amount: 0, currency: currency)
    }

    /// Rounds to the currency's decimal places, producing `Money`.
    ///
    /// - Parameter mode: How to round digits beyond the currency's decimal places.
    /// - Throws:
    ///   - `MoneyError.invalidDecimal` if the amount is NaN.
    ///   - `MoneyError.amountOverflow` if the rounded amount does not fit in `Money`.
    public func rounded(_ mode: RoundingMode) throws -> Money {
        try Money(decimalAmount: amount, currency: currency, rounding: mode)
    }
}

// MARK: - Sign

extension BigMoney {
    /// Whether the amount is zero.
    public var isZero: Bool {
        amount.isZero
    }

    /// Whether the amount is greater than zero.
    public var isPositive: Bool {
        amount > 0
    }

    /// Whether the amount is less than zero.
    public var isNegative: Bool {
        amount < 0
    }
}

// MARK: - Arithmetic

extension BigMoney {
    /// Adds two BigMoney values.
    ///
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if the currencies don't match.
    ///   - `MoneyError.decimalPlacesMismatch` if the codes match but the decimal places differ.
    public static func + (lhs: BigMoney, rhs: BigMoney) throws -> BigMoney {
        try lhs.currency.requireSame(as: rhs.currency)
        return BigMoney(amount: lhs.amount + rhs.amount, currency: lhs.currency)
    }

    /// Subtracts one BigMoney value from another.
    ///
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if the currencies don't match.
    ///   - `MoneyError.decimalPlacesMismatch` if the codes match but the decimal places differ.
    public static func - (lhs: BigMoney, rhs: BigMoney) throws -> BigMoney {
        try lhs + -rhs
    }

    /// Adds a Money value.
    ///
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if the currencies don't match.
    ///   - `MoneyError.decimalPlacesMismatch` if the codes match but the decimal places differ.
    public static func + (lhs: BigMoney, rhs: Money) throws -> BigMoney {
        try lhs + rhs.toBigMoney()
    }

    /// Subtracts a Money value.
    ///
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if the currencies don't match.
    ///   - `MoneyError.decimalPlacesMismatch` if the codes match but the decimal places differ.
    public static func - (lhs: BigMoney, rhs: Money) throws -> BigMoney {
        try lhs - rhs.toBigMoney()
    }

    /// Multiplies by a decimal. Never rounds.
    public static func * (lhs: BigMoney, rhs: Decimal) -> BigMoney {
        BigMoney(amount: lhs.amount * rhs, currency: lhs.currency)
    }

    /// Divides by a decimal. Never rounds beyond `Decimal`'s 38-digit precision.
    ///
    /// - Throws:
    ///   - `MoneyError.invalidDecimal` if the divisor is NaN.
    ///   - `MoneyError.divisionByZero` if the divisor is zero.
    public static func / (lhs: BigMoney, rhs: Decimal) throws -> BigMoney {
        guard !rhs.isNaN else {
            throw MoneyError.invalidDecimal(.nan)
        }
        guard !rhs.isZero else {
            throw MoneyError.divisionByZero
        }
        return BigMoney(amount: lhs.amount / rhs, currency: lhs.currency)
    }

    /// Multiplies by a `Double`, converted through its shortest text (so
    /// `1.1` is exactly 1.1). Never rounds.
    ///
    /// - Throws: `MoneyError.invalidDecimal` for NaN, infinity, or an out-of-range multiplier.
    public static func * (lhs: BigMoney, rhs: Double) throws -> BigMoney {
        lhs * (try Decimal(shortestRepresentationOf: rhs))
    }

    /// Multiplies by an integer. Never rounds.
    public static func * (lhs: BigMoney, rhs: Int) -> BigMoney {
        lhs * Decimal(rhs)
    }

    /// Divides by a `Double`, converted through its shortest text.
    ///
    /// - Throws:
    ///   - `MoneyError.invalidDecimal` for NaN, infinity, or an out-of-range divisor.
    ///   - `MoneyError.divisionByZero` if the divisor is zero.
    public static func / (lhs: BigMoney, rhs: Double) throws -> BigMoney {
        try lhs / Decimal(shortestRepresentationOf: rhs)
    }

    /// Divides by an integer.
    ///
    /// - Throws: `MoneyError.divisionByZero` if the divisor is zero.
    public static func / (lhs: BigMoney, rhs: Int) throws -> BigMoney {
        try lhs / Decimal(rhs)
    }

    /// Negates the value.
    public static prefix func - (value: BigMoney) -> BigMoney {
        BigMoney(amount: -value.amount, currency: value.currency)
    }

    /// The value without its sign.
    public func abs() -> BigMoney {
        isNegative ? -self : self
    }
}

// MARK: - Comparable

extension BigMoney: Comparable {
    /// Compares two BigMoney values.
    ///
    /// - Note: Only values with the same currency can be compared. Comparing
    ///         different currencies (or the same code at different decimal
    ///         places) is a precondition failure. Use `tryCompare(_:)` for a
    ///         comparison that returns nil on mismatch.
    public static func < (lhs: BigMoney, rhs: BigMoney) -> Bool {
        if let failure = lhs.currency.comparisonFailure(with: rhs.currency, comparing: "BigMoney") {
            preconditionFailure(failure)
        }
        return lhs.amount < rhs.amount
    }

    /// Safely compares two BigMoney values, returning nil if currencies don't match.
    public func tryCompare(_ other: BigMoney) -> ComparisonResult? {
        guard currency == other.currency else { return nil }
        if amount < other.amount {
            return .orderedAscending
        } else if amount > other.amount {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
}

// MARK: - Summation

extension Sequence where Element == BigMoney {
    /// Sums a sequence of BigMoney values. The explicit currency defines the
    /// result for an empty sequence.
    ///
    /// - Throws:
    ///   - `MoneyError.currencyMismatch` if any element differs from `currency`.
    ///   - `MoneyError.decimalPlacesMismatch` if the codes match but the decimal places differ.
    public func sum(in currency: Currency) throws -> BigMoney {
        try reduce(BigMoney.zero(currency), +)
    }
}

// MARK: - CustomStringConvertible

extension BigMoney: CustomStringConvertible {
    /// The currency code and the unrounded amount, e.g. "USD 12.3456".
    public var description: String {
        "\(currency.code) \(amount)"
    }
}

// MARK: - Codable

extension BigMoney: Codable {
    private enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode
        case decimalPlaces
    }

    private static let posix = Locale(identifier: "en_US_POSIX")

    /// Decodes `amount` from a string so no precision is lost to JSON numbers.
    /// `decimalPlaces` is optional: absent means the code's default.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let text = try container.decode(String.self, forKey: .amount)
        guard let amount = Decimal(string: text, locale: Self.posix), !amount.isNaN else {
            throw DecodingError.dataCorruptedError(
                forKey: .amount,
                in: container,
                debugDescription: "Invalid decimal amount: '\(text)'"
            )
        }
        try self.init(
            amount: amount,
            currency: Currency(
                code: container.decode(String.self, forKey: .currencyCode),
                decimalPlaces: container.decodeIfPresent(Int.self, forKey: .decimalPlaces)
            )
        )
    }

    /// Writes `decimalPlaces` only for a custom scale, matching `Money`.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amount.description, forKey: .amount)
        try container.encode(currency.code, forKey: .currencyCode)
        if !currency.hasDefaultDecimalPlaces {
            try container.encode(currency.decimalPlaces, forKey: .decimalPlaces)
        }
    }
}
