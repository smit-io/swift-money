import Foundation
import Testing
@testable import MoneyKit

/// `Double` arguments convert through their shortest text, like joda-money's
/// `BigDecimal.valueOf(double)`, so a literal like `0.07` is exactly 0.07.
/// A `Decimal` built from the same literal goes through `Double` and is not:
/// `Decimal(0.07)` is 0.07000000000000001024.
@Suite("Double Conversion Tests")
struct DoubleConversionTests {

    // MARK: - The bug this fixes

    @Test("A Double rate is exact: 100 × 0.07 rounded up is 7, not 8")
    func literalRateIsExact() throws {
        let money = try Money(amount: 100, currency: .JPY)

        #expect(try money.multiplied(by: 0.07, rounding: .up).amount == 7)
        #expect(try money.multiplied(by: 0.07, rounding: .down).amount == 7)
        #expect(try (money.toBigMoney() * 0.07).rounded(.up).amount == 7)
    }

    @Test("A Double amount is exact: 19.99 is 1999 cents under every mode")
    func literalAmountIsExact() throws {
        for mode in [RoundingMode.up, .down, .halfUp, .bankers, .towardZero, .awayFromZero] {
            #expect(try Money(decimalAmount: 19.99, currency: .USD, rounding: mode).amount == 1999)
        }
        #expect(try BigMoney(amount: 19.99, currency: .USD).amount == Decimal(string: "19.99"))
    }

    @Test("Every 2- and 3-decimal value from 0 to 100 converts exactly")
    func exhaustiveConversion() throws {
        for cents in 0..<10_000 {
            #expect(try Decimal(shortestRepresentationOf: Double(cents) / 100) == Decimal(cents) / 100)
        }
        for mills in 0..<100_000 {
            #expect(try Decimal(shortestRepresentationOf: Double(mills) / 1000) == Decimal(mills) / 1000)
        }
    }

    @Test("Conversion handles signs, exponents, and large values", arguments: [
        (-0.07, "-0.07"),
        (1e-7, "0.0000001"),
        (1.5e20, "150000000000000000000"),
        (0.1 + 0.2, "0.30000000000000004"),  // already inexact as a Double; stays so
    ])
    func conversionEdgeCases(value: Double, expected: String) throws {
        #expect(try Decimal(shortestRepresentationOf: value) == Decimal(string: expected))
    }

    // MARK: - Invalid Doubles

    @Test("NaN, infinity, and out-of-range values throw invalidDecimal", arguments: [
        Double.nan, .infinity, -.infinity, 1e300, 1e-200,
    ])
    func invalidDoubles(value: Double) throws {
        let money = try Money(amount: 100, currency: .USD)
        let big = money.toBigMoney()

        for error in [
            #expect(throws: MoneyError.self) { try money.multiplied(by: value, rounding: .down) },
            #expect(throws: MoneyError.self) { try money.divided(by: value, rounding: .down) },
            #expect(throws: MoneyError.self) { try Money(decimalAmount: value, currency: .USD, rounding: .down) },
            #expect(throws: MoneyError.self) { try BigMoney(amount: value, currency: .USD) },
            #expect(throws: MoneyError.self) { try big * value },
            #expect(throws: MoneyError.self) { try big / value },
        ] {
            guard case .invalidDecimal = error else {
                Issue.record("Expected invalidDecimal, got \(String(describing: error))")
                continue
            }
        }
    }

    @Test("Dividing by a Double zero throws divisionByZero")
    func doubleZeroDivisor() throws {
        let money = try Money(amount: 100, currency: .USD)

        #expect(throws: MoneyError.self) { try money.divided(by: 0.0, rounding: .down) }
        #expect(throws: MoneyError.self) { try money.toBigMoney() / 0.0 }
    }

    // MARK: - Overload selection

    @Test("Integer literals pick the Int overloads")
    func integerOverloads() throws {
        let money = try Money(amount: 1000, currency: .JPY)

        #expect(try money.multiplied(by: 2, rounding: .down).amount == 2000)
        #expect(try money.divided(by: 3, rounding: .down).amount == 333)
        #expect(try Money(decimalAmount: 5000, currency: .JPY, rounding: .down).amount == 5000)
        #expect(try Money(decimalAmount: 50, currency: .USD, rounding: .down).amount == 5000)
        #expect(BigMoney(amount: 12, currency: .USD).amount == 12)
        #expect(try (money.toBigMoney() * 3 / 4).rounded(.down).amount == 750)
        #expect(throws: MoneyError.self) { try money.toBigMoney() / 0 }
    }

    @Test("Decimal values pick the Decimal overloads unchanged")
    func decimalOverloads() throws {
        let money = try Money(amount: 100, currency: .JPY)
        let exact = Decimal(string: "0.07")!
        let viaDouble = Decimal(0.07)  // the pitfall: 0.07000000000000001024

        #expect(try money.multiplied(by: exact, rounding: .up).amount == 7)
        #expect(try money.multiplied(by: viaDouble, rounding: .up).amount == 8)
    }

    @Test("Mixed literal chains type-check and round once")
    func mixedChain() throws {
        let price = try Money(amount: 1234, currency: .JPY)
        let coupon = try Money(amount: 100, currency: .JPY)

        let total = try (price.toBigMoney() * 1.1 - coupon) / 2
        #expect(total.amount == Decimal(string: "628.7"))
        #expect(try total.rounded(.halfUp).amount == 629)
    }
}
