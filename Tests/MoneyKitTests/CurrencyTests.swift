import Testing
import Foundation
@testable import MoneyKit

@Suite("Currency Tests")
struct CurrencyTests {

    @Test("Currency initialization with valid codes")
    func validCurrencyCodes() throws {
        let usd = try Currency(code: "USD")
        #expect(usd.code == "USD")
        #expect(usd.decimalPlaces == 2)

        let jpy = try Currency(code: "JPY")
        #expect(jpy.code == "JPY")
        #expect(jpy.decimalPlaces == 0)

        let kwd = try Currency(code: "KWD")
        #expect(kwd.code == "KWD")
        #expect(kwd.decimalPlaces == 3)
    }

    @Test("Currency initialization normalizes to uppercase")
    func normalizesToUppercase() throws {
        let usd = try Currency(code: "usd")
        #expect(usd.code == "USD")

        let eur = try Currency(code: "EuR")
        #expect(eur.code == "EUR")
    }

    @Test("Currency rejects invalid codes with invalidFormat, reporting the input", arguments: [
        "US", "USDD", "", "12D", "US$", "U D", " USD",  // length, digits, symbols, spaces
        "日本円", "ÄÖÜ", "äbc", "ΑΒΓ", "ǆAB",             // letters, but not ASCII
    ])
    func invalidCurrencyCodes(code: String) {
        for decimalPlaces in [nil, 2] {
            let error = #expect(throws: CurrencyError.self) { try Currency(code: code, decimalPlaces: decimalPlaces) }
            guard case .invalidFormat(code) = error else {
                Issue.record("Expected invalidFormat(\(code)), got \(String(describing: error))")
                continue
            }
        }
    }

    @Test("normalizedCode uppercases valid codes and rejects the rest with the input", arguments: [
        ("USD", "USD"), ("usd", "USD"), ("EuR", "EUR"), ("zzz", "ZZZ"),
        ("US", nil), ("USDD", nil), ("12D", nil), ("日本円", nil), ("ÄÖÜ", nil), ("", nil),
    ] as [(String, String?)])
    func normalizedCode(input: String, expected: String?) throws {
        if let expected {
            #expect(try Currency.normalizedCode(input) == expected)
        } else {
            let error = #expect(throws: CurrencyError.self) { try Currency.normalizedCode(input) }
            guard case .invalidFormat(input) = error else {
                Issue.record("Expected invalidFormat(\(input)), got \(String(describing: error))")
                return
            }
        }
    }

    @Test("validate() passes for every currency that can be built", arguments: CurrencyFixture.all)
    func validateFixtures(fixture: CurrencyFixture) throws {
        // init runs the same check, so no Currency can fail validate().
        try fixture.currency.validate()
        try JSONDecoder().decode(Currency.self, from: JSONEncoder().encode(fixture.currency)).validate()
    }

    @Test("decimalPlaces outside 0...30 throws invalidDecimalPlaces", arguments: [-1, -2, 31, 32, 100, Int.min, Int.max])
    func invalidDecimalPlaces(places: Int) {
        for code in ["USD", "JPY", "ZZZ"] {
            let error = #expect(throws: CurrencyError.self) { try Currency(code: code, decimalPlaces: places) }
            guard case .invalidDecimalPlaces(places) = error else {
                Issue.record("Expected invalidDecimalPlaces(\(places)) for \(code), got \(String(describing: error))")
                continue
            }
        }
    }

    @Test("An invalid code is reported before invalid decimal places")
    func invalidCodeAndDecimalPlaces() {
        let error = #expect(throws: CurrencyError.self) { try Currency(code: "US", decimalPlaces: 31) }
        guard case .invalidFormat("US") = error else {
            Issue.record("Expected invalidFormat(US), got \(String(describing: error))")
            return
        }
    }

    @Test("decimalPlaces 0 and 30 are the inclusive limits")
    func decimalPlacesLimits() throws {
        let zero = try Currency(code: "ZZZ", decimalPlaces: 0)
        #expect(zero.divisor == 1)

        let thirty = try Currency(code: "ZZZ", decimalPlaces: 30)
        #expect(thirty.divisor == Decimal(sign: .plus, exponent: -30, significand: 1))

        // Every digit survives at the top scale, through BigMoney and Codable too.
        for amount in [Int.max, -Int.max, 1, -1] {
            let money = try Money(amount: amount, currency: thirty)
            let digits = String(amount.magnitude)
            let expected = (amount < 0 ? "-" : "") + "0." + String(repeating: "0", count: 30 - digits.count) + digits
            #expect(money.numericString == expected)
            #expect(try money.toBigMoney().rounded(.down) == money)
            #expect(try JSONDecoder().decode(Money.self, from: JSONEncoder().encode(money)) == money)
            #expect(try JSONDecoder().decode(BigMoney.self, from: JSONEncoder().encode(money.toBigMoney())) == money.toBigMoney())
        }
    }

    @Test("Decoding validates the code and decimal places like init")
    func decodingValidates() {
        func decode<T: Decodable>(_ type: T.Type, _ json: String) -> CurrencyError? {
            #expect(throws: CurrencyError.self, "\(T.self) \(json)") {
                try JSONDecoder().decode(type, from: Data(json.utf8))
            }
        }

        for places in [-1, 31] {
            for error in [
                decode(Currency.self, #"{"code":"USD","decimalPlaces":\#(places)}"#),
                decode(Money.self, #"{"amount":1,"currencyCode":"USD","decimalPlaces":\#(places)}"#),
                decode(BigMoney.self, #"{"amount":"1.5","currencyCode":"USD","decimalPlaces":\#(places)}"#),
            ] {
                guard case .invalidDecimalPlaces(places) = error else {
                    Issue.record("Expected invalidDecimalPlaces(\(places)), got \(String(describing: error))")
                    continue
                }
            }
        }

        for code in ["US", "日本円"] {
            for error in [
                decode(Currency.self, #"{"code":"\#(code)","decimalPlaces":2}"#),
                decode(Money.self, #"{"amount":1,"currencyCode":"\#(code)"}"#),
                decode(BigMoney.self, #"{"amount":"1.5","currencyCode":"\#(code)"}"#),
            ] {
                guard case .invalidFormat(code) = error else {
                    Issue.record("Expected invalidFormat(\(code)), got \(String(describing: error))")
                    continue
                }
            }
        }
    }

    @Test("Standard currency constants")
    func standardConstants() {
        #expect(Currency.USD.code == "USD")
        #expect(Currency.USD.decimalPlaces == 2)

        #expect(Currency.EUR.code == "EUR")
        #expect(Currency.EUR.decimalPlaces == 2)

        #expect(Currency.GBP.code == "GBP")
        #expect(Currency.GBP.decimalPlaces == 2)

        #expect(Currency.JPY.code == "JPY")
        #expect(Currency.JPY.decimalPlaces == 0)

        #expect(Currency.KWD.code == "KWD")
        #expect(Currency.KWD.decimalPlaces == 3)
    }

    @Test("Currency divisor calculation")
    func divisorCalculation() throws {
        let usd = try Currency(code: "USD")
        #expect(usd.divisor == 0.01)  // 2 decimal places

        let jpy = try Currency(code: "JPY")
        #expect(jpy.divisor == 1.0)   // 0 decimal places

        let kwd = try Currency(code: "KWD")
        #expect(kwd.divisor == 0.001) // 3 decimal places
    }

    @Test("Currency equality")
    func equality() throws {
        let usd1 = try Currency(code: "USD")
        let usd2 = try Currency(code: "USD")
        let eur = try Currency(code: "EUR")

        #expect(usd1 == usd2)
        #expect(usd1 != eur)
        #expect(usd1 == Currency.USD)
    }

    @Test("Currency validation")
    func validation() throws {
        let usd = try Currency(code: "USD")
        try usd.validate()  // Should not throw

        // Valid currency should pass validation
        #expect(throws: Never.self) {
            try usd.validate()
        }
    }

    @Test("Currency custom decimal places")
    func customDecimalPlaces() throws {
        // Override default decimal places
        let customCurrency = try Currency(code: "XXX", decimalPlaces: 4)
        #expect(customCurrency.decimalPlaces == 4)
        #expect(customCurrency.divisor == 0.0001)
    }

    @Test("Currency description")
    func description() throws {
        let usd = try Currency(code: "USD")
        #expect(usd.description.contains("USD"))
        #expect(usd.description.contains("2"))
    }

    @Test("Currency Codable conformance")
    func codable() throws {
        let original = try Currency(code: "EUR")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Currency.self, from: data)

        #expect(decoded == original)
        #expect(decoded.code == "EUR")
        #expect(decoded.decimalPlaces == 2)
    }

    @Test("Currencies with the same code but different decimal places are not equal")
    func equalityWithCustomDecimals() throws {
        let c1 = try Currency(code: "XXX", decimalPlaces: 2)
        let c2 = try Currency(code: "XXX", decimalPlaces: 4)

        #expect(c1 != c2)
        #expect(c1 == (try Currency(code: "XXX", decimalPlaces: 2)))
    }

    @Test("Currency Set operations with custom decimals")
    func setOperationsWithCustomDecimals() throws {
        let c1 = try Currency(code: "XXX", decimalPlaces: 2)
        let c2 = try Currency(code: "XXX", decimalPlaces: 4)

        var set: Set<Currency> = [c1]
        set.insert(c2)

        // Two elements: the decimal places make them different currencies
        #expect(set.count == 2)
        #expect(set.contains(c1))
        #expect(set.contains(c2))
    }

    @Test("Currency Dictionary operations with custom decimals")
    func dictionaryOperationsWithCustomDecimals() throws {
        let c1 = try Currency(code: "YYY", decimalPlaces: 2)
        let c2 = try Currency(code: "YYY", decimalPlaces: 3)

        var dict: [Currency: String] = [:]
        dict[c1] = "first"
        dict[c2] = "second"

        // Two entries: c2 doesn't overwrite c1
        #expect(dict.count == 2)
        #expect(dict[c1] == "first")
        #expect(dict[c2] == "second")
    }

    @Test("Currency hash consistency across standard currencies")
    func hashConsistencyStandardCurrencies() {
        // Standard currencies should have consistent hash values
        let usd1 = Currency.USD
        let usd2 = Currency.USD

        #expect(usd1.hashValue == usd2.hashValue)

        let set: Set<Currency> = [usd1, usd2, Currency.EUR, Currency.JPY]
        #expect(set.count == 3)  // USD counted once
    }
}
