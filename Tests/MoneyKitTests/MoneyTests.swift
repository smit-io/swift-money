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

    @Test("Money rejects negative amounts")
    func negativeAmounts() {
        #expect(throws: MoneyError.self) {
            _ = try Money(amount: -100, currency: .USD)
        }

        #expect(throws: MoneyError.self) {
            _ = try Money(amount: -1, currencyCode: "JPY")
        }
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
        let money = try Money(decimalAmount: 19.99, currency: .USD)
        #expect(money.amount == 1999)

        // ¥1000 = 1000 yen (no decimal)
        let yen = try Money(decimalAmount: 1000, currency: .JPY)
        #expect(yen.amount == 1000)

        // 1.234 KWD = 1234 fils (3 decimal places)
        let kwd = try Money(decimalAmount: 1.234, currency: .KWD)
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
        #expect(yen.numericString == "1000" || yen.numericString == "1,000")

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

        let fromDecimal = try Money(decimalAmount: 5.678, currency: .KWD)
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
            _ = try Money(decimalAmount: tooLarge, currency: .JPY)
        }
    }

    @Test("Decimal amount near Int.max for JPY")
    func decimalAmountNearIntMax() throws {
        // JPY has no decimal places, so large amounts can hit Int.max
        let nearMax = Decimal(Int.max - 1000)
        let money = try Money(decimalAmount: nearMax, currency: .JPY)
        #expect(money.amount == Int.max - 1000)
    }

    @Test("Decimal amount exceeding Int.max throws overflow")
    func decimalAmountExceedingIntMax() {
        #expect(throws: MoneyError.self) {
            // Convert to Decimal first to avoid Int overflow in literal
            let tooLarge = Decimal(Int.max) + Decimal(1000)
            _ = try Money(decimalAmount: tooLarge, currency: .JPY)
        }
    }

    @Test("Negative decimal amount is rejected")
    func negativeDecimalAmount() {
        #expect(throws: MoneyError.self) {
            _ = try Money(decimalAmount: -10.50, currency: .USD)
        }
    }
}
