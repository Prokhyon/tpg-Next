//
//  LineColors.swift
//  tpg Next
//
//  Created by Loris Thomas on 05.12.2024.
//
import SwiftUI

public struct LineColors {
    static let lineBrown = Color(red: 124.0/255.0, green: 74.0/255.0, blue: 38.0/255.0)
    static let lineBlue = Color(red: 77.0/255.0, green: 169.0/255.0, blue: 226.0/255.0)
    static let lineGrayBlue = Color(red: 61.0/255.0, green: 138.0/255.0, blue: 185.0/255.0)
    static let lineDarkBlue = Color(red: 77.0/255.0, green: 169.0/255.0, blue: 226.0/255.0)
    static let lineOrange = Color(red: 239.0/255.0, green: 133.0/255.0, blue: 50.0/255.0)
    static let lineLightOrange = Color(red: 233.0/255.0, green: 167.0/255.0, blue: 58.0/255.0)
    static let lineIndigo = Color(red: 83.0/255.0, green: 34.0/255.0, blue: 125.0/255.0)
    static let linePurple = Color(red: 170.0/255.0, green: 59.0/255.0, blue: 134.0/255.0)
    static let lineAcidGreen = Color(red: 212.0/255.0, green: 219.0/255.0, blue: 99.0/255.0)
    static let lineDarkGreen = Color(red: 46.0/255.0, green: 108.0/255.0, blue: 66.0/255.0)
    static let lineBordeau = Color(red: 110.0/255.0, green: 18.0/255.0, blue: 59.0/255.0)
    static let lineLightIndigo = Color(red: 122.0/255.0, green: 58.0/255.0, blue: 153.0/255.0)
    static let lineLightMint = Color(red: 152.0/255.0, green: 201.0/255.0, blue: 190.0/255.0)
    static let lineDarkMint = Color(red: 39.0/255.0, green: 93.0/255.0, blue: 96.0/255.0)
    static let linePink = Color(red: 219.0/255.0, green: 106.0/255.0, blue: 157.0/255.0)
    static let lineLightPink = Color(red: 235.0/255.0, green: 184.0/255.0, blue: 209.0/255.0)
    static let lineSalmon = Color(red: 241.0/255.0, green: 160.0/255.0, blue: 171.0/255.0)
    static let lineDarkSalmon = Color(red: 240.0/255.0, green: 91.0/255.0, blue: 83.0/255.0)
    
    static let tpgColors: [String: Color] = [
            "12": lineLightOrange,
            "14": lineIndigo,
            "15": lineBrown,
            "17": lineBlue,
            "18": linePurple,
            "2": lineAcidGreen,
            "3": linePurple,
            "6": lineGrayBlue,
            "7": .green,
            "10": lineDarkGreen,
            "19": lineBrown,
            "1": lineIndigo,
            "5": lineBlue,
            "8": lineBrown,
            "9": .red,
            "11": lineLightIndigo,
            "20": .green,
            "21": lineBrown,
            "22": lineIndigo,
            "23": linePurple,
            "25": lineBrown,
            "28": lineLightIndigo,
            "29": .pink,
            "31": .mint,
            "32": lineLightMint,
            "33": .mint,
            "34": lineLightMint,
            "37": lineDarkMint,
            "38": lineDarkMint,
            "39": .mint,
            "40": lineLightMint,
            "41": .mint,
            "42": .mint,
            "43": lineLightMint,
            "44": .mint,
            "45": lineLightMint,
            "46": .mint,
            "47": .mint,
            "48": lineLightMint,
            "50": .mint,
            "51": .mint,
            "52": lineLightMint,
            "53": lineLightMint,
            "54": lineLightMint,
            "55": lineDarkMint,
            "56": .mint,
            "57": lineLightMint,
            "59": lineDarkMint,
            "60": linePink,
            "61": lineLightPink,
            "64": linePink,
            "66": lineLightPink,
            "67": lineLightPink,
            "68": linePink,
            "69": lineLightPink,
            "70": .mint,
            "71": lineDarkMint,
            "72": lineLightMint,
            "73": lineDarkMint,
            "74": lineLightMint,
            "75": lineDarkMint,
            "78": lineDarkMint,
            "80": lineLightPink,
            "82": linePink,
            "83": linePink,
            "91": lineDarkMint,
            "92": lineLightMint,
            "A": lineOrange,
            "E": lineOrange,
            "G": lineSalmon,
            "J": lineOrange,
            "K": lineSalmon,
            "L": lineOrange,
            "E+": .black,
            "G+": .black,
        ]
    static let sbbColors: [String: Color] = [
        "RL1": .red,
        "RL2": .blue,
        "RL3": .green,
        "RL4": .yellow,
        "RL5": lineBordeau,
        "RL6": lineIndigo
        ]
    
    static let tacColors: [String: Color] = [
        "TANGO": lineBlue,
        "3": .mint,
        "4": lineLightOrange,
        "5": linePurple,
        "6": lineAcidGreen,
        "7": lineBrown,
        "8": lineLightPink
        ]
    
    static let tlColors: [String: Color] = [
        "1" : Color(red: 0.94, green: 0.36, blue: 0.33, opacity: 1.00),
        "2" : Color(red: 0.99, green: 0.65, blue: 0.09, opacity: 1.00),
        "3" : Color(red: 0.53, green: 0.54, blue: 0.55, opacity: 1.00),
        "4" : Color(red: 0.00, green: 0.61, blue: 0.28, opacity: 1.00),
        "6" : Color(red: 0.00, green: 0.64, blue: 0.93, opacity: 1.00),
        "7" : Color(red: 0.16, green: 0.17, blue: 0.53, opacity: 1.00),
        "8" : Color(red: 0.52, green: 0.29, blue: 0.59, opacity: 1.00),
        "9" : Color(red: 0.67, green: 0.11, blue: 0.51, opacity: 1.00),
        "13" : Color(red: 0.23, green: 0.55, blue: 0.51, opacity: 1.00),
        "16" : Color(red: 0.73, green: 0.67, blue: 0.00, opacity: 1.00),
        "17" : .red,
        "18" : Color(red: 0.24, green: 0.76, blue: 0.95, opacity: 1.00),
        "19" : Color(red: 0.16, green: 0.37, blue: 0.67, opacity: 1.00),
        "20" : Color(red: 0.85, green: 0.42, blue: 0.10, opacity: 1.00),
        "21" : Color(red: 0.76, green: 0.30, blue: 0.49, opacity: 1.00),
        "24" : Color(red: 0.28, green: 0.59, blue: 0.52, opacity: 1.00),
        "25" : Color(red: 0.27, green: 0.43, blue: 0.62, opacity: 1.00),
        "31" : Color(red: 0.28, green: 0.57, blue: 0.69, opacity: 1.00),
        "32" : Color(red: 0.57, green: 0.48, blue: 0.71, opacity: 1.00),
        "33" : Color(red: 0.26, green: 0.42, blue: 0.11, opacity: 1.00),
        "35" : Color(red: 0.98, green: 0.60, blue: 0.15, opacity: 1.00),
        "36" : Color(red: 0.57, green: 0.67, blue: 0.71, opacity: 1.00),
        "38" : Color(red: 0.70, green: 0.49, blue: 0.17, opacity: 1.00),
        "41" : Color(red: 0.67, green: 0.11, blue: 0.51, opacity: 1.00),
        "42" : Color(red: 0.77, green: 0.51, blue: 0.55, opacity: 1.00),
        "44" : Color(red: 0.95, green: 0.56, blue: 0.66, opacity: 1.00),
        "45" : Color(red: 0.00, green: 0.51, blue: 0.54, opacity: 1.00),
        "46" : Color(red: 0.67, green: 0.57, blue: 0.00, opacity: 1.00),
        "47" : Color(red: 0.78, green: 0.57, blue: 0.28, opacity: 1.00),
        "48" : Color(red: 0.46, green: 0.59, blue: 0.80, opacity: 1.00),
        "49" : Color(red: 0.73, green: 0.53, blue: 0.73, opacity: 1.00),
        "54" : Color(red: 0.69, green: 0.36, blue: 0.25, opacity: 1.00),
        "56" : Color(red: 0.00, green: 0.29, blue: 0.61, opacity: 1.00),
        "58" : Color(red: 0.00, green: 0.69, blue: 0.79, opacity: 1.00),
        "60" : Color(red: 0.51, green: 0.75, blue: 0.22, opacity: 1.00),
        "64" : Color(red: 0.73, green: 0.18, blue: 0.21, opacity: 1.00),
        "68" : Color(red: 0.16, green: 0.16, blue: 0.19, opacity: 1.00),
        "69" : Color(red: 0.56, green: 0.54, blue: 0.76, opacity: 1.00),
        "Bus-LEB" : Color(red: 0.32, green: 0.66, blue: 0.18, opacity: 1.00),
        "R20" : Color(red: 0.32, green: 0.66, blue: 0.18, opacity: 1.00),
        "m1" : Color(red: 0.91, green: 0.00, blue: 0.51, opacity: 1.00),
        "m2" : Color(red: 0.91, green: 0.00, blue: 0.51, opacity: 1.00),
    ]
    
    static let mbcColors: [String: Color] = [
        "2003" : Color(red: 0.59, green: 0.59, blue: 0.59, opacity: 1.00),
        "R56" : Color(red: 0.02, green: 0.68, blue: 0.24, opacity: 1.00),
        "R57" : Color(red: 0.00, green: 0.37, blue: 0.14, opacity: 1.00),
        "701" : Color(red: 0.00, green: 0.27, blue: 0.12, opacity: 1.00),
        "702" : Color(red: 0.00, green: 0.27, blue: 0.12, opacity: 1.00),
        "703" : Color(red: 0.34, green: 0.11, blue: 0.47, opacity: 1.00),
        "704" : Color(red: 0.51, green: 0.71, blue: 0.06, opacity: 1.00),
        "705" : Color(red: 0.34, green: 0.11, blue: 0.47, opacity: 1.00),
        "706" : Color(red: 0.34, green: 0.11, blue: 0.47, opacity: 1.00),
        "724" : Color(red: 0.64, green: 0.29, blue: 0.57, opacity: 1.00),
        "726" : Color(red: 0.00, green: 0.60, blue: 0.89, opacity: 1.00),
        "728" : .red,
        "730" : Color(red: 0.49, green: 0.50, blue: 0.49, opacity: 1.00),
        "735" : Color(red: 0.89, green: 0.00, blue: 0.44, opacity: 1.00),
        "736" :Color(red: 0.49, green: 0.47, blue: 0.71, opacity: 1.00),
        "742" :Color(red: 0.72, green: 0.07, blue: 0.11, opacity: 1.00),
        "750" :Color(red: 0.13, green: 0.17, blue: 0.50, opacity: 1.00),
        "760" : Color(red: 0.00, green: 0.55, blue: 0.54, opacity: 1.00)
    ]
    
    static let tpnColors: [String: Color] = [
        "803" :Color(red: 0.89, green: 0.16, blue: 0.13, opacity: 1.00),
            "804" :Color(red: 0.00, green: 0.55, blue: 0.22, opacity: 1.00),
            "805" :Color(red: 0.93, green: 0.45, blue: 0.00, opacity: 1.00),
            "810" :Color(red: 0.75, green: 0.53, blue: 0.73, opacity: 1.00),
            "811" :Color(red: 0.55, green: 0.18, blue: 0.51, opacity: 1.00),
            "813" :Color(red: 0.95, green: 0.57, blue: 0.62, opacity: 1.00),
            "814" :Color(red: 0.00, green: 0.23, blue: 0.44, opacity: 1.00),
            "815" :Color(red: 0.64, green: 0.12, blue: 0.15, opacity: 1.00),
            "818" :Color(red: 0.48, green: 0.23, blue: 0.11, opacity: 1.00),
            "891" :Color(red: 1.00, green: 0.88, blue: 0.15, opacity: 1.00)
        ]
    
    static let travysColors: [String: Color] = [
        "601" : Color(red: 0.92, green: 0.20, blue: 0.14, opacity: 1.00),
        "602" :Color(red: 0.32, green: 0.45, blue: 0.96, opacity: 1.00),
            "603" :Color(red: 0.54, green: 0.99, blue: 0.30, opacity: 1.00),
            "604" :Color(red: 0.95, green: 0.62, blue: 0.22, opacity: 1.00),
            "605" :Color(red: 0.61, green: 0.12, blue: 0.87, opacity: 1.00),
            "611" :Color(red: 0.96, green: 0.78, blue: 0.98, opacity: 1.00),
            "613" :Color(red: 0.35, green: 0.65, blue: 0.86, opacity: 1.00),
            "615" :Color(red: 0.57, green: 0.79, blue: 0.33, opacity: 1.00),
            "685" :Color(red: 0.73, green: 0.31, blue: 0.60, opacity: 1.00),
            "686" :Color(red: 0.87, green: 0.51, blue: 0.27, opacity: 1.00),
            "691" :Color(red: 0.92, green: 0.20, blue: 0.14, opacity: 1.00),
            "692" :Color(red: 0.12, green: 0.30, blue: 0.82, opacity: 1.00),
            "693" :Color(red: 0.32, green: 0.70, blue: 0.20, opacity: 1.00)
        ]
    
    static let vmcvColors: [String: Color] = [
            "201" :Color(red: 0.20, green: 0.44, blue: 0.71, opacity: 1.00),
                "202" :Color(red: 0.43, green: 0.29, blue: 0.60, opacity: 1.00),
                "203" :Color(red: 0.80, green: 0.59, blue: 0.75, opacity: 1.00),
                "204" :Color(red: 0.91, green: 0.60, blue: 0.32, opacity: 1.00),
                "205" :Color(red: 0.64, green: 0.80, blue: 0.41, opacity: 1.00),
                "206" :Color(red: 0.19, green: 0.42, blue: 0.24, opacity: 1.00),
                "207" :Color(red: 0.64, green: 0.45, blue: 0.23, opacity: 1.00),
                "208" :Color(red: 0.18, green: 0.26, blue: 0.56, opacity: 1.00),
                "209" :Color(red: 0.46, green: 0.12, blue: 0.12, opacity: 1.00),
            "210" : .red,
                "211" :Color(red: 0.42, green: 0.75, blue: 0.76, opacity: 1.00),
                "212" :Color(red: 0.40, green: 0.55, blue: 0.61, opacity: 1.00),
                "213" :Color(red: 0.85, green: 0.27, blue: 0.55, opacity: 1.00),
                "215" : Color(red: 0.87, green: 0.44, blue: 0.22, opacity: 1.00),
                "216" :Color(red: 0.31, green: 0.63, blue: 0.42, opacity: 1.00),
                "217" :Color(red: 0.76, green: 0.67, blue: 0.27, opacity: 1.00)
        ]
    
    static let tpcColors: [String: Color] = [
        "R70" :Color(red: 0.82, green: 0.64, blue: 0.21, opacity: 1.00),
            "R71" :Color(red: 0.54, green: 0.45, blue: 0.23, opacity: 1.00),
            "R72" :Color(red: 0.55, green: 0.63, blue: 0.35, opacity: 1.00),
            "R74" :Color(red: 0.47, green: 0.34, blue: 0.46, opacity: 1.00),
            
            "61" :Color(red: 0.70, green: 0.73, blue: 0.23, opacity: 1.00),
            "63" :Color(red: 0.13, green: 0.31, blue: 0.54, opacity: 1.00),
            "81" :Color(red: 0.70, green: 0.73, blue: 0.23, opacity: 1.00),
            "82" :Color(red: 0.70, green: 0.73, blue: 0.23, opacity: 1.00),
            "111" :Color(red: 0.13, green: 0.31, blue: 0.54, opacity: 1.00),
            "143" :Color(red: 0.22, green: 0.50, blue: 0.69, opacity: 1.00),
            "144" :Color(red: 0.82, green: 0.78, blue: 0.25, opacity: 1.00),
            "145" :Color(red: 0.71, green: 0.58, blue: 0.19, opacity: 1.00),
            "152" :Color(red: 0.20, green: 0.46, blue: 0.39, opacity: 1.00),
            "153" :Color(red: 0.70, green: 0.73, blue: 0.23, opacity: 1.00),
            "161" :Color(red: 0.54, green: 0.43, blue: 0.26, opacity: 1.00),
            "162" :Color(red: 0.13, green: 0.31, blue: 0.54, opacity: 1.00),
            "163" :Color(red: 0.41, green: 0.63, blue: 0.81, opacity: 1.00),
            "164" :Color(red: 0.82, green: 0.78, blue: 0.25, opacity: 1.00),
            "165" :Color(red: 0.42, green: 0.49, blue: 0.38, opacity: 1.00),
            "172" :Color(red: 0.20, green: 0.46, blue: 0.39, opacity: 1.00),
            "175" :Color(red: 0.73, green: 0.43, blue: 0.48, opacity: 1.00),
        
            "101" :Color(red: 0.18, green: 0.42, blue: 0.36, opacity: 1.00),
            "102" :Color(red: 0.75, green: 0.17, blue: 0.16, opacity: 1.00),
            "103" :Color(red: 0.62, green: 0.23, blue: 0.45, opacity: 1.00),
            "104" :Color(red: 0.62, green: 0.23, blue: 0.45, opacity: 1.00),
            "105" :Color(red: 0.62, green: 0.23, blue: 0.45, opacity: 1.00),
            "106" :Color(red: 0.40, green: 0.29, blue: 0.43, opacity: 1.00),
            "107" :Color(red: 0.62, green: 0.23, blue: 0.45, opacity: 1.00),
            "108" :Color(red: 0.62, green: 0.23, blue: 0.45, opacity: 1.00),
            "109" :Color(red: 0.62, green: 0.23, blue: 0.45, opacity: 1.00),
            "110" :Color(red: 0.54, green: 0.43, blue: 0.26, opacity: 1.00),
            "112" :Color(red: 0.83, green: 0.67, blue: 0.73, opacity: 1.00),
            "113" :Color(red: 0.20, green: 0.46, blue: 0.63, opacity: 1.00),
            "114" :Color(red: 0.42, green: 0.49, blue: 0.38, opacity: 1.00),
            "115" :Color(red: 0.13, green: 0.31, blue: 0.52, opacity: 1.00),
            "116" :Color(red: 0.41, green: 0.61, blue: 0.79, opacity: 1.00),
            "119" :Color(red: 0.69, green: 0.14, blue: 0.35, opacity: 1.00)
        ]
    
    static let cgnColors: [String: Color] = [
        "N1": .pink,
        "N2": .green,
        "N3": .orange,
        "N4": .blue
        ]
    
    
    
    public static func lineColor(for lineID: String, operatorName: String, inverted: Bool = false) -> Color {
        let colorMaps: [String: [String: Color]] = [
            "Transports Publics Genevois": tpgColors,
            "Schweizerische Bundesbahnen SBB": sbbColors,
            "Transports Publics de l'agglomération d'Annemasse": tacColors,
            "Transports Publics de la Région Lausannoise sa": tlColors,
            "Lausanne-Echallens-Bercher": tlColors,
            "Automobiles MBC": mbcColors,
            "Bus Nyon-Prangins": tpnColors,
            "Transports Vallée de Joux-Yverdon-Ste-Croix": travysColors,
            "Transports publics Vevey-Montreux-Chillon-Villeneuve": vmcvColors,
            "Transports Publics du Chablais": tpcColors,
            "Transports Publics du Chablais (Bus)": tpcColors,
            "CGN SA" : cgnColors
        ]

        if let colorMap = colorMaps[operatorName], let color = colorMap[lineID] {
            return color
        } else {
            if operatorName == "Schweizerische Bundesbahnen SBB" {
                return .red
            } else if operatorName == "PostAuto AG" {
                return .yellow
            } else if operatorName == "CGN SA" {
                return lineDarkBlue
            } else {
                Log.ui.debug("Couleurs manquantes pour \(operatorName)")
                return inverted ? .color1 : .primary
            }
        }
    }
}
