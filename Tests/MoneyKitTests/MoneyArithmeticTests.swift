import Testing
import Foundation
@testable import MoneyKit

@Suite("Money Arithmetic Tests")
struct MoneyArithmeticTests {

    // MARK: - Exact arithmetic

    @Test("Addition across sign combinations", arguments: CurrencyFixture.all)
    func addition(fixture: CurrencyFixture) throws {
        for (lhs, rhs, expected) in [(500, 300, 800), (500, -300, 200), (-500, 300, -200), (-500, -300, -800), (500, -500, 0)] {
            let sum = try fixture.money(lhs) + fixture.money(rhs)
            #expect(sum.amount == expected)
            #expect(sum.currency == fixture.currency)
        }
    }

    @Test("Subtraction can go negative", arguments: CurrencyFixture.all)
    func subtraction(fixture: CurrencyFixture) throws {
        let a = try fixture.money(100)
        let b = try fixture.money(500)

        #expect(try (b - a).amount == 400)
        #expect(try (a - b).amount == -400)
        #expect(try (a - a).isZero)
        #expect(try (a - b).currency == fixture.currency)
    }

    @Test("Multiplication by an integer, including negative and zero", arguments: CurrencyFixture.all)
    func multiplication(fixture: CurrencyFixture) throws {
        let money = try fixture.money(250)

        #expect(try (money * 5).amount == 1250)
        #expect(try (money * -3).amount == -750)
        #expect(try (-money * -2).amount == 500)
        #expect(try (fixture.money(Int.max) * 0).isZero)
    }

    @Test("Negation and abs; zero stays zero", arguments: CurrencyFixture.all)
    func negationAndAbs(fixture: CurrencyFixture) throws {
        let money = try fixture.money(500)

        #expect((-money).amount == -500)
        #expect(money.negated() == -money)
        #expect(-(-money) == money)
        #expect((-money).abs() == money)
        #expect(money.abs() == money)
        #expect(-Money.zero(fixture.currency) == Money.zero(fixture.currency))
        #expect((-(try fixture.money(Int.max))).amount == -Int.max)
    }

    @Test("Mixing in another code throws currencyMismatch", arguments: CurrencyFixture.all)
    func currencyMismatch(fixture: CurrencyFixture) throws {
        let a = try fixture.money(100)
        let b = try Money(amount: 100, currency: fixture.otherCode)

        for error in [
            #expect(throws: MoneyError.self) { try a + b },
            #expect(throws: MoneyError.self) { try a - b },
            #expect(throws: MoneyError.self) { try [a, b].sum(in: fixture.currency) },
        ] {
            guard case .currencyMismatch = error else {
                Issue.record("Expected currencyMismatch, got \(String(describing: error))")
                continue
            }
        }
    }

    // MARK: - Overflow

    @Test("Overflow throws instead of trapping", arguments: CurrencyFixture.all)
    func overflow(fixture: CurrencyFixture) throws {
        let max = try fixture.money(Int.max)
        let min = try fixture.money(-Int.max)
        let one = try fixture.money(1)

        #expect(throws: MoneyError.self) { try max + one }
        #expect(throws: MoneyError.self) { try min - one }       // lands on Int.min
        #expect(throws: MoneyError.self) { try min - max }       // overflows Int
        #expect(throws: MoneyError.self) { try max - min }
        #expect(throws: MoneyError.self) { try max * 2 }
        #expect(throws: MoneyError.self) { try fixture.money(Int.min / 2) * 2 }  // lands on Int.min
        #expect(throws: MoneyError.self) { try [max, one].sum(in: fixture.currency) }
    }

    @Test("Arithmetic near the limits succeeds", arguments: CurrencyFixture.all)
    func nearLimits(fixture: CurrencyFixture) throws {
        let nearMax = try fixture.money(Int.max - 100)

        #expect(try (nearMax + fixture.money(50)).amount == Int.max - 50)
        #expect(try (fixture.money(-Int.max) + fixture.money(Int.max)).isZero)
        #expect(try (fixture.money(1000) * (Int.max / 1000)).amount == Int.max / 1000 * 1000)
    }

    // MARK: - Rounded arithmetic

    /// 1234 × 1.1 = 1357.4 and -1234 × 1.1 = -1357.4, in minor units.
    static let multiplicationTable: [RoundingMode: (positive: Int, negative: Int)] = [
        .up: (1358, -1357),
        .down: (1357, -1358),
        .halfUp: (1357, -1357),
        .bankers: (1357, -1357),
        .towardZero: (1357, -1357),
        .awayFromZero: (1358, -1358),
    ]

    @Test("multiplied(by:) rounds with the given mode", arguments: CurrencyFixture.all, CurrencyFixture.roundingModes)
    func multiplied(fixture: CurrencyFixture, mode: RoundingMode) throws {
        let money = try fixture.money(1234)
        let rate = Decimal(string: "1.1")!
        let expected = try #require(Self.multiplicationTable[mode])

        #expect(try money.multiplied(by: rate, rounding: mode).amount == expected.positive)
        #expect(try (-money).multiplied(by: rate, rounding: mode).amount == expected.negative)
        #expect(try money.multiplied(by: -rate, rounding: mode).amount == expected.negative)
    }

    /// 1234 ÷ 3 = 411.33… and -1234 ÷ 3 = -411.33…, in minor units.
    static let divisionTable: [RoundingMode: (positive: Int, negative: Int)] = [
        .up: (412, -411),
        .down: (411, -412),
        .halfUp: (411, -411),
        .bankers: (411, -411),
        .towardZero: (411, -411),
        .awayFromZero: (412, -412),
    ]

    @Test("divided(by:) rounds with the given mode", arguments: CurrencyFixture.all, CurrencyFixture.roundingModes)
    func divided(fixture: CurrencyFixture, mode: RoundingMode) throws {
        let money = try fixture.money(1234)
        let expected = try #require(Self.divisionTable[mode])

        #expect(try money.divided(by: Decimal(3), rounding: mode).amount == expected.positive)
        #expect(try (-money).divided(by: Decimal(3), rounding: mode).amount == expected.negative)
        #expect(try money.divided(by: Decimal(4), rounding: mode).amount == Self.tieTable[mode])
    }

    /// 1234 ÷ 4 = 308.5, a tie: 308 is the even neighbor.
    static let tieTable: [RoundingMode: Int] = [
        .up: 309, .down: 308, .halfUp: 309, .bankers: 308, .towardZero: 308, .awayFromZero: 309,
    ]

    @Test("Rounded arithmetic errors", arguments: CurrencyFixture.all)
    func roundedErrors(fixture: CurrencyFixture) throws {
        let money = try fixture.money(100)
        let large = try fixture.money(Int.max / 2)

        #expect(throws: MoneyError.self) { try money.divided(by: Decimal(0), rounding: .down) }
        #expect(throws: MoneyError.self) { try large.multiplied(by: Decimal(3), rounding: .down) }
        #expect(throws: MoneyError.self) { try large.multiplied(by: Decimal(-3), rounding: .down) }
        #expect(throws: MoneyError.self) { try large.divided(by: Decimal(string: "0.1")!, rounding: .down) }
    }

    @Test("Percentages in minor units", arguments: CurrencyFixture.all)
    func percentages(fixture: CurrencyFixture) throws {
        // Subtotal 5499, 8.5% tax = 467.415 → 467; total 5966.
        let subtotal = try fixture.money(5499)
        let tax = try subtotal.multiplied(by: Decimal(string: "0.085")!, rounding: .halfUp)

        #expect(tax.amount == 467)
        #expect(try (subtotal + tax).amount == 5966)

        // 2.9% fee on 4999 = 144.971 → 145, plus a fixed 30.
        let fee = try fixture.money(4999).multiplied(by: Decimal(string: "0.029")!, rounding: .halfUp) + fixture.money(30)
        #expect(try (fixture.money(4999) - fee).amount == 4824)
    }

    // MARK: - Distribution

    @Test("distribute splits evenly with the remainder first, for either sign", arguments: CurrencyFixture.all)
    func distribute(fixture: CurrencyFixture) throws {
        #expect(try fixture.money(100).distribute(into: 3).map(\.amount) == [34, 33, 33])
        #expect(try fixture.money(-100).distribute(into: 3).map(\.amount) == [-34, -33, -33])
        #expect(try fixture.money(15000).distribute(into: 4).map(\.amount) == [3750, 3750, 3750, 3750])
        #expect(try fixture.money(0).distribute(into: 2).map(\.amount) == [0, 0])

        for amount in [10850, -10850, Int.max - 1000, -(Int.max - 1000)] {
            let total = try fixture.money(amount)
            let parts = try total.distribute(into: 7)
            #expect(try parts.sum(in: fixture.currency) == total)
            #expect(parts.allSatisfy { $0.currency == fixture.currency })
        }
    }

    @Test("distribute rejects zero or negative part counts", arguments: CurrencyFixture.all)
    func distributeInvalid(fixture: CurrencyFixture) throws {
        let money = try fixture.money(100)

        #expect(throws: MoneyError.self) { try money.distribute(into: 0) }
        #expect(throws: MoneyError.self) { try money.distribute(into: -1) }
    }

    // MARK: - Allocation

    @Test("allocate splits by ratio", arguments: CurrencyFixture.all)
    func allocate(fixture: CurrencyFixture) throws {
        #expect(try fixture.money(100).allocate(by: [1, 1, 1]).map(\.amount) == [34, 33, 33])
        #expect(try fixture.money(100).allocate(by: [70, 30]).map(\.amount) == [70, 30])
        #expect(try fixture.money(100_000).allocate(by: [70, 20, 10]).map(\.amount) == [70_000, 20_000, 10_000])
        #expect(try fixture.money(-10000).allocate(by: [1, 1, 1]).map(\.amount) == [-3334, -3333, -3333])
    }

    @Test("allocate never gives a remainder unit to a zero ratio", arguments: CurrencyFixture.all)
    func allocateZeroRatios(fixture: CurrencyFixture) throws {
        for (amount, ratios, expected) in [
            (5, [0, 1, 1], [0, 3, 2]),
            (-5, [0, 1, 1], [0, -3, -2]),
            (100, [1, 0, 1, 0, 1], [34, 0, 33, 0, 33]),
            (100, [0, 0, 1], [0, 0, 100]),
            (100, [0, 2, 0, 1], [0, 67, 0, 33]),
        ] {
            #expect(try fixture.money(amount).allocate(by: ratios).map(\.amount) == expected)
        }
    }

    @Test("allocate sums exactly and keeps the currency", arguments: CurrencyFixture.all)
    func allocateSums(fixture: CurrencyFixture) throws {
        for (amount, ratios) in [
            (-10001, [70, 30]),
            (-1001, [1, 2, 3]),
            (-1000, [3, 0, 4]),
            (9999, [1, 1, 1, 1]),
            (120_000, [16, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 15]),
            (Int.max - 1000, [1, 1, 1]),
            (-(Int.max - 1000), [1, 1, 1]),
        ] {
            let total = try fixture.money(amount)
            let parts = try total.allocate(by: ratios)

            #expect(parts.count == ratios.count)
            #expect(parts.allSatisfy { $0.currency == fixture.currency })
            #expect(try parts.sum(in: fixture.currency) == total)
        }

        // Splitting a part again still sums to the original.
        let total = try fixture.money(-10000)
        let first = try total.allocate(by: [1, 2])
        let nested = try first[1].allocate(by: [1, 1, 1])
        #expect(try (nested + [first[0]]).sum(in: fixture.currency) == total)
    }

    @Test("allocate rejects empty or all-zero ratios", arguments: CurrencyFixture.all)
    func allocateInvalid(fixture: CurrencyFixture) throws {
        let money = try fixture.money(-100)

        #expect(throws: MoneyError.self) { try money.allocate(by: []) }
        #expect(throws: MoneyError.self) { try money.allocate(by: [0, 0]) }
    }

    // MARK: - Summation

    @Test("sum nets signs, defines the empty case, and rejects mismatches", arguments: CurrencyFixture.all)
    func sum(fixture: CurrencyFixture) throws {
        let entries = try [5000, -3000, -2500].map(fixture.money)

        #expect(try entries.sum(in: fixture.currency).amount == -500)
        #expect(try [Money]().sum(in: fixture.currency) == Money.zero(fixture.currency))
        #expect(throws: MoneyError.self) { try entries.sum(in: fixture.otherCode) }
        #expect(throws: MoneyError.self) { try entries.sum(in: fixture.rescaled) }
    }

    @Test("A running balance goes negative naturally", arguments: CurrencyFixture.all)
    func runningBalance(fixture: CurrencyFixture) throws {
        var balance = Money.zero(fixture.currency)
        balance = try balance + fixture.money(2000)
        balance = try balance - fixture.money(3000)

        #expect(balance.amount == -1000)
        #expect(balance.isNegative)
        #expect(balance.numericString == fixture.numericString(minor: -1000))
    }
}
