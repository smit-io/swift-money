import Testing
import Foundation
@testable import MoneyKit

@Suite("Money Arithmetic Tests")
struct MoneyArithmeticTests {

    @Test("Addition with same currency")
    func addition() throws {
        let m1 = try Money(amount: 1000, currency: .USD)
        let m2 = try Money(amount: 500, currency: .USD)

        let result = try m1 + m2
        #expect(result.amount == 1500)
        #expect(result.currency == .USD)
    }

    @Test("Addition with different currencies throws error")
    func additionDifferentCurrencies() throws {
        let usd = try Money(amount: 1000, currency: .USD)
        let eur = try Money(amount: 500, currency: .EUR)

        #expect(throws: MoneyError.self) {
            _ = try usd + eur
        }
    }

    @Test("Subtraction with same currency")
    func subtraction() throws {
        let m1 = try Money(amount: 1000, currency: .USD)
        let m2 = try Money(amount: 300, currency: .USD)

        let result = try m1 - m2
        #expect(result.amount == 700)
        #expect(result.currency == .USD)
    }

    @Test("Subtraction can go negative")
    func subtractionNegativeResult() throws {
        let m1 = try Money(amount: 100, currency: .USD)
        let m2 = try Money(amount: 500, currency: .USD)

        #expect(try (m1 - m2).amount == -400)
        #expect(try (m1 - m1).isZero)
    }

    @Test("Subtraction with different currencies throws error")
    func subtractionDifferentCurrencies() throws {
        let usd = try Money(amount: 1000, currency: .USD)
        let eur = try Money(amount: 500, currency: .EUR)

        #expect(throws: MoneyError.self) {
            _ = try usd - eur
        }
    }

    @Test("Multiplication by integer")
    func multiplicationByInteger() throws {
        let money = try Money(amount: 100, currency: .USD)
        let result = try money * 5

        #expect(result.amount == 500)
        #expect(result.currency == .USD)
    }

    @Test("Multiplication by decimal rounds with the given mode")
    func multiplicationByDecimal() throws {
        let money = try Money(amount: 1234, currency: .JPY)

        #expect(try money.multiplied(by: 1.1, rounding: .up).amount == 1358)
        #expect(try money.multiplied(by: 1.1, rounding: .down).amount == 1357)
        #expect(try money.multiplied(by: -1.1, rounding: .towardZero).amount == -1357)
        #expect(try money.multiplied(by: -1.1, rounding: .awayFromZero).amount == -1358)
    }

    @Test("Multiplication by a negative integer flips the sign")
    func multiplicationByNegative() throws {
        let money = try Money(amount: 250, currency: .USD)

        #expect(try (money * -3).amount == -750)
        #expect(try (-money * -2).amount == 500)
    }

    @Test("Division rounds with the given mode")
    func divisionByInteger() throws {
        let money = try Money(amount: 1000, currency: .JPY)

        #expect(try money.divided(by: 4, rounding: .down).amount == 250)
        #expect(try money.divided(by: 3, rounding: .up).amount == 334)
        #expect(try money.divided(by: 3, rounding: .down).amount == 333)
        #expect(try (-money).divided(by: 3, rounding: .towardZero).amount == -333)
        #expect(try (-money).divided(by: 3, rounding: .down).amount == -334)
    }

    @Test("Division by zero throws error")
    func divisionByZero() throws {
        let money = try Money(amount: 100, currency: .USD)

        #expect(throws: MoneyError.self) {
            _ = try money.divided(by: 0, rounding: .down)
        }
    }

    @Test("Distribution into equal parts")
    func distribution() throws {
        let money = try Money(amount: 100, currency: .USD)
        let parts = try money.distribute(into: 3)

        #expect(parts.count == 3)
        #expect(parts[0].amount == 34)  // Gets extra from remainder
        #expect(parts[1].amount == 33)
        #expect(parts[2].amount == 33)

        // Sum should equal original
        let sum = parts.reduce(0) { $0 + $1.amount }
        #expect(sum == 100)
    }

    @Test("Distribution with zero parts throws error")
    func distributionZeroParts() throws {
        let money = try Money(amount: 100, currency: .USD)

        #expect(throws: MoneyError.self) {
            _ = try money.distribute(into: 0)
        }
    }

    @Test("Allocation by ratios")
    func allocation() throws {
        let money = try Money(amount: 100, currency: .USD)
        let parts = try money.allocate(by: [1, 1, 1])

        #expect(parts.count == 3)

        // Sum should equal original
        let sum = parts.reduce(0) { $0 + $1.amount }
        #expect(sum == 100)
    }

    @Test("Allocation by weighted ratios")
    func allocationWeighted() throws {
        let money = try Money(amount: 100, currency: .USD)
        let parts = try money.allocate(by: [70, 30])

        #expect(parts.count == 2)
        #expect(parts[0].amount == 70)
        #expect(parts[1].amount == 30)

        // Sum should equal original
        let sum = parts.reduce(0) { $0 + $1.amount }
        #expect(sum == 100)
    }

    @Test("Allocation never gives a remainder unit to a zero ratio")
    func allocationZeroRatioGetsNothing() throws {
        let money = try Money(amount: 5, currency: .USD)
        let parts = try money.allocate(by: [0, 1, 1])

        #expect(parts.map(\.amount) == [0, 3, 2])
    }

    @Test("Allocation skips zero ratios anywhere in the list", arguments: [
        ([1, 0, 1, 0, 1], [34, 0, 33, 0, 33]),
        ([0, 0, 1], [0, 0, 100]),
        ([0, 2, 0, 1], [0, 67, 0, 33]),
    ])
    func allocationZeroRatioPositions(ratios: [Int], expected: [Int]) throws {
        let money = try Money(amount: 100, currency: .USD)
        let parts = try money.allocate(by: ratios)

        #expect(parts.map(\.amount) == expected)
        #expect(parts.reduce(0) { $0 + $1.amount } == 100)
    }

    @Test("Zero-ratio allocation is the same for currencies without two decimal places", arguments: [
        ("JPY", 0),
        ("KRW", 0),
        ("KWD", 3),
        ("BHD", 3),
        ("CLF", 4),
    ])
    func allocationZeroRatioOtherDecimalPlaces(code: String, decimalPlaces: Int) throws {
        let currency = try Currency(code: code)
        #expect(currency.decimalPlaces == decimalPlaces)

        let money = try Money(amount: 5, currency: currency)
        let parts = try money.allocate(by: [0, 1, 1])

        #expect(parts.map(\.amount) == [0, 3, 2])
        #expect(parts.allSatisfy { $0.currency == currency })
    }

    @Test("Allocation with empty ratios throws error")
    func allocationEmptyRatios() throws {
        let money = try Money(amount: 100, currency: .USD)

        #expect(throws: MoneyError.self) {
            _ = try money.allocate(by: [])
        }
    }

    @Test("Zero checks")
    func zeroChecks() throws {
        let zero = try Money(amount: 0, currency: .USD)
        let positive = try Money(amount: 100, currency: .USD)

        #expect(zero.isZero)
        #expect(!zero.isPositive)

        #expect(!positive.isZero)
        #expect(positive.isPositive)
    }

    @Test("Complex calculation example")
    func complexCalculation() throws {
        // Simulate: $100 item + 8.5% tax
        let price = try Money(amount: 10000, currency: .USD)
        let taxRate: Decimal = 0.085
        let tax = try price.multiplied(by: taxRate, rounding: .halfUp)
        let total = try price + tax

        #expect(total.amount == 10850)  // $108.50

        // Split bill 3 ways
        let split = try total.distribute(into: 3)
        let sum = split.reduce(0) { $0 + $1.amount }
        #expect(sum == 10850)
    }

    @Test("Payment API scenario")
    func paymentApiScenario() throws {
        // Product: $49.99
        let productPrice = try Money(amount: 4999, currency: .USD)

        // Shipping: $5.00
        let shipping = try Money(amount: 500, currency: .USD)

        // Subtotal
        let subtotal = try productPrice + shipping

        // Tax: 7.5%
        let tax = try subtotal.multiplied(by: 0.075, rounding: .halfUp)

        // Total
        let total = try subtotal + tax

        #expect(total.amount == 5911)  // $59.11

        // Convert to decimal for API
        #expect(total.decimalAmount == 59.11)
    }

    // MARK: - Overflow Tests

    @Test("Addition overflow detection")
    func additionOverflow() throws {
        let large = try Money(amount: Int.max - 100, currency: .JPY)
        let small = try Money(amount: 200, currency: .JPY)

        #expect(throws: MoneyError.self) {
            _ = try large + small
        }
    }

    @Test("Addition near Int.max succeeds")
    func additionNearIntMax() throws {
        let large = try Money(amount: Int.max - 100, currency: .JPY)
        let small = try Money(amount: 50, currency: .JPY)

        let result = try large + small
        #expect(result.amount == Int.max - 50)
    }

    @Test("Multiplication overflow detection")
    func multiplicationOverflow() throws {
        let large = try Money(amount: Int.max / 2 + 1, currency: .JPY)

        #expect(throws: MoneyError.self) {
            _ = try large * 3
        }
    }

    @Test("Multiplication near Int.max succeeds")
    func multiplicationNearIntMax() throws {
        let money = try Money(amount: 1000, currency: .JPY)
        let result = try money * (Int.max / 1000)

        // Should succeed without overflow
        #expect(result.amount > 0)
    }

    @Test("Multiplication by zero is safe")
    func multiplicationByZero() throws {
        let money = try Money(amount: Int.max, currency: .JPY)
        let result = try money * 0

        #expect(result.amount == 0)
    }

    @Test("Addition of zero is safe")
    func additionOfZero() throws {
        let large = try Money(amount: Int.max, currency: .JPY)
        let zero = try Money(amount: 0, currency: .JPY)

        let result = try large + zero
        #expect(result.amount == Int.max)
    }

    @Test("Large allocation maintains sum")
    func largeAllocation() throws {
        let large = try Money(amount: Int.max - 1000, currency: .JPY)
        let parts = try large.allocate(by: [1, 1, 1])

        let sum = parts.reduce(0) { $0 + $1.amount }
        #expect(sum == Int.max - 1000)
    }

    @Test("Large distribution maintains sum")
    func largeDistribution() throws {
        let large = try Money(amount: Int.max - 1000, currency: .JPY)
        let parts = try large.distribute(into: 7)

        let sum = parts.reduce(0) { $0 + $1.amount }
        #expect(sum == Int.max - 1000)
    }

    @Test("Decimal multiplication throws overflow error")
    func decimalMultiplicationOverflow() throws {
        let large = try Money(amount: Int.max / 2, currency: .JPY)

        #expect(throws: MoneyError.self) {
            _ = try large.multiplied(by: 3, rounding: .down)
        }
        #expect(throws: MoneyError.self) {
            _ = try large.multiplied(by: -3, rounding: .down)
        }
    }

    @Test("Decimal multiplication succeeds with large valid multiplication")
    func decimalMultiplicationLarge() throws {
        let money = try Money(amount: 1_000_000_000, currency: .JPY)
        let result = try money.multiplied(by: 1.5, rounding: .bankers)

        #expect(result.amount == 1_500_000_000)
    }

    // MARK: - Negation

    @Test("Negation flips sign; zero stays zero")
    func negation() throws {
        let money = try Money(amount: 500, currency: .USD)

        #expect((-money).amount == -500)
        #expect(money.negated() == -money)
        #expect(-(-money) == money)
        #expect(-Money.zero(.USD) == Money.zero(.USD))
        #expect(try (-Money(amount: Int.max, currency: .JPY)).amount == -Int.max)
    }

    @Test("abs drops the sign")
    func absoluteValue() throws {
        let money = try Money(amount: 500, currency: .USD)

        #expect((-money).abs() == money)
        #expect(money.abs() == money)
        #expect(Money.zero(.USD).abs() == Money.zero(.USD))
    }

    @Test("Arithmetic landing exactly on Int.min throws instead of trapping")
    func intMinResults() throws {
        let nearMin = try Money(amount: -Int.max, currency: .JPY)
        let one = try Money(amount: 1, currency: .JPY)

        #expect(throws: MoneyError.self) { try nearMin - one }
        #expect(throws: MoneyError.self) { try Money(amount: Int.min / 2, currency: .JPY) * 2 }
    }

    @Test("Addition across sign combinations", arguments: [
        (500, 300, 800),
        (500, -300, 200),
        (-500, 300, -200),
        (-500, -300, -800),
        (500, -500, 0),
    ])
    func signedAddition(lhs: Int, rhs: Int, expected: Int) throws {
        let sum = try Money(amount: lhs, currency: .USD) + Money(amount: rhs, currency: .USD)
        #expect(sum.amount == expected)
    }

    // MARK: - Summation

    @Test("sum totals a sequence, nets signs, and defines the empty case")
    func sum() throws {
        let entries = [
            try Money(amount: 5000, currency: .USD),   // income
            try Money(amount: -3000, currency: .USD),  // rent
            try Money(amount: -2500, currency: .USD),  // groceries
        ]

        #expect(try entries.sum(in: .USD).amount == -500)
        #expect(try [Money]().sum(in: .USD).isZero)
        #expect(throws: MoneyError.self) {
            try entries.sum(in: .EUR)
        }
    }

    // MARK: - Negative Splitting

    @Test("Allocation of a negative value gives negative parts that sum exactly")
    func allocateNegative() throws {
        let total = try Money(amount: -10000, currency: .USD)
        let parts = try total.allocate(by: [1, 1, 1])

        #expect(parts.map(\.amount) == [-3334, -3333, -3333])
        #expect(try parts.sum(in: .USD) == total)
    }

    @Test("Allocation of a negative value gives a zero ratio zero")
    func allocateNegativeZeroRatio() throws {
        let parts = try Money(amount: -5, currency: .USD).allocate(by: [0, 1, 1])

        #expect(parts.map(\.amount) == [0, -3, -2])
    }

    @Test("Allocation keeps the currency and sums exactly", arguments: [
        ("USD", -10001, [70, 30]),
        ("JPY", -1001, [1, 2, 3]),
        ("KWD", -1000, [3, 0, 4]),
        ("USD", 9999, [1, 1, 1, 1]),
        ("JPY", -(Int.max - 1000), [1, 1, 1]),
    ])
    func allocateSumsExactly(code: String, amount: Int, ratios: [Int]) throws {
        let currency = try Currency(code: code)
        let total = try Money(amount: amount, currency: currency)
        let parts = try total.allocate(by: ratios)

        #expect(parts.count == ratios.count)
        #expect(parts.allSatisfy { $0.currency == currency })
        #expect(try parts.sum(in: currency) == total)
    }

    @Test("Distribution of a negative value gives negative parts that sum exactly")
    func distributeNegative() throws {
        let parts = try Money(amount: -100, currency: .USD).distribute(into: 3)

        #expect(parts.map(\.amount) == [-34, -33, -33])
    }

    @Test("Distribution with negative parts throws error")
    func distributionNegativeParts() throws {
        #expect(throws: MoneyError.self) {
            _ = try Money(amount: 100, currency: .USD).distribute(into: -1)
        }
    }

    // MARK: - Remaining Error Paths

    @Test("Subtraction overflow throws instead of trapping")
    func subtractionOverflow() throws {
        let low = try Money(amount: -Int.max, currency: .JPY)
        let high = try Money(amount: Int.max, currency: .JPY)

        #expect(throws: MoneyError.self) { try low - high }
        #expect(throws: MoneyError.self) { try high - low }
    }

    @Test("Division overflow throws")
    func divisionOverflow() throws {
        let large = try Money(amount: Int.max / 2, currency: .JPY)

        #expect(throws: MoneyError.self) {
            _ = try large.divided(by: 0.1, rounding: .down)
        }
    }

    @Test("Allocation with all-zero ratios throws")
    func allocationAllZeroRatios() throws {
        #expect(throws: MoneyError.self) {
            _ = try Money(amount: -100, currency: .USD).allocate(by: [0, 0])
        }
    }

    @Test("sum overflow throws")
    func sumOverflow() throws {
        let large = try Money(amount: Int.max, currency: .JPY)

        #expect(throws: MoneyError.self) {
            try [large, large].sum(in: .JPY)
        }
    }
}
