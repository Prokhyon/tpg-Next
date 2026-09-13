//
//  BasicFunc.swift
//  TPG4
//
//  Created by Loris Thomas on 04.07.2024.
//

import Foundation
import SwiftUI

/// Une des clés d'API OJP, tirée au hasard pour répartir la charge entre elles.
/// Les clés vivent dans `Secrets.swift`, généré par `ci_scripts/ci_post_clone.sh` et jamais versionné.
public func keySelect() -> String {
    Secrets.ojpAPIKeys.randomElement() ?? ""
}

/// Minutes d'une durée ISO 8601 telle que renvoyée par OJP (`PT20M`, `PT1H5M`, `P1DT2H`).
///
/// Découper la chaîne à la main (`dropFirst(2).dropLast(1)`) affichait « 2' » pour `PT2H`
/// et « 1H5' » pour `PT1H5M`. `nil` si la chaîne n'est pas une durée.
public func durationMinutes(_ iso: String) -> Int? {
    guard iso.hasPrefix("P") else { return nil }
    var total = 0.0
    var number = ""
    var inTime = false
    var found = false
    for character in iso.dropFirst() {
        switch character {
        case "T":
            inTime = true
        case "0"..."9", ".":
            number.append(character)
        default:
            guard let value = Double(number) else { return nil }
            number = ""
            switch (character, inTime) {
            case ("D", false): total += value * 1440
            case ("H", true): total += value * 60
            case ("M", true): total += value
            case ("S", true): total += value / 60
            default: return nil
            }
            found = true
        }
    }
    return found && number.isEmpty ? Int(total.rounded()) : nil
}

/// Une durée ISO 8601 lisible : « 20' » sous l'heure, « 1h05 » au-delà.
public func durationText(_ iso: String) -> String {
    guard let minutes = durationMinutes(iso) else { return "" }
    return minutes < 60 ? "\(minutes)'" : String(format: "%dh%02d", minutes / 60, minutes % 60)
}

extension String {
    /// Le texte prêt à être inséré dans une requête XML : un `&` ou un `<` dans un nom
    /// de lieu rendait sinon toute la requête invalide.
    public var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

/// - Parameter now: l'instant de référence du décompte. Le widget passe la date de
///   l'entrée de timeline qu'il est en train de construire, pas l'heure courante.
public func displayTimeOrMinutesRemaining(for timetableInput: String, estimatedInput: String, with showTime: Bool, at now: Date = Date()) -> (text: String, color: Color) {
    // Lu dans le groupe d'app : @AppStorage écrit dans .standard, invisible depuis le widget.
    let delayTimeIntegrated = SharedStorage.bool(forSetting: SettingKey.delayIncludedInTime)
    let estimatedInput = estimatedInput.isEmpty ? timetableInput : estimatedInput
    guard let timetableTime = OJPDate.date(from: timetableInput),
          let estimatedTime = OJPDate.date(from: estimatedInput) else {
        Log.data.error("Dates illisibles : \(timetableInput) / \(estimatedInput)")
        return ("", .yellow)//to change, yellow just for testing
    }

    let estimatedClock = OJPDate.clockTime(from: estimatedTime)
    let timetableClock = OJPDate.clockTime(from: timetableTime)
    let minutesRemaining = estimatedTime.timeIntervalSince(now) / 60
    let delay = Int(estimatedTime.timeIntervalSince(timetableTime) / 60)
    let delayString = delay > 0 ? "(+\(delay)')" : "(\(delay)')"
    let delayColor: Color = delay > 0 ? .accent : .primary

    if showTime && minutesRemaining > 0 {
        if delay == 0 {
            return (timetableClock, .primary)
        }
        return delayTimeIntegrated ? (estimatedClock, delayColor) : ("\(timetableClock);\(delayString)", .accent)
    } else if minutesRemaining < 60 && minutesRemaining > 1 {
        return ("\(Int(minutesRemaining))'", delayColor)
    } else if minutesRemaining <= 1 && minutesRemaining > 0.5 {
        return ("< 1'", delayColor)
    } else if Int(minutesRemaining) == 0 {
        return ("0", .primary)
    } else {
        return (estimatedClock, .primary)
    }
}

/// `true` si l'heure OJP est passée, à la minute près : les secondes sont ignorées.
/// - Parameter equalReturnsTrue: la minute en cours compte déjà comme passée.
public func dateStringHasPassed(with dateString: String, equalReturnsTrue: Bool, now: Date = Date()) -> Bool {
    guard let date = OJPDate.date(from: dateString) else {
        if !dateString.isEmpty {
            Log.data.error("Date illisible : \(dateString)")
        }
        return false
    }
    let minute = (date.timeIntervalSince1970 / 60).rounded(.down)
    let currentMinute = (now.timeIntervalSince1970 / 60).rounded(.down)
    return equalReturnsTrue ? minute <= currentMinute : minute < currentMinute
}

public func stringToDate(with dateString: String) -> Date? {
    OJPDate.date(from: dateString)
}

/// L'heure locale, « 14:05 ».
public func dateToString(with date: Date) -> String {
    OJPDate.clockTime(from: date)
}

private let isoDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private let shortDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "d/M/yy"
    return formatter
}()

/// « 2026-09-13 » devient « 13/9/26 ».
public func convertDateString(_ dateString: String) -> String? {
    isoDayFormatter.date(from: dateString).map(shortDayFormatter.string(from:))
}

public func transportIcon(with transportType: String) -> Image {
    let type = transportType
    if type == "Bus" {
        return Image(systemName: "bus.fill")
    } else if type == "Tram" {
        return Image(systemName: "tram.fill")
    } else if ["Regio", "InterRegio", "RegioExpress", "InterCity", "Train Express Regional", "Train à grande vit."].contains(type) {
        return Image(systemName: "lightrail.fill")
    } else if type == "Schiff" {
        return Image(systemName: "ferry.fill")
    } else if type == "walk" {
        return Image(systemName: "figure.walk")
    } else {
       return Image(systemName: "bus.fill")
    }
}

public func splitString(_ input: String, separator: String) -> (String, String) {
    
    // Split the string at the comma
    let parts = input.split(separator: separator)
    
    // Ensure we have exactly two parts
    guard parts.count == 2 else {
        return (input, "")
    }
    
    // Trim spaces from both parts and return them as a tuple
    let firstPart = parts[0].trimmingCharacters(in: .whitespaces)
    let secondPart = parts[1].trimmingCharacters(in: .whitespaces)
    
    return (firstPart, secondPart)
}

public struct eventStopName: View {
    public let stopName: String
    
    public init(stopName: String) {
        self.stopName = stopName
    }
    
    public var body: some View {
        let splitStopName = splitString(stopName, separator: ",")
        
        HStack {
            Group {
                Text(splitStopName.0) +
                Text(" ") +
                Text(splitStopName.1).bold()
            }
            .multilineTextAlignment(.leading)
        }
    }
}

public struct ScrollMask: View {
    let leading: Bool
    let vertical: Bool
    let gradientLength: CGFloat
    
    public init(leading: Bool = true, vertical: Bool = true, gradientLength: CGFloat = 10) {
        self.leading = leading
        self.vertical = vertical
        self.gradientLength = gradientLength
    }

    public var body: some View {
        if !vertical {
            LinearGradient(colors: [.black, .clear], startPoint: UnitPoint(x: leading ? 0 : 1, y: 0), endPoint: UnitPoint(x: leading ? 1 : 0, y: 0))
                .frame(width: gradientLength)
                .blendMode(.destinationOut)
        } else {
            LinearGradient(colors: [.black, .clear], startPoint: UnitPoint(x: 0 , y: leading ? 1 : 0), endPoint: UnitPoint(x: 0, y: leading ? 0 : 1))
                .frame(height: gradientLength)
                .blendMode(.destinationOut)
        }
    }
}

public func startsWithVowel(_ word: String) -> Bool {
    guard let firstChar = word.lowercased().first else { return false }
    let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
    return vowels.contains(firstChar)
}

public func determineColor(for time: String) -> Color {
    if dateStringHasPassed(with: time, equalReturnsTrue: false) {
        return Color.gray
    } else {
        return Color.primary
    }
}
