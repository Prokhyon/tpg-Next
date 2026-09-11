#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"loristhomas.tpgNextFunc";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "AccentColor 1" asset catalog color resource.
static NSString * const ACColorNameAccentColor1 AC_SWIFT_PRIVATE = @"AccentColor 1";

/// The "Color 1" asset catalog color resource.
static NSString * const ACColorNameColor1 AC_SWIFT_PRIVATE = @"Color 1";

/// The "CustomBackground" asset catalog color resource.
static NSString * const ACColorNameCustomBackground AC_SWIFT_PRIVATE = @"CustomBackground";

/// The "PickerColor" asset catalog color resource.
static NSString * const ACColorNamePickerColor AC_SWIFT_PRIVATE = @"PickerColor";

/// The "Shadows" asset catalog color resource.
static NSString * const ACColorNameShadows AC_SWIFT_PRIVATE = @"Shadows";

/// The "borderDark" asset catalog color resource.
static NSString * const ACColorNameBorderDark AC_SWIFT_PRIVATE = @"borderDark";

/// The "borderLight" asset catalog color resource.
static NSString * const ACColorNameBorderLight AC_SWIFT_PRIVATE = @"borderLight";

/// The "customShadows" asset catalog color resource.
static NSString * const ACColorNameCustomShadows AC_SWIFT_PRIVATE = @"customShadows";

/// The "customShadows2" asset catalog color resource.
static NSString * const ACColorNameCustomShadows2 AC_SWIFT_PRIVATE = @"customShadows2";

/// The "text" asset catalog color resource.
static NSString * const ACColorNameText AC_SWIFT_PRIVATE = @"text";

/// The "tpgMap" asset catalog image resource.
static NSString * const ACImageNameTpgMap AC_SWIFT_PRIVATE = @"tpgMap";

/// The "scurvepath.stack.fill" asset catalog image resource.
static NSString * const ACImageNameScurvepathStackFill AC_SWIFT_PRIVATE = @"scurvepath.stack.fill";

/// The "scurvepath.stack.fill.badge.minus" asset catalog image resource.
static NSString * const ACImageNameScurvepathStackFillBadgeMinus AC_SWIFT_PRIVATE = @"scurvepath.stack.fill.badge.minus";

/// The "scurvepath.stack.fill.badge.plus" asset catalog image resource.
static NSString * const ACImageNameScurvepathStackFillBadgePlus AC_SWIFT_PRIVATE = @"scurvepath.stack.fill.badge.plus";

#undef AC_SWIFT_PRIVATE
