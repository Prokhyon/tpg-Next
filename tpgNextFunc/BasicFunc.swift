//
//  BasicFunc.swift
//  TPG4
//
//  Created by Loris Thomas on 04.07.2024.
//

import Foundation
import SwiftUI

public func keySelect() -> String {
    let keys = ["eyJvcmciOiI2NDA2NTFhNTIyZmEwNTAwMDEyOWJiZTEiLCJpZCI6ImFhODIyNjI1MTNlNzQzNTc5YzM3ODBlN2E4ZGM4YWRjIiwiaCI6Im11cm11cjEyOCJ9","eyJvcmciOiI2NDA2NTFhNTIyZmEwNTAwMDEyOWJiZTEiLCJpZCI6IjBmYTA2Y2Q0N2JlYzRjYjM5Y2NhM2MwMTQ2MGNhNWY1IiwiaCI6Im11cm11cjEyOCJ9", "eyJvcmciOiI2NDA2NTFhNTIyZmEwNTAwMDEyOWJiZTEiLCJpZCI6IjM0ZmVkNzM2NWEzYzRlNWE5MGM2MmQ3NjRlZTM4ZDZkIiwiaCI6Im11cm11cjEyOCJ9"]
    
    return keys.randomElement()!
}

/// - Parameter now: l'instant de référence du décompte. Le widget passe la date de
///   l'entrée de timeline qu'il est en train de construire, pas l'heure courante.
public func displayTimeOrMinutesRemaining(for timetableInput: String, estimatedInput: String, with showTime: Bool, at now: Date = Date()) -> (text: String, color: Color) {
    // Lu dans le groupe d'app : @AppStorage écrit dans .standard, invisible depuis le widget.
    let delayTimeIntegrated = SharedStorage.bool(forSetting: "DelayTimeIntegrated")
    var estimatedInput = estimatedInput
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    formatter.timeZone = TimeZone(identifier: "UTC")

    let currentDate = now
    
    // Parse the timetabledTime and estimatedTime
    if estimatedInput.isEmpty {
        estimatedInput = timetableInput
    }
    guard let timetableTime = formatter.date(from: timetableInput),
          let estimatedTime = formatter.date(from: estimatedInput) else {
        print("Failed to parse date strings: \(timetableInput) or \(estimatedInput)")
        return ("", .yellow)//to change, yellow just for testing
    }
    
    // Format the date to HH:mm in the desired time zone (UTC+2)
    let targetTimeZone = TimeZone.current
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    timeFormatter.timeZone = targetTimeZone
    let EstimatedFormatted = timeFormatter.string(from: estimatedTime)
    let TimetableFormatted = timeFormatter.string(from: timetableTime)
    
    // Calculate the time difference
    let timeDifference = estimatedTime.timeIntervalSince(currentDate)
    let minutesRemaining = /*Int(*/timeDifference / 60//)
//    print("EstimatedTime: \(estimatedTime), timeDifference: \(timeDifference), minutesRemaining: \(minutesRemaining),  Int: \(Int(minutesRemaining))")
    
    // Calculate the delay
    let delay = Int(estimatedTime.timeIntervalSince(timetableTime) / 60)
    let delayString = delay > 0 ? "(+\(delay)')" : "(\(delay)')"
    
    if showTime && minutesRemaining > 0 {
        if delay == 0 {
            return (TimetableFormatted, .primary)
        } else {
            if !delayTimeIntegrated {
                return ("\(TimetableFormatted);\(delayString)", .accent)
            } else {
                return ("\(EstimatedFormatted)", delay > 0 ? .accent : .primary)
            }
        }
    } else if minutesRemaining < 60 && minutesRemaining > 1 {
        return ("\(Int(minutesRemaining))'", delay > 0 ? .accent : .primary)
    } else if minutesRemaining <= 1 && minutesRemaining > 0.5 {
        return ("< 1'", delay > 0 ? .accent : .primary)
    } else if Int(minutesRemaining) == 0 {
        return ("0", .primary)
    } else {
        return ("\(EstimatedFormatted)", .primary)
    }
}

public func dateStringHasPassed(with dateString: String, equalReturnsTrue: Bool) -> Bool {
    let formatter = ISO8601DateFormatter()
    
    // Parse the date string into a Date object
    guard let date = formatter.date(from: dateString) else {
        print("Failed to parse date string: \(dateString)")
        return false
    }
    
    // Get the current date and time
    let currentDate = Date()
    
    // Adjust the parsed date to UTC+2
    let targetTimeZone = TimeZone.current
    let adjustedParsedDate = date.addingTimeInterval(TimeInterval(targetTimeZone.secondsFromGMT(for: date)))
    
    // Adjust the current date to UTC+2
    let adjustedCurrentDate = currentDate.addingTimeInterval(TimeInterval(targetTimeZone.secondsFromGMT(for: currentDate)))
    
    // Round both dates to the nearest minute
    let calendar = Calendar.current
    let componentsParsedDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: adjustedParsedDate)
    let componentsCurrentDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: adjustedCurrentDate)
    
    // Recreate dates without seconds for comparison
    guard let roundedParsedDate = calendar.date(from: componentsParsedDate),
          let roundedCurrentDate = calendar.date(from: componentsCurrentDate) else {
        print("Failed to round dates")
        return false
    }
    
    // Compare the adjusted parsed date with the adjusted current date ignoring seconds
    if equalReturnsTrue {
        return roundedParsedDate <= roundedCurrentDate
    } else {
        return roundedParsedDate < roundedCurrentDate
    }
} //A check: hh:mm:30, arrondi vers le haut ou le bas ?

public func stringToDate(with dateString: String) -> Date? {
    let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ" // Adjust this format to match your date string format
        return dateFormatter.date(from: dateString)
}

public func dateToString(with date: Date) -> String {
    let targetTimeZone = TimeZone.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.timeZone = targetTimeZone
        let formattedDate = dateFormatter.string(from: date)
        return formattedDate
}

public func convertDateString(_ dateString: String) -> String? {
    // Step 1: Create a DateFormatter to parse the input string
    let inputFormatter = DateFormatter()
    inputFormatter.dateFormat = "yyyy-MM-dd" // The format of the input string
    
    // Step 2: Create a DateFormatter to output the desired format
    let outputFormatter = DateFormatter()
    outputFormatter.dateFormat = "d/M/yy" // The desired output format
    
    // Step 3: Convert the input string to a Date object
    if let date = inputFormatter.date(from: dateString) {
        // Step 4: Convert the Date object back to a string in the desired format
        return outputFormatter.string(from: date)
    }
    
    return nil // Return nil if the input string is not in the correct format
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
