import Foundation
import Testing
@testable import MoneyKit

/// The same currency code at different decimal places is a different scale:
/// combining the amounts throws `decimalPlacesMismatch`, not `currencyMismatch`.
@Suite("Decimal Places Mismatch Tests")
struct DecimalPlacesMismatchTests {

    /// Whether `error` is `decimalPlacesMismatch` for `fixture` vs its rescaled twin (in either order).
    private func isMismatch(_ error: MoneyError?, _ fixture: CurrencyFixture) -> Bool {
        guard case .decimalPlacesMismatch(let code, let lhs, let rhs) = error else { return false }
        return code == fixture.currency.code
            && Set([lhs, rhs]) == [fixture.decimalPlaces, fixture.rescaled.decimalPlaces]
    }

    @Test("The same amount at different decimal places is not equal", arguments: CurrencyFixture.all)
    func notEqual(fixture: CurrencyFixture) throws {
        let a = try fixture.money(34590)
        let b = try Money(amount: 34590, currency: fixture.rescaled)

        #expect(a != b)
        #expect(a.tryCompare(b) == nil)
        #expect(a.toBigMoney() != b.toBigMoney())
        #expect(a.toBigMoney().tryCompare(b.toBigMoney()) == nil)
    }

    @Test("Money arithmetic throws decimalPlacesMismatch", arguments: CurrencyFixture.all)
    func moneyArithmetic(fixture: CurrencyFixture) throws {
        let a = try fixture.money(34590)
        let b = try Money(amount: 100, currency: fixture.rescaled)

        #expect(isMismatch(#expect(throws: MoneyError.self) { try a + b }, fixture))
        #expect(isMismatch(#expect(throws: MoneyError.self) { try a - b }, fixture))
        #expect(isMismatch(#expect(throws: MoneyError.self) { try b - a }, fixture))
        #expect(isMismatch(#expect(throws: MoneyError.self) { try [a, b].sum(in: fixture.currency) }, fixture))
        #expect(isMismatch(#expect(throws: MoneyError.self) { try [a].sum(in: fixture.rescaled) }, fixture))
    }

    @Test("BigMoney arithmetic throws decimalPlacesMismatch", arguments: CurrencyFixture.all)
    func bigMoneyArithmetic(fixture: CurrencyFixture) throws {
        let a = try fixture.money(1000).toBigMoney()
        let b = try Money(amount: 1000, currency: fixture.rescaled)

        #expect(isMismatch(#expect(throws: MoneyError.self) { try a + b }, fixture))
        #expect(isMismatch(#expect(throws: MoneyError.self) { try a - b }, fixture))
        #expect(isMismatch(#expect(throws: MoneyError.self) { try a + b.toBigMoney() }, fixture))
        #expect(isMismatch(#expect(throws: MoneyError.self) { try a - b.toBigMoney() }, fixture))
        #expect(isMismatch(#expect(throws: MoneyError.self) { try [a, b.toBigMoney()].sum(in: fixture.currency) }, fixture))
    }

    @Test("Different codes still throw currencyMismatch", arguments: CurrencyFixture.all)
    func differentCodes(fixture: CurrencyFixture) throws {
        let a = try fixture.money(100)
        let b = try Money(amount: 100, currency: fixture.otherCode)

        let error = #expect(throws: MoneyError.self) { try a + b }
        guard case .currencyMismatch = error else {
            Issue.record("Expected currencyMismatch, got \(String(describing: error))")
            return
        }
    }

    @Test("The message names the code and both decimal places")
    func message() {
        let description = MoneyError.decimalPlacesMismatch(code: "USD", lhs: 2, rhs: 4).errorDescription ?? ""

        #expect(description.contains("USD"))
        #expect(description.contains("2 and 4 decimal places"))
        #expect(description.contains("custom decimalPlaces"))
    }
}
