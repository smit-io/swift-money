import Foundation
import Testing
@testable import MoneyKit

/// `Double` arguments convert through their shortest text, like joda-money's
/// `BigDecimal.valueOf(double)`, so a literal like `0.07` is exactly 0.07.
/// A `Decimal` built from the same literal goes through `Double` and is not:
/// `Decimal(0.07)` is 0.07000000000000001024.
@Suite("Double Conversion Tests")
struct DoubleConversionTests {

    // MARK: - Conversion (no currency involved)

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

    // MARK: - The bug this fixes

    @Test("A Double rate is exact: 100 × 0.07 is 7 under every mode", arguments: CurrencyFixture.all, CurrencyFixture.roundingModes)
    func literalRateIsExact(fixture: CurrencyFixture, mode: RoundingMode) throws {
        let money = try fixture.money(100)

        #expect(try money.multiplied(by: 0.07, rounding: mode).amount == 7)
        #expect(try (money.toBigMoney() * 0.07).rounded(mode).amount == 7)
        #expect(try money.divided(by: 0.25, rounding: mode).amount == 400)
        #expect(try (money.toBigMoney() / 0.25).rounded(mode).amount == 400)
    }

    @Test("A Double amount matches the same digits parsed as text", arguments: CurrencyFixture.all, CurrencyFixture.roundingModes)
    func literalAmountMatchesText(fixture: CurrencyFixture, mode: RoundingMode) throws {
        // Below 9 standard units, so every value fits Int at 18 decimal places too.
        for (value, text) in [(0.07, "0.07"), (1.99, "1.99"), (-1.05, "-1.05"), (1.5678, "1.5678"), (0.125, "0.125")] {
            let viaDouble = try Money(decimalAmount: value, currency: fixture.currency, rounding: mode)
            let viaText = try Money(decimalAmount: Decimal(string: text)!, currency: fixture.currency, rounding: mode)
            #expect(viaDouble == viaText, "\(value)")

            #expect(try BigMoney(amount: value, currency: fixture.currency).amount == Decimal(string: text))
        }
    }

    @Test("1.99 is exact at every scale with at least 2 places", arguments: CurrencyFixture.all.filter { $0.decimalPlaces >= 2 })
    func literalAmountIsExact(fixture: CurrencyFixture) throws {
        let expected = fixture.minorUnitsPerUnit / 100 * 199

        for mode in CurrencyFixture.roundingModes {
            #expect(try Money(decimalAmount: 1.99, currency: fixture.currency, rounding: mode).amount == expected)
        }
    }

    // MARK: - Invalid Doubles

    @Test("NaN, infinity, and out-of-range values throw invalidDecimal", arguments: CurrencyFixture.all)
    func invalidDoubles(fixture: CurrencyFixture) throws {
        let money = try fixture.money(100)
        let big = money.toBigMoney()

        for value in [Double.nan, .infinity, -.infinity, 1e300, 1e-200] {
            for error in [
                #expect(throws: MoneyError.self) { try money.multiplied(by: value, rounding: .down) },
                #expect(throws: MoneyError.self) { try money.divided(by: value, rounding: .down) },
                #expect(throws: MoneyError.self) { try Money(decimalAmount: value, currency: fixture.currency, rounding: .down) },
                #expect(throws: MoneyError.self) { try BigMoney(amount: value, currency: fixture.currency) },
                #expect(throws: MoneyError.self) { try big * value },
                #expect(throws: MoneyError.self) { try big / value },
            ] {
                guard case .invalidDecimal = error else {
                    Issue.record("Expected invalidDecimal for \(value), got \(String(describing: error))")
                    continue
                }
            }
        }
    }

    @Test("A NaN Decimal throws invalidDecimal wherever it is rounded or divided by", arguments: CurrencyFixture.all, CurrencyFixture.roundingModes)
    func nanDecimal(fixture: CurrencyFixture, mode: RoundingMode) throws {
        let money = try fixture.money(100)
        let big = money.toBigMoney()
        let nan = BigMoney(amount: Decimal.nan, currency: fixture.currency)

        let errors: [MoneyError?] = [
            // Throwing entry points reject NaN at the call.
            #expect(throws: MoneyError.self) { try money.multiplied(by: Decimal.nan, rounding: mode) },
            #expect(throws: MoneyError.self) { try money.divided(by: Decimal.nan, rounding: mode) },
            #expect(throws: MoneyError.self) { try Money(decimalAmount: Decimal.nan, currency: fixture.currency, rounding: mode) },
            #expect(throws: MoneyError.self) { try big / Decimal.nan },
            #expect(throws: MoneyError.self) { try Money.zero(fixture.currency).divided(by: Decimal.nan, rounding: mode) },
            // A NaN BigMoney can be built without `try`; it fails when rounded.
            #expect(throws: MoneyError.self) { try nan.rounded(mode) },
            #expect(throws: MoneyError.self) { try (big * Decimal.nan).rounded(mode) },
            #expect(throws: MoneyError.self) { try (big + nan).rounded(mode) },
            #expect(throws: MoneyError.self) { try (nan / Decimal(2)).rounded(mode) },
            #expect(throws: MoneyError.self) { try (nan * Decimal(0)).rounded(mode) },
        ]
        for error in errors {
            guard case .invalidDecimal(let value) = error, value.isNaN else {
                Issue.record("Expected invalidDecimal(nan), got \(String(describing: error))")
                continue
            }
        }
    }

    @Test("A NaN Decimal divisor is reported before a zero check", arguments: CurrencyFixture.all)
    func nanBeforeZero(fixture: CurrencyFixture) throws {
        // NaN is checked first, so a NaN is never reported as divisionByZero.
        let error = #expect(throws: MoneyError.self) { try fixture.money(0).toBigMoney() / Decimal.nan }
        guard case .invalidDecimal = error else {
            Issue.record("Expected invalidDecimal, got \(String(describing: error))")
            return
        }
    }

    @Test("Dividing by a Double zero throws divisionByZero", arguments: CurrencyFixture.all)
    func doubleZeroDivisor(fixture: CurrencyFixture) throws {
        let money = try fixture.money(100)

        for error in [
            #expect(throws: MoneyError.self) { try money.divided(by: 0.0, rounding: .down) },
            #expect(throws: MoneyError.self) { try money.toBigMoney() / 0.0 },
        ] {
            guard case .divisionByZero = error else {
                Issue.record("Expected divisionByZero, got \(String(describing: error))")
                continue
            }
        }
    }

    // MARK: - Overload selection

    @Test("Integer literals pick the Int overloads", arguments: CurrencyFixture.all)
    func integerOverloads(fixture: CurrencyFixture) throws {
        let money = try fixture.money(1000)

        #expect(try money.multiplied(by: 2, rounding: .down).amount == 2000)
        #expect(try money.divided(by: 3, rounding: .down).amount == 333)
        #expect(try (money.toBigMoney() * 3 / 4).rounded(.down).amount == 750)
        #expect(throws: MoneyError.self) { try money.toBigMoney() / 0 }
        #expect(throws: MoneyError.self) { try money.divided(by: 0, rounding: .down) }
    }

    @Test("Decimal values pick the Decimal overloads unchanged", arguments: CurrencyFixture.all)
    func decimalOverloads(fixture: CurrencyFixture) throws {
        let money = try fixture.money(100)
        let exact = Decimal(string: "0.07")!
        let viaDouble = Decimal(0.07)  // the pitfall: 0.07000000000000001024

        #expect(try money.multiplied(by: exact, rounding: .up).amount == 7)
        #expect(try money.multiplied(by: viaDouble, rounding: .up).amount == 8)
    }

    @Test("Mixed literal chains type-check and round once", arguments: CurrencyFixture.all)
    func mixedChain(fixture: CurrencyFixture) throws {
        let price = try fixture.money(1234)
        let coupon = try fixture.money(100)

        let total = try (price.toBigMoney() * 1.1 - coupon) / 2
        #expect(total.amount == fixture.standardUnits(minor: "628.7"))
        #expect(try total.rounded(.halfUp).amount == 629)
    }
}
