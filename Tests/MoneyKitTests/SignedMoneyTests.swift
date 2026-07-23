import Foundation
import Testing
@testable import MoneyKit

@Suite("SignedMoney Tests")
struct SignedMoneyTests {

    @Test("minus produces a negative result without throwing")
    func minusGoesNegative() throws {
        let paid = try Money(amount: 100, currency: .USD)
        let refund = try Money(amount: 500, currency: .USD)

        let net = try paid.minus(refund)

        #expect(net.isNegative)
        #expect(net.amount == -400)
        #expect(net.currency == .USD)
        #expect(net.money == nil)
        #expect(net.absolute == (try Money(amount: 400, currency: .USD)))
    }

    @Test("minus with different currencies throws")
    func minusCurrencyMismatch() throws {
        let usd = try Money(amount: 100, currency: .USD)
        let eur = try Money(amount: 50, currency: .EUR)

        #expect(throws: MoneyError.self) {
            try usd.minus(eur)
        }
    }

    @Test("signed wraps Money as non-negative")
    func signedWrap() throws {
        let money = try Money(amount: 1999, currency: .USD)
        let signed = money.signed

        #expect(!signed.isNegative)
        #expect(signed.amount == 1999)
        #expect(signed.money == money)
    }

    @Test("negation flips sign; zero stays normalized")
    func negation() throws {
        let value = try SignedMoney(amount: 500, currency: .USD)
        let negated = -value

        #expect(negated.amount == -500)
        #expect(-negated == value)

        let zero = try SignedMoney(amount: 0, currency: .USD)
        #expect(!(-zero).isNegative)
        #expect(-zero == zero)
    }

    @Test("addition across sign combinations", arguments: [
        (500, 300, 800),
        (500, -300, 200),
        (-500, 300, -200),
        (-500, -300, -800),
        (500, -500, 0),
    ])
    func addition(pair: (Int, Int, Int)) throws {
        let lhs = try SignedMoney(amount: pair.0, currency: .USD)
        let rhs = try SignedMoney(amount: pair.1, currency: .USD)

        let sum = try lhs + rhs

        #expect(sum.amount == pair.2)
    }

    @Test("subtraction never throws on negative results")
    func subtraction() throws {
        let lhs = try SignedMoney(amount: 100, currency: .USD)
        let rhs = try SignedMoney(amount: 500, currency: .USD)

        let difference = try lhs - rhs

        #expect(difference.amount == -400)
    }

    @Test("addition with different currencies throws")
    func additionCurrencyMismatch() throws {
        let usd = try SignedMoney(amount: 100, currency: .USD)
        let eur = try SignedMoney(amount: 100, currency: .EUR)

        #expect(throws: MoneyError.self) {
            try usd + eur
        }
    }

    @Test("multiplication by negative scalar flips sign")
    func multiplication() throws {
        let value = try SignedMoney(amount: 250, currency: .USD)

        #expect(try (value * -3).amount == -750)
        #expect(try (value * 2).amount == 500)
        #expect(try (value * 0).amount == 0)
    }

    @Test("division truncates toward zero for negative values")
    func division() throws {
        let value = try SignedMoney(amount: -7, currency: .USD)

        // Swift Int division truncates toward zero: -7 / 2 == -3.
        #expect(try (value / 2).amount == -3)

        #expect(throws: MoneyError.self) {
            try value / 0
        }
    }

    @Test("overflow throws instead of trapping")
    func overflow() throws {
        let max = try SignedMoney(amount: Int.max, currency: .USD)
        let one = try SignedMoney(amount: 1, currency: .USD)

        #expect(throws: MoneyError.self) {
            try max + one
        }
        #expect(throws: MoneyError.self) {
            try max * 2
        }
        #expect(throws: MoneyError.self) {
            try SignedMoney(amount: Int.min, currency: .USD)
        }
    }

    @Test("arithmetic landing exactly on Int.min throws instead of trapping")
    func intMinResults() throws {
        // Neither result overflows Int, but Int.min has no representable
        // magnitude — the init guard inside +/* must reject it.
        let nearMin = try SignedMoney(amount: -Int.max, currency: .USD)
        let minusOne = try SignedMoney(amount: -1, currency: .USD)
        #expect(throws: MoneyError.self) {
            try nearMin + minusOne
        }

        let halfMin = try SignedMoney(amount: Int.min / 2, currency: .USD)
        #expect(throws: MoneyError.self) {
            try halfMin * 2
        }
    }

    @Test("division by a negative scalar flips sign and truncates toward zero")
    func divisionByNegativeScalar() throws {
        let value = try SignedMoney(amount: -7, currency: .USD)

        #expect(try (value / -2).amount == 3)
        #expect(try ((-value) / -2).amount == -3)
    }

    @Test("decoding rejects Int.min amounts and invalid currency codes")
    func codableFailurePaths() throws {
        let intMin = Data(#"{"amount":-9223372036854775808,"currencyCode":"USD"}"#.utf8)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(SignedMoney.self, from: intMin)
        }

        let badCode = Data(#"{"amount":100,"currencyCode":"US"}"#.utf8)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(SignedMoney.self, from: badCode)
        }
    }

    @Test("minus landing on zero is sign-normalized")
    func minusToZero() throws {
        let money = try Money(amount: 500, currency: .USD)

        let net = try money.minus(money)

        #expect(net.isZero)
        #expect(!net.isNegative)
        #expect(net == (try SignedMoney(amount: 0, currency: .USD)))
    }

    @Test("zero is sign-normalized")
    func zeroNormalization() throws {
        let negativeZero = try SignedMoney(amount: 0, currency: .USD)

        #expect(!negativeZero.isNegative)
        #expect(negativeZero.isZero)
        #expect(!negativeZero.isPositive)
    }

    @Test("Comparable orders across signs")
    func comparable() throws {
        let negative = try SignedMoney(amount: -500, currency: .USD)
        let zero = try SignedMoney(amount: 0, currency: .USD)
        let positive = try SignedMoney(amount: 500, currency: .USD)

        #expect(negative < zero)
        #expect(zero < positive)
        #expect(negative < positive)
    }

    @Test("Codable round-trips negative amounts")
    func codable() throws {
        let original = try SignedMoney(amount: -1999, currency: .USD)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SignedMoney.self, from: data)

        #expect(decoded == original)
        #expect(decoded.amount == -1999)
    }

    @Test("description carries the sign")
    func description() throws {
        let negative = try SignedMoney(amount: -1999, currency: .USD)
        let positive = try SignedMoney(amount: 1999, currency: .USD)

        #expect(negative.description == "-\(positive.magnitude.description)")
        #expect(positive.description == positive.magnitude.description)
    }

    @Test("decimalAmount carries the sign")
    func decimalAmount() throws {
        let value = try SignedMoney(amount: -1999, currency: .USD)

        #expect(value.decimalAmount == Decimal(string: "-19.99"))
    }
}
