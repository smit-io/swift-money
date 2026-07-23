import Foundation

/// Represents an ISO 4217 currency with metadata for payment processing.
///
/// Currency encapsulates the ISO code, decimal places, and divisor needed to convert
/// between user-facing decimal amounts and integer amounts in the smallest unit
/// (e.g., cents for USD, yen for JPY).
public struct Currency: Sendable, Hashable, Codable {
    /// The ISO 4217 currency code (e.g., "USD", "EUR", "JPY").
    public let code: String

    /// The number of decimal places for this currency (typically 2, but 0 for JPY, 3 for some).
    public let decimalPlaces: Int

    /// The divisor used to convert from the smallest unit to the standard unit.
    /// Multiply the smallest unit amount by this divisor to get the standard unit amount.
    /// For USD: 0.01 (1999 cents × 0.01 = 19.99 dollars), for JPY: 1.0 (1000 yen × 1.0 = 1000 yen).
    public let divisor: Decimal

    /// Creates a currency with the specified code and decimal places.
    ///
    /// - Parameters:
    ///   - code: The ISO 4217 currency code (must be exactly 3 alphabetic characters).
    ///   - decimalPlaces: The number of decimal places (defaults based on currency).
    /// - Throws: `CurrencyError.invalidFormat` if the code is not valid, or
    ///   `CurrencyError.invalidDecimalPlaces` if decimalPlaces is outside 0...30.
    public init(code: String, decimalPlaces: Int? = nil) throws {
        let upperCode = code.uppercased()
        guard upperCode.count == 3,
              upperCode.allSatisfy({ $0.isLetter }) else {
            throw CurrencyError.invalidFormat(code)
        }

        let places = decimalPlaces ?? Self.defaultDecimalPlaces(for: upperCode)
        // Beyond ~30, Decimal's exponent range silently degrades the divisor
        // toward 0; negative values would turn it into a multiplier.
        guard (0...30).contains(places) else {
            throw CurrencyError.invalidDecimalPlaces(places)
        }

        self.code = upperCode
        self.decimalPlaces = places
        self.divisor = Decimal(sign: .plus, exponent: -places, significand: 1)
    }

    /// Validates that this currency conforms to ISO 4217 standards.
    ///
    /// - Throws: `CurrencyError.invalidFormat` if validation fails.
    public func validate() throws {
        guard code.count == 3, code.allSatisfy({ $0.isLetter }) else {
            throw CurrencyError.invalidFormat(code)
        }
    }

    /// Returns the default decimal places for a given currency code.
    ///
    /// The source of truth is `isoMinorUnits` — the full ISO 4217 minor-units
    /// table generated from the official registry (see
    /// `Currency+ISO4217.generated.swift`). Codes absent from the registry
    /// (withdrawn/historical codes, or non-ISO codes, which the format-only
    /// validation accepts) fall back to 2, matching the previous behavior.
    private static func defaultDecimalPlaces(for code: String) -> Int {
        isoMinorUnits[code] ?? 2
    }

    /// Whether this currency's code appears in the generated minor-units table,
    /// i.e. the ISO 4217 registry rows with an applicable minor unit. `false`
    /// for withdrawn/historical codes, arbitrary well-formed codes like `"ZZZ"`,
    /// and registry codes whose minor unit is "N.A." (XAU, XDR, XXX, ...) — all
    /// of which `Currency(code:)` still accepts with the 2-decimal default.
    public var isISO: Bool {
        Self.isoMinorUnits[code] != nil
    }

    // MARK: - Standard Currency Constants

    /// Japanese Yen (zero decimal places)
    public static let JPY = try! Currency(code: "JPY")

    /// United States Dollar (two decimal places)
    public static let USD = try! Currency(code: "USD")

    /// Euro (two decimal places)
    public static let EUR = try! Currency(code: "EUR")

    /// British Pound Sterling (two decimal places)
    public static let GBP = try! Currency(code: "GBP")

    /// Canadian Dollar (two decimal places)
    public static let CAD = try! Currency(code: "CAD")

    /// Australian Dollar (two decimal places)
    public static let AUD = try! Currency(code: "AUD")

    /// Swiss Franc (two decimal places)
    public static let CHF = try! Currency(code: "CHF")

    /// Chinese Yuan (two decimal places)
    public static let CNY = try! Currency(code: "CNY")

    /// Kuwaiti Dinar (three decimal places)
    public static let KWD = try! Currency(code: "KWD")

    /// Bahraini Dinar (three decimal places)
    public static let BHD = try! Currency(code: "BHD")
}

// MARK: - CustomStringConvertible

extension Currency: CustomStringConvertible {
    public var description: String {
        "\(code) (\(decimalPlaces) decimal places)"
    }
}

// MARK: - Codable

extension Currency {
    private enum CodingKeys: String, CodingKey {
        case code
        case decimalPlaces
    }

    /// Decodes through `init(code:decimalPlaces:)` so persisted values get the
    /// same validation as fresh ones and `divisor` is always re-derived.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            code: container.decode(String.self, forKey: .code),
            decimalPlaces: container.decode(Int.self, forKey: .decimalPlaces)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encode(decimalPlaces, forKey: .decimalPlaces)
    }
}

// MARK: - Equatable

extension Currency {
    public static func == (lhs: Currency, rhs: Currency) -> Bool {
        lhs.code == rhs.code
    }
}

// MARK: - Hashable

extension Currency {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
}
