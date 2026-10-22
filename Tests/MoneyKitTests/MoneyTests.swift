import Testing
import Foundation
@testable import MoneyKit

@Suite("Money Tests")
struct MoneyTests {

    static let amounts = [0, 1, -1, 1999, -1999, Int.max, -Int.max]

    // MARK: - Initialization

    @Test("init stores the signed amount and currency", arguments: CurrencyFixture.all)
    func initialization(fixture: CurrencyFixture) throws {
        for amount in Self.amounts {
            let money = try fixture.money(amount)
            #expect(money.amount == amount)
            #expect(money.currency == fixture.currency)
        }
    }

    @Test("init(currencyCode:) uses the code's default decimal places", arguments: CurrencyFixture.all)
    func initializationFromCurrencyCode(fixture: CurrencyFixture) throws {
        let money = try Money(amount: -1999, currencyCode: fixture.currency.code.lowercased())

        #expect(money.amount == -1999)
        #expect(money.currency == (try Currency(code: fixture.currency.code)))
        #expect((money.currency == fixture.currency) == fixture.isDefaultScale)
    }

    @Test("Int.min is rejected, directly and when decoding", arguments: CurrencyFixture.all)
    func intMinRejected(fixture: CurrencyFixture) throws {
        #expect(throws: MoneyError.self) { try fixture.money(Int.min) }

        let json = Data(#"{"amount":-9223372036854775808,"currencyCode":"\#(fixture.currency.code)"}"#.utf8)
        #expect(throws: MoneyError.self) { try JSONDecoder().decode(Money.self, from: json) }
    }

    @Test("Money from an invalid currency code throws")
    func invalidCurrencyCode() {
        #expect(throws: CurrencyError.self) {
            _ = try Money(amount: 100, currencyCode: "US")
        }
    }

    @Test("zero is a zero amount in the given currency", arguments: CurrencyFixture.all)
    func zeroFactory(fixture: CurrencyFixture) {
        let zero = Money.zero(fixture.currency)

        #expect(zero.isZero)
        #expect(zero.currency == fixture.currency)
        #expect(zero.numericString == fixture.numericString(minor: 0))
    }

    @Test("Sign queries", arguments: CurrencyFixture.all)
    func signQueries(fixture: CurrencyFixture) throws {
        for amount in Self.amounts {
            let money = try fixture.money(amount)
            #expect(money.isNegative == (amount < 0))
            #expect(money.isZero == (amount == 0))
            #expect(money.isPositive == (amount > 0))
            #expect(money.isPositiveOrZero == (amount >= 0))
            #expect(money.isNegativeOrZero == (amount <= 0))
        }
    }

    // MARK: - Representation

    @Test("decimalAmount and numericString follow the decimal places", arguments: CurrencyFixture.all)
    func representation(fixture: CurrencyFixture) throws {
        for amount in Self.amounts {
            let money = try fixture.money(amount)
            #expect(money.decimalAmount == fixture.standardUnits(minor: amount))
            #expect(money.numericString == fixture.numericString(minor: amount))
        }
    }

    @Test("formatted carries the sign and description matches it", arguments: CurrencyFixture.all)
    func formatted(fixture: CurrencyFixture) throws {
        // Loose matching on purpose: exact NumberFormatter output differs
        // across ICU versions and corelibs-foundation on Linux CI.
        let negativeSigns = ["-", "\u{2212}", "("]  // hyphen, minus sign, accounting

        for identifier in ["en_US", "de_DE", "ja_JP"] {
            let locale = Locale(identifier: identifier)
            let negative = try fixture.money(-1999).formatted(locale: locale)
            let positive = try fixture.money(1999).formatted(locale: locale)

            #expect(negativeSigns.contains { negative.contains($0) })
            #expect(!negativeSigns.contains { positive.contains($0) })
            #expect(negative.filter(\.isNumber).hasSuffix("1999"))
        }

        let money = try fixture.money(1999)
        #expect(money.description == money.formatted)
    }

    @Test("formatted keeps every digit at the range limits", arguments: CurrencyFixture.all)
    func formattedPrecision(fixture: CurrencyFixture) throws {
        let digits = String(Int.max)

        for amount in [Int.max, -Int.max] {
            let text = try fixture.money(amount).formatted(locale: Locale(identifier: "en_US"))
            #expect(text.filter(\.isNumber).hasSuffix(digits), "\(text)")
        }
    }

    // MARK: - NumberFormatter fallback (before iOS 15 / macOS 12)

    @Test("The NumberFormatter fallback carries the sign and the digits", arguments: CurrencyFixture.all)
    func fallbackFormatting(fixture: CurrencyFixture) throws {
        let negativeSigns = ["-", "\u{2212}", "("]

        for identifier in ["en_US", "de_DE", "ja_JP"] {
            let locale = Locale(identifier: identifier)
            let negative = try fixture.money(-1999).formatWithNumberFormatter(locale: locale)
            let positive = try fixture.money(1999).formatWithNumberFormatter(locale: locale)

            #expect(negativeSigns.contains { negative.contains($0) })
            #expect(!negativeSigns.contains { positive.contains($0) })
            #expect(negative.filter(\.isNumber).hasSuffix("1999"))
        }
    }

    #if canImport(Darwin)
    @Test("The fallback matches FormatStyle below 16 decimal places", arguments: CurrencyFixture.all.filter { $0.decimalPlaces < 16 })
    func fallbackMatchesFormatStyle(fixture: CurrencyFixture) throws {
        for amount in [0, 1, -1, 1999, -1999, Int.max, -Int.max] {
            let money = try fixture.money(amount)
            for identifier in ["en_US", "de_DE", "ja_JP", "ar_SA", "fr_CH"] {
                let locale = Locale(identifier: identifier)
                #expect(money.formatWithNumberFormatter(locale: locale) == money.formatted(locale: locale), "\(amount) \(identifier)")
            }
        }
    }

    @Test("The fallback loses digits at 16 or more decimal places, which is why FormatStyle is used", arguments: CurrencyFixture.all.filter { $0.decimalPlaces >= 16 })
    func fallbackPrecisionLoss(fixture: CurrencyFixture) throws {
        let money = try fixture.money(Int.max)
        let locale = Locale(identifier: "en_US")

        // NumberFormatter keeps about 15 significant digits: 9.223372036854780000.
        #expect(!money.formatWithNumberFormatter(locale: locale).filter(\.isNumber).hasSuffix(String(Int.max)))
        #expect(money.formatted(locale: locale).filter(\.isNumber).hasSuffix(String(Int.max)))
    }
    #endif

    // MARK: - Equality and comparison

    @Test("Equality and hashing include amount, code, and decimal places", arguments: CurrencyFixture.all)
    func equality(fixture: CurrencyFixture) throws {
        let a = try fixture.money(1999)
        let same = try fixture.money(1999)
        let otherAmount = try fixture.money(2000)
        let rescaled = try Money(amount: 1999, currency: fixture.rescaled)
        let otherCode = try Money(amount: 1999, currency: fixture.otherCode)

        #expect(a == same)
        #expect(a != otherAmount)
        #expect(a != rescaled)
        #expect(a != otherCode)
        #expect(Set([a, same, otherAmount, rescaled, otherCode]).count == 4)
    }

    @Test("Comparable orders across signs", arguments: CurrencyFixture.all)
    func comparable(fixture: CurrencyFixture) throws {
        let ordered = try [-Int.max, -500, 0, 500, Int.max].map(fixture.money)

        #expect(ordered == ordered.shuffled().sorted())
        #expect(ordered[0] < ordered[1])
        #expect(ordered[3] > ordered[2])
        #expect(ordered[2] <= ordered[2])
    }

    @Test("tryCompare orders same-currency values and returns nil on mismatch", arguments: CurrencyFixture.all)
    func tryCompare(fixture: CurrencyFixture) throws {
        let small = try fixture.money(-100)
        let large = try fixture.money(100)

        #expect(small.tryCompare(large) == .orderedAscending)
        #expect(large.tryCompare(small) == .orderedDescending)
        #expect(small.tryCompare(small) == .orderedSame)
        #expect(small.tryCompare(try Money(amount: -100, currency: fixture.rescaled)) == nil)
        #expect(small.tryCompare(try Money(amount: -100, currency: fixture.otherCode)) == nil)
    }

    // MARK: - Codable

    @Test("Codable round-trips every amount", arguments: CurrencyFixture.all)
    func codable(fixture: CurrencyFixture) throws {
        for amount in Self.amounts {
            let original = try fixture.money(amount)
            let decoded = try JSONDecoder().decode(Money.self, from: JSONEncoder().encode(original))

            #expect(decoded == original)
            #expect(decoded.currency.decimalPlaces == fixture.decimalPlaces)
        }
    }

    @Test("Payloads add decimalPlaces only for a custom scale", arguments: CurrencyFixture.all)
    func wireFormat(fixture: CurrencyFixture) throws {
        let json = try String(decoding: JSONEncoder().encode(fixture.money(34590)), as: UTF8.self)

        #expect(json.contains(#""amount":34590"#))
        #expect(json.contains(#""currencyCode":"\#(fixture.currency.code)""#))
        #expect(json.contains(#""decimalPlaces":\#(fixture.decimalPlaces)"#) == !fixture.isDefaultScale)

        // Payloads without decimalPlaces decode at the code's default.
        let legacy = Data(#"{"amount":34590,"currencyCode":"\#(fixture.currency.code)"}"#.utf8)
        let decoded = try JSONDecoder().decode(Money.self, from: legacy)
        #expect(decoded.currency == (try Currency(code: fixture.currency.code)))
    }

    // MARK: - Money(decimalAmount:)

    @Test("Money(decimalAmount:) rounds per the table", arguments: CurrencyFixture.all, CurrencyFixture.roundingModes)
    func decimalAmountRounding(fixture: CurrencyFixture, mode: RoundingMode) throws {
        let results = try ["1357.4", "1357.5", "-1357.5"].map {
            try Money(decimalAmount: fixture.standardUnits(minor: $0), currency: fixture.currency, rounding: mode).amount
        }

        #expect(results == CurrencyFixture.roundingTable[mode])
    }

    @Test("Money(decimalAmount:) round-trips decimalAmount and rejects out-of-range values", arguments: CurrencyFixture.all)
    func decimalAmountRange(fixture: CurrencyFixture) throws {
        for amount in Self.amounts {
            let money = try fixture.money(amount)
            for mode in CurrencyFixture.roundingModes {
                #expect(try Money(decimalAmount: money.decimalAmount, currency: fixture.currency, rounding: mode) == money)
            }
        }

        let beyond = fixture.standardUnits(minor: "9223372036854775808")  // Int.max + 1
        #expect(throws: MoneyError.self) {
            try Money(decimalAmount: beyond, currency: fixture.currency, rounding: .down)
        }
        #expect(throws: MoneyError.self) {
            try Money(decimalAmount: -beyond, currency: fixture.currency, rounding: .down)
        }
    }

    @Test("Money(decimalAmount:) from an Int is whole standard units", arguments: CurrencyFixture.all)
    func decimalAmountInt(fixture: CurrencyFixture) throws {
        let money = try Money(decimalAmount: 5, currency: fixture.currency, rounding: .down)
        #expect(money.amount == 5 * fixture.minorUnitsPerUnit)

        let negative = try Money(decimalAmount: -5, currency: fixture.currency, rounding: .down)
        #expect(negative == -money)
    }
}
