import Foundation

/// Represents a monetary calculation in progress with high precision.
///
/// `MoneyCalculation` holds a decimal amount before rounding, allowing you to
/// choose the rounding mode when converting back to `Money`.
///
/// Example:
/// ```swift
/// let price = try Money(amount: 1234, currency: .JPY)
/// let calc = price * 1.1
///
/// let roundedUp = try calc.roundedUp      // 1358 yen
/// let roundedDown = try calc.roundedDown  // 1357 yen
/// let bankers = try calc.bankers          // 1357 yen (banker's rounding)
/// ```
public struct MoneyCalculation: Sendable {
    private let decimalAmount: Decimal
    private let currency: Currency

    internal init(decimalAmount: Decimal, currency: Currency) {
        self.decimalAmount = decimalAmount
        self.currency = currency
    }

    // MARK: - Rounding Properties

    /// Default rounding (Banker's Rounding)
    public var value: Money {
        get throws {
            try bankers
        }
    }

    /// Round up (ceiling)
    public var roundedUp: Money {
        get throws {
            try rounded(.up)
        }
    }

    /// Round down (floor)
    public var roundedDown: Money {
        get throws {
            try rounded(.down)
        }
    }

    /// Half up rounding (0.5 rounds up)
    public var halfUp: Money {
        get throws {
            try rounded(.halfUp)
        }
    }

    /// Banker's rounding (round to nearest even)
    public var bankers: Money {
        get throws {
            try rounded(.bankers)
        }
    }

    /// Round with a specific rounding mode
    ///
    /// - Parameter mode: The rounding mode to apply
    /// - Returns: A Money value with the specified rounding applied
    /// - Throws: `MoneyError.negativeAmount` if the result is negative
    public func rounded(_ mode: RoundingMode) throws -> Money {
        let multiplier = pow(Decimal(10), currency.decimalPlaces)
        var scaled = decimalAmount * multiplier
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, mode.nsRoundingMode)

        // Use int64Value for safe conversion
        let int64Amount = NSDecimalNumber(decimal: rounded).int64Value

        // Check for negative
        guard int64Amount >= 0 else {
            throw MoneyError.negativeAmount(Int(clamping: int64Amount))
        }

        // Check for overflow
        guard int64Amount <= Int.max else {
            throw MoneyError.amountOverflow(
                description: "Calculation overflow: result \(int64Amount) exceeds maximum for \(currency.code)"
            )
        }

        let amount = Int(int64Amount)
        return try Money(amount: amount, currency: currency)
    }

    // MARK: - Arithmetic Operations

    /// Multiply by a scalar
    public static func * (lhs: MoneyCalculation, rhs: Double) -> MoneyCalculation {
        MoneyCalculation(
            decimalAmount: lhs.decimalAmount * Decimal(rhs),
            currency: lhs.currency
        )
    }

    /// Multiply by a scalar (Float)
    public static func * (lhs: MoneyCalculation, rhs: Float) -> MoneyCalculation {
        lhs * Double(rhs)
    }

    /// Divide by a scalar
    public static func / (lhs: MoneyCalculation, rhs: Double) throws -> MoneyCalculation {
        guard rhs != 0 else {
            throw MoneyError.divisionByZero
        }
        return MoneyCalculation(
            decimalAmount: lhs.decimalAmount / Decimal(rhs),
            currency: lhs.currency
        )
    }

    /// Divide by a scalar (Float)
    public static func / (lhs: MoneyCalculation, rhs: Float) throws -> MoneyCalculation {
        try lhs / Double(rhs)
    }

    /// Add two calculations
    public static func + (lhs: MoneyCalculation, rhs: MoneyCalculation) throws -> MoneyCalculation {
        guard lhs.currency == rhs.currency else {
            throw MoneyError.currencyMismatch(from: lhs.currency, to: rhs.currency)
        }
        return MoneyCalculation(
            decimalAmount: lhs.decimalAmount + rhs.decimalAmount,
            currency: lhs.currency
        )
    }

    /// Subtract two calculations
    public static func - (lhs: MoneyCalculation, rhs: MoneyCalculation) throws -> MoneyCalculation {
        guard lhs.currency == rhs.currency else {
            throw MoneyError.currencyMismatch(from: lhs.currency, to: rhs.currency)
        }
        return MoneyCalculation(
            decimalAmount: lhs.decimalAmount - rhs.decimalAmount,
            currency: lhs.currency
        )
    }
}

// MARK: - CustomStringConvertible

extension MoneyCalculation: CustomStringConvertible {
    public var description: String {
        "MoneyCalculation(\(decimalAmount) \(currency.code))"
    }
}
