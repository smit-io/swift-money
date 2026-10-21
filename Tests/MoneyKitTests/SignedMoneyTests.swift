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

        #expect(signed.isNegative == false)
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
        #expect((-zero).isNegative == false)
        #expect(-zero == zero)
    }

    @Test("addition across sign combinations", arguments: [
        (500, 300, 800),
        (500, -300, 200),
        (-500, 300, -200),
        (-500, -300, -800),
        (500, -500, 0),
    ])
    func addition(pair: (lhs: Int, rhs: Int, expected: Int)) throws {
        let lhs = try SignedMoney(amount: pair.lhs, currency: .USD)
        let rhs = try SignedMoney(amount: pair.rhs, currency: .USD)

        let sum = try lhs + rhs

        #expect(sum.amount == pair.expected)
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
        #expect(throws: MoneyError.self) {
            try JSONDecoder().decode(SignedMoney.self, from: intMin)
        }

        let badCode = Data(#"{"amount":100,"currencyCode":"US"}"#.utf8)
        #expect(throws: CurrencyError.self) {
            try JSONDecoder().decode(SignedMoney.self, from: badCode)
        }
    }

    @Test("minus landing on zero is sign-normalized")
    func minusToZero() throws {
        let money = try Money(amount: 500, currency: .USD)

        let net = try money.minus(money)

        #expect(net.isZero)
        #expect(net.isNegative == false)
        #expect(net == (try SignedMoney(amount: 0, currency: .USD)))
    }

    @Test("zero is sign-normalized")
    func zeroNormalization() throws {
        let negativeZero = try SignedMoney(amount: 0, currency: .USD)

        #expect(negativeZero.isNegative == false)
        #expect(negativeZero.isZero)
        #expect(negativeZero.isPositive == false)
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

    @Test("decimalAmount carries the sign")
    func decimalAmount() throws {
        let value = try SignedMoney(amount: -1999, currency: .USD)

        #expect(value.decimalAmount == Decimal(string: "-19.99"))
    }

    // MARK: - Mixed Money/SignedMoney arithmetic

    @Test("zero is a signed zero in the given currency")
    func zeroFactory() throws {
        let zero = SignedMoney.zero(.USD)

        #expect(zero.isZero)
        #expect(zero.isNegative == false)
        #expect(zero.currency == .USD)
        #expect(try zero + SignedMoney(amount: -100, currency: .USD)
            == SignedMoney(amount: -100, currency: .USD))
    }

    @Test("mixed operators promote to SignedMoney")
    func mixedOperators() throws {
        let balance = try SignedMoney(amount: -1000, currency: .USD)
        let deposit = try Money(amount: 3000, currency: .USD)

        #expect(try (balance + deposit).amount == 2000)
        #expect(try (balance - deposit).amount == -4000)
        #expect(try (deposit + balance).amount == 2000)
        #expect(try (deposit - balance).amount == 4000)
    }

    @Test("mixed operators throw on currency mismatch")
    func mixedOperatorsCurrencyMismatch() throws {
        let usd = try SignedMoney(amount: 100, currency: .USD)
        let eur = try Money(amount: 100, currency: .EUR)

        #expect(throws: MoneyError.self) { try usd + eur }
        #expect(throws: MoneyError.self) { try usd - eur }
        #expect(throws: MoneyError.self) { try eur + usd }
        #expect(throws: MoneyError.self) { try eur - usd }
    }

    @Test("prefix minus on Money yields negative SignedMoney; zero stays zero")
    func prefixMinusOnMoney() throws {
        let expense = try Money(amount: 3000, currency: .USD)
        let negated = -expense

        #expect(negated.isNegative)
        #expect(negated.amount == -3000)

        let zero = try Money(amount: 0, currency: .USD)
        #expect((-zero).isNegative == false)
        #expect((-zero).isZero)
    }

    @Test("bank account balance goes negative naturally")
    func bankAccountWalkthrough() throws {
        var balance = SignedMoney.zero(.USD)
        balance = try balance + Money(amount: 2000, currency: .USD)  // +$20
        balance = try balance - Money(amount: 3000, currency: .USD)  // -$30

        #expect(balance.amount == -1000)  // -$10.00
        #expect(balance.isNegative)
        #expect(balance.money == nil)
    }

    // MARK: - Summation

    @Test("Money sum totals a sequence and defines the empty case")
    func moneySum() throws {
        let expenses = [
            try Money(amount: 1000, currency: .USD),
            try Money(amount: 2500, currency: .USD),
        ]

        #expect(try expenses.sum(in: .USD).amount == 3500)
        #expect(try [Money]().sum(in: .USD).isZero)
        #expect(throws: MoneyError.self) {
            try expenses.sum(in: .EUR)
        }
    }

    @Test("SignedMoney sum nets income against expenses")
    func signedSum() throws {
        let entries = [
            try SignedMoney(amount: 5000, currency: .USD),   // income
            try SignedMoney(amount: -3000, currency: .USD),  // rent
            try SignedMoney(amount: -2500, currency: .USD),  // groceries
        ]

        #expect(try entries.sum(in: .USD).amount == -500)
        #expect(try [SignedMoney]().sum(in: .USD).isZero)
        #expect(throws: MoneyError.self) {
            try entries.sum(in: .EUR)
        }
    }

    // MARK: - Allocation

    @Test("Allocation of a negative value gives negative parts that sum exactly")
    func allocateNegative() throws {
        let total = try SignedMoney(amount: -10000, currency: .USD)
        let parts = try total.allocate(by: [1, 1, 1])

        #expect(parts.map(\.amount) == [-3334, -3333, -3333])
        #expect(try parts.sum(in: .USD) == total)
    }

    @Test("Allocation of a positive value matches Money.allocate")
    func allocatePositiveMatchesMoney() throws {
        let money = try Money(amount: 120_000, currency: .USD)
        let days = [16, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 15]

        let signed = try money.signed.allocate(by: days)

        #expect(signed.map(\.amount) == (try money.allocate(by: days)).map(\.amount))
        #expect(signed.allSatisfy { !$0.isNegative })
    }

    @Test("Allocation gives a zero ratio zero, never negative zero")
    func allocateNegativeZeroRatio() throws {
        let total = try SignedMoney(amount: -5, currency: .USD)
        let parts = try total.allocate(by: [0, 1, 1])

        #expect(parts.map(\.amount) == [0, -3, -2])
        #expect(!parts[0].isNegative)
        #expect(parts[0] == SignedMoney.zero(.USD))
    }

    @Test("Allocation of zero gives zero parts, none negative")
    func allocateZero() throws {
        let parts = try SignedMoney.zero(.USD).allocate(by: [2, 1])

        #expect(parts.map(\.amount) == [0, 0])
        #expect(parts.allSatisfy { !$0.isNegative })
    }

    @Test("Allocation keeps the currency and sums exactly", arguments: [
        ("USD", -10001, [70, 30]),
        ("JPY", -1001, [1, 2, 3]),
        ("KWD", -1000, [3, 0, 4]),
        ("USD", 9999, [1, 1, 1, 1]),
    ])
    func allocateSumsExactly(code: String, amount: Int, ratios: [Int]) throws {
        let currency = try Currency(code: code)
        let total = try SignedMoney(amount: amount, currency: currency)
        let parts = try total.allocate(by: ratios)

        #expect(parts.count == ratios.count)
        #expect(parts.allSatisfy { $0.currency == currency })
        #expect(try parts.sum(in: currency) == total)
    }

    @Test("Splitting a part again still sums to the original")
    func allocateNested() throws {
        let total = try SignedMoney(amount: -10000, currency: .USD)
        let first = try total.allocate(by: [1, 2])
        let nested = try first[1].allocate(by: [1, 1, 1])

        #expect(try (nested + [first[0]]).sum(in: .USD) == total)
    }

    @Test("Allocation with empty or all-zero ratios throws")
    func allocateInvalidRatios() throws {
        let total = try SignedMoney(amount: -100, currency: .USD)

        #expect(throws: MoneyError.self) { try total.allocate(by: []) }
        #expect(throws: MoneyError.self) { try total.allocate(by: [0, 0]) }
    }

    // MARK: - Formatting

    @Test("formatted carries a negative indicator and the magnitude")
    func formattedNegative() throws {
        let value = try SignedMoney(amount: -1999, currency: .USD)

        // Loose matching on purpose: exact NumberFormatter output differs
        // across ICU versions and corelibs-foundation on Linux CI.
        let negativeSigns = ["-", "\u{2212}", "("]  // hyphen, minus sign, accounting
        let us = value.formatted(locale: Locale(identifier: "en_US"))
        #expect(us.contains("19"))
        #expect(negativeSigns.contains { us.contains($0) })

        let de = value.formatted(locale: Locale(identifier: "de_DE"))
        #expect(de.contains("19"))
        #expect(negativeSigns.contains { de.contains($0) })
    }

    @Test("description delegates to formatted")
    func descriptionMatchesFormatted() throws {
        let value = try SignedMoney(amount: -1999, currency: .USD)

        #expect(value.description == value.formatted)
    }

    @Test("numericString is a machine-parseable signed dot-decimal")
    func numericString() throws {
        #expect(try SignedMoney(amount: -1999, currency: .USD).numericString == "-19.99")
        #expect(try SignedMoney(amount: 1999, currency: .USD).numericString == "19.99")
        #expect(SignedMoney.zero(.JPY).numericString == "0")
    }
}
