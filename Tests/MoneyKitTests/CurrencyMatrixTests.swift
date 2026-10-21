import Foundation
import Testing
@testable import MoneyKit

/// Runs every Money and BigMoney operation across currencies with fewer, the
/// usual, and more decimal places, including custom currencies.
///
/// Amounts are in minor units, and scaling is linear, so the expected minor-unit
/// results are the same for every currency: 1234 minor units × 1.1 is 1357.4
/// minor units whether a minor unit is a yen, a cent, or a satoshi.
@Suite("Currency Matrix Tests")
struct CurrencyMatrixTests {

    /// Each currency with the `numericString` of -1999 minor units in it.
    static let cases: [(Currency, String)] = [
        (.JPY, "-1999"),                                                         // ISO, 0 places
        (try! Currency(code: "KWD", decimalPlaces: 1), "-199.9"),                // custom, fewer than ISO
        (.USD, "-19.99"),                                                        // ISO, 2 places
        (.KWD, "-1.999"),                                                        // ISO, 3 places
        (try! Currency(code: "CLF"), "-0.1999"),                                 // ISO, 4 places
        (try! Currency(code: "USD", decimalPlaces: 4), "-0.1999"),               // custom, more than ISO
        (try! Currency(code: "ZZZ", decimalPlaces: 8), "-0.00001999"),           // custom non-ISO code
        (try! Currency(code: "ZZZ", decimalPlaces: 18), "-0.000000000000001999"), // custom, wei-like scale
    ]

    static let currencies = cases.map(\.0)

    static let modes: [RoundingMode] = [.up, .down, .halfUp, .bankers, .towardZero, .awayFromZero]

    /// Minor-unit results of rounding 1357.4, 1357.5, and -1357.5 minor units.
    static let roundingTable: [RoundingMode: [Int]] = [
        .up: [1358, 1358, -1357],
        .down: [1357, 1357, -1358],
        .halfUp: [1357, 1358, -1358],
        .bankers: [1357, 1358, -1358],
        .towardZero: [1357, 1357, -1357],
        .awayFromZero: [1358, 1358, -1358],
    ]

    /// `minorUnits` (a decimal string) expressed in standard units of `currency`.
    private func standardUnits(_ minorUnits: String, _ currency: Currency) -> Decimal {
        Decimal(string: minorUnits)! * currency.divisor
    }

    /// The same code at different decimal places.
    private func rescaled(_ currency: Currency) throws -> Currency {
        try Currency(code: currency.code, decimalPlaces: currency.decimalPlaces == 2 ? 3 : 2)
    }

    // MARK: - Money: exact arithmetic

    @Test("Exact arithmetic is the same in minor units", arguments: currencies)
    func exactArithmetic(currency: Currency) throws {
        let a = try Money(amount: 1000, currency: currency)
        let b = try Money(amount: 1500, currency: currency)

        #expect(try (a + b).amount == 2500)
        #expect(try (a - b).amount == -500)
        #expect(try (a * -3).amount == -3000)
        #expect((-a).amount == -1000)
        #expect(a.negated() == -a)
        #expect((-a).abs() == a)
        #expect(Money.zero(currency).isZero)
        #expect(try (a - b).isNegative)
        #expect(try (a - b).currency == currency)
    }

    @Test("Overflow and Int.min throw", arguments: currencies)
    func overflow(currency: Currency) throws {
        let max = try Money(amount: Int.max, currency: currency)
        let min = try Money(amount: -Int.max, currency: currency)
        let one = try Money(amount: 1, currency: currency)

        #expect(throws: MoneyError.self) { try max + one }
        #expect(throws: MoneyError.self) { try min - one }
        #expect(throws: MoneyError.self) { try max * 2 }
        #expect(throws: MoneyError.self) { try Money(amount: Int.min, currency: currency) }
        #expect(throws: MoneyError.self) { try [max, one].sum(in: currency) }
    }

    @Test("decimalAmount and numericString follow the decimal places", arguments: cases)
    func representation(currency: Currency, numeric: String) throws {
        let money = try Money(amount: -1999, currency: currency)

        #expect(money.numericString == numeric)
        #expect(money.decimalAmount == Decimal(string: numeric))
    }

    // MARK: - Money: rounded arithmetic

    @Test("multiplied and divided round in minor units", arguments: currencies)
    func roundedArithmetic(currency: Currency) throws {
        let money = try Money(amount: 1234, currency: currency)

        #expect(try money.multiplied(by: 1.1, rounding: .up).amount == 1358)
        #expect(try money.multiplied(by: 1.1, rounding: .down).amount == 1357)
        #expect(try money.multiplied(by: -1.1, rounding: .towardZero).amount == -1357)
        #expect(try money.multiplied(by: -1.1, rounding: .awayFromZero).amount == -1358)
        #expect(try money.divided(by: 3, rounding: .up).amount == 412)
        #expect(try money.divided(by: 3, rounding: .down).amount == 411)
        #expect(try (-money).divided(by: 3, rounding: .towardZero).amount == -411)
        #expect(throws: MoneyError.self) { try money.divided(by: 0, rounding: .down) }
    }

    @Test("Money(decimalAmount:) rounds per the table", arguments: currencies, modes)
    func decimalAmountRounding(currency: Currency, mode: RoundingMode) throws {
        let results = try ["1357.4", "1357.5", "-1357.5"].map {
            try Money(decimalAmount: standardUnits($0, currency), currency: currency, rounding: mode).amount
        }

        #expect(results == Self.roundingTable[mode])
    }

    @Test("Money(decimalAmount:) round-trips decimalAmount at the range limits", arguments: currencies)
    func decimalAmountRoundTrip(currency: Currency) throws {
        for amount in [Int.max, -Int.max, 0, 1, -1] {
            let money = try Money(amount: amount, currency: currency)
            #expect(try Money(decimalAmount: money.decimalAmount, currency: currency, rounding: .down) == money)
        }

        let beyond = standardUnits("9223372036854775808", currency)  // Int.max + 1
        #expect(throws: MoneyError.self) {
            try Money(decimalAmount: beyond, currency: currency, rounding: .down)
        }
        #expect(throws: MoneyError.self) {
            try Money(decimalAmount: -beyond, currency: currency, rounding: .down)
        }
    }

    // MARK: - Money: splitting and summation

    @Test("allocate and distribute sum exactly for either sign", arguments: currencies)
    func splitting(currency: Currency) throws {
        for amount in [10001, -10001, Int.max - 1000, -(Int.max - 1000)] {
            let total = try Money(amount: amount, currency: currency)

            let allocated = try total.allocate(by: [70, 0, 30])
            #expect(try allocated.sum(in: currency) == total)
            #expect(allocated[1].isZero)

            let distributed = try total.distribute(into: 3)
            #expect(try distributed.sum(in: currency) == total)
            #expect(distributed.allSatisfy { $0.currency == currency })
        }

        let parts = try Money(amount: -100, currency: currency).distribute(into: 3)
        #expect(parts.map(\.amount) == [-34, -33, -33])
    }

    // MARK: - Money: mismatches

    @Test("Mixing in the same code at other decimal places throws decimalPlacesMismatch", arguments: currencies)
    func decimalPlacesMismatch(currency: Currency) throws {
        let a = try Money(amount: 100, currency: currency)
        let b = try Money(amount: 100, currency: rescaled(currency))

        for error in [
            #expect(throws: MoneyError.self) { try a + b },
            #expect(throws: MoneyError.self) { try a - b },
            #expect(throws: MoneyError.self) { try [a, b].sum(in: currency) },
            #expect(throws: MoneyError.self) { try a.toBigMoney() + b },
        ] {
            guard case .decimalPlacesMismatch = error else {
                Issue.record("Expected decimalPlacesMismatch, got \(String(describing: error))")
                continue
            }
        }
        #expect(a != b)
        #expect(a.tryCompare(b) == nil)
        #expect(a.toBigMoney().tryCompare(b.toBigMoney()) == nil)
    }

    @Test("Mixing in another code throws currencyMismatch", arguments: currencies)
    func currencyMismatch(currency: Currency) throws {
        let a = try Money(amount: 100, currency: currency)
        let b = try Money(amount: 100, currency: currency.code == "EUR" ? .USD : .EUR)

        let error = #expect(throws: MoneyError.self) { try a + b }
        guard case .currencyMismatch = error else {
            Issue.record("Expected currencyMismatch, got \(String(describing: error))")
            return
        }
    }

    // MARK: - Money: Codable

    @Test("Money Codable round-trips, including custom decimal places", arguments: currencies)
    func moneyCodable(currency: Currency) throws {
        let original = try Money(amount: -1999, currency: currency)

        let decoded = try JSONDecoder().decode(Money.self, from: JSONEncoder().encode(original))

        #expect(decoded == original)
        #expect(decoded.currency.decimalPlaces == currency.decimalPlaces)
    }

    @Test("Default currencies keep the two-key payload; custom scales add decimalPlaces")
    func moneyWireFormat() throws {
        let standard = try String(decoding: JSONEncoder().encode(Money(amount: 1999, currency: .USD)), as: UTF8.self)
        #expect(!standard.contains("decimalPlaces"))

        let custom = try Currency(code: "USD", decimalPlaces: 4)
        let scaled = try String(decoding: JSONEncoder().encode(Money(amount: 34590, currency: custom)), as: UTF8.self)
        #expect(scaled.contains(#""decimalPlaces":4"#))

        // Payloads written before decimalPlaces existed decode at the default scale.
        let legacy = Data(#"{"amount":34590,"currencyCode":"USD"}"#.utf8)
        #expect(try JSONDecoder().decode(Money.self, from: legacy) == Money(amount: 34590, currency: .USD))
    }

    // MARK: - BigMoney

    @Test("BigMoney rounds per the table", arguments: currencies, modes)
    func bigMoneyRounding(currency: Currency, mode: RoundingMode) throws {
        let results = try ["1357.4", "1357.5", "-1357.5"].map {
            try BigMoney(amount: standardUnits($0, currency), currency: currency).rounded(mode).amount
        }

        #expect(results == Self.roundingTable[mode])
    }

    @Test("BigMoney chains without rounding and rounds once", arguments: currencies)
    func bigMoneyChain(currency: Currency) throws {
        let price = try Money(amount: 1234, currency: currency)
        let coupon = try Money(amount: 100, currency: currency)

        let gross = try price.toBigMoney() * 1.1 - coupon  // 1257.4 minor units
        #expect(gross.amount == standardUnits("1257.4", currency))
        #expect(try gross.rounded(.down).amount == 1257)
        #expect(try gross.rounded(.up).amount == 1258)

        let third = try price.toBigMoney() / 3
        #expect(try (third * 3).rounded(.halfUp) == price)
        #expect(throws: MoneyError.self) { try price.toBigMoney() / 0 }
    }

    @Test("Money → BigMoney → Money is lossless at the range limits", arguments: currencies)
    func bigMoneyRoundTrip(currency: Currency) throws {
        for amount in [Int.max, -Int.max, 0, 1, -1] {
            let money = try Money(amount: amount, currency: currency)
            for mode in Self.modes {
                #expect(try money.toBigMoney().rounded(mode) == money)
            }
        }

        let beyond = try Money(amount: Int.max, currency: currency).toBigMoney() * 2
        #expect(throws: MoneyError.self) { try beyond.rounded(.down) }
        #expect(throws: MoneyError.self) { try (-beyond).rounded(.down) }
    }

    @Test("BigMoney sign, comparison, and summation", arguments: currencies)
    func bigMoneyBasics(currency: Currency) throws {
        let a = try Money(amount: 500, currency: currency).toBigMoney()

        #expect((-a).isNegative)
        #expect((-a).abs() == a)
        #expect(-a < a)
        #expect(BigMoney.zero(currency).isZero)
        #expect(try [a, -a, a].sum(in: currency) == a)
        #expect(try [BigMoney]().sum(in: currency).isZero)
    }

    @Test("BigMoney Codable round-trips, including custom decimal places", arguments: currencies)
    func bigMoneyCodable(currency: Currency) throws {
        let original = BigMoney(amount: standardUnits("-1357.123456789", currency), currency: currency)

        let decoded = try JSONDecoder().decode(BigMoney.self, from: JSONEncoder().encode(original))

        #expect(decoded == original)
        #expect(decoded.currency.decimalPlaces == currency.decimalPlaces)
    }
}

// MARK: - Comparable Preconditions

#if compiler(>=6.2) && (os(macOS) || os(Linux) || os(Windows))
/// `<` on values that can't be compared is a precondition failure. Exit tests
/// run each body in a child process and check that it stops.
@Suite("Comparable Precondition Tests")
struct ComparablePreconditionTests {

    @Test("Money < with different codes stops the process")
    func moneyDifferentCodes() async {
        await #expect(processExitsWith: .failure) {
            _ = try! Money(amount: 100, currency: .USD) < Money(amount: 100, currency: .EUR)
        }
    }

    @Test("Money < at different decimal places stops the process")
    func moneyDifferentDecimalPlaces() async {
        await #expect(processExitsWith: .failure) {
            let custom = try! Currency(code: "USD", decimalPlaces: 4)
            _ = try! Money(amount: 100, currency: .USD) < Money(amount: 100, currency: custom)
        }
    }

    @Test("BigMoney < with different codes stops the process")
    func bigMoneyDifferentCodes() async {
        await #expect(processExitsWith: .failure) {
            _ = BigMoney(amount: 1, currency: .USD) < BigMoney(amount: 1, currency: .EUR)
        }
    }

    @Test("BigMoney < at different decimal places stops the process")
    func bigMoneyDifferentDecimalPlaces() async {
        await #expect(processExitsWith: .failure) {
            let custom = try! Currency(code: "USD", decimalPlaces: 4)
            _ = BigMoney(amount: 1, currency: .USD) < BigMoney(amount: 1, currency: custom)
        }
    }

    @Test("max() on mixed currencies stops the process too")
    func sequenceMax() async {
        await #expect(processExitsWith: .failure) {
            _ = [try! Money(amount: 1, currency: .USD), try! Money(amount: 2, currency: .JPY)].max()
        }
    }
}
#endif
