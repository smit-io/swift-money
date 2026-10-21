import Foundation

/// A monetary amount in the smallest currency unit (integer-based).
///
/// `Money` holds a signed integer amount (e.g., cents for USD, yen for JPY)
/// along with its currency. Amounts may be negative — net balances, refunds,
/// and deltas are all plain `Money`. Arithmetic that stays in whole minor
/// units is exact; anything that can produce a fraction of a minor unit takes
/// an explicit `RoundingMode`, or goes through `BigMoney` to round once at
/// the end.
///
/// Example:
/// ```swift
/// let price = try Money(amount: 1999, currency: .USD) // $19.99
/// let refund = try Money(amount: 2500, currency: .USD) // $25.00
/// let net = try price - refund // -$5.01
/// print(net.formatted) // "-$5.01"
/// ```
public struct Money: Sendable, Hashable, Codable {
    /// The amount in the smallest currency unit (e.g., cents, pence, yen).
    /// Never `Int.min`, so negation and `abs()` cannot overflow.
    public let amount: Int

    /// The currency for this monetary amount.
    public let currency: Currency

    /// Creates a Money value with the specified amount and currency.
    ///
    /// - Parameters:
    ///   - amount: The signed amount in the smallest currency unit.
    ///   - currency: The currency for this amount.
    /// - Throws: `MoneyError.amountOverflow` if `amount == Int.min` (its
    ///   negation is not representable).
    public init(amount: Int, currency: Currency) throws {
        guard amount != Int.min else {
            throw MoneyError.amountOverflow(
                description: "Amount \(amount) has no representable negation"
            )
        }
        self.init(unchecked: amount, currency: currency)
    }

    /// Creates a Money value from an ISO 4217 currency code string.
    ///
    /// - Parameters:
    ///   - amount: The signed amount in the smallest currency unit.
    ///   - currencyCode: The ISO 4217 currency code (e.g., "USD", "EUR").
    /// - Throws:
    ///   - `MoneyError.amountOverflow` if `amount == Int.min`.
    ///   - `CurrencyError.invalidFormat` if the currency code is invalid.
    public init(amount: Int, currencyCode: String) throws {
        let currency = try Currency(code: currencyCode)
        try self.init(amount: amount, currency: currency)
    }

    /// Creates a Money value from a decimal amount in standard units (e.g.,
    /// 19.99 for $19.99), rounding to the currency's decimal places.
    ///
    /// - Parameters:
    ///   - decimalAmount: The amount in standard currency units (e.g., dollars, euros).
    ///   - currency: The currency for this amount.
    ///   - rounding: How to round digits beyond the currency's decimal places.
    /// - Throws: `MoneyError.amountOverflow` if the rounded amount is outside
    ///   `-Int.max...Int.max`.
    public init(decimalAmount: Decimal, currency: Currency, rounding: RoundingMode) throws {
        var scaled = decimalAmount * pow(Decimal(10), currency.decimalPlaces)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, rounding.nsRoundingMode(for: scaled))

        // Range-check BEFORE conversion: int64Value saturates out of range.
        guard rounded >= Decimal(-Int.max), rounded <= Decimal(Int.max) else {
            throw MoneyError.amountOverflow(
                description: "Amount \(decimalAmount) exceeds the range for \(currency.code)"
            )
        }

        self.init(unchecked: Int(NSDecimalNumber(decimal: rounded).int64Value), currency: currency)
    }

    /// Skips the `Int.min` check. Callers must guarantee `amount != Int.min`.
    init(unchecked amount: Int, currency: Currency) {
        self.amount = amount
        self.currency = currency
    }

    /// A zero amount in the given currency.
    public static func zero(_ currency: Currency) -> Money {
        Money(unchecked: 0, currency: currency)
    }

    // MARK: - Computed Properties

    /// The signed amount as a Decimal in standard currency units (e.g., 19.99 for $19.99).
    ///
    /// This provides a precise decimal representation without floating-point loss.
    public var decimalAmount: Decimal {
        Decimal(amount) * currency.divisor
    }

    /// Returns a formatted string representation of the money value.
    ///
    /// Uses the device's current locale to format with appropriate currency symbol
    /// and decimal places.
    ///
    /// Example: "$19.99", "¥1000", "€25.50"
    public var formatted: String {
        Self.formatCurrency(decimalAmount, currency: currency, locale: .current)
    }

    /// Returns a formatted string using a specific locale.
    ///
    /// - Parameter locale: The locale to use for formatting.
    /// - Returns: A formatted currency string.
    public func formatted(locale: Locale) -> String {
        Self.formatCurrency(decimalAmount, currency: currency, locale: locale)
    }

    /// Returns a numeric string representation without currency symbols.
    ///
    /// Example: "19.99" for $19.99, "1000" for ¥1000
    public var numericString: String {
        Self.formatNumeric(decimalAmount, currency: currency)
    }

    // MARK: - Formatting Implementation

    static func formatCurrency(
        _ amount: Decimal,
        currency: Currency,
        locale: Locale
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        formatter.locale = locale
        formatter.minimumFractionDigits = currency.decimalPlaces
        formatter.maximumFractionDigits = currency.decimalPlaces

        return formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? formatNumeric(amount, currency: currency)
    }

    static func formatNumeric(
        _ amount: Decimal,
        currency: Currency
    ) -> String {
        // Pinned so numericString is a stable, machine-parseable dot-decimal
        // string on every host locale; formatted(locale:) is the display path.
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = currency.decimalPlaces
        formatter.maximumFractionDigits = currency.decimalPlaces

        return formatter.string(from: NSDecimalNumber(decimal: amount))
            ?? "\(amount)"
    }
}

// MARK: - CustomStringConvertible

extension Money: CustomStringConvertible {
    public var description: String {
        formatted
    }
}

// MARK: - Sign

extension Money {
    /// Whether the amount is zero.
    public var isZero: Bool {
        amount == 0
    }

    /// Whether the amount is greater than zero.
    public var isPositive: Bool {
        amount > 0
    }

    /// Whether the amount is less than zero.
    public var isNegative: Bool {
        amount < 0
    }

    /// Whether the amount is zero or greater.
    public var isPositiveOrZero: Bool {
        amount >= 0
    }

    /// Whether the amount is zero or less.
    public var isNegativeOrZero: Bool {
        amount <= 0
    }
}

// MARK: - Comparable

extension Money: Comparable {
    /// Compares two Money values.
    ///
    /// - Note: Only Money values with the same currency can be compared.
    ///         Comparing different currencies (or the same code at different
    ///         decimal places) will result in a precondition failure.
    ///         Use `tryCompare(_:)` for safe comparison that returns nil on mismatch.
    public static func < (lhs: Money, rhs: Money) -> Bool {
        if let mismatch = lhs.currency.mismatch(with: rhs.currency) {
            preconditionFailure("Cannot compare Money values. \(mismatch.errorDescription ?? "")")
        }
        return lhs.amount < rhs.amount
    }

    /// Safely compares two Money values, returning nil if currencies don't match.
    ///
    /// - Parameter other: The Money value to compare against.
    /// - Returns: The comparison result, or nil if currencies don't match.
    public func tryCompare(_ other: Money) -> ComparisonResult? {
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

// MARK: - Codable

extension Money {
    enum CodingKeys: String, CodingKey {
        case amount
        case currencyCode
        case decimalPlaces
    }

    /// `decimalPlaces` is optional: absent means the code's default.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            amount: container.decode(Int.self, forKey: .amount),
            currency: Currency(
                code: container.decode(String.self, forKey: .currencyCode),
                decimalPlaces: container.decodeIfPresent(Int.self, forKey: .decimalPlaces)
            )
        )
    }

    /// Writes `decimalPlaces` only for a custom scale, so payloads for
    /// default currencies stay `{"amount":…,"currencyCode":…}`.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amount, forKey: .amount)
        try container.encode(currency.code, forKey: .currencyCode)
        if !currency.hasDefaultDecimalPlaces {
            try container.encode(currency.decimalPlaces, forKey: .decimalPlaces)
        }
    }
}
