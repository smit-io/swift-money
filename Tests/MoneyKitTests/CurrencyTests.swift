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
