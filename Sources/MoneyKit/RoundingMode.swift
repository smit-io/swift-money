import Foundation

/// Rounding modes for Money calculations.
///
/// Specifies how to round decimal amounts when converting to Money.
public enum RoundingMode: Sendable, Codable, Hashable {
    /// Round up (toward positive infinity)
    case up

    /// Round down (toward negative infinity)
    case down

    /// Round to nearest, ties to even (Banker's rounding)
    case bankers

    /// Round to nearest, ties away from zero (standard rounding)
    case halfUp

    /// Round toward zero (truncate)
    case towardZero

    /// Round away from zero
    case awayFromZero

    /// Default rounding mode (Banker's rounding)
    public static let `default`: RoundingMode = .bankers

    /// Default rounding mode for tax calculations (commonly round down)
    public static let taxDefault: RoundingMode = .down

    /// The Foundation mode that rounds `value` this way. `NSDecimalRound`'s
    /// `.down`/`.up` are floor/ceiling, so the zero-relative modes depend on
    /// the sign of the value being rounded.
    internal func nsRoundingMode(for value: Decimal) -> NSDecimalNumber.RoundingMode {
        switch self {
        case .up:
            return .up
        case .down:
            return .down
        case .bankers:
            return .bankers
        case .halfUp:
            return .plain
        case .towardZero:
            return value < 0 ? .up : .down
        case .awayFromZero:
            return value < 0 ? .down : .up
        }
    }
}

// MARK: - CustomStringConvertible

extension RoundingMode: CustomStringConvertible {
    public var description: String {
        switch self {
        case .up:
            return "Round Up"
        case .down:
            return "Round Down"
        case .bankers:
            return "Banker's Rounding"
        case .halfUp:
            return "Half Up"
        case .towardZero:
            return "Toward Zero"
        case .awayFromZero:
            return "Away From Zero"
        }
    }
}
