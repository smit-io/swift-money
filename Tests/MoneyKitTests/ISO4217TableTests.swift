// Tests/MoneyKitTests/ISO4217TableTests.swift
// Snapshot + anchor tests for the generated ISO 4217 minor-units table.

import Testing
import Foundation
@testable import MoneyKit

@Suite("ISO 4217 table")
struct ISO4217TableTests {

    /// Re-derives the table from the checked-in registry XML and compares it to
    /// the generated dictionary, so `Currency+ISO4217.generated.swift` can never
    /// drift from its source. Mirrors the generator's policy: skip entries with
    /// no currency code; "N.A." minor units map to 0.
    @Test("generated table matches the checked-in registry XML")
    func generatedTableMatchesRegistry() throws {
        let xmlURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // MoneyKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Resources/iso4217/list-one.xml")
        let xml = try String(contentsOf: xmlURL, encoding: .utf8)

        var derived: [String: Int] = [:]
        // The registry format is flat and regular; entry-scoped matching keeps
        // this oracle independent of the generator's implementation.
        let entryPattern = /<CcyNtry>(.*?)<\/CcyNtry>/.dotMatchesNewlines()
        let codePattern = /<Ccy>([A-Z]{3})<\/Ccy>/
        let unitsPattern = /<CcyMnrUnts>(.*?)<\/CcyMnrUnts>/
        for entry in xml.matches(of: entryPattern) {
            let body = String(entry.1)
            guard let code = body.firstMatch(of: codePattern).map({ String($0.1) }) else { continue }
            let rawUnits = body.firstMatch(of: unitsPattern).map { String($0.1) } ?? "N.A."
            let units = rawUnits == "N.A." ? 0 : Int(rawUnits)!
            if let existing = derived[code] {
                #expect(existing == units, "registry self-contradiction for \(code)")
            }
            derived[code] = units
        }

        #expect(!derived.isEmpty)
        #expect(derived == Currency.isoMinorUnits)
    }

    @Test("ISO anchors: the exponent classes resolve per the registry",
          arguments: [
            ("JPY", 0), ("KRW", 0), ("CLP", 0), ("VND", 0), ("ISK", 0), ("UYI", 0),
            ("USD", 2), ("EUR", 2), ("HUF", 2), ("MGA", 2),
            ("KWD", 3), ("BHD", 3), ("OMR", 3), ("TND", 3), ("JOD", 3), ("IQD", 3), ("LYD", 3),
            ("CLF", 4), ("UYW", 4),
          ])
    func isoAnchors(pair: (String, Int)) throws {
        let currency = try Currency(code: pair.0)
        #expect(currency.decimalPlaces == pair.1)
        #expect(currency.isISO)
    }

    @Test("non-ISO and withdrawn codes stay lenient with the 2-decimal default")
    func nonISOFallback() throws {
        for code in ["ZZZ", "ITL", "TRL"] {
            let currency = try Currency(code: code)
            #expect(currency.decimalPlaces == 2)
            #expect(!currency.isISO)
        }
    }
}
