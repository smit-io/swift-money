import Testing
import Foundation
@testable import MoneyKit

@Suite("Money Calculation Tests")
struct MoneyCalculationTests {

    @Test("Money * Double creates MoneyCalculation")
    func multiplicationCreatesCalculation() throws {
        let money = try Money(amount: 1234, currency: .JPY)
        let calc = money * 1.1

        // Verify we can round the calculation
        let result = try calc.roundedDown
        #expect(result.amount == 1357)
    }

    @Test("Rounding up calculation")
    func roundingUp() throws {
        let money = try Money(amount: 1234, currency: .JPY)
        let calc = money * 1.1  // 1357.4

        let result = try calc.roundedUp
        #expect(result.amount == 1358)
        #expect(result.currency == .JPY)
    }

    @Test("Rounding down calculation")
    func roundingDown() throws {
        let money = try Money(amount: 1234, currency: .JPY)
        let calc = money * 1.1  // 1357.4

        let result = try calc.roundedDown
        #expect(result.amount == 1357)
        #expect(result.currency == .JPY)
    }

    @Test("Half up rounding")
    func halfUpRounding() throws {
        // Test 0.5 rounds up
        let money = try Money(amount: 1000, currency: .JPY)
        let calc = money * 1.05  // 1050.0 (no rounding needed)

        let result = try calc.halfUp
        #expect(result.amount == 1050)

        // Test 0.4 rounds down
        let calc2 = money * 1.04  // 1040.0
        let result2 = try calc2.halfUp
        #expect(result2.amount == 1040)

        // Test 0.6 rounds up
        let calc3 = money * 1.06  // 1060.0
        let result3 = try calc3.halfUp
        #expect(result3.amount == 1060)
    }

    @Test("Banker's rounding")
    func bankersRounding() throws {
        let money = try Money(amount: 1000, currency: .JPY)
        let calc = money * 1.05  // 1050.0

        let result = try calc.bankers
        #expect(result.amount == 1050)
    }

    @Test("Default value uses banker's rounding")
    func defaultValueUsesBankers() throws {
        let money = try Money(amount: 1234, currency: .JPY)
        let calc = money * 1.1

        let defaultValue = try calc.value
        let bankersValue = try calc.bankers

        #expect(defaultValue == bankersValue)
    }

    @Test("Chained multiplication")
    func chainedMultiplication() throws {
        let money = try Money(amount: 1000, currency: .JPY)
        let calc = money * 0.8 * 1.1  // 1000 * 0.8 * 1.1 = 880

        let result = try calc.roundedDown
        #expect(result.amount == 880)
    }

    @Test("Division creates calculation")
    func divisionCreatesCalculation() throws {
        let money = try Money(amount: 1000, currency: .JPY)
        let calc = try money / 3.0  // 333.333...

        let up = try calc.roundedUp
        #expect(up.amount == 334)

        let down = try calc.roundedDown
        #expect(down.amount == 333)
    }

    @Test("Division by zero throws error")
    func divisionByZero() throws {
        let money = try Money(amount: 1000, currency: .JPY)

        #expect(throws: MoneyError.self) {
            _ = try money / 0.0
        }
    }

    @Test("Float multiplication")
    func floatMultiplication() throws {
        let money = try Money(amount: 1000, currency: .JPY)
        let calc = money * Float(1.1)

        let result = try calc.roundedDown
        #expect(result.amount == 1100)
    }

    @Test("Multiple rounding modes on same calculation")
    func multipleRoundingModes() throws {
        let money = try Money(amount: 1234, currency: .JPY)
        let calc = money * 1.1  // 1357.4

        let up = try calc.roundedUp
        let down = try calc.roundedDown
        let half = try calc.halfUp
        let banker = try calc.bankers

        #expect(up.amount == 1358)
        #expect(down.amount == 1357)
        #expect(half.amount == 1357)  // .4 rounds down
        #expect(banker.amount == 1357)
    }

    @Test("USD calculation with decimals")
    func usdCalculation() throws {
        let money = try Money(amount: 1999, currency: .USD)  // $19.99
        let calc = money * 1.08  // $21.5892

        let up = try calc.roundedUp
        #expect(up.amount == 2159)  // $21.59

        let down = try calc.roundedDown
        #expect(down.amount == 2158)  // $21.58
    }

    @Test("KWD calculation with 3 decimals")
    func kwdCalculation() throws {
        let money = try Money(amount: 1234, currency: .KWD)  // 1.234 KWD
        let calc = money * 1.1  // 1.3574

        let up = try calc.roundedUp
        #expect(up.amount == 1358)  // 1.358

        let down = try calc.roundedDown
        #expect(down.amount == 1357)  // 1.357
    }

    @Test("Addition of calculations")
    func calculationAddition() throws {
        let money1 = try Money(amount: 1000, currency: .JPY)
        let money2 = try Money(amount: 500, currency: .JPY)

        let calc1 = money1 * 1.1
        let calc2 = money2 * 1.1

        let combined = try calc1 + calc2
        let result = try combined.roundedDown

        #expect(result.amount == 1650)  // (1100 + 550)
    }

    @Test("Subtraction of calculations")
    func calculationSubtraction() throws {
        let money1 = try Money(amount: 1000, currency: .JPY)
        let money2 = try Money(amount: 300, currency: .JPY)

        let calc1 = money1 * 1.1
        let calc2 = money2 * 1.1

        let combined = try calc1 - calc2
        let result = try combined.roundedDown

        #expect(result.amount == 770)  // (1100 - 330)
    }

    @Test("Currency mismatch in calculation addition")
    func currencyMismatchAddition() throws {
        let jpy = try Money(amount: 1000, currency: .JPY)
        let usd = try Money(amount: 1000, currency: .USD)

        let calc1 = jpy * 1.1
        let calc2 = usd * 1.1

        #expect(throws: MoneyError.self) {
            _ = try calc1 + calc2
        }
    }

    @Test("Complex calculation scenario")
    func complexScenario() throws {
        // Discount 20%, then add 10% tax
        let price = try Money(amount: 10000, currency: .JPY)
        let discounted = price * 0.8
        let withTax = discounted * 1.1

        let final = try withTax.roundedDown
        #expect(final.amount == 8800)  // 10000 * 0.8 * 1.1
    }

    @Test("Convenience multiply method")
    func convenienceMultiply() throws {
        let money = try Money(amount: 1234, currency: .JPY)

        let up = try money.multiply(by: 1.1, rounding: .up)
        #expect(up.amount == 1358)

        let down = try money.multiply(by: 1.1, rounding: .down)
        #expect(down.amount == 1357)
    }

    @Test("Convenience divide method")
    func convenienceDivide() throws {
        let money = try Money(amount: 1000, currency: .JPY)

        let up = try money.divide(by: 3.0, rounding: .up)
        #expect(up.amount == 334)

        let down = try money.divide(by: 3.0, rounding: .down)
        #expect(down.amount == 333)
    }

    @Test("withTax convenience method")
    func withTaxMethod() throws {
        let price = try Money(amount: 1000, currency: .JPY)

        // Default 10% tax, round down
        let withTax = try price.withTax()
        #expect(withTax.amount == 1100)

        // Custom tax rate
        let withTax8 = try price.withTax(rate: 1.08)
        #expect(withTax8.amount == 1080)

        // Custom rounding
        let withTaxUp = try price.withTax(rate: 1.08, rounding: .up)
        #expect(withTaxUp.amount == 1080)
    }

    // MARK: - Overflow Tests

    @Test("Calculation overflow on rounding")
    func calculationOverflow() {
        let large = try! Money(amount: Int.max - 1000, currency: .JPY)
        let calc = large * 1.5  // Will exceed Int.max

        #expect(throws: MoneyError.self) {
            _ = try calc.roundedDown
        }
    }

    @Test("Calculation near Int.max succeeds")
    func calculationNearIntMax() throws {
        let large = try Money(amount: Int.max - 1000, currency: .JPY)
        let calc = large * 0.99  // Should stay within bounds

        let result = try calc.roundedDown
        #expect(result.amount > 0)
        #expect(result.amount < Int.max)
    }

    @Test("Very large multiplication overflow")
    func veryLargeMultiplication() {
        let large = try! Money(amount: Int.max / 2, currency: .JPY)
        let calc = large * 3.0  // Will overflow

        #expect(throws: MoneyError.self) {
            _ = try calc.roundedUp
        }

        #expect(throws: MoneyError.self) {
            _ = try calc.roundedDown
        }

        #expect(throws: MoneyError.self) {
            _ = try calc.bankers
        }
    }

    @Test("Negative calculation result is rejected")
    func negativeCalculationResult() {
        let money = try! Money(amount: 1000, currency: .JPY)
        let calc = money * -1.5  // Negative result

        #expect(throws: MoneyError.self) {
            _ = try calc.roundedDown
        }
    }

    @Test("Calculation addition overflow")
    func calculationAdditionOverflow() throws {
        let large1 = try Money(amount: Int.max - 500, currency: .JPY)
        let large2 = try Money(amount: 1000, currency: .JPY)

        let calc1 = large1 * 1.0
        let calc2 = large2 * 1.0

        let combined = try calc1 + calc2  // Will exceed Int.max

        #expect(throws: MoneyError.self) {
            _ = try combined.roundedDown
        }
    }
}
