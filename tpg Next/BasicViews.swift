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
            let splitStopName = splitString(stopName, separator: ",")
            if splitStopName.1.isEmpty {
                HStack {
                    Text(splitStopName.0)
                        .font(.headline)
                        .bold()
                        .minimumScaleFactor(0.5)
                    if let transportType {
                        if transportType == "TRAIN" {
                            Image(systemName: "lightrail").font(.subheadline)
                        } else if transportType == "BOAT" {
                            Image(systemName: "ferry").font(.subheadline)
                        }
                    }
                }
            } else {
                    VStack(alignment: .leading) {
                        Text(splitStopName.0)
                            .font(.caption)
                            .minimumScaleFactor(0.4)
                        Text(splitStopName.1)
                            .font(.callout)
                            .bold()
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
            }
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

struct titleTestView: View {
    var items: [Int] = Array(0..<10)
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var maxRows = 5
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items, id: \.self) { item in
                BasicLocationView(name: "Meinier, église", transportType: "Bus")
            }
        }
        .padding(15)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 35, style: .continuous))
        .padding(.horizontal)
        .shadow(color: Color.customShadows, radius: 2, y: 1.5)
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
    @AppStorage("TimeDefault") var timeDefault = false
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
