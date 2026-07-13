import Foundation

enum DistanceDisplayUnit: Equatable {
    case miles
    case kilometers

    var abbreviation: String {
        switch self {
        case .miles: "mi"
        case .kilometers: "km"
        }
    }
}

enum DistanceUnitPreference: String, CaseIterable, Identifiable {
    static let storageKey = "mugshot.distance-unit-preference"

    case automatic
    case miles
    case kilometers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .miles: "Miles"
        case .kilometers: "Kilometers"
        }
    }

    static func stored(_ rawValue: String) -> DistanceUnitPreference {
        DistanceUnitPreference(rawValue: rawValue) ?? .automatic
    }

    func resolvedUnit(locale: Locale = .current) -> DistanceDisplayUnit {
        switch self {
        case .miles:
            return .miles
        case .kilometers:
            return .kilometers
        case .automatic:
            return locale.measurementSystem == .metric ? .kilometers : .miles
        }
    }

    func menuTitle(locale: Locale = .current) -> String {
        guard self == .automatic else { return title }
        return "Automatic (\(resolvedUnit(locale: locale).abbreviation))"
    }
}

enum MugshotDistanceFormatter {
    private static let kilometersPerMile = 1.609344

    static func distance(
        kilometers: Double,
        preference: DistanceUnitPreference,
        locale: Locale = .current
    ) -> String {
        let unit = preference.resolvedUnit(locale: locale)
        let value = unit == .miles ? kilometers / kilometersPerMile : kilometers
        let fractionDigits = value < 10 ? 1 : 0
        return "\(number(value, fractionDigits: fractionDigits, locale: locale)) \(unit.abbreviation)"
    }

    static func discoveryRadius(
        kilometers: Double,
        preference: DistanceUnitPreference,
        locale: Locale = .current
    ) -> String {
        let unit = preference.resolvedUnit(locale: locale)
        let value = unit == .miles ? kilometers / kilometersPerMile : kilometers
        return "\(number(value, fractionDigits: 0, locale: locale)) \(unit.abbreviation)"
    }

    private static func number(
        _ value: Double,
        fractionDigits: Int,
        locale: Locale
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.*f", fractionDigits, value)
    }
}
