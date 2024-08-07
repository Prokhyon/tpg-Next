//
//  BasicFunc.swift
//  TPG4
//
//  Created by Loris Thomas on 04.07.2024.
//

import Foundation
import SwiftUI

extension UINavigationBar {
    static func setTransparentAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.backgroundEffect = nil
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = appearance
    }
}

func displayTimeOrMinutesRemaining(for timetableInput: String, estimatedInput: String, with showTime: Bool) -> String {
   var estimatedInput = estimatedInput // Use a var to allow modification
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    formatter.timeZone = TimeZone(identifier: "UTC") // Specify UTC timezone

    let currentDate = Date()
    //print("Input timetabledTime:", timetabledTime)
    //print("Input estimatedTime:", estimatedTime)
    
    // Parse the timetabledTime and estimatedTime
    if estimatedInput.isEmpty {
        estimatedInput = timetableInput
    }
    guard let timetableTime = formatter.date(from: timetableInput),
          let estimatedTime = formatter.date(from: estimatedInput) else {
        print("Failed to parse date strings: \(timetableInput) or \(estimatedInput)")
        return ""
    }
    //print("Parsed timetableDate:", timetableDate)
    //print("Parsed estimatedDate:", estimatedDate)
    
    // Format the date to HH:mm in the desired time zone (UTC+2)
    let targetTimeZone = TimeZone(secondsFromGMT: 2 * 3600)!
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "HH:mm"
    timeFormatter.timeZone = targetTimeZone
    let EstimatedFormatted = timeFormatter.string(from: estimatedTime)
    let TimetableFormatted = timeFormatter.string(from: timetableTime)
    
    // Calculate the time difference
    let timeDifference = estimatedTime.timeIntervalSince(currentDate)
    let minutesRemaining = Int(timeDifference / 60)
    
    // Calculate the delay
    let delay = Int(estimatedTime.timeIntervalSince(timetableTime) / 60)
    let delayString = delay == 0 ? "" : (delay > 0 ? " (+\(delay)')" : " (\(delay)')")
    
    if showTime && minutesRemaining > 0 {
        return "\(TimetableFormatted)\(delayString)"
    } else if minutesRemaining <= 60 && minutesRemaining >= 1 {
        return "\(minutesRemaining)'"
    } else if minutesRemaining == 0 {
        return "0"
    } else {
        return "\(EstimatedFormatted)"
    }
}

func compareDateString(with dateString: String) -> Bool {
    let formatter = ISO8601DateFormatter()
    
    // Parse the date string into a Date object
    guard let date = formatter.date(from: dateString) else {
        print("Failed to parse date string: \(dateString)")
        return false
    }
    
    // Get the current date and time
    let currentDate = Date()
    
    // Adjust the parsed date to UTC+2
    let targetTimeZone = TimeZone(secondsFromGMT: 2 * 3600)!
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
    return roundedParsedDate < roundedCurrentDate
}

func stringToDate(with dateString: String) -> Date? {
    let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ" // Adjust this format to match your date string format
        return dateFormatter.date(from: dateString)
}

func dateToString(with date: Date) -> String {
    let targetTimeZone = TimeZone(secondsFromGMT: 2 * 3600)!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        dateFormatter.timeZone = targetTimeZone
        let formattedDate = dateFormatter.string(from: date)
        //print(date, formattedDate)
        return formattedDate
}

func transportIcon(with transportType: String) -> Image {
    if transportType.lowercased() == "tram" {
        return Image(systemName: "tram.fill")
    } else {
       return Image(systemName: "bus.fill")
    }
}
