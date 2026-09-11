import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AccentColor" asset catalog color resource.
    static let accent = DeveloperToolsSupport.ColorResource(name: "AccentColor", bundle: resourceBundle)

    /// The "AccentColor 1" asset catalog color resource.
    static let accentColor1 = DeveloperToolsSupport.ColorResource(name: "AccentColor 1", bundle: resourceBundle)

    /// The "Color 1" asset catalog color resource.
    static let color1 = DeveloperToolsSupport.ColorResource(name: "Color 1", bundle: resourceBundle)

    /// The "CustomBackground" asset catalog color resource.
    static let customBackground = DeveloperToolsSupport.ColorResource(name: "CustomBackground", bundle: resourceBundle)

    /// The "PickerColor" asset catalog color resource.
    static let picker = DeveloperToolsSupport.ColorResource(name: "PickerColor", bundle: resourceBundle)

    /// The "Shadows" asset catalog color resource.
    static let shadows = DeveloperToolsSupport.ColorResource(name: "Shadows", bundle: resourceBundle)

    /// The "borderDark" asset catalog color resource.
    static let borderDark = DeveloperToolsSupport.ColorResource(name: "borderDark", bundle: resourceBundle)

    /// The "borderLight" asset catalog color resource.
    static let borderLight = DeveloperToolsSupport.ColorResource(name: "borderLight", bundle: resourceBundle)

    /// The "customShadows" asset catalog color resource.
    static let customShadows = DeveloperToolsSupport.ColorResource(name: "customShadows", bundle: resourceBundle)

    /// The "customShadows2" asset catalog color resource.
    static let customShadows2 = DeveloperToolsSupport.ColorResource(name: "customShadows2", bundle: resourceBundle)

    /// The "text" asset catalog color resource.
    static let text = DeveloperToolsSupport.ColorResource(name: "text", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "scurvepath.stack.fill" asset catalog image resource.
    static let scurvepathStackFill = DeveloperToolsSupport.ImageResource(name: "scurvepath.stack.fill", bundle: resourceBundle)

    /// The "scurvepath.stack.fill.badge.minus" asset catalog image resource.
    static let scurvepathStackFillBadgeMinus = DeveloperToolsSupport.ImageResource(name: "scurvepath.stack.fill.badge.minus", bundle: resourceBundle)

    /// The "scurvepath.stack.fill.badge.plus" asset catalog image resource.
    static let scurvepathStackFillBadgePlus = DeveloperToolsSupport.ImageResource(name: "scurvepath.stack.fill.badge.plus", bundle: resourceBundle)

    /// The "tpgMap" asset catalog image resource.
    static let tpgMap = DeveloperToolsSupport.ImageResource(name: "tpgMap", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "AccentColor" asset catalog color.
    static var accent: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .accent)
#else
        .init()
#endif
    }

    /// The "AccentColor 1" asset catalog color.
    static var accentColor1: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .accentColor1)
#else
        .init()
#endif
    }

    /// The "Color 1" asset catalog color.
    static var color1: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .color1)
#else
        .init()
#endif
    }

    /// The "CustomBackground" asset catalog color.
    static var customBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .customBackground)
#else
        .init()
#endif
    }

    /// The "PickerColor" asset catalog color.
    static var picker: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .picker)
#else
        .init()
#endif
    }

    /// The "Shadows" asset catalog color.
    static var shadows: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .shadows)
#else
        .init()
#endif
    }

    /// The "borderDark" asset catalog color.
    static var borderDark: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .borderDark)
#else
        .init()
#endif
    }

    /// The "borderLight" asset catalog color.
    static var borderLight: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .borderLight)
#else
        .init()
#endif
    }

    /// The "customShadows" asset catalog color.
    static var customShadows: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .customShadows)
#else
        .init()
#endif
    }

    /// The "customShadows2" asset catalog color.
    static var customShadows2: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .customShadows2)
#else
        .init()
#endif
    }

    /// The "text" asset catalog color.
    static var text: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .text)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "AccentColor" asset catalog color.
    static var accent: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .accent)
#else
        .init()
#endif
    }

    /// The "AccentColor 1" asset catalog color.
    static var accentColor1: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .accentColor1)
#else
        .init()
#endif
    }

    /// The "Color 1" asset catalog color.
    static var color1: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .color1)
#else
        .init()
#endif
    }

    /// The "CustomBackground" asset catalog color.
    static var customBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .customBackground)
#else
        .init()
#endif
    }

    /// The "PickerColor" asset catalog color.
    static var picker: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .picker)
#else
        .init()
#endif
    }

    /// The "Shadows" asset catalog color.
    static var shadows: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .shadows)
#else
        .init()
#endif
    }

    /// The "borderDark" asset catalog color.
    static var borderDark: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .borderDark)
#else
        .init()
#endif
    }

    /// The "borderLight" asset catalog color.
    static var borderLight: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .borderLight)
#else
        .init()
#endif
    }

    /// The "customShadows" asset catalog color.
    static var customShadows: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .customShadows)
#else
        .init()
#endif
    }

    /// The "customShadows2" asset catalog color.
    static var customShadows2: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .customShadows2)
#else
        .init()
#endif
    }

    /// The "text" asset catalog color.
    static var text: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .text)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

    /// The "AccentColor 1" asset catalog color.
    static var accentColor1: SwiftUI.Color { .init(.accentColor1) }

    /// The "Color 1" asset catalog color.
    static var color1: SwiftUI.Color { .init(.color1) }

    /// The "CustomBackground" asset catalog color.
    static var customBackground: SwiftUI.Color { .init(.customBackground) }

    /// The "PickerColor" asset catalog color.
    static var picker: SwiftUI.Color { .init(.picker) }

    /// The "Shadows" asset catalog color.
    static var shadows: SwiftUI.Color { .init(.shadows) }

    /// The "borderDark" asset catalog color.
    static var borderDark: SwiftUI.Color { .init(.borderDark) }

    /// The "borderLight" asset catalog color.
    static var borderLight: SwiftUI.Color { .init(.borderLight) }

    /// The "customShadows" asset catalog color.
    static var customShadows: SwiftUI.Color { .init(.customShadows) }

    /// The "customShadows2" asset catalog color.
    static var customShadows2: SwiftUI.Color { .init(.customShadows2) }

    /// The "text" asset catalog color.
    static var text: SwiftUI.Color { .init(.text) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

    /// The "AccentColor 1" asset catalog color.
    static var accentColor1: SwiftUI.Color { .init(.accentColor1) }

    /// The "Color 1" asset catalog color.
    static var color1: SwiftUI.Color { .init(.color1) }

    /// The "CustomBackground" asset catalog color.
    static var customBackground: SwiftUI.Color { .init(.customBackground) }

    /// The "PickerColor" asset catalog color.
    static var picker: SwiftUI.Color { .init(.picker) }

    /// The "Shadows" asset catalog color.
    static var shadows: SwiftUI.Color { .init(.shadows) }

    /// The "borderDark" asset catalog color.
    static var borderDark: SwiftUI.Color { .init(.borderDark) }

    /// The "borderLight" asset catalog color.
    static var borderLight: SwiftUI.Color { .init(.borderLight) }

    /// The "customShadows" asset catalog color.
    static var customShadows: SwiftUI.Color { .init(.customShadows) }

    /// The "customShadows2" asset catalog color.
    static var customShadows2: SwiftUI.Color { .init(.customShadows2) }

    /// The "text" asset catalog color.
    static var text: SwiftUI.Color { .init(.text) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "scurvepath.stack.fill" asset catalog image.
    static var scurvepathStackFill: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .scurvepathStackFill)
#else
        .init()
#endif
    }

    /// The "scurvepath.stack.fill.badge.minus" asset catalog image.
    static var scurvepathStackFillBadgeMinus: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .scurvepathStackFillBadgeMinus)
#else
        .init()
#endif
    }

    /// The "scurvepath.stack.fill.badge.plus" asset catalog image.
    static var scurvepathStackFillBadgePlus: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .scurvepathStackFillBadgePlus)
#else
        .init()
#endif
    }

    /// The "tpgMap" asset catalog image.
    static var tpgMap: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .tpgMap)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "scurvepath.stack.fill" asset catalog image.
    static var scurvepathStackFill: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .scurvepathStackFill)
#else
        .init()
#endif
    }

    /// The "scurvepath.stack.fill.badge.minus" asset catalog image.
    static var scurvepathStackFillBadgeMinus: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .scurvepathStackFillBadgeMinus)
#else
        .init()
#endif
    }

    /// The "scurvepath.stack.fill.badge.plus" asset catalog image.
    static var scurvepathStackFillBadgePlus: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .scurvepathStackFillBadgePlus)
#else
        .init()
#endif
    }

    /// The "tpgMap" asset catalog image.
    static var tpgMap: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .tpgMap)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

