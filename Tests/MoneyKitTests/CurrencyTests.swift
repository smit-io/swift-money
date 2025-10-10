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

    @Test("Currency rejects invalid codes")
    func invalidCurrencyCodes() {
        #expect(throws: CurrencyError.self) {
            _ = try Currency(code: "US")  // Too short
        }

        #expect(throws: CurrencyError.self) {
            _ = try Currency(code: "USDD")  // Too long
        }

        #expect(throws: CurrencyError.self) {
            _ = try Currency(code: "12D")  // Contains numbers
        }

        #expect(throws: CurrencyError.self) {
            _ = try Currency(code: "US$")  // Contains special chars
        }

        #expect(throws: CurrencyError.self) {
            _ = try Currency(code: "")  // Empty
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

    @Test("Zero decimal currencies")
    func zeroDecimalCurrencies() throws {
        let zeroDecimalCodes = ["JPY", "KRW", "VND", "CLP"]

        for code in zeroDecimalCodes {
            let currency = try Currency(code: code)
            #expect(currency.decimalPlaces == 0)
        }
    }

    @Test("Three decimal currencies")
    func threeDecimalCurrencies() throws {
        let threeDecimalCodes = ["BHD", "KWD", "OMR", "TND"]

        for code in threeDecimalCodes {
            let currency = try Currency(code: code)
            #expect(currency.decimalPlaces == 3)
        }
    }

    @Test("Currency hash consistency with custom decimal places")
    func hashConsistencyWithCustomDecimals() throws {
        // Two currencies with same code but different decimal places
        // should be equal and have same hash (equality is code-only)
        let c1 = try Currency(code: "XXX", decimalPlaces: 2)
        let c2 = try Currency(code: "XXX", decimalPlaces: 4)

        // They should be equal (code-only comparison)
        #expect(c1 == c2)

        // They MUST have the same hash value to maintain hash/equality contract
        #expect(c1.hashValue == c2.hashValue)
    }

    @Test("Currency Set operations with custom decimals")
    func setOperationsWithCustomDecimals() throws {
        let c1 = try Currency(code: "XXX", decimalPlaces: 2)
        let c2 = try Currency(code: "XXX", decimalPlaces: 4)

        var set: Set<Currency> = [c1]
        set.insert(c2)

        // Should only have one element since c1 == c2
        #expect(set.count == 1)
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

        // Should only have one entry since c1 == c2
        #expect(dict.count == 1)
        #expect(dict[c1] == "second")  // c2's value overwrites c1
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
