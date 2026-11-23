import SwiftUI
import UIKit

enum Theme {
    /// Warm paper white by day, soft ink black by night.
    static let paper = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.07, blue: 0.075, alpha: 1)
            : UIColor(red: 0.98, green: 0.973, blue: 0.957, alpha: 1)
    })
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.93, alpha: 1)
            : UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
    })
    /// Cards sit slightly lifted off the paper.
    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
            : UIColor.white
    })
    /// Soft background tints for feed cards (pastel by day, muted by night).
    private static let tints: [Color] = [
        (UIColor(red: 0.965, green: 0.937, blue: 0.886, alpha: 1), UIColor(red: 0.17, green: 0.155, blue: 0.13, alpha: 1)),  // sand
        (UIColor(red: 0.906, green: 0.937, blue: 0.906, alpha: 1), UIColor(red: 0.12, green: 0.16, blue: 0.135, alpha: 1)),  // sage
        (UIColor(red: 0.906, green: 0.929, blue: 0.965, alpha: 1), UIColor(red: 0.115, green: 0.135, blue: 0.175, alpha: 1)), // mist
        (UIColor(red: 0.965, green: 0.914, blue: 0.894, alpha: 1), UIColor(red: 0.18, green: 0.135, blue: 0.125, alpha: 1)), // clay
        (UIColor(red: 0.929, green: 0.914, blue: 0.965, alpha: 1), UIColor(red: 0.145, green: 0.135, blue: 0.18, alpha: 1)),  // lavender
    ].map { (pair: (UIColor, UIColor)) -> Color in
        Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? pair.1 : pair.0 })
    }

    /// A stable tint for an id (the same card always gets the same colour).
    static func tint(for id: String) -> Color {
        let sum = id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return tints[sum % tints.count]
    }

    /// The one accent: a muted sand gold.
    static let accent = Color(red: 0.71, green: 0.55, blue: 0.33)

    static let quoteFont = Font.system(size: 27, weight: .regular)
    static let sayerFont = Font.system(size: 17, weight: .semibold)
    static let sourceFont = Font.system(size: 14, weight: .regular)
    static let smallFont = Font.system(size: 13, weight: .medium)
}

enum Arabic {
    static let locale = Locale(identifier: "ar")

    static func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }

    static func dayAndTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle().weekday(.wide).day().month(.wide).hour().minute().locale(locale))
    }

    static func hour(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return time(date)
    }

    static func schedule(startHour: Int) -> String {
        Cycle.dailyHours(startHour: startHour).map { hour($0) }.joined(separator: "  ·  ")
    }
}
