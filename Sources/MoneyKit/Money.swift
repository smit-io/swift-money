import Foundation

/// A value type representing a monetary amount in the smallest unit (integer-based).
///
/// `Money` holds an integer amount (e.g., cents for USD, yen for JPY) along with
/// its associated currency. This design avoids floating-point precision issues
/// and aligns with payment processor APIs.
///
/// Example:
/// ```swift
/// let price = try Money(amount: 1999, currency: .USD) // $19.99
/// let tax = try Money(amount: 159, currencyCode: "USD") // $1.59
/// let total = try price + tax // $21.58
/// print(total.formatted) // "$21.58"
/// ```
public struct Money: Sendable, Hashable, Codable {
    /// The amount in the smallest currency unit (e.g., cents, pence, yen).
    public let amount: Int

    /// The currency for this monetary amount.
    public let currency: Currency

    /// Creates a Money value with the specified amount and currency.
    ///
    /// - Parameters:
    ///   - amount: The amount in the smallest currency unit (must be non-negative).
    ///   - currency: The currency for this amount.
    /// - Throws: `MoneyError.negativeAmount` if amount is negative.
    public init(amount: Int, currency: Currency) throws {
        guard amount >= 0 else {
            throw MoneyError.negativeAmount(amount)
        }
        self.amount = amount
        self.currency = currency
    }

    /// Creates a Money value from an ISO 4217 currency code string.
    ///
    /// - Parameters:
    ///   - amount: The amount in the smallest currency unit (must be non-negative).
    ///   - currencyCode: The ISO 4217 currency code (e.g., "USD", "EUR").
    /// - Throws:
    ///   - `MoneyError.negativeAmount` if amount is negative.
    ///   - `CurrencyError.invalidFormat` if the currency code is invalid.
    public init(amount: Int, currencyCode: String) throws {
        let currency = try Currency(code: currencyCode)
        try self.init(amount: amount, currency: currency)
    }

    /// Creates a Money value from a decimal amount (e.g., 19.99 for $19.99).
    ///
    /// This convenience initializer converts the decimal to the smallest unit
    /// based on the currency's decimal places.
    ///
    /// - Parameters:
    ///   - decimalAmount: The amount in standard currency units (e.g., dollars, euros).
    ///   - currency: The currency for this amount.
    /// - Throws: `MoneyError.negativeAmount` if the resulting amount is negative.
    public init(decimalAmount: Decimal, currency: Currency) throws {
        let multiplier = pow(Decimal(10), currency.decimalPlaces)
        var smallestUnitAmount = decimalAmount * multiplier
        var rounded = Decimal()
        NSDecimalRound(&rounded, &smallestUnitAmount, 0, .plain)

        // Use int64Value for safe conversion
        let int64Amount = NSDecimalNumber(decimal: rounded).int64Value

        // Check for negative
        guard int64Amount >= 0 else {
            throw MoneyError.negativeAmount(Int(clamping: int64Amount))
        }

        // Check for overflow
        guard int64Amount <= Int.max else {
            throw MoneyError.amountOverflow(
                description: "Amount \(int64Amount) exceeds maximum for \(currency.code)"
            )
        }

        let intAmount = Int(int64Amount)
        try self.init(amount: intAmount, currency: currency)
    }

    // MARK: - Computed Properties

    /// The amount as a Decimal value in standard currency units (e.g., 19.99 for $19.99).
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

// MARK: - Comparable

extension Money: Comparable {
    /// Compares two Money values.
    ///
    /// - Note: Only Money values with the same currency can be compared.
    ///         Comparing different currencies will result in a precondition failure.
    ///         Use `tryCompare(_:)` for safe comparison that returns nil on mismatch.
    public static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency == rhs.currency,
                     "Cannot compare Money values with different currencies: \(lhs.currency.code) vs \(rhs.currency.code)")
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
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let amount = try container.decode(Int.self, forKey: .amount)
        let currencyCode = try container.decode(String.self, forKey: .currencyCode)
        try self.init(amount: amount, currencyCode: currencyCode)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amount, forKey: .amount)
        try container.encode(currency.code, forKey: .currencyCode)
    }
}
