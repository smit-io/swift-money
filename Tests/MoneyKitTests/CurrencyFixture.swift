import Foundation
import Testing
@testable import MoneyKit

/// A currency that every Money and BigMoney test runs against.
///
/// Tests state amounts and expectations in minor units. Scaling is linear, so
/// 1234 minor units × 1.1 is 1357.4 minor units whether a minor unit is a yen,
/// a cent, or a fils; the same expectations hold for every fixture. The
/// helpers here compute standard units and strings without going through
/// `Money`, so they act as an independent oracle.
struct CurrencyFixture: Sendable, CustomTestStringConvertible {
    enum Kind: String, Sendable {
        /// An ISO 4217 code at its registry decimal places.
        case iso
        /// An ISO 4217 code whose minor unit is "N.A." (falls back to 2).
        case isoWithoutMinorUnit
        /// A known code built with custom decimal places.
        case customScaleOfKnown
        /// A code that is not in ISO 4217.
        case newCode
        /// Scales well outside the usual 0...4.
        case extremeScale
    }

    let currency: Currency
    let kind: Kind

    var decimalPlaces: Int { currency.decimalPlaces }

    var testDescription: String { "\(currency.code)@\(decimalPlaces) (\(kind.rawValue))" }

    /// Standard units for an amount given in minor units, e.g. "1357.4".
    func standardUnits(minor text: String) -> Decimal {
        Decimal(string: "\(text)e-\(decimalPlaces)")!
    }

    /// Standard units for an amount given in minor units.
    func standardUnits(minor amount: Int) -> Decimal {
        standardUnits(minor: String(amount))
    }

    /// The expected `numericString`: the digits with a dot `decimalPlaces` from the right.
    func numericString(minor amount: Int) -> String {
        let digits = String(amount.magnitude)
        let padded = String(repeating: "0", count: max(0, decimalPlaces + 1 - digits.count)) + digits
        let body = decimalPlaces == 0 ? padded : "\(padded.dropLast(decimalPlaces)).\(padded.suffix(decimalPlaces))"
        return (amount < 0 ? "-" : "") + body
    }

    /// `10^decimalPlaces` minor units: one standard unit.
    var minorUnitsPerUnit: Int {
        (0..<decimalPlaces).reduce(1) { result, _ in result * 10 }
    }

    /// Whether `decimalPlaces` is what `Currency(code:)` would pick.
    var isDefaultScale: Bool {
        (try? Currency(code: currency.code)) == currency
    }

    /// The same code at different decimal places.
    var rescaled: Currency {
        try! Currency(code: currency.code, decimalPlaces: decimalPlaces == 2 ? 3 : 2)
    }

    /// A currency with a different code.
    var otherCode: Currency {
        currency.code == "EUR" ? .USD : .EUR
    }

    func money(_ amount: Int) throws -> Money {
        try Money(amount: amount, currency: currency)
    }

    static let all: [CurrencyFixture] = [
        // ISO, one per decimal-places class in the registry
        CurrencyFixture(currency: .JPY, kind: .iso),
        CurrencyFixture(currency: .USD, kind: .iso),
        CurrencyFixture(currency: .KWD, kind: .iso),
        CurrencyFixture(currency: try! Currency(code: "CLF"), kind: .iso),
        CurrencyFixture(currency: try! Currency(code: "XAU"), kind: .isoWithoutMinorUnit),

        // Custom: a known code at a custom scale, and a new code at 0, 2, 3
        CurrencyFixture(currency: try! Currency(code: "USD", decimalPlaces: 4), kind: .customScaleOfKnown),
        CurrencyFixture(currency: try! Currency(code: "ZZZ", decimalPlaces: 0), kind: .newCode),
        CurrencyFixture(currency: try! Currency(code: "ZZZ", decimalPlaces: 2), kind: .newCode),
        CurrencyFixture(currency: try! Currency(code: "ZZZ", decimalPlaces: 3), kind: .newCode),

        // Extreme scales
        CurrencyFixture(currency: try! Currency(code: "KWD", decimalPlaces: 1), kind: .extremeScale),
        CurrencyFixture(currency: try! Currency(code: "ZZZ", decimalPlaces: 8), kind: .extremeScale),
        CurrencyFixture(currency: try! Currency(code: "ZZZ", decimalPlaces: 18), kind: .extremeScale),
    ]

    static let roundingModes: [RoundingMode] = [.up, .down, .halfUp, .bankers, .towardZero, .awayFromZero]

    /// Minor-unit results of rounding 1357.4, 1357.5, and -1357.5 minor units.
    static let roundingTable: [RoundingMode: [Int]] = [
        .up: [1358, 1358, -1357],
        .down: [1357, 1357, -1358],
        .halfUp: [1357, 1358, -1358],
        .bankers: [1357, 1358, -1358],
        .towardZero: [1357, 1357, -1357],
        .awayFromZero: [1358, 1358, -1358],
    ]
}

@Suite("Currency Fixture Tests")
struct CurrencyFixtureTests {

    @Test("Fixtures are what they claim to be", arguments: CurrencyFixture.all)
    func fixtureKinds(fixture: CurrencyFixture) {
        switch fixture.kind {
        case .iso:
            #expect(fixture.currency.isISO)
            #expect(fixture.isDefaultScale)
        case .isoWithoutMinorUnit:
            #expect(!fixture.currency.isISO)
            #expect(fixture.isDefaultScale)
            #expect(fixture.decimalPlaces == 2)
        case .customScaleOfKnown:
            #expect(fixture.currency.isISO)
            #expect(!fixture.isDefaultScale)
        case .newCode:
            #expect(!fixture.currency.isISO)
        case .extremeScale:
            #expect(!fixture.isDefaultScale)
        }
    }

    @Test("Fixtures cover every decimal-places class")
    func coverage() {
        let places = Set(CurrencyFixture.all.map(\.decimalPlaces))
        #expect(places.isSuperset(of: [0, 1, 2, 3, 4, 8, 18]))

        let newCodePlaces = CurrencyFixture.all.filter { $0.kind == .newCode }.map(\.decimalPlaces)
        #expect(newCodePlaces == [0, 2, 3])
        #expect(CurrencyFixture.all.contains { $0.kind == .customScaleOfKnown })
    }

    @Test("The numericString oracle pads and places the dot")
    func oracle() throws {
        let usd = CurrencyFixture(currency: .USD, kind: .iso)
        #expect(usd.numericString(minor: -1999) == "-19.99")
        #expect(usd.numericString(minor: 5) == "0.05")
        #expect(usd.numericString(minor: 0) == "0.00")

        let jpy = CurrencyFixture(currency: .JPY, kind: .iso)
        #expect(jpy.numericString(minor: -1999) == "-1999")
        #expect(jpy.standardUnits(minor: "1357.4") == Decimal(string: "1357.4"))
    }
}
