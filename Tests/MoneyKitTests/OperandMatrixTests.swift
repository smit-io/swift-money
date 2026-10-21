import Foundation
import Testing
@testable import MoneyKit

/// Every operand type (`Int`, `Double`, `Decimal`) through every rounding
/// mode, for every currency fixture.
///
/// Expected results come from an integer-only oracle: each case states the
/// exact result as a fraction `numerator / denominator` of minor units, and
/// `exactRound` rounds it with integer arithmetic. No `Decimal` or `Double`
/// is involved in computing an expectation.
@Suite("Operand Matrix Tests")
struct OperandMatrixTests {

    /// The type a rate or divisor is passed as.
    enum Operand: String, CaseIterable, Sendable, CustomTestStringConvertible {
        case int, double, decimal

        var testDescription: String { rawValue }

        /// Whether `text` can be passed as this type (Int only takes whole numbers).
        func accepts(_ text: String) -> Bool {
            self != .int || Int(text) != nil
        }

        func multiply(_ money: Money, by text: String, _ mode: RoundingMode) throws -> Money {
            switch self {
            case .int: try money.multiplied(by: Int(text)!, rounding: mode)
            case .double: try money.multiplied(by: Double(text)!, rounding: mode)
            case .decimal: try money.multiplied(by: Decimal(string: text)!, rounding: mode)
            }
        }

        func divide(_ money: Money, by text: String, _ mode: RoundingMode) throws -> Money {
            switch self {
            case .int: try money.divided(by: Int(text)!, rounding: mode)
            case .double: try money.divided(by: Double(text)!, rounding: mode)
            case .decimal: try money.divided(by: Decimal(string: text)!, rounding: mode)
            }
        }

        func multiply(_ big: BigMoney, by text: String) throws -> BigMoney {
            switch self {
            case .int: big * Int(text)!
            case .double: try big * Double(text)!
            case .decimal: big * Decimal(string: text)!
            }
        }

        func divide(_ big: BigMoney, by text: String) throws -> BigMoney {
            switch self {
            case .int: try big / Int(text)!
            case .double: try big / Double(text)!
            case .decimal: try big / Decimal(string: text)!
            }
        }

        func money(standardUnits text: String, _ currency: Currency, _ mode: RoundingMode) throws -> Money {
            switch self {
            case .int: try Money(decimalAmount: Int(text)!, currency: currency, rounding: mode)
            case .double: try Money(decimalAmount: Double(text)!, currency: currency, rounding: mode)
            case .decimal: try Money(decimalAmount: Decimal(string: text)!, currency: currency, rounding: mode)
            }
        }
    }

    /// Rounds `numerator / denominator` to an integer with `mode`, using only Int math.
    static func exactRound(_ numerator: Int, _ denominator: Int, _ mode: RoundingMode) -> Int {
        let (num, den) = denominator < 0 ? (-numerator, -denominator) : (numerator, denominator)
        let truncated = num / den
        let remainder = num % den
        guard remainder != 0 else { return truncated }

        let floor = num < 0 ? truncated - 1 : truncated
        let ceiling = floor + 1
        let awayFromZero = num < 0 ? floor : ceiling
        let twiceRemainder = 2 * remainder.magnitude

        switch mode {
        case .up: return ceiling
        case .down: return floor
        case .towardZero: return truncated
        case .awayFromZero: return awayFromZero
        case .halfUp:
            return twiceRemainder >= UInt(den) ? awayFromZero : truncated
        case .bankers:
            if twiceRemainder > UInt(den) { return awayFromZero }
            if twiceRemainder < UInt(den) { return truncated }
            return floor.isMultiple(of: 2) ? floor : ceiling
        }
    }

    /// Amount in minor units, multiplier text, and the exact product as a fraction.
    ///
    /// The cases that land on a whole number or a .5 tie use rates with no
    /// exact binary form (0.07, 0.15, 0.57, …): a lossy Double → Decimal
    /// conversion pushes them across the boundary, so these are the cases
    /// that would catch it.
    static let multiplications: [(amount: Int, rate: String, numerator: Int, denominator: Int)] = [
        (1234, "1.1", 13574, 10),       // 1357.4
        (1234, "-1.1", -13574, 10),     // -1357.4
        (1234, "0.07", 8638, 100),      // 86.38
        (1234, "1.005", 124017, 100),   // 1240.17
        (1234, "0.125", 15425, 100),    // 154.25
        (1234, "2.5", 3085, 1),         // exact
        (1234, "3", 3702, 1),           // exact
        (1234, "-3", -3702, 1),         // exact
        (1234, "0", 0, 1),              // exact
        (100, "0.07", 7, 1),            // whole: 0.07 as a Double is 0.07000000000000000666
        (100, "0.57", 57, 1),           // whole: 0.57 as a Double is 0.56999999999999995
        (100, "0.29", 29, 1),           // whole: 0.29 as a Double is 0.28999999999999998
        (1000, "1.13", 1130, 1),        // whole: 1.13 as a Double is 1.1299999999999999
        (10, "0.15", 15, 10),           // tie 1.5: 0.15 as a Double is 0.14999999999999999
        (10, "0.35", 35, 10),           // tie 3.5: 0.35 as a Double is 0.34999999999999998
        (10, "2.05", 205, 10),          // tie 20.5: 2.05 as a Double is 2.0499999999999998
    ]

    /// Amount in minor units, divisor text, and the exact quotient as a fraction.
    static let divisions: [(amount: Int, divisor: String, numerator: Int, denominator: Int)] = [
        (1234, "3", 1234, 3),           // 411.33…
        (1234, "-3", -1234, 3),         // -411.33…
        (1234, "4", 1234, 4),           // 308.5, a tie
        (1234, "-8", -1234, 8),         // -154.25
        (1234, "7", 1234, 7),           // 176.28…
        (1234, "1.5", 2468, 3),         // 822.66…
        (1234, "0.25", 4936, 1),        // exact
        (1234, "1", 1234, 1),           // exact
        (7, "0.07", 100, 1),            // whole: lossy 0.07 gives 99.999…
        (57, "0.57", 100, 1),           // whole: lossy 0.57 gives 100.000…1
        (3, "0.2", 15, 1),              // whole: 0.2 as a Double is 0.200000000000000011
        (3, "2", 3, 2),                 // tie 1.5
    ]

    // MARK: - Oracle

    @Test("The oracle rounds like the documented table")
    func oracle() {
        for mode in CurrencyFixture.roundingModes {
            let results = [
                Self.exactRound(13574, 10, mode),
                Self.exactRound(13575, 10, mode),
                Self.exactRound(-13575, 10, mode),
            ]
            #expect(results == CurrencyFixture.roundingTable[mode])
        }
    }

    // MARK: - Money

    @Test("multiplied(by:) matches the oracle", arguments: CurrencyFixture.all, Operand.allCases)
    func multiplied(fixture: CurrencyFixture, operand: Operand) throws {
        for (amount, rate, numerator, denominator) in Self.multiplications where operand.accepts(rate) {
            for sign in [1, -1] {
                let money = try fixture.money(sign * amount)
                for mode in CurrencyFixture.roundingModes {
                    let expected = Self.exactRound(sign * numerator, denominator, mode)
                    let result = try operand.multiply(money, by: rate, mode)
                    #expect(result.amount == expected, "\(sign * amount) × \(rate) \(mode)")
                    #expect(result.currency == fixture.currency)
                }
            }
        }
    }

    @Test("divided(by:) matches the oracle", arguments: CurrencyFixture.all, Operand.allCases)
    func divided(fixture: CurrencyFixture, operand: Operand) throws {
        for (amount, divisor, numerator, denominator) in Self.divisions where operand.accepts(divisor) {
            for sign in [1, -1] {
                let money = try fixture.money(sign * amount)
                for mode in CurrencyFixture.roundingModes {
                    let expected = Self.exactRound(sign * numerator, denominator, mode)
                    let result = try operand.divide(money, by: divisor, mode)
                    #expect(result.amount == expected, "\(sign * amount) ÷ \(divisor) \(mode)")
                }
            }
        }
    }

    // MARK: - BigMoney

    @Test("BigMoney * and / then rounded match the oracle", arguments: CurrencyFixture.all, Operand.allCases)
    func bigMoney(fixture: CurrencyFixture, operand: Operand) throws {
        for sign in [1, -1] {
            for mode in CurrencyFixture.roundingModes {
                for (amount, rate, numerator, denominator) in Self.multiplications where operand.accepts(rate) {
                    let big = try fixture.money(sign * amount).toBigMoney()
                    let result = try operand.multiply(big, by: rate).rounded(mode)
                    #expect(result.amount == Self.exactRound(sign * numerator, denominator, mode), "\(sign * amount) × \(rate) \(mode)")
                }
                for (amount, divisor, numerator, denominator) in Self.divisions where operand.accepts(divisor) {
                    let big = try fixture.money(sign * amount).toBigMoney()
                    let result = try operand.divide(big, by: divisor).rounded(mode)
                    #expect(result.amount == Self.exactRound(sign * numerator, denominator, mode), "\(sign * amount) ÷ \(divisor) \(mode)")
                }
            }
        }
    }

    @Test("BigMoney chains stay exact until rounded", arguments: CurrencyFixture.all, Operand.allCases)
    func bigMoneyChain(fixture: CurrencyFixture, operand: Operand) throws {
        // 1234 × 3 ÷ 7 × 7 ÷ 3 = 1234 exactly when nothing is rounded in between
        // (÷ 7 is inexact in Decimal; × 7 brings it back within rounding).
        guard operand.accepts("3") else { return }
        let big = try fixture.money(1234).toBigMoney()

        let roundTrip = try operand.divide(operand.multiply(operand.divide(operand.multiply(big, by: "3"), by: "7"), by: "7"), by: "3")
        #expect(try roundTrip.rounded(.halfUp).amount == 1234)
    }

    // MARK: - Money(decimalAmount:)

    @Test("Money(decimalAmount:) from Double and Decimal matches the oracle", arguments: CurrencyFixture.all, [Operand.double, .decimal])
    func decimalAmountFractional(fixture: CurrencyFixture, operand: Operand) throws {
        // Minor-unit values written in standard units of the fixture.
        for (minorText, numerator, denominator) in [
            ("1357.4", 13574, 10), ("1357.5", 13575, 10), ("1357.6", 13576, 10),
            ("86.38", 8638, 100), ("154.25", 15425, 100), ("0.5", 5, 10), ("1999", 1999, 1),
        ] {
            for sign in [1, -1] {
                let text = fixture.standardUnits(minor: (sign < 0 ? "-" : "") + minorText).description
                for mode in CurrencyFixture.roundingModes {
                    let result = try operand.money(standardUnits: text, fixture.currency, mode)
                    #expect(result.amount == Self.exactRound(sign * numerator, denominator, mode), "\(text) \(mode)")
                }
            }
        }
    }

    @Test("Money(decimalAmount:) from whole units is the same for every operand type", arguments: CurrencyFixture.all, Operand.allCases)
    func decimalAmountWhole(fixture: CurrencyFixture, operand: Operand) throws {
        for units in [0, 5, -5, 7] {
            for mode in CurrencyFixture.roundingModes {
                let result = try operand.money(standardUnits: String(units), fixture.currency, mode)
                #expect(result.amount == units * fixture.minorUnitsPerUnit)
            }
        }
    }

    // MARK: - Range edges

    /// Amount × rate lands exactly at `Int.max + fraction` minor units.
    /// Rounding the fraction away overflows; rounding it off fits at `Int.max`.
    static let edgeMultiplications: [(amount: Int, rate: String, fraction: Int, of: Int)] = [
        (4_854_406_335_186_724_109, "1.9", 1, 10),     // Int.max + 0.1
        (7_849_678_329_238_107_070, "1.175", 1, 4),    // Int.max + 0.25
        (9_042_521_604_759_584_125, "1.02", 1, 2),     // Int.max + 0.5, a tie
        (5_950_562_604_422_436_005, "1.55", 3, 4),     // Int.max + 0.75
    ]

    /// Amount ÷ divisor lands exactly at `Int.max + fraction` minor units.
    static let edgeDivisions: [(amount: Int, divisor: String, fraction: Int, of: Int)] = [
        (3_689_348_814_741_910_323, "0.4", 1, 2),      // Int.max + 0.5, a tie
    ]

    /// Checks a result at ±(Int.max + fraction): it must equal ±Int.max when
    /// the fraction rounds off, and throw when it rounds away from zero
    /// (including banker's rounding of a .5 tie, since Int.max is odd).
    private func expectEdge(
        sign: Int, fraction: Int, of denominator: Int, mode: RoundingMode,
        _ label: String, _ body: () throws -> Money
    ) {
        // Round ±(1 + fraction), not ±fraction: Int.max is odd, and banker's
        // rounding of a tie depends on the parity of the integer part.
        let delta = Self.exactRound(sign * (denominator + fraction), denominator, mode) - sign  // -1, 0, or 1
        if delta == 0 {
            #expect((try? body())?.amount == sign * Int.max, "\(label)")
        } else {
            #expect(throws: MoneyError.self, "\(label)") { try body() }
        }
    }

    @Test("Rounding at Int.max fits or overflows per mode", arguments: CurrencyFixture.all, [Operand.double, .decimal])
    func rangeEdge(fixture: CurrencyFixture, operand: Operand) throws {
        for sign in [1, -1] {
            for mode in CurrencyFixture.roundingModes {
                for (amount, rate, fraction, of) in Self.edgeMultiplications {
                    let money = try fixture.money(sign * amount)
                    expectEdge(sign: sign, fraction: fraction, of: of, mode: mode, "\(sign * amount) × \(rate) \(mode)") {
                        try operand.multiply(money, by: rate, mode)
                    }
                    expectEdge(sign: sign, fraction: fraction, of: of, mode: mode, "BigMoney \(sign * amount) × \(rate) \(mode)") {
                        try operand.multiply(money.toBigMoney(), by: rate).rounded(mode)
                    }
                }
                for (amount, divisor, fraction, of) in Self.edgeDivisions {
                    let money = try fixture.money(sign * amount)
                    expectEdge(sign: sign, fraction: fraction, of: of, mode: mode, "\(sign * amount) ÷ \(divisor) \(mode)") {
                        try operand.divide(money, by: divisor, mode)
                    }
                    expectEdge(sign: sign, fraction: fraction, of: of, mode: mode, "BigMoney \(sign * amount) ÷ \(divisor) \(mode)") {
                        try operand.divide(money.toBigMoney(), by: divisor).rounded(mode)
                    }
                }
            }
        }
    }

    @Test("Money(decimalAmount:) at Int.max fits or overflows per mode", arguments: CurrencyFixture.all)
    func decimalAmountRangeEdge(fixture: CurrencyFixture) throws {
        // A Double can't hold Int.max + 0.4 minor units (it has 53 bits), so
        // this edge is Decimal-only; the Double path shares the same range check.
        for sign in [1, -1] {
            for mode in CurrencyFixture.roundingModes {
                for (fraction, text) in [(4, "4"), (5, "5"), (6, "6")] {
                    let value = fixture.standardUnits(minor: "\(sign < 0 ? "-" : "")9223372036854775807.\(text)")
                    expectEdge(sign: sign, fraction: fraction, of: 10, mode: mode, "\(value) \(mode)") {
                        try Money(decimalAmount: value, currency: fixture.currency, rounding: mode)
                    }
                }

                // One unit inside the edge always fits: Int.max - 1 + 0.5 rounds to Int.max - 1 or Int.max.
                // Int.max - 1 is even, so rounding ±0.5 alone gives the right banker's result.
                let inside = fixture.standardUnits(minor: "\(sign < 0 ? "-" : "")9223372036854775806.5")
                let result = try Money(decimalAmount: inside, currency: fixture.currency, rounding: mode)
                let delta = Self.exactRound(sign * 5, 10, mode)
                #expect(result.amount == sign * (Int.max - 1) + delta, "\(inside) \(mode)")
            }
        }
    }

    @Test("Integer multiplication at Int.max fits or overflows for every mode", arguments: CurrencyFixture.all)
    func integerRangeEdge(fixture: CurrencyFixture) throws {
        for sign in [1, -1] {
            let fits = try fixture.money(sign * (Int.max / 2))          // × 2 = ±(Int.max - 1)
            let overflows = try fixture.money(sign * (Int.max / 2 + 1)) // × 2 = ±(Int.max + 1)

            #expect(try (fits * 2).amount == sign * (Int.max - 1))
            #expect(throws: MoneyError.self) { try overflows * 2 }
            for mode in CurrencyFixture.roundingModes {
                #expect(try fits.multiplied(by: 2, rounding: mode).amount == sign * (Int.max - 1))
                #expect(throws: MoneyError.self) { try overflows.multiplied(by: 2, rounding: mode) }
                #expect(throws: MoneyError.self) { try (overflows.toBigMoney() * 2).rounded(mode) }
            }
        }
    }

    // MARK: - Errors

    @Test("Overflow and division by zero throw for every operand type", arguments: CurrencyFixture.all, Operand.allCases)
    func errors(fixture: CurrencyFixture, operand: Operand) throws {
        let large = try fixture.money(Int.max / 2)
        let small = try fixture.money(100)

        for rate in ["3", "-3"] {
            #expect(throws: MoneyError.self) { try operand.multiply(large, by: rate, .down) }
            #expect(throws: MoneyError.self) { try operand.multiply(large.toBigMoney(), by: rate).rounded(.down) }
        }
        #expect(throws: MoneyError.self) { try operand.divide(small, by: "0", .down) }
        #expect(throws: MoneyError.self) { try operand.divide(small.toBigMoney(), by: "0") }

        if operand.accepts("0.1") {
            #expect(throws: MoneyError.self) { try operand.divide(large, by: "0.1", .down) }
        }
    }

    @Test("Money(decimalAmount:) out of range throws for every operand type", arguments: CurrencyFixture.all, Operand.allCases)
    func decimalAmountOverflow(fixture: CurrencyFixture, operand: Operand) throws {
        // 10^19 minor units is beyond Int.max at every scale.
        let tooLarge = fixture.decimalPlaces == 0 ? "10000000000000000000" : "1" + String(repeating: "0", count: max(0, 19 - fixture.decimalPlaces))

        if operand == .int, Int(tooLarge) == nil {
            return  // An Int can't hold 10^19; decimalAmountIntMax covers the Int path.
        }
        for text in [tooLarge, "-" + tooLarge] {
            #expect(throws: MoneyError.self, "\(text)") {
                try operand.money(standardUnits: text, fixture.currency, .down)
            }
        }
    }

    @Test("Money(decimalAmount:) from Int.max whole units overflows at any scale above 0", arguments: CurrencyFixture.all)
    func decimalAmountIntMax(fixture: CurrencyFixture) throws {
        if fixture.decimalPlaces == 0 {
            #expect(try Money(decimalAmount: Int.max, currency: fixture.currency, rounding: .down).amount == Int.max)
        } else {
            #expect(throws: MoneyError.self) {
                try Money(decimalAmount: Int.max, currency: fixture.currency, rounding: .down)
            }
        }
    }
}
