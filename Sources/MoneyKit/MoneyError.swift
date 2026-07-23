import Foundation

/// Errors that can occur when working with Money values.
public enum MoneyError: LocalizedError, Sendable {
    /// The specified currency code is invalid (not 3 alphabetic characters).
    case invalidCurrencyCode(String)

    /// The amount cannot be negative.
    case negativeAmount(Int)

    /// Attempted to perform an operation on Money values with different currencies.
    case currencyMismatch(from: Currency, to: Currency)

    /// Division by zero was attempted.
    case divisionByZero

    /// Amount overflow occurred during calculation.
    case amountOverflow(description: String)

    public var errorDescription: String? {
        switch self {
        case .invalidCurrencyCode(let code):
            return "Invalid currency code: '\(code)'. Currency codes must be exactly 3 alphabetic characters (ISO 4217)."
        case .negativeAmount(let amount):
            return "Amount cannot be negative: \(amount)."
        case .currencyMismatch(let from, let to):
            return "Currency mismatch: cannot operate on \(from.code) and \(to.code)."
        case .divisionByZero:
            return "Division by zero is not allowed."
        case .amountOverflow(let description):
            return "Amount overflow: \(description)"
        }
    }
}

/// Errors that can occur during currency validation.
public enum CurrencyError: LocalizedError, Sendable {
    /// The currency code does not match ISO 4217 format.
    case invalidFormat(String)

    /// The currency is not recognized in the system.
    case unknownCurrency(String)

    /// The decimal places value is outside the supported range.
    case invalidDecimalPlaces(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let code):
            return "Invalid currency format: '\(code)'. Expected 3 uppercase letters."
        case .unknownCurrency(let code):
            return "Unknown currency: '\(code)'."
        case .invalidDecimalPlaces(let places):
            return "Invalid decimal places: \(places). Expected 0...30."
        }
    }
}

/// Errors that can occur during money formatting.
public enum MoneyFormattingError: LocalizedError, Sendable {
    /// The formatter failed to format the money value.
    case formatterFailed(amount: Decimal, currencyCode: String)

    /// The locale is not supported for the specified currency.
    case unsupportedLocale(locale: Locale, currency: String)

    public var errorDescription: String? {
        switch self {
        case .formatterFailed(let amount, let currencyCode):
            return "Failed to format amount \(amount) for currency \(currencyCode)."
        case .unsupportedLocale(let locale, let currency):
            return "Locale '\(locale.identifier)' is not supported for currency \(currency)."
        }
    }
}
