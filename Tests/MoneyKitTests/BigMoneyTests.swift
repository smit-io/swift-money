import Foundation
import Testing
@testable import MoneyKit

@Suite("BigMoney Tests")
struct BigMoneyTests {

    @Test("toBigMoney keeps the value in standard units")
    func toBigMoney() throws {
        let big = try Money(amount: 1999, currency: .USD).toBigMoney()

        #expect(big.amount == Decimal(string: "19.99"))
        #expect(big.currency == .USD)
    }

    @Test("Multiplication never rounds")
    func multiplicationKeepsPrecision() throws {
        let big = try Money(amount: 1999, currency: .USD).toBigMoney() * 1.08

        #expect(big.amount == Decimal(string: "21.5892"))
    }

    @Test("rounded applies the mode once", arguments: [
        (RoundingMode.up, 2159),
        (.down, 2158),
        (.halfUp, 2159),
        (.bankers, 2159),
        (.towardZero, 2158),
        (.awayFromZero, 2159),
    ])
    func rounding(mode: RoundingMode, expected: Int) throws {
        let big = try Money(amount: 1999, currency: .USD).toBigMoney() * 1.08  // $21.5892

        let money = try big.rounded(mode)
        #expect(money.amount == expected)
        #expect(money.currency == .USD)
    }

    @Test("Rounding a negative value respects zero-relative modes", arguments: [
        (RoundingMode.up, -1357),
        (.down, -1358),
        (.towardZero, -1357),
        (.awayFromZero, -1358),
        (.halfUp, -1357),
    ])
    func negativeRounding(mode: RoundingMode, expected: Int) throws {
        let big = try -Money(amount: 1234, currency: .JPY).toBigMoney() * 1.1  // -1357.4

        #expect(try big.rounded(mode).amount == expected)
    }

    @Test("Chained calculation rounds once at the end")
    func chainedCalculation() throws {
        // 20% off, then 10% tax: 10000 * 0.8 * 1.1 = 8800 exactly.
        let price = try Money(amount: 10000, currency: .JPY)
        let final = try (price.toBigMoney() * 0.8 * 1.1).rounded(.down)

        #expect(final.amount == 8800)
    }

    @Test("Rounding once differs from rounding every step")
    func roundOnceVersusEachStep() throws {
        let price = try Money(amount: 1, currency: .JPY)

        let eachStep = try price.multiplied(by: 1.5, rounding: .down).multiplied(by: 1.5, rounding: .down)
        let once = try (price.toBigMoney() * 1.5 * 1.5).rounded(.down)  // 2.25

        #expect(eachStep.amount == 1)
        #expect(once.amount == 2)
    }

    @Test("Division keeps precision until rounding")
    func division() throws {
        let third = try Money(amount: 1000, currency: .JPY).toBigMoney() / 3

        #expect(try third.rounded(.up).amount == 334)
        #expect(try third.rounded(.down).amount == 333)
        #expect(try (third * 3).rounded(.halfUp).amount == 1000)
    }

    @Test("Division by zero throws")
    func divisionByZero() throws {
        let big = try Money(amount: 1000, currency: .JPY).toBigMoney()

        #expect(throws: MoneyError.self) {
            _ = try big / 0
        }
    }

    @Test("Addition and subtraction with BigMoney and Money")
    func additionAndSubtraction() throws {
        let price = try Money(amount: 1234, currency: .JPY)
        let discount = try Money(amount: 100, currency: .JPY)

        let gross = try price.toBigMoney() * 1.1 - discount
        #expect(gross.amount == Decimal(string: "1257.4"))
        #expect(try (gross + discount.toBigMoney()).amount == Decimal(string: "1357.4"))
        #expect(try (gross + discount).amount == Decimal(string: "1357.4"))
        #expect(try (gross - gross).isZero)
    }

    @Test("Arithmetic with different currencies throws")
    func currencyMismatch() throws {
        let jpy = try Money(amount: 1000, currency: .JPY).toBigMoney()
        let usd = try Money(amount: 1000, currency: .USD)

        #expect(throws: MoneyError.self) { try jpy + usd }
        #expect(throws: MoneyError.self) { try jpy - usd }
        #expect(throws: MoneyError.self) { try jpy + usd.toBigMoney() }
        #expect(jpy.tryCompare(usd.toBigMoney()) == nil)
    }

    @Test("Negation, abs, and sign queries")
    func sign() throws {
        let big = BigMoney(amount: Decimal(string: "12.3456")!, currency: .USD)

        #expect((-big).isNegative)
        #expect((-big).abs() == big)
        #expect(big.abs() == big)
        #expect(big.isPositive)
        #expect(BigMoney.zero(.USD).isZero)
        #expect(-big < big)
        #expect(big.tryCompare(big) == .orderedSame)
    }

    @Test("sum totals a sequence and defines the empty case")
    func sum() throws {
        let entries = [
            BigMoney(amount: Decimal(string: "0.001")!, currency: .USD),
            BigMoney(amount: Decimal(string: "-0.004")!, currency: .USD),
        ]

        #expect(try entries.sum(in: .USD).amount == Decimal(string: "-0.003"))
        #expect(try [BigMoney]().sum(in: .USD).isZero)
        #expect(throws: MoneyError.self) {
            try entries.sum(in: .EUR)
        }
    }

    @Test("Rounding a value beyond Money's range throws overflow")
    func roundingOverflow() throws {
        let large = try Money(amount: Int.max - 1000, currency: .JPY).toBigMoney() * 1.5

        #expect(throws: MoneyError.self) { try large.rounded(.down) }
        #expect(throws: MoneyError.self) { try (-large).rounded(.down) }
    }

    @Test("Codable round-trips the amount as a string without losing precision")
    func codable() throws {
        let original = BigMoney(amount: Decimal(string: "-12.345678901234567890123")!, currency: .USD)

        let data = try JSONEncoder().encode(original)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains(#""amount":"-12.345678901234567890123""#))

        let decoded = try JSONDecoder().decode(BigMoney.self, from: data)
        #expect(decoded == original)
    }

    @Test("Decoding rejects invalid amounts and currency codes")
    func codableFailurePaths() throws {
        let badAmount = Data(#"{"amount":"abc","currencyCode":"USD"}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(BigMoney.self, from: badAmount)
        }

        let badCode = Data(#"{"amount":"1.5","currencyCode":"US"}"#.utf8)
        #expect(throws: CurrencyError.self) {
            try JSONDecoder().decode(BigMoney.self, from: badCode)
        }
    }

    @Test("description shows the code and the unrounded amount")
    func description() {
        let big = BigMoney(amount: Decimal(string: "12.3456")!, currency: .USD)

        #expect(big.description == "USD 12.3456")
    }

    @Test("Rounding modes match the documented table", arguments: [
        (RoundingMode.up, [1358, 1358, -1357]),
        (.down, [1357, 1357, -1358]),
        (.halfUp, [1357, 1358, -1358]),
        (.bankers, [1357, 1358, -1358]),
        (.towardZero, [1357, 1357, -1357]),
        (.awayFromZero, [1358, 1358, -1358]),
    ])
    func documentedRoundingTable(mode: RoundingMode, expected: [Int]) throws {
        let inputs = ["1357.4", "1357.5", "-1357.5"].map {
            BigMoney(amount: Decimal(string: $0)!, currency: .JPY)
        }

        #expect(try inputs.map { try $0.rounded(mode).amount } == expected)
    }

    @Test("Equal amounts at different scales are equal and hash the same")
    func hashable() {
        let a = BigMoney(amount: Decimal(string: "1.0")!, currency: .USD)
        let b = BigMoney(amount: Decimal(string: "1.00")!, currency: .USD)
        let c = BigMoney(amount: Decimal(string: "1.00")!, currency: .EUR)

        #expect(a == b)
        #expect(Set([a, b, c]).count == 2)
    }

    @Test("Sign queries on zero and negative values")
    func signQueries() {
        let zero = BigMoney.zero(.USD)
        let negative = BigMoney(amount: Decimal(string: "-0.001")!, currency: .USD)

        #expect(!zero.isPositive && !zero.isNegative)
        #expect(negative.isNegative && !negative.isPositive && !negative.isZero)
        #expect(negative < zero)
    }
}
