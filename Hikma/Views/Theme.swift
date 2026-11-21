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
