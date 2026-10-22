import Foundation
import Testing
@testable import MoneyKit

/// Every error case has a message that names its inputs.
///
/// Each `fragments` function switches over its enum with no `default`, so
/// adding a case fails to compile until it gets a sample here.
@Suite("Error Description Tests")
struct ErrorDescriptionTests {

    static let moneyErrors: [MoneyError] = [
        .currencyMismatch(from: .USD, to: .EUR),
        .decimalPlacesMismatch(code: "USD", lhs: 2, rhs: 4),
        .divisionByZero,
        .amountOverflow(description: "Sum of 9223372036854775807 and 1"),
        .invalidDecimal(.nan),
        .invalidDecimal(-.infinity),
        .invalidDecimal(1e300),
        .negativeRatio(-3),
        .negativePartCount(-2),
    ]

    static func fragments(_ error: MoneyError) -> [String] {
        switch error {
        case .currencyMismatch(let from, let to): [from.code, to.code]
        case .decimalPlacesMismatch(let code, let lhs, let rhs): [code, "\(lhs)", "\(rhs)"]
        case .divisionByZero: ["zero"]
        case .amountOverflow(let description): [description]
        case .invalidDecimal(let value): ["\(value)"]
        case .negativeRatio(let ratio): ["\(ratio)"]
        case .negativePartCount(let parts): ["\(parts)"]
        }
    }

    static let currencyErrors: [CurrencyError] = [
        .invalidFormat("12D"),
        .invalidDecimalPlaces(31),
        .invalidDecimalPlaces(-1),
    ]

    static func fragments(_ error: CurrencyError) -> [String] {
        switch error {
        case .invalidFormat(let code): [code]
        case .invalidDecimalPlaces(let places): ["\(places)", "0...30"]
        }
    }

    private func expectMessage(_ error: some LocalizedError, _ fragments: [String]) {
        guard let message = error.errorDescription else {
            Issue.record("\(error) has no errorDescription")
            return
        }
        for fragment in fragments {
            #expect(message.contains(fragment), "\(message) should contain \(fragment)")
        }
        // NSError bridging, as seen by `catch` blocks that only log, uses the same text.
        #expect(error.localizedDescription == message)
    }

    @Test("MoneyError messages name their inputs", arguments: moneyErrors)
    func moneyError(error: MoneyError) {
        expectMessage(error, Self.fragments(error))
    }

    @Test("CurrencyError messages name their inputs", arguments: currencyErrors)
    func currencyError(error: CurrencyError) {
        expectMessage(error, Self.fragments(error))
    }

    @Test("Thrown errors carry those messages")
    func thrownMessages() throws {
        let usd = try Money(amount: 100, currency: .USD)

        let mismatch = #expect(throws: MoneyError.self) { try usd + Money(amount: 1, currency: .EUR) }
        #expect(mismatch?.localizedDescription.contains("EUR") == true)

        let overflow = #expect(throws: MoneyError.self) { try Money(amount: Int.max, currency: .USD) + usd }
        #expect(overflow?.localizedDescription.hasPrefix("Amount overflow: ") == true)

        let places = #expect(throws: CurrencyError.self) { try Currency(code: "USD", decimalPlaces: 31) }
        #expect(places?.localizedDescription.contains("31") == true)
    }
}
