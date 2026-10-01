//
//  APIDiagnosticsView.swift
//  tpg Next
//
//  L'usage des clés OJP : le quota restant de chaque clé (tous appareils confondus, lu dans
//  les en-têtes des réponses), puis ce que cet appareil a envoyé et les échecs qu'il a vus.
//  Ouverte d'un appui long sur le numéro de version, en bas des paramètres.
//

import SwiftUI
import tpgNextFunc

struct APIDiagnosticsView: View {
    @State private var snapshot: OJPUsage.Snapshot
    @State private var isChecking = false
    private let isPreview: Bool

    init(preview: OJPUsage.Snapshot? = nil) {
        _snapshot = State(initialValue: preview ?? OJPUsage.merged())
        isPreview = preview != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                keysSection
                Button {
                    check()
                } label: {
                    HStack {
                        if isChecking {
                            ProgressView()
                        }
                        Text("Vérifier les clés maintenant")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 40)
                }
                .prominentButtonStyle()
                .disabled(isChecking)
                deviceSection
                incidentsSection
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .readableScrollContent()
        .navigationTitle("Diagnostic de l'API")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: report) {
                    Label("Partager le rapport", systemImage: "square.and.arrow.up")
                }
            }
        }
        .refreshable { reload() }
        .periodicRefresh(every: .seconds(10)) { _ in reload() }
    }

    // MARK: Clés

    private var keysSection: some View {
        CardSection("Quota des clés",
                    footer: "Chaque clé a 20 000 requêtes par jour et 50 par minute, partagées par tous les appareils qui ont l'app. Le quota d'une clé repart 24 h après le début de sa période, pas à minuit.") {
            if let total = totalQuota {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Toutes les clés")
                            .font(.headline)
                        Spacer()
                        Text(verbatim: "\(total.used.formatted()) / \(total.limit.formatted())")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(total.used), total: Double(max(total.limit, 1)))
                        .tint(Self.color(remainingShare: 1 - Double(total.used) / Double(max(total.limit, 1))))
                }
                .padding(.vertical, 12)
                CardDivider(inset: 0)
            }
            ForEach(1...max(OJPUsage.keyCount, 1), id: \.self) { number in
                if number > 1 {
                    CardDivider(inset: 0)
                }
                keyRow(number)
            }
        }
    }

    private func keyRow(_ number: Int) -> some View {
        let state = snapshot.keys[number]
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Clé \(number)")
                    .font(.headline)
                Spacer()
                if let remaining = state?.quotaRemaining, let limit = state?.quotaLimit {
                    Text("\(remaining.formatted()) restantes sur \(limit.formatted())")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if let state, let used = state.quotaUsed, let limit = state.quotaLimit {
                ProgressView(value: Double(used), total: Double(max(limit, 1)))
                    .tint(Self.color(remainingShare: Double(state.quotaRemaining ?? 0) / Double(max(limit, 1))))
                Text(details(state))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let paused = state.pausedUntil, paused > Date() {
                    Label("En pause jusqu'à \(paused.formatted(date: .omitted, time: .shortened)) (\(state.lastFailure ?? ""))",
                          systemImage: "pause.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
            } else {
                Text("Pas encore de réponse avec cette clé sur cet appareil.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
    }

    /// « Repart à 07:16 · 48/50 cette minute · vu il y a 2 min ».
    private func details(_ state: OJPUsage.KeyState) -> String {
        var parts: [String] = []
        if let reset = state.quotaReset {
            parts.append(String(localized: "Repart \(reset.formatted(.relative(presentation: .named)))"))
        }
        if let remaining = state.rateRemaining, let limit = state.rateLimit {
            parts.append(String(localized: "\(remaining)/\(limit) cette minute"))
        }
        if let updated = state.updated {
            parts.append(String(localized: "lu \(updated.formatted(.relative(presentation: .named)))"))
        }
        return parts.joined(separator: " · ")
    }

    private var totalQuota: (used: Int, limit: Int)? {
        // Seulement quand toutes les clés ont répondu : une partie passerait pour le tout.
        let states = (1...max(OJPUsage.keyCount, 1)).compactMap { snapshot.keys[$0] }.filter { $0.quotaLimit != nil }
        guard states.count == OJPUsage.keyCount else { return nil }
        return (states.compactMap(\.quotaUsed).reduce(0, +), states.compactMap(\.quotaLimit).reduce(0, +))
    }

    private static func color(remainingShare: Double) -> Color {
        remainingShare > 0.5 ? .green : remainingShare > 0.2 ? .orange : .red
    }

    // MARK: Cet appareil

    private var days: [String] {
        snapshot.requestsByDay.keys.sorted(by: >).prefix(7).map { $0 }
    }

    private var deviceSection: some View {
        CardSection("Cet appareil",
                    footer: "Les requêtes de l'app et du widget, et le plus grand nombre envoyé en une minute : à comparer aux 50 par minute d'une clé.") {
            if days.isEmpty {
                Text("Aucune requête enregistrée.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }
            ForEach(Array(days.enumerated()), id: \.element) { index, day in
                if index > 0 {
                    CardDivider(inset: 0)
                }
                dayRow(day)
            }
        }
    }

    private func dayRow(_ day: String) -> some View {
        let failures = snapshot.failuresByDay[day] ?? [:]
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: Self.dayTitle(day))
                    .font(.headline)
                Spacer()
                Text("\(snapshot.requestsByDay[day] ?? 0) requêtes · pic \(snapshot.peakPerMinuteByDay[day] ?? 0)/min")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if failures.isEmpty {
                Text("Aucun échec")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(verbatim: failures.sorted { $0.value > $1.value }.map { "\($0.value) × \($0.key)" }.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 12)
    }

    /// « Aujourd'hui », « Hier », puis « lun. 28 sept. ».
    private static func dayTitle(_ day: String) -> String {
        let now = Date()
        if day == OJPUsage.day(now) { return String(localized: "Aujourd'hui") }
        if day == OJPUsage.day(now.addingTimeInterval(-86_400)) { return String(localized: "Hier") }
        guard let date = try? Date(day, strategy: .iso8601.year().month().day()) else { return day }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    // MARK: Incidents

    private var incidentsSection: some View {
        CardSection("Derniers incidents") {
            if snapshot.incidents.isEmpty {
                Text("Aucun incident.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }
            ForEach(Array(snapshot.incidents.prefix(20).enumerated()), id: \.element) { index, incident in
                if index > 0 {
                    CardDivider(inset: 0)
                }
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: incident.code)
                            .font(.subheadline.weight(.medium))
                        Text(verbatim: [incident.endpoint, incident.key.map { String(localized: "clé \($0)") }]
                            .compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(incident.date.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: Actions

    private func reload() {
        guard !isPreview else { return }
        snapshot = OJPUsage.merged()
    }

    private func check() {
        isChecking = true
        Task {
            await OJPClient.checkAllKeys()
            reload()
            isChecking = false
        }
    }

    /// Le rapport à partager, en texte.
    private var report: String {
        var lines = ["tpg Next — diagnostic de l'API, \(Date().formatted())"]
        for number in 1...max(OJPUsage.keyCount, 1) {
            let state = snapshot.keys[number]
            let quota = state.flatMap { state in state.quotaRemaining.map { "\($0)/\(state.quotaLimit ?? 0)" } } ?? "?"
            let reset = state?.quotaReset?.formatted() ?? "?"
            lines.append("Clé \(number) : \(quota) restantes, repart \(reset)")
        }
        for day in days {
            let failures = (snapshot.failuresByDay[day] ?? [:]).map { "\($0.value)× \($0.key)" }.joined(separator: ", ")
            lines.append("\(day) : \(snapshot.requestsByDay[day] ?? 0) requêtes, pic \(snapshot.peakPerMinuteByDay[day] ?? 0)/min\(failures.isEmpty ? "" : ", " + failures)")
        }
        for incident in snapshot.incidents.prefix(20) {
            lines.append("\(incident.date.formatted()) \(incident.code) \(incident.endpoint) clé \(incident.key.map(String.init) ?? "-")")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Messages d'échec

extension OJPClient.Failure {
    /// Ce que l'utilisateur lit quand une requête échoue.
    var userMessage: LocalizedStringResource {
        switch self {
        case .offline:
            "Pas de connexion à internet."
        case .timeout, .network:
            "Connexion au service des horaires impossible. Vérifiez votre réseau."
        default:
            "Le service des horaires ne répond pas pour le moment. Réessayez dans un instant."
        }
    }
}

// MARK: - Aperçus

extension OJPUsage.Snapshot {
    static var preview: OJPUsage.Snapshot {
        var snapshot = OJPUsage.Snapshot()
        let now = Date()
        func key(_ remaining: Int, resetIn hours: Double, rate: Int, paused: Bool = false) -> OJPUsage.KeyState {
            var state = OJPUsage.KeyState()
            state.quotaLimit = 20_000
            state.quotaRemaining = remaining
            state.quotaReset = now.addingTimeInterval(hours * 3600)
            state.rateLimit = 50
            state.rateRemaining = rate
            state.updated = now.addingTimeInterval(-90)
            if paused {
                state.pausedUntil = now.addingTimeInterval(40)
                state.lastFailure = "limite-minute"
            }
            return state
        }
        snapshot.keys = [1: key(19_489, resetIn: 14.6, rate: 48),
                         2: key(8_210, resetIn: 20, rate: 31),
                         3: key(2_904, resetIn: 9, rate: 0, paused: true)]
        let today = OJPUsage.day(now)
        let yesterday = OJPUsage.day(now.addingTimeInterval(-86_400))
        snapshot.requestsByDay = [today: 214, yesterday: 388]
        snapshot.peakPerMinuteByDay = [today: 17, yesterday: 23]
        snapshot.failuresByDay = [today: ["hors-ligne": 3, "limite-minute": 1], yesterday: ["serveur (503)": 2]]
        snapshot.incidents = [
            .init(date: now.addingTimeInterval(-300), code: "limite-minute", key: 3, endpoint: "ojp20"),
            .init(date: now.addingTimeInterval(-3_600), code: "hors-ligne", key: 1, endpoint: "ojp2020"),
            .init(date: now.addingTimeInterval(-90_000), code: "serveur (503)", key: 2, endpoint: "ojp20"),
        ]
        return snapshot
    }
}

#Preview("Diagnostic de l'API") {
    NavigationStack {
        APIDiagnosticsView(preview: .preview)
    }
    .previewEnvironment(navigation: false)
}
