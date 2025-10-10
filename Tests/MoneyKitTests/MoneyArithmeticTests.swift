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

    @Test("Subtraction resulting in negative throws error")
    func subtractionNegativeResult() throws {
        let m1 = try Money(amount: 100, currency: .USD)
        let m2 = try Money(amount: 500, currency: .USD)

        #expect(throws: MoneyError.self) {
            _ = try m1 - m2
        }
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

    @Test("Multiplication by decimal")
    func multiplicationByDecimal() throws {
        let money = try Money(amount: 100, currency: .USD)
        let result = try money * Decimal(1.5)

        #expect(result.amount == 150)
        #expect(result.currency == .USD)
    }

    @Test("Multiplication by negative throws error")
    func multiplicationByNegative() throws {
        let money = try Money(amount: 100, currency: .USD)

        #expect(throws: MoneyError.self) {
            _ = try money * -2
        }
    }

    @Test("Division by integer")
    func divisionByInteger() throws {
        let money = try Money(amount: 100, currency: .USD)
        let result = try money / 4

        #expect(result.amount == 25)
        #expect(result.currency == .USD)
    }

    @Test("Division by zero throws error")
    func divisionByZero() throws {
        let money = try Money(amount: 100, currency: .USD)

        #expect(throws: MoneyError.self) {
            _ = try money / 0
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

    @Test("Allocation with empty ratios throws error")
    func allocationEmptyRatios() throws {
        let money = try Money(amount: 100, currency: .USD)

        #expect(throws: MoneyError.self) {
            _ = try money.allocate(by: [])
        }
    }

    @Test("Percentage calculation")
    func percentage() throws {
        let money = try Money(amount: 10000, currency: .USD)  // $100.00
        let tax = try money.percentage(0.15)  // 15%

        #expect(tax.amount == 1500)  // $15.00
        #expect(tax.currency == .USD)
    }

    @Test("Safe addition - try add")
    func tryAdd() throws {
        let m1 = try Money(amount: 100, currency: .USD)
        let m2 = try Money(amount: 50, currency: .USD)
        let m3 = try Money(amount: 50, currency: .EUR)

        let result = m1.tryAdd(m2)
        #expect(result?.amount == 150)

        let mismatch = m1.tryAdd(m3)
        #expect(mismatch == nil)
    }

    @Test("Safe subtraction - try subtract")
    func trySubtract() throws {
        let m1 = try Money(amount: 100, currency: .USD)
        let m2 = try Money(amount: 50, currency: .USD)
        let m3 = try Money(amount: 150, currency: .USD)
        let m4 = try Money(amount: 50, currency: .EUR)

        let result = m1.trySubtract(m2)
        #expect(result?.amount == 50)

        let negative = m1.trySubtract(m3)
        #expect(negative == nil)

        let mismatch = m1.trySubtract(m4)
        #expect(mismatch == nil)
    }

    @Test("Safe multiplication - try multiply")
    func tryMultiply() throws {
        let money = try Money(amount: 100, currency: .USD)

        let result = money.tryMultiply(by: 5)
        #expect(result?.amount == 500)

        let negative = money.tryMultiply(by: -2)
        #expect(negative == nil)
    }

    @Test("Safe division - try divide")
    func tryDivide() throws {
        let money = try Money(amount: 100, currency: .USD)

        let result = money.tryDivide(by: 4)
        #expect(result?.amount == 25)

        let zero = money.tryDivide(by: 0)
        #expect(zero == nil)
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

    @Test("Absolute value")
    func absoluteValue() throws {
        // Money is always non-negative, so absolute should return self
        let money = try Money(amount: 100, currency: .USD)
        #expect(money.absolute == money)
    }

    @Test("Complex calculation example")
    func complexCalculation() throws {
        // Simulate: $100 item + 8.5% tax
        let price = try Money(amount: 10000, currency: .USD)
        let taxRate = Decimal(0.085)
        let tax = try price.percentage(taxRate)
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
        let tax = try subtotal.percentage(0.075)

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

    // MARK: - Safe Arithmetic Overflow Tests

    @Test("tryAdd returns nil on overflow")
    func tryAddOverflow() throws {
        let large = try Money(amount: Int.max - 100, currency: .JPY)
        let small = try Money(amount: 200, currency: .JPY)

        let result = large.tryAdd(small)
        #expect(result == nil)  // Should return nil, not crash
    }

    @Test("tryAdd succeeds near Int.max")
    func tryAddNearMax() throws {
        let large = try Money(amount: Int.max - 100, currency: .JPY)
        let small = try Money(amount: 50, currency: .JPY)

        let result = large.tryAdd(small)
        #expect(result?.amount == Int.max - 50)
    }

    @Test("tryMultiply returns nil on overflow")
    func tryMultiplyOverflow() throws {
        let large = try Money(amount: Int.max / 2 + 1, currency: .JPY)

        let result = large.tryMultiply(by: 3)
        #expect(result == nil)  // Should return nil, not crash
    }

    @Test("tryMultiply succeeds with valid multiplication")
    func tryMultiplyValid() throws {
        let money = try Money(amount: 1000, currency: .JPY)

        let result = money.tryMultiply(by: 100)
        #expect(result?.amount == 100000)
    }

    @Test("tryDivide returns nil on division by zero")
    func tryDivideByZero() throws {
        let money = try Money(amount: 1000, currency: .JPY)

        let result = money.tryDivide(by: 0)
        #expect(result == nil)
    }

    @Test("tryDivide succeeds with valid division")
    func tryDivideValid() throws {
        let money = try Money(amount: 1000, currency: .JPY)

        let result = money.tryDivide(by: 3)
        #expect(result?.amount == 333)
    }

    @Test("Money * Decimal throws overflow error")
    func decimalMultiplicationOverflow() throws {
        let large = try Money(amount: Int.max / 2, currency: .JPY)

        #expect(throws: MoneyError.self) {
            _ = try large * Decimal(3.0)
        }
    }

    @Test("Money * Decimal succeeds with large valid multiplication")
    func decimalMultiplicationLarge() throws {
        let money = try Money(amount: 1_000_000_000, currency: .JPY)
        let result = try money * Decimal(1.5)

        #expect(result.amount == 1_500_000_000)
    }
}
