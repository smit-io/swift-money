import Foundation
import Testing
@testable import MoneyKit

/// The same currency code at different decimal places is a different scale:
/// combining the amounts throws `decimalPlacesMismatch`, not `currencyMismatch`.
@Suite("Decimal Places Mismatch Tests")
struct DecimalPlacesMismatchTests {

    /// USD at its ISO 4217 default (2) and USD built with a custom 4.
    let usd2 = Currency.USD
    let usd4 = try! Currency(code: "USD", decimalPlaces: 4)

    /// Whether `error` is `decimalPlacesMismatch` for USD, 2 vs 4 (in either order).
    private func isUSDMismatch(_ error: MoneyError?) -> Bool {
        guard case .decimalPlacesMismatch(let code, let lhs, let rhs) = error else { return false }
        return code == "USD" && Set([lhs, rhs]) == [2, 4]
    }

    // MARK: - Equality

    @Test("Money with the same amount at different decimal places is not equal")
    func moneyNotEqual() throws {
        let fourPlaces = try Money(amount: 34590, currency: usd4)  // $3.4590
        let twoPlaces = try Money(amount: 34590, currency: usd2)   // $345.90

        #expect(fourPlaces != twoPlaces)
        #expect(fourPlaces.tryCompare(twoPlaces) == nil)
    }

    @Test("Default currencies are unaffected")
    func defaultsStillEqual() throws {
        #expect(try Currency(code: "USD") == Currency.USD)
        #expect(try Currency(code: "usd") == Currency.USD)
        #expect(try Currency(code: "USD", decimalPlaces: 2) == Currency.USD)

        let decoded = try JSONDecoder().decode(Money.self, from: JSONEncoder().encode(Money(amount: 1999, currency: .USD)))
        #expect(decoded == (try Money(amount: 1999, currency: .USD)))
    }

    // MARK: - Throwing operations

    @Test("Money addition and subtraction throw decimalPlacesMismatch")
    func moneyArithmetic() throws {
        let a = try Money(amount: 34590, currency: usd4)
        let b = try Money(amount: 100, currency: usd2)

        #expect(isUSDMismatch(#expect(throws: MoneyError.self) { try a + b }))
        #expect(isUSDMismatch(#expect(throws: MoneyError.self) { try a - b }))
    }

    @Test("Sums throw decimalPlacesMismatch on an element at other decimal places")
    func sums() throws {
        let mixed = [try Money(amount: 100, currency: usd2), try Money(amount: 100, currency: usd4)]

        #expect(isUSDMismatch(#expect(throws: MoneyError.self) { try mixed.sum(in: .USD) }))
        #expect(isUSDMismatch(#expect(throws: MoneyError.self) { try mixed.map { $0.toBigMoney() }.sum(in: .USD) }))
    }

    @Test("BigMoney arithmetic and comparison reject decimalPlacesMismatch")
    func bigMoney() throws {
        let a = try Money(amount: 1000, currency: usd2).toBigMoney()
        let b = try Money(amount: 1000, currency: usd4)

        #expect(isUSDMismatch(#expect(throws: MoneyError.self) { try a + b }))
        #expect(isUSDMismatch(#expect(throws: MoneyError.self) { try a - b }))
        #expect(isUSDMismatch(#expect(throws: MoneyError.self) { try a + b.toBigMoney() }))
        #expect(a.tryCompare(b.toBigMoney()) == nil)
    }

    // MARK: - Error choice and message

    @Test("Different codes still throw currencyMismatch")
    func differentCodes() throws {
        let usd = try Money(amount: 100, currency: usd4)
        let eur = try Money(amount: 100, currency: .EUR)

        let error = #expect(throws: MoneyError.self) { try usd + eur }
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
