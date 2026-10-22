import Foundation

extension Decimal {
    private static let posix = Locale(identifier: "en_US_POSIX")

    /// Converts a `Double` through its shortest round-trip text, like Java's
    /// `BigDecimal.valueOf(double)` (which joda-money uses).
    ///
    /// `Decimal(0.07)` copies the Double's binary error
    /// (0.07000000000000001024); this parses `"0.07"` instead, so any Double
    /// written as a literal becomes exactly that decimal. A Double that is
    /// already inexact, like `0.1 + 0.2`, stays inexact
    /// (0.30000000000000004).
    ///
    /// - Throws: `MoneyError.invalidDecimal` for NaN, infinity, or a value
    ///   outside `Decimal`'s range.
    init(shortestRepresentationOf value: Double) throws {
        guard value.isFinite,
              let decimal = Decimal(string: value.description, locale: Self.posix) else {
            throw MoneyError.invalidDecimal(value)
        }
        self = decimal
    }
}
