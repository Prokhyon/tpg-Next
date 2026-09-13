//
//  BasicViews.swift
//  tpg Next
//
//  Created by Loris Thomas on 09.02.2025.
//

import SwiftUI
import tpgNextFunc
import MapKit

struct SmallStopTitleView: View {
    var stopName: String
    var transportType: String?

    var body: some View {
        HStack {
            StopNameView(stopName, style: .row, transportType: transportType)
            Spacer()
        }
    }
}

///Alternative for stop display inside SmallStopTitleVIew. Has to be tested
//VStack(alignment: .leading) {
//    GeometryReader { geometry in
//        ZStack {
//            Text(splitStopName.1)
//                .font(.callout)
//                .bold()
//                .minimumScaleFactor(0.5) // Shrinks if needed
//                .lineLimit(1)
//                .background(GeometryReader { textGeometry in
//                    Color.clear.preference(key: TextWidthPreferenceKey.self, value: textGeometry.size.width)
//                })
//        }
//        .frame(maxWidth: .infinity, alignment: .leading)
//    }
//    .frame(height: 20) // Adjust based on your UI needs
//
//    Text(splitStopName.0)
//        .font(.caption)
//        .minimumScaleFactor(0.4) // Will shrink if necessary
//        .lineLimit(1)
//}
//.onPreferenceChange(TextWidthPreferenceKey.self) { textWidth in
//    let remainingWidth = UIScreen.main.bounds.width - textWidth - 10 // Adjust padding
//    print("Remaining width for top text:", remainingWidth)
//}

// MARK: - Surfaces flottantes

/// Titres et boutons flottants : Liquid Glass sur iOS 26, matériau et ombre avant.
enum TPGSurface {
    static var isGlass: Bool {
        if #available(iOS 26, *) { return true } else { return false }
    }
}

extension View {
    /// Pose la vue sur une surface flottante.
    /// - Parameters:
    ///   - interactive: le verre réagit au toucher (iOS 26).
    ///   - legacy: le matériau avant iOS 26, `nil` pour aucun fond.
    ///   - glassID: identifiant de morphing entre surfaces d'un même `TPGGlassContainer` (iOS 26).
    func tpgSurface<S: Shape>(in shape: S, interactive: Bool = false, legacy: Material? = .ultraThinMaterial,
                              glassID: String? = nil, namespace: Namespace.ID? = nil) -> some View {
        modifier(TPGSurfaceModifier(shape: shape, interactive: interactive, legacy: legacy, glassID: glassID, namespace: namespace))
    }

    func tpgSurface(interactive: Bool = false, legacy: Material? = .ultraThinMaterial,
                    glassID: String? = nil, namespace: Namespace.ID? = nil) -> some View {
        tpgSurface(in: Capsule(), interactive: interactive, legacy: legacy, glassID: glassID, namespace: namespace)
    }

    /// Le fond d'avant iOS 26 seulement : sur iOS 26 le système pose déjà le verre (barre d'outils).
    @ViewBuilder func legacySurface(material: Material = .ultraThinMaterial) -> some View {
        if TPGSurface.isGlass {
            self
        } else {
            tpgSurface(legacy: material)
        }
    }

    /// Couleur du contenu posé sur du verre ; avant iOS 26 le contenu garde la sienne.
    @ViewBuilder func glassForegroundStyle(_ color: Color) -> some View {
        if TPGSurface.isGlass {
            foregroundStyle(color)
        } else {
            self
        }
    }
}

private struct TPGSurfaceModifier<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool
    let legacy: Material?
    let glassID: String?
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            let glass = content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
            if let glassID, let namespace {
                glass.glassEffectID(glassID, in: namespace)
            } else {
                glass
            }
        } else if let legacy {
            content.background {
                shape
                    .fill(legacy)
                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
            }
        } else {
            content
        }
    }
}

/// `GlassEffectContainer` sur iOS 26, pour que les surfaces voisines fusionnent ; le contenu tel quel avant.
struct TPGGlassContainer<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer { content }
        } else {
            content
        }
    }
}

/// Voile flou en haut de l'écran, sous le titre flottant. Rien sur iOS 26 : la barre de
/// navigation estompe déjà le contenu qui défile dessous.
struct LegacyTopFade: View {
    var body: some View {
        if !TPGSurface.isGlass {
            VStack(spacing: 0) {
                Rectangle()
                    .foregroundStyle(.ultraThickMaterial)
                    .frame(height: 50)
                Rectangle()
                    .foregroundStyle(.ultraThickMaterial)
                    .frame(height: 100)
                    .mask {
                        Rectangle()
                            .overlay(alignment: .trailing) {
                                ScrollMask(leading: true, vertical: true, gradientLength: 100)
                            }
                    }
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

struct BasicElement: View {
    var transparent = false
    var highlighted = false
    var button = false
    var borderGradient = Gradient(colors: [.borderLight, .borderDark, .borderLight, .borderDark, .borderLight])
    var accentBorder = Gradient(colors: [.accentColor, .orange, .accentColor, .orange, .accentColor])
    
    var body: some View {
        Capsule()
            .fill(button ? .accent : .color1.opacity(transparent ? 0.5 : 1))
            .stroke(AngularGradient(gradient: highlighted ? accentBorder : borderGradient, center: .center, angle: .degrees(45)), lineWidth: 1)
            .shadow(color: .customShadows.opacity(0.2), radius: 7)
    }
}

struct BasicCard: View {
    var cornerRadius: CGFloat = 30
    var borderGradient = Gradient(colors: [.borderLight, .borderDark, .borderLight, .borderDark, .borderLight])
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.color1)
            .stroke(AngularGradient(gradient: borderGradient, center: .center, angle: .degrees(45)), lineWidth: 1)
            .shadow(color: .customShadows.opacity(0.2), radius: 10)
    }
}

struct BasicLocationView: View {
    var name: String
    var subtitle: String?
    var transportType: String?
    var isGeoPosition : Bool = false
    var isFavorite: Bool = false
    var showButton: Bool = false
    var showFavorite: Bool = false
    var buttonAction: (() -> Void)? = nil
    var favoriteAction: (() -> Void)? = nil
    
    
    var body: some View {
//        RoundedRectangle(cornerRadius: 20)
//        Capsule()
//            .fill(.color1)
//            .stroke(.border, lineWidth: 1)
        BasicElement()
            .frame(height: 45)
//            .shadow(color: Color.customShadows, radius: 1.5, y: 1)
//            .shadow(color: .customShadows.opacity(0.2), radius: 10)
            .overlay(
                HStack {
                    if showFavorite, let favoriteAction = favoriteAction {
                        Button(action: favoriteAction) {
                            Image(systemName: isFavorite ? "star.fill" : "star").foregroundColor(.accent)
                        }
                    }
                    if isGeoPosition {
                        VStack(alignment: .leading) {
                            Text(name)
                                .font(.callout)
                                .bold()
                            Text(subtitle ?? "")
                                .font(.caption)
                                .minimumScaleFactor(0.3)
                        }
                    } else {
                        SmallStopTitleView(stopName: name, transportType: transportType ?? "")
                    }
                        Spacer()
                    if showButton, let buttonAction = buttonAction {
                        Button(action: buttonAction) {
                            Image(systemName: isGeoPosition ? "mappin.and.ellipse.circle" : "figure.wave.circle").font(.title2).foregroundStyle(.accent)
                        }
                    }
                }
                    .padding(.horizontal, 20)
            )

    }
}

struct StopIcon: View {
    var color: Color
    var currentStop: Bool = false
    var size: CGFloat = 18
    @State var isAnimating = false
    
    var body: some View {
        ZStack {
            if currentStop {
//                Circle()
//                    .stroke(color, lineWidth: size/2)//current stop highlight
//                    .scaleEffect(self.isAnimating ? 0.5: 1)
//                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: self.isAnimating)
//                    .onAppear {
//                        self.isAnimating = true
//                    }
                Circle()
                    .stroke(.accent, lineWidth: size/4)//current stop highlight
//                Circle()
//                    .shadow(color: Color.customShadows, radius: 1.5, y: 1)
               
                    
            }
                Circle()
                    .fill(color)
                    .strokeBorder(Color.primary, lineWidth: size/4)
//            .shadow(color: Color.customShadows, radius: 1.5, y: 1)

        }
            .frame(width: size, height: size)
    }
}

struct ShowTimeButton: View {
    @AppStorage(SettingKey.clockTimeByDefault) var timeDefault = false
    @Binding var showTime: Bool
    @State private var rotation: Double = 0
    @State private var imageName: String = "hourglass"
    @State private var wiggle: Bool = false
    
    var body: some View {
        Button(action: {
            withAnimation {
                showTime.toggle()
            }
        }) {
            if #available(iOS 26, *) {
                Image(systemName: imageName)
                    .symbolEffect(.wiggle.clockwise.byLayer, value: wiggle)
                    .foregroundColor(showTime ? .text : .white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 5)
                    .rotationEffect(.degrees(rotation))
                    .background {
                        Capsule()
                            .foregroundStyle(showTime ? .clear : .accent)
                    }
            } else {
                Image(systemName: imageName)
                    .symbolEffect(.wiggle.clockwise.byLayer, value: wiggle)
                    .foregroundColor(showTime ? .accent : .white)
                    .padding(.horizontal, 5)
                    .rotationEffect(.degrees(rotation))
                    .background {
                        Capsule()
                            .foregroundStyle(showTime ? .clear : .accent)
                    }
            }
        }
        .onAppear {
            showTime = timeDefault
        }
        .onChange(of: showTime) {
            if !showTime {
                rotation = 180
                imageName = "hourglass.bottomhalf.filled"
                withAnimation {
                    rotation += 180
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        imageName = "hourglass"
                    }
//                    imageName = "hourglass.bottomhalf.filled"
                }
                    } else {
                        wiggle.toggle()
                        imageName = "hourglass.tophalf.filled"
                    }
                }
    }
}

struct Filterbutton: View {
    @Binding var filterLines: Bool
    @Binding var viewLineFiltered: Bool
    @State private var trueAnimation: Bool = false
    @State private var falseAnimation: Bool = false
    
    var body: some View {
        Button {
            withAnimation {
                filterLines.toggle()
                if filterLines {
                    trueAnimation.toggle()
                } else {
                    falseAnimation.toggle()
                }
            }
        } label: {
            if #available(iOS 26, *) {
                Image(systemName: "line.3.horizontal.decrease")
//                    .symbolEffect(.bounce.up.byLayer, value: trueAnimation)
//                    .symbolEffect(.wiggle, value: falseAnimation)
                    .foregroundColor(viewLineFiltered ? .white : .text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 11)
                    .background {
                        Capsule()
                            .foregroundStyle(viewLineFiltered ? .accent : .clear)
                    }
            } else {
                Image(systemName: "line.3.horizontal.decrease")
                    .symbolEffect(.bounce.up.byLayer, value: trueAnimation)
                    .symbolEffect(.wiggle, value: falseAnimation)
                    .foregroundColor(viewLineFiltered ? .white : .accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 11)

                    .background {
                        Capsule()
                            .foregroundStyle(viewLineFiltered ? .accent : .clear)
                    }
            }
        }
    }
}

struct AdjustTimeButton : View {
    var moveTime: ((Bool) -> Void)
    @State var earlierAnimation = false
    @State var laterAnimation = false
    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                moveTime(true)
                earlierAnimation.toggle()
            }) {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .symbolEffect(.bounce.down.byLayer, value: earlierAnimation)
            }
            .padding()
            Button(action: {
                moveTime(false)
                laterAnimation.toggle()
            }) {
                Image(systemName: "text.line.last.and.arrowtriangle.forward")
                    .symbolEffect(.bounce.down.byLayer, value: laterAnimation)
            }
            .padding()
        }
    }
}

/// A View in which content reflects all behind it
struct BackdropView: UIViewRepresentable {
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView()
        let blur = UIBlurEffect()
        let animator = UIViewPropertyAnimator()
        animator.addAnimations { view.effect = blur }
        animator.fractionComplete = 0
        animator.stopAnimation(false)
        animator.finishAnimation(at: .current)
        return view
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { }
    
}

/// A transparent View that blurs its background
struct BackdropBlurView: View {
    
    let radius: CGFloat
    
    @ViewBuilder
    var body: some View {
        BackdropView().blur(radius: radius)
    }
}


#Preview {
    @Previewable @State var bool: Bool = false
//    ShowTimeButton(showTime: $bool)
    Filterbutton(filterLines: $bool, viewLineFiltered: $bool)
}

#Preview {
    BasicElement()
        .frame(height: 50)
}
