import Testing
import Foundation
@testable import MoneyKit

@Suite("Money Tests")
struct MoneyTests {

    @Test("Money initialization with valid amounts")
    func validInitialization() throws {
        let money = try Money(amount: 1999, currency: .USD)
        #expect(money.amount == 1999)
        #expect(money.currency == .USD)
    }

    @Test("Money initialization from currency code")
    func initializationFromCurrencyCode() throws {
        let money = try Money(amount: 5000, currencyCode: "EUR")
        #expect(money.amount == 5000)
        #expect(money.currency.code == "EUR")
    }

    @Test("Money accepts negative amounts")
    func negativeAmounts() throws {
        let money = try Money(amount: -100, currency: .USD)
        #expect(money.amount == -100)
        #expect(money.isNegative)

        #expect(try Money(amount: -1, currencyCode: "JPY").amount == -1)
        #expect(try Money(amount: -Int.max, currency: .JPY).amount == -Int.max)
    }

    @Test("Money rejects Int.min, whose negation is not representable")
    func intMinRejected() {
        #expect(throws: MoneyError.self) {
            _ = try Money(amount: Int.min, currency: .USD)
        }

        let intMin = Data(#"{"amount":-9223372036854775808,"currencyCode":"USD"}"#.utf8)
        #expect(throws: MoneyError.self) {
            try JSONDecoder().decode(Money.self, from: intMin)
        }
    }

    @Test("zero is a zero amount in the given currency")
    func zeroFactory() {
        let zero = Money.zero(.JPY)
        #expect(zero.isZero)
        #expect(zero.currency == .JPY)
        #expect(zero.numericString == "0")
    }

    @Test("Sign queries", arguments: [
        (-1, true, false, false, false, true),
        (0, false, true, false, true, true),
        (1, false, false, true, true, false),
    ])
    func signQueries(
        amount: Int, negative: Bool, zero: Bool, positive: Bool, positiveOrZero: Bool, negativeOrZero: Bool
    ) throws {
        let money = try Money(amount: amount, currency: .USD)
        #expect(money.isNegative == negative)
        #expect(money.isZero == zero)
        #expect(money.isPositive == positive)
        #expect(money.isPositiveOrZero == positiveOrZero)
        #expect(money.isNegativeOrZero == negativeOrZero)
    }

    @Test("Money accepts zero amount")
    func zeroAmount() throws {
        let money = try Money(amount: 0, currency: .USD)
        #expect(money.amount == 0)
        #expect(money.isZero)
        #expect(!money.isPositive)
    }

    @Test("Money from decimal amount")
    func decimalInitialization() throws {
        // $19.99 = 1999 cents
        let money = try Money(decimalAmount: 19.99, currency: .USD, rounding: .halfUp)
        #expect(money.amount == 1999)

        // ¥1000 = 1000 yen (no decimal)
        let yen = try Money(decimalAmount: 1000, currency: .JPY, rounding: .halfUp)
        #expect(yen.amount == 1000)

        // 1.234 KWD = 1234 fils (3 decimal places)
        let kwd = try Money(decimalAmount: 1.234, currency: .KWD, rounding: .halfUp)
        #expect(kwd.amount == 1234)
    }

    @Test("Decimal amount conversion")
    func decimalAmountConversion() throws {
        let money = try Money(amount: 1999, currency: .USD)
        #expect(money.decimalAmount == Decimal(sign: .plus, exponent: -2, significand: 1999))

        let yen = try Money(amount: 1000, currency: .JPY)
        #expect(yen.decimalAmount == Decimal(1000))

        let kwd = try Money(amount: 1234, currency: .KWD)
        #expect(kwd.decimalAmount == Decimal(sign: .plus, exponent: -3, significand: 1234))
    }

    @Test("Numeric string formatting")
    func numericString() throws {
        let money = try Money(amount: 1999, currency: .USD)
        #expect(money.numericString == "19.99")

        let yen = try Money(amount: 1000, currency: .JPY)
        #expect(yen.numericString == "1000")

        let zero = try Money(amount: 0, currency: .USD)
        #expect(zero.numericString == "0.00")
    }

    @Test("Currency formatted display")
    func formattedDisplay() throws {
        let money = try Money(amount: 1999, currency: .USD)
        let formatted = money.formatted
        // Format depends on locale, but should contain the amount
        #expect(formatted.contains("19") || formatted.contains("20"))
    }

    @Test("Money equality")
    func equality() throws {
        let money1 = try Money(amount: 1999, currency: .USD)
        let money2 = try Money(amount: 1999, currency: .USD)
        let money3 = try Money(amount: 2000, currency: .USD)
        let money4 = try Money(amount: 1999, currency: .EUR)

        #expect(money1 == money2)
        #expect(money1 != money3)
        #expect(money1 != money4)
    }

    @Test("Money comparison - same currency")
    func comparison() throws {
        let small = try Money(amount: 100, currency: .USD)
        let large = try Money(amount: 200, currency: .USD)

        #expect(small < large)
        #expect(large > small)
        #expect(small <= large)
        #expect(large >= small)
        #expect(small <= small)
        #expect(small >= small)
    }

    @Test("Money try compare - different currencies")
    func tryCompare() throws {
        let usd = try Money(amount: 100, currency: .USD)
        let eur = try Money(amount: 100, currency: .EUR)

        let result = usd.tryCompare(eur)
        #expect(result == nil)

        let same = usd.tryCompare(usd)
        #expect(same == .orderedSame)
    }

    @Test("Money is positive check")
    func isPositiveCheck() throws {
        let positive = try Money(amount: 100, currency: .USD)
        #expect(positive.isPositive)

        let zero = try Money(amount: 0, currency: .USD)
        #expect(!zero.isPositive)
    }

    @Test("Money Codable conformance")
    func codable() throws {
        let original = try Money(amount: 1999, currency: .USD)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Money.self, from: data)

        #expect(decoded == original)
        #expect(decoded.amount == 1999)
        #expect(decoded.currency == .USD)
    }

    @Test("Money description")
    func description() throws {
        let money = try Money(amount: 1999, currency: .USD)
        let desc = money.description
        // Description uses formatted, which depends on locale
        #expect(!desc.isEmpty)
    }

    @Test("Zero decimal currency handling")
    func zeroDecimalCurrency() throws {
        let yen = try Money(amount: 1000, currency: .JPY)
        #expect(yen.decimalAmount == 1000)
        #expect(yen.amount == 1000)
    }

    @Test("Three decimal currency handling")
    func threeDecimalCurrency() throws {
        let kwd = try Money(amount: 1234, currency: .KWD)
        #expect(kwd.decimalAmount == 1.234)

        let fromDecimal = try Money(decimalAmount: 5.678, currency: .KWD, rounding: .halfUp)
        #expect(fromDecimal.amount == 5678)
    }

    @Test("Money hashable")
    func hashable() throws {
        let money1 = try Money(amount: 100, currency: .USD)
        let money2 = try Money(amount: 100, currency: .USD)
        let money3 = try Money(amount: 200, currency: .USD)

        var set = Set<Money>()
        set.insert(money1)
        set.insert(money2)
        set.insert(money3)

        #expect(set.count == 2)  // money1 and money2 are equal
    }

    @Test("Large decimal amount overflow detection")
    func largeDecimalAmountOverflow() {
        // Test overflow when converting very large decimal to smallest unit
        // Need to use a value that actually exceeds Int.max (9,223,372,036,854,775,807)
        let tooLarge = Decimal(string: "10000000000000000000")!  // 10^19, much larger than Int.max
        #expect(throws: MoneyError.self) {
            _ = try Money(decimalAmount: tooLarge, currency: .JPY, rounding: .halfUp)
        }
    }

    @Test("Decimal amount near Int.max for JPY")
    func decimalAmountNearIntMax() throws {
        // JPY has no decimal places, so large amounts can hit Int.max
        let nearMax = Decimal(Int.max - 1000)
        let money = try Money(decimalAmount: nearMax, currency: .JPY, rounding: .halfUp)
        #expect(money.amount == Int.max - 1000)
    }

    @Test("Decimal amount exceeding Int.max throws overflow")
    func decimalAmountExceedingIntMax() {
        #expect(throws: MoneyError.self) {
            // Convert to Decimal first to avoid Int overflow in literal
            let tooLarge = Decimal(Int.max) + Decimal(1000)
            _ = try Money(decimalAmount: tooLarge, currency: .JPY, rounding: .halfUp)
        }
    }

    @Test("Negative decimal amount is accepted")
    func negativeDecimalAmount() throws {
        let money = try Money(decimalAmount: -10.50, currency: .USD, rounding: .halfUp)
        #expect(money.amount == -1050)
        #expect(money.decimalAmount == Decimal(string: "-10.5"))
    }

    @Test("Decimal amount rounds with the given mode", arguments: [
        ("1.005", RoundingMode.halfUp, 101),
        ("1.005", .bankers, 100),
        ("1.001", .up, 101),
        ("1.009", .down, 100),
        ("-1.005", .halfUp, -101),
        ("-1.001", .up, -100),
        ("-1.001", .down, -101),
        ("-1.009", .towardZero, -100),
        ("-1.001", .awayFromZero, -101),
        ("1.009", .towardZero, 100),
        ("1.001", .awayFromZero, 101),
    ])
    func decimalAmountRounding(text: String, mode: RoundingMode, expected: Int) throws {
        let money = try Money(decimalAmount: Decimal(string: text)!, currency: .USD, rounding: mode)
        #expect(money.amount == expected)
    }

    @Test("Decimal amount below -Int.max throws overflow")
    func decimalAmountBelowRange() {
        #expect(throws: MoneyError.self) {
            _ = try Money(decimalAmount: Decimal(Int.min), currency: .JPY, rounding: .down)
        }
    }

    @Test("Codable round-trips negative amounts")
    func codableNegative() throws {
        let original = try Money(amount: -1999, currency: .USD)
        let decoded = try JSONDecoder().decode(Money.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test("Comparable orders across signs")
    func comparableAcrossSigns() throws {
        let negative = try Money(amount: -500, currency: .USD)
        let positive = try Money(amount: 500, currency: .USD)
        #expect(negative < Money.zero(.USD))
        #expect(Money.zero(.USD) < positive)
    }

    @Test("numericString is a machine-parseable signed dot-decimal")
    func numericStringNegative() throws {
        #expect(try Money(amount: -1999, currency: .USD).numericString == "-19.99")
    }

    @Test("formatted carries a negative indicator and the magnitude")
    func formattedNegative() throws {
        let value = try Money(amount: -1999, currency: .USD)

        // Loose matching on purpose: exact NumberFormatter output differs
        // across ICU versions and corelibs-foundation on Linux CI.
        let negativeSigns = ["-", "\u{2212}", "("]  // hyphen, minus sign, accounting
        for identifier in ["en_US", "de_DE"] {
            let text = value.formatted(locale: Locale(identifier: identifier))
            #expect(text.contains("19"))
            #expect(negativeSigns.contains { text.contains($0) })
        }
    }

    @Test("Money from an invalid currency code throws")
    func invalidCurrencyCode() {
        #expect(throws: CurrencyError.self) {
            _ = try Money(amount: 100, currencyCode: "US")
        }
    }
}
