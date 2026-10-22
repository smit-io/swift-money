import Foundation
import Testing
@testable import MoneyKit

@Suite("BigMoney Tests")
struct BigMoneyTests {

    private func big(_ minor: String, _ fixture: CurrencyFixture) -> BigMoney {
        BigMoney(amount: fixture.standardUnits(minor: minor), currency: fixture.currency)
    }

    // MARK: - Construction

    @Test("toBigMoney keeps the value in standard units", arguments: CurrencyFixture.all)
    func toBigMoney(fixture: CurrencyFixture) throws {
        for amount in MoneyTests.amounts {
            let big = try fixture.money(amount).toBigMoney()
            #expect(big.amount == fixture.standardUnits(minor: amount))
            #expect(big.currency == fixture.currency)
        }
    }

    @Test("Construction from Decimal, Double, and Int", arguments: CurrencyFixture.all)
    func construction(fixture: CurrencyFixture) throws {
        #expect(BigMoney(amount: Decimal(string: "12.3456")!, currency: fixture.currency).amount == Decimal(string: "12.3456"))
        #expect(try BigMoney(amount: 19.99, currency: fixture.currency).amount == Decimal(string: "19.99"))
        #expect(BigMoney(amount: 12, currency: fixture.currency).amount == 12)
        #expect(BigMoney.zero(fixture.currency).isZero)
        #expect(BigMoney.zero(fixture.currency).currency == fixture.currency)
    }

    // MARK: - Rounding

    @Test("rounded applies the table", arguments: CurrencyFixture.all, CurrencyFixture.roundingModes)
    func rounding(fixture: CurrencyFixture, mode: RoundingMode) throws {
        let results = try ["1357.4", "1357.5", "-1357.5"].map { try big($0, fixture).rounded(mode).amount }

        #expect(results == CurrencyFixture.roundingTable[mode])
    }

    @Test("Money → BigMoney → Money is lossless at the range limits", arguments: CurrencyFixture.all)
    func roundTrip(fixture: CurrencyFixture) throws {
        for amount in MoneyTests.amounts {
            let money = try fixture.money(amount)
            for mode in CurrencyFixture.roundingModes {
                #expect(try money.toBigMoney().rounded(mode) == money)
            }
        }
    }

    @Test("Rounding a value beyond Money's range throws", arguments: CurrencyFixture.all)
    func roundingOverflow(fixture: CurrencyFixture) throws {
        let beyond = try fixture.money(Int.max).toBigMoney() * Decimal(2)

        #expect(throws: MoneyError.self) { try beyond.rounded(.down) }
        #expect(throws: MoneyError.self) { try (-beyond).rounded(.down) }
    }

    // MARK: - Arithmetic

    @Test("Multiplication never rounds", arguments: CurrencyFixture.all)
    func multiplication(fixture: CurrencyFixture) throws {
        let price = try fixture.money(1999).toBigMoney()

        #expect((price * Decimal(string: "1.08")!).amount == fixture.standardUnits(minor: "2158.92"))
        #expect((price * 3).amount == fixture.standardUnits(minor: 5997))
        #expect(try (price * 1.08).amount == fixture.standardUnits(minor: "2158.92"))
    }

    @Test("Chains round once at the end", arguments: CurrencyFixture.all)
    func chain(fixture: CurrencyFixture) throws {
        let price = try fixture.money(1234)
        let coupon = try fixture.money(100)

        let gross = try price.toBigMoney() * Decimal(string: "1.1")! - coupon  // 1257.4
        #expect(gross.amount == fixture.standardUnits(minor: "1257.4"))
        #expect(try gross.rounded(.down).amount == 1257)
        #expect(try gross.rounded(.up).amount == 1258)

        let discounted = try fixture.money(10000).toBigMoney() * Decimal(string: "0.8")! * Decimal(string: "1.1")!
        #expect(try discounted.rounded(.down).amount == 8800)
    }

    @Test("Rounding once differs from rounding every step", arguments: CurrencyFixture.all)
    func roundOnceVersusEachStep(fixture: CurrencyFixture) throws {
        let one = try fixture.money(1)
        let rate = Decimal(string: "1.5")!

        let eachStep = try one.multiplied(by: rate, rounding: .down).multiplied(by: rate, rounding: .down)
        let once = try (one.toBigMoney() * rate * rate).rounded(.down)  // 2.25

        #expect(eachStep.amount == 1)
        #expect(once.amount == 2)
    }

    @Test("Division keeps precision until rounding", arguments: CurrencyFixture.all)
    func division(fixture: CurrencyFixture) throws {
        let price = try fixture.money(1000)
        let third = try price.toBigMoney() / Decimal(3)

        #expect(try third.rounded(.up).amount == 334)
        #expect(try third.rounded(.down).amount == 333)
        #expect(try (third * 3).rounded(.halfUp) == price)
        #expect(try (price.toBigMoney() / 4).amount == fixture.standardUnits(minor: 250))
        #expect(throws: MoneyError.self) { try price.toBigMoney() / Decimal(0) }
        #expect(throws: MoneyError.self) { try price.toBigMoney() / 0 }
    }

    @Test("Addition and subtraction with BigMoney and Money", arguments: CurrencyFixture.all)
    func additionAndSubtraction(fixture: CurrencyFixture) throws {
        let gross = big("1257.4", fixture)
        let coupon = try fixture.money(100)

        #expect(try (gross + coupon).amount == fixture.standardUnits(minor: "1357.4"))
        #expect(try (gross + coupon.toBigMoney()).amount == fixture.standardUnits(minor: "1357.4"))
        #expect(try (gross - coupon).amount == fixture.standardUnits(minor: "1157.4"))
        #expect(try (gross - gross).isZero)
    }

    @Test("Mixing currencies throws", arguments: CurrencyFixture.all)
    func mismatch(fixture: CurrencyFixture) throws {
        let a = try fixture.money(1000).toBigMoney()

        for other in [fixture.otherCode, fixture.rescaled] {
            let b = try Money(amount: 1000, currency: other)
            #expect(throws: MoneyError.self) { try a + b }
            #expect(throws: MoneyError.self) { try a - b }
            #expect(throws: MoneyError.self) { try a + b.toBigMoney() }
            #expect(throws: MoneyError.self) { try [a, b.toBigMoney()].sum(in: fixture.currency) }
            #expect(a.tryCompare(b.toBigMoney()) == nil)
        }
    }

    // MARK: - Sign and comparison

    @Test("Negation, abs, sign queries, and comparison", arguments: CurrencyFixture.all)
    func sign(fixture: CurrencyFixture) throws {
        let positive = big("1234.5678", fixture)
        let negative = -positive
        let zero = BigMoney.zero(fixture.currency)

        #expect(positive.isPositive && !positive.isNegative && !positive.isZero)
        #expect(negative.isNegative && !negative.isPositive && !negative.isZero)
        #expect(zero.isZero && !zero.isPositive && !zero.isNegative)
        #expect(negative.abs() == positive)
        #expect(positive.abs() == positive)
        #expect(negative < zero && zero < positive)
        #expect(negative.tryCompare(positive) == .orderedAscending)
        #expect(positive.tryCompare(negative) == .orderedDescending)
        #expect(positive.tryCompare(positive) == .orderedSame)
    }

    @Test("Equal amounts at different scales are equal and hash the same", arguments: CurrencyFixture.all)
    func hashable(fixture: CurrencyFixture) {
        let a = BigMoney(amount: Decimal(string: "1.0")!, currency: fixture.currency)
        let b = BigMoney(amount: Decimal(string: "1.00")!, currency: fixture.currency)
        let rescaled = BigMoney(amount: Decimal(string: "1.00")!, currency: fixture.rescaled)

        #expect(a == b)
        #expect(a != rescaled)
        #expect(Set([a, b, rescaled]).count == 2)
    }

    @Test("sum totals a sequence and defines the empty case", arguments: CurrencyFixture.all)
    func sum(fixture: CurrencyFixture) throws {
        let entries = [big("0.001", fixture), big("-0.004", fixture)]

        #expect(try entries.sum(in: fixture.currency).amount == fixture.standardUnits(minor: "-0.003"))
        #expect(try [BigMoney]().sum(in: fixture.currency).isZero)
        #expect(throws: MoneyError.self) { try entries.sum(in: fixture.otherCode) }
    }

    // MARK: - Codable and description

    @Test("Codable round-trips the amount as a string", arguments: CurrencyFixture.all)
    func codable(fixture: CurrencyFixture) throws {
        let original = big("-1357.123456789012345678", fixture)

        let data = try JSONEncoder().encode(original)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains(#""amount":"\#(original.amount.description)""#))
        #expect(json.contains("decimalPlaces") == !fixture.isDefaultScale)

        let decoded = try JSONDecoder().decode(BigMoney.self, from: data)
        #expect(decoded == original)
        #expect(decoded.currency.decimalPlaces == fixture.decimalPlaces)
    }

    @Test("Decoding rejects invalid amounts and currency codes", arguments: CurrencyFixture.all)
    func codableFailures(fixture: CurrencyFixture) throws {
        let badAmount = Data(#"{"amount":"abc","currencyCode":"\#(fixture.currency.code)"}"#.utf8)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(BigMoney.self, from: badAmount) }

        let badCode = Data(#"{"amount":"1.5","currencyCode":"US"}"#.utf8)
        #expect(throws: CurrencyError.self) { try JSONDecoder().decode(BigMoney.self, from: badCode) }
    }

    @Test("description shows the code and the unrounded amount", arguments: CurrencyFixture.all)
    func description(fixture: CurrencyFixture) {
        let value = BigMoney(amount: Decimal(string: "-12.3456")!, currency: fixture.currency)

        #expect(value.description == "\(fixture.currency.code) -12.3456")
    }
}
