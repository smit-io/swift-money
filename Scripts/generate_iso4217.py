#!/usr/bin/env python3
"""Generates Sources/MoneyKit/Currency+ISO4217.generated.swift from the official
ISO 4217 registry (Resources/iso4217/list-one.xml, published by SIX Financial
Services, the ISO 4217 registrar).

Policy (documented in the generated header):
- Entries without a currency code (e.g. "No universal currency") are skipped.
- "N.A." minor units (XAU gold, XDR, test codes) map to 0.
- Duplicate code entries (one per country) must agree on minor units; the
  generator fails loudly if the registry ever contradicts itself.

Usage:  python3 Scripts/generate_iso4217.py
"""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Resources/iso4217/list-one.xml"
OUTPUT = ROOT / "Sources/MoneyKit/Currency+ISO4217.generated.swift"

tree = ET.parse(SOURCE)
published = tree.getroot().attrib.get("Pblshd", "unknown")

minor_units: dict[str, int] = {}
for entry in tree.getroot().iter("CcyNtry"):
    code = entry.findtext("Ccy")
    if code is None:
        continue  # "No universal currency" rows
    raw = (entry.findtext("CcyMnrUnts") or "").strip()
    units = 0 if raw == "N.A." else int(raw)
    if code in minor_units and minor_units[code] != units:
        sys.exit(f"registry self-contradiction for {code}: {minor_units[code]} vs {units}")
    minor_units[code] = units

lines = [
    "// Currency+ISO4217.generated.swift",
    "// MoneyKit",
    "//",
    f"// GENERATED from Resources/iso4217/list-one.xml (ISO 4217 registry,",
    f"// published {published} by SIX Financial Services, the ISO registrar).",
    "// Regenerate with: python3 Scripts/generate_iso4217.py — DO NOT EDIT.",
    "//",
    "// Policy: entries without a currency code are skipped; \"N.A.\" minor units",
    "// (XAU, XDR, test codes) map to 0; duplicates must agree (generator-enforced).",
    "",
    "extension Currency {",
    "",
    "    /// ISO 4217 minor units (decimal places) for every active currency code,",
    "    /// straight from the registry. Codes absent here are either withdrawn",
    "    /// (historical) or non-ISO; `Currency(code:)` falls back to 2 for those.",
    f"    static let isoMinorUnits: [String: Int] = [",
]
for code in sorted(minor_units):
    lines.append(f'        "{code}": {minor_units[code]},')
lines += [
    "    ]",
    "}",
    "",
]
OUTPUT.write_text("\n".join(lines))
counts = {}
for u in minor_units.values():
    counts[u] = counts.get(u, 0) + 1
print(f"{len(minor_units)} codes (published {published}); by minor units: {dict(sorted(counts.items()))}")
print(f"ISK={minor_units.get('ISK')} CLF={minor_units.get('CLF')} UYI={minor_units.get('UYI')} UYW={minor_units.get('UYW')} MGA={minor_units.get('MGA')} JPY={minor_units.get('JPY')} KWD={minor_units.get('KWD')} XAU={minor_units.get('XAU')}")
