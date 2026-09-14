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

/// `hasPassed` pour une heure OJP en texte, quand on n'a pas le modèle sous la main.
/// - Parameter equalReturnsTrue: la minute en cours compte déjà comme passée.
public func dateStringHasPassed(with dateString: String, equalReturnsTrue: Bool, now: Date = Date()) -> Bool {
    let date = OJPDate.date(from: dateString)
    if date == nil && !dateString.isEmpty {
        Log.data.error("Date illisible : \(dateString)")
    }
    return hasPassed(date, includingCurrentMinute: equalReturnsTrue, now: now)
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

/// - Parameter now: l'heure d'affichage (`\.displayTime`), pour que la couleur suive l'horloge.
public func determineColor(for time: String, now: Date = Date()) -> Color {
    if dateStringHasPassed(with: time, equalReturnsTrue: false, now: now) {
        return Color.gray
    } else {
        return Color.primary
    }
}
