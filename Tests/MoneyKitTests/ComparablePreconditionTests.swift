import Foundation
import Testing
@testable import MoneyKit

// `<` on values that can't be compared is a precondition failure. Exit tests
// run each body in a child process and check that it stops. Capturing a
// fixture's currencies needs Swift 6.3; 6.2 runs fixed USD cases instead.

#if compiler(>=6.3) && (os(macOS) || os(Linux) || os(Windows))
@Suite("Comparable Precondition Tests")
struct ComparablePreconditionTests {

    @Test("Money < with a different code stops the process", arguments: CurrencyFixture.all)
    func moneyDifferentCode(fixture: CurrencyFixture) async {
        await #expect(processExitsWith: .failure) { [currency = fixture.currency as Currency, other = fixture.otherCode as Currency] in
            _ = try! Money(amount: 100, currency: currency) < Money(amount: 100, currency: other)
        }
    }

    @Test("Money < at different decimal places stops the process", arguments: CurrencyFixture.all)
    func moneyDifferentDecimalPlaces(fixture: CurrencyFixture) async {
        await #expect(processExitsWith: .failure) { [currency = fixture.currency as Currency, rescaled = fixture.rescaled as Currency] in
            _ = try! Money(amount: 100, currency: currency) < Money(amount: 100, currency: rescaled)
        }
    }

    @Test("BigMoney < with a different code stops the process", arguments: CurrencyFixture.all)
    func bigMoneyDifferentCode(fixture: CurrencyFixture) async {
        await #expect(processExitsWith: .failure) { [currency = fixture.currency as Currency, other = fixture.otherCode as Currency] in
            _ = BigMoney(amount: 1, currency: currency) < BigMoney(amount: 1, currency: other)
        }
    }

    @Test("BigMoney < at different decimal places stops the process", arguments: CurrencyFixture.all)
    func bigMoneyDifferentDecimalPlaces(fixture: CurrencyFixture) async {
        await #expect(processExitsWith: .failure) { [currency = fixture.currency as Currency, rescaled = fixture.rescaled as Currency] in
            _ = BigMoney(amount: 1, currency: currency) < BigMoney(amount: 1, currency: rescaled)
        }
    }

    @Test("max() on mixed currencies stops the process", arguments: CurrencyFixture.all)
    func sequenceMax(fixture: CurrencyFixture) async {
        await #expect(processExitsWith: .failure) { [currency = fixture.currency as Currency, rescaled = fixture.rescaled as Currency] in
            _ = [try! Money(amount: 1, currency: currency), try! Money(amount: 2, currency: rescaled)].max()
        }
    }
}
#elseif compiler(>=6.2) && (os(macOS) || os(Linux) || os(Windows))
@Suite("Comparable Precondition Tests")
struct ComparablePreconditionTests {

    @Test("Money < with a different code stops the process")
    func moneyDifferentCode() async {
        await #expect(processExitsWith: .failure) {
            _ = try! Money(amount: 100, currency: .USD) < Money(amount: 100, currency: .EUR)
        }
    }

    @Test("Money < at different decimal places stops the process")
    func moneyDifferentDecimalPlaces() async {
        await #expect(processExitsWith: .failure) {
            _ = try! Money(amount: 100, currency: .USD) < Money(amount: 100, currency: Currency(code: "USD", decimalPlaces: 4))
        }
    }

    @Test("BigMoney < with a different code stops the process")
    func bigMoneyDifferentCode() async {
        await #expect(processExitsWith: .failure) {
            _ = BigMoney(amount: 1, currency: .USD) < BigMoney(amount: 1, currency: .EUR)
        }
    }

    @Test("BigMoney < at different decimal places stops the process")
    func bigMoneyDifferentDecimalPlaces() async {
        await #expect(processExitsWith: .failure) {
            _ = BigMoney(amount: 1, currency: .USD) < BigMoney(amount: 1, currency: try! Currency(code: "USD", decimalPlaces: 4))
        }
    }
}
#endif
