import Foundation
import Testing
@testable import MoneyKit

// `<` on values that can't be compared is a precondition failure. Exit tests
// run each body in a child process and check that it stops. Capturing a
// fixture's currencies needs Swift 6.3; 6.2 runs fixed USD cases instead.

#if compiler(>=6.3) && (os(macOS) || os(Linux) || os(Windows))
@Suite("Comparable Precondition Tests")
struct ComparablePreconditionTests {

    /// Checks that the child process printed `message` to stderr when it stopped.
    private func expectMessage(_ message: String?, in result: ExitTest.Result?) {
        let stderr = result.map { String(decoding: $0.standardErrorContent, as: UTF8.self) } ?? ""
        #expect(message.map { stderr.contains($0) } == true, "stderr: \(stderr)")
    }

    @Test("Money < with a different code stops the process", arguments: CurrencyFixture.all)
    func moneyDifferentCode(fixture: CurrencyFixture) async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) { [currency = fixture.currency as Currency, other = fixture.otherCode as Currency] in
            _ = try! Money(amount: 100, currency: currency) < Money(amount: 100, currency: other)
        }
        expectMessage(fixture.currency.comparisonFailure(with: fixture.otherCode, comparing: "Money"), in: result)
    }

    @Test("Money < at different decimal places stops the process", arguments: CurrencyFixture.all)
    func moneyDifferentDecimalPlaces(fixture: CurrencyFixture) async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) { [currency = fixture.currency as Currency, rescaled = fixture.rescaled as Currency] in
            _ = try! Money(amount: 100, currency: currency) < Money(amount: 100, currency: rescaled)
        }
        expectMessage(fixture.currency.comparisonFailure(with: fixture.rescaled, comparing: "Money"), in: result)
    }

    @Test("BigMoney < with a different code stops the process", arguments: CurrencyFixture.all)
    func bigMoneyDifferentCode(fixture: CurrencyFixture) async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) { [currency = fixture.currency as Currency, other = fixture.otherCode as Currency] in
            _ = BigMoney(amount: 1, currency: currency) < BigMoney(amount: 1, currency: other)
        }
        expectMessage(fixture.currency.comparisonFailure(with: fixture.otherCode, comparing: "BigMoney"), in: result)
    }

    @Test("BigMoney < at different decimal places stops the process", arguments: CurrencyFixture.all)
    func bigMoneyDifferentDecimalPlaces(fixture: CurrencyFixture) async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) { [currency = fixture.currency as Currency, rescaled = fixture.rescaled as Currency] in
            _ = BigMoney(amount: 1, currency: currency) < BigMoney(amount: 1, currency: rescaled)
        }
        expectMessage(fixture.currency.comparisonFailure(with: fixture.rescaled, comparing: "BigMoney"), in: result)
    }

    @Test("max() on mixed currencies stops the process", arguments: CurrencyFixture.all)
    func sequenceMax(fixture: CurrencyFixture) async {
        let result = await #expect(processExitsWith: .failure, observing: [\.standardErrorContent]) { [currency = fixture.currency as Currency, rescaled = fixture.rescaled as Currency] in
            _ = [try! Money(amount: 1, currency: currency), try! Money(amount: 2, currency: rescaled)].max()
        }
        // max() may compare in either order, so check only the common part.
        expectMessage("Cannot compare Money values. Decimal places mismatch: \(fixture.currency.code)", in: result)
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

/// The message `<` stops with, checked in-process for every fixture.
@Suite("Comparison Failure Message Tests")
struct ComparisonFailureMessageTests {

    @Test("Comparable currencies have no failure message", arguments: CurrencyFixture.all)
    func sameCurrency(fixture: CurrencyFixture) throws {
        let copy = try Currency(code: fixture.currency.code, decimalPlaces: fixture.decimalPlaces)
        #expect(fixture.currency.comparisonFailure(with: copy, comparing: "Money") == nil)
    }

    @Test("The message names the type and the mismatch", arguments: CurrencyFixture.all)
    func mismatch(fixture: CurrencyFixture) throws {
        let currency = fixture.currency

        for typeName in ["Money", "BigMoney"] {
            let otherCode = try #require(currency.comparisonFailure(with: fixture.otherCode, comparing: typeName))
            #expect(otherCode.hasPrefix("Cannot compare \(typeName) values. Currency mismatch: "))
            #expect(otherCode.contains(currency.code) && otherCode.contains(fixture.otherCode.code))

            let rescaled = try #require(currency.comparisonFailure(with: fixture.rescaled, comparing: typeName))
            #expect(rescaled.hasPrefix("Cannot compare \(typeName) values. Decimal places mismatch: "))
            #expect(rescaled.contains("\(fixture.decimalPlaces)") && rescaled.contains("\(fixture.rescaled.decimalPlaces)"))
        }
    }
}
