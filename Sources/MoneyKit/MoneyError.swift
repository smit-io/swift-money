import Foundation

/// Errors that can occur when working with Money values.
public enum MoneyError: LocalizedError, Sendable {
    /// Attempted to perform an operation on Money values with different currencies.
    case currencyMismatch(from: Currency, to: Currency)

    /// Attempted to combine values of the same currency code at different decimal
    /// places: a `Currency` was built with a custom `decimalPlaces`, so the same
    /// integer amount means a different value on each side.
    case decimalPlacesMismatch(code: String, lhs: Int, rhs: Int)

    /// Division by zero was attempted.
    case divisionByZero

    /// Amount overflow occurred during calculation.
    case amountOverflow(description: String)

    /// A value is not a usable number: a `Double` that is NaN, infinite, or out
    /// of `Decimal`'s range, or a NaN `Decimal` (reported as `.nan`).
    case invalidDecimal(Double)

    /// `allocate(by:)` was given a negative ratio.
    case negativeRatio(Int)

    /// `distribute(into:)` was asked for a negative number of parts.
    case negativePartCount(Int)

    public var errorDescription: String? {
        switch self {
        case .currencyMismatch(let from, let to):
            return "Currency mismatch: cannot operate on \(from.code) and \(to.code)."
        case .decimalPlacesMismatch(let code, let lhs, let rhs):
            return "Decimal places mismatch: \(code) is configured with \(lhs) and \(rhs) decimal places. A Currency was built with a custom decimalPlaces, so the amounts are at different scales."
        case .divisionByZero:
            return "Division by zero is not allowed."
        case .amountOverflow(let description):
            return "Amount overflow: \(description)"
        case .invalidDecimal(let value):
            return "Invalid decimal: \(value) has no Decimal representation."
        case .negativeRatio(let ratio):
            return "Negative ratio: \(ratio). Allocation ratios must be zero or greater."
        case .negativePartCount(let parts):
            return "Negative part count: \(parts). Distribution needs at least one part."
        }
    }
}

/// Errors that can occur during currency validation.
public enum CurrencyError: LocalizedError, Sendable {
    /// The currency code is not 3 ASCII letters.
    case invalidFormat(String)

    /// The decimal places value is outside the supported range.
    case invalidDecimalPlaces(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let code):
            return "Invalid currency format: '\(code)'. Expected 3 ASCII letters, such as USD."
        case .invalidDecimalPlaces(let places):
            return "Invalid decimal places: \(places). Expected 0...30."
        }
    }
}
