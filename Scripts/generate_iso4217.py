#!/usr/bin/env python3
"""Generates Sources/MoneyKit/Currency+ISO4217.generated.swift from the official
ISO 4217 registry (Resources/iso4217/list-one.xml, published by SIX Financial
Services, the ISO 4217 registrar).

Policy (documented in the generated header):
- Entries without a currency code (e.g. "No universal currency") are skipped.
- "N.A." minor-unit rows (XAU gold, XDR, XXX, test codes) are skipped too:
  the registry says no minor unit applies, so those codes fall back to
  Currency's lenient 2-decimal default instead of asserting an exponent.
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
    if not re.fullmatch(r"[A-Z]{3}", code):
        sys.exit(f"malformed currency code {code!r}")
    raw = (entry.findtext("CcyMnrUnts") or "").strip()
    if raw == "N.A.":
        continue  # no applicable minor unit (XAU, XDR, XXX, ...): 2-decimal fallback
    units = int(raw)
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
    "// Policy: entries without a currency code and \"N.A.\" minor-unit rows (XAU,",
    "// XDR, XXX, test codes) are skipped — those codes fall back to the 2-decimal",
    "// default; duplicates must agree (generator-enforced).",
    "",
    "extension Currency {",
    "",
    "    /// ISO 4217 minor units (decimal places) straight from the registry.",
    "    /// Codes absent here are withdrawn (historical), non-ISO, or have no",
    "    /// applicable minor unit (\"N.A.\": XAU, XDR, XXX, ...); `Currency(code:)`",
    "    /// falls back to 2 for all of those.",
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
