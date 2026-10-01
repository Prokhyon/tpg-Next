//
//  WelcomeView.swift
//  tpg Next
//
//  Created by Loris Thomas on 16.10.2024.
//
//  La bienvenue, en trois temps :
//  1. les autorisations : on ne passe qu'après avoir accepté ou refusé chacune ;
//  2. la suite au choix : visite guidée, guide complet, ou commencer tout de suite ;
//  3. la visite guidée (GuideTourView), facultative.
//

import SwiftUI
import UserNotifications
import CoreLocation
import tpgNextFunc

struct WelcomeView: View {
    @Binding var viewingWelcome: Bool
    /// Ouvre le guide d'utilisation, une fois la bienvenue fermée.
    var openGuide: () -> Void = {}
    @State private var stage: Stage = .permissions

    enum Stage {
        case permissions, ready, tour
    }

    var body: some View {
        ZStack {
            switch stage {
            case .permissions:
                WelcomePermissionsPage {
                    stage = .ready
                }
                .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
            case .ready:
                WelcomeReadyPage(onTour: { stage = .tour },
                                 onGuide: showGuide,
                                 onStart: close)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
            case .tour:
                GuideTourView(onOpenGuide: showGuide, onClose: close)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.45), value: stage)
    }

    private func close() {
        viewingWelcome = false
    }

    private func showGuide() {
        viewingWelcome = false
        openGuide()
    }
}

// MARK: Autorisations

/// Une autorisation, telle que la page l'affiche.
private enum PermissionState: Equatable {
    /// Pas encore connue : le système répond dans l'instant.
    case checking
    case undecided
    case granted
    case denied

    var isDecided: Bool { self == .granted || self == .denied }
}

private struct WelcomePermissionsPage: View {
    let onContinue: () -> Void
    @State private var location = LocationManager()
    @State private var notificationStatus: UNAuthorizationStatus?
    @AppStorage(SettingKey.notificationAsked) private var notificationAsked = false
    @AppStorage(SettingKey.iCloudSync) private var iCloudSync = true
    @Environment(\.scenePhase) private var scenePhase

    private var locationState: PermissionState {
        switch location.locationStatus {
        case .authorizedAlways?, .authorizedWhenInUse?: .granted
        case .denied?, .restricted?: .denied
        case .notDetermined?: .undecided
        default: .checking
        }
    }

    private var notificationState: PermissionState {
        switch notificationStatus {
        case .authorized?, .provisional?, .ephemeral?: .granted
        case .denied?: .denied
        case .notDetermined?: .undecided
        default: .checking
        }
    }

    private var canContinue: Bool { locationState.isDecided && notificationState.isDecided }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pour commencer, deux autorisations")
                        .font(.headline)
                    PermissionCard(symbol: "location.fill", color: .blue,
                                   title: "Localisation",
                                   text: "Pour voir les arrêts autour de vous, votre position sur la carte, et partir de là où vous êtes.",
                                   state: locationState) {
                        location.requestLocationAuthorization()
                    }
                    PermissionCard(symbol: "bell.badge.fill", color: .red,
                                   title: "Notifications",
                                   text: "Pour les rappels de départ, les alertes de retard de vos trajets, et le suivi en direct.",
                                   state: notificationState) {
                        requestNotifications()
                    }
                    Text("Répondez à chacune pour continuer. Vous pourrez changer d'avis à tout moment dans les Réglages de l'iPhone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Vos données")
                        .font(.headline)
                    SyncCard(isOn: $iCloudSync)
                    Text("Rien n'est envoyé ailleurs que dans votre compte iCloud. Ce choix se change dans les paramètres de l'app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text("Continuer")
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .welcomeProminentStyle()
            .disabled(!canContinue)
            .animation(.snappy, value: canContinue)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
        }
        .task { await refreshNotifications() }
        // Retour des Réglages : l'autorisation a pu changer.
        .onChange(of: scenePhase) {
            if scenePhase == .active { Task { await refreshNotifications() } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppIconView(size: 68)
            Text("Bienvenue dans tpg Next")
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text("Départs, itinéraires et trajets en temps réel, partout en Suisse.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func requestNotifications() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            notificationAsked = true
            await refreshNotifications()
            NotificationManager.shared.checkAuthorizationStatus()
        }
    }

    private func refreshNotifications() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        withAnimation(.snappy) { notificationStatus = status }
    }
}

private struct PermissionCard: View {
    let symbol: String
    let color: Color
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    let state: PermissionState
    let onAllow: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                control
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemBackground)))
        .animation(.snappy, value: state)
    }

    @ViewBuilder private var control: some View {
        switch state {
        case .checking:
            ProgressView()
                .frame(height: 34)
        case .undecided:
            Button(action: onAllow) {
                Text("Choisir")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 26)
            }
            .welcomeProminentStyle()
        case .granted:
            Label("Autorisée", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .frame(minHeight: 34)
        case .denied:
            HStack(spacing: 12) {
                Label("Refusée", systemImage: "xmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Button("Ouvrir les Réglages") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.subheadline)
            }
            .frame(minHeight: 34)
        }
    }
}

/// Le partage par iCloud, activé par défaut : la synchro ne commence qu'une fois la bienvenue
/// passée (`CloudSync.isEnabled`), le choix est donc respecté dès le premier lancement.
private struct SyncCard: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "icloud.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.cyan.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Synchronisation iCloud").font(.headline)
                    Text("Vos favoris, lieux, itinéraires enregistrés et trajets réguliers se retrouvent sur tous vos appareils.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemBackground)))
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

// MARK: La suite

private struct WelcomeReadyPage: View {
    let onTour: () -> Void
    let onGuide: () -> Void
    let onStart: () -> Void
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: appeared)
                        .accessibilityHidden(true)
                    Text("Tout est prêt")
                        .font(.largeTitle.bold())
                    Text("Vous pouvez commencer tout de suite, ou prendre deux minutes pour découvrir l'app en l'essayant.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 12) {
                    ChoiceCard(symbol: "hand.tap.fill", color: .orange,
                               title: "Visite guidée",
                               text: "Sept gestes à essayer du doigt : favoris, rappels, tri, suivi en direct…",
                               action: onTour)
                    ChoiceCard(symbol: "book.pages.fill", color: .blue,
                               title: "Guide complet",
                               text: "Tout ce que l'app sait faire, page par page.",
                               action: onGuide)
                }
                Text("La visite et le guide restent disponibles dans Paramètres → Guide d'utilisation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button(action: onStart) {
                Text("Commencer")
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .welcomeProminentStyle()
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: 560)
        }
        .onAppear { appeared = true }
    }
}

private struct ChoiceCard: View {
    let symbol: String
    let color: Color
    let title: LocalizedStringKey
    let text: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemBackground)))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview("Bienvenue") {
    @Previewable @State var welcome = true
    WelcomeView(viewingWelcome: $welcome)
        .previewEnvironment(navigation: false, favorites: [])
}

#Preview("Bienvenue — la suite") {
    WelcomeReadyPage(onTour: {}, onGuide: {}, onStart: {})
        .previewEnvironment(navigation: false, favorites: [])
}
