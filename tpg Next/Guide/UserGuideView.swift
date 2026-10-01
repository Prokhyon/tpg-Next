//
//  UserGuideView.swift
//  tpg Next
//
//  Le guide d'utilisation : les rubriques, puis une page par rubrique. Le texte est dans
//  UserGuideContent.swift.
//

import SwiftUI
import tpgNextFunc

/// Les rubriques du guide, par groupe, en cartes comme le reste de l'app, et une recherche
/// dans tous les points.
struct UserGuideView: View {
    @State private var query = ""
    @State private var showsTour = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if query.isEmpty {
                    Text("Tout ce que l'app sait faire, page par page. Les encadrés à la main se touchent : essayez-les !")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                    CardSection {
                        Button {
                            showsTour = true
                        } label: {
                            SettingsRow("Visite guidée", subtitle: "Sept gestes à essayer du doigt, en deux minutes.",
                                        systemImage: "hand.tap.fill", color: .orange, showsChevron: true)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(UserGuide.groups) { group in
                        CardSection(group.title) {
                            ForEach(Array(group.topics.enumerated()), id: \.element.id) { index, topic in
                                if index > 0 {
                                    CardDivider(inset: 48)
                                }
                                NavigationLink(value: AppRoute.userGuideTopic(id: topic.id)) {
                                    GuideTopicRow(topic: topic)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    searchResults
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .readableScrollContent()
        .navigationTitle("Guide d'utilisation")
        .searchable(text: $query, prompt: "Rechercher dans le guide")
        .sheet(isPresented: $showsTour) {
            GuideTourView { showsTour = false }
                .presentationCornerRadius(35)
        }
    }

    @ViewBuilder private var searchResults: some View {
        let results = UserGuide.search(query)
        if results.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            ForEach(results, id: \.topic.id) { result in
                CardSection(result.topic.title) {
                    ForEach(Array(result.entries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            CardDivider(inset: 0)
                        }
                        NavigationLink(value: AppRoute.userGuideTopic(id: result.topic.id, entry: entry.id)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.title).font(.headline)
                                    Text(entry.text)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .multilineTextAlignment(.leading)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.bold())
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct GuideTopicRow: View {
    let topic: GuideTopic

    var body: some View {
        HStack(spacing: 14) {
            GuideTopicIcon(topic: topic, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(topic.title)
                Text(topic.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.footnote.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// Le symbole d'une rubrique, blanc sur sa couleur, comme dans les Réglages d'iOS.
private struct GuideTopicIcon: View {
    let topic: GuideTopic
    var size: CGFloat

    var body: some View {
        Image(systemName: topic.systemImage)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(topic.color.gradient, in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Une rubrique : ses points l'un sous l'autre. `entry` (depuis la recherche) fait défiler
/// jusqu'au point et le met en avant un instant.
struct UserGuideTopicView: View {
    let topic: GuideTopic
    var entry: String?
    @State private var highlighted: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        GuideTopicIcon(topic: topic, size: 48)
                        Text(topic.summary)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // Chaque point dans sa carte ; celui cherché prend un instant la bordure orange.
                    ForEach(topic.entries) { item in
                        GuideEntryRow(entry: item, tint: topic.color)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(BasicCard(cornerRadius: 26, highlighted: highlighted == item.id))
                            .id(item.id)
                    }
                }
                .padding()
                .padding(.bottom, 30)
            }
            .readableScrollContent()
            .task {
                guard let entry else { return }
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation { proxy.scrollTo(entry, anchor: .center) }
                highlighted = entry
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation(.easeOut(duration: 0.8)) { highlighted = nil }
            }
        }
        .navigationTitle(Text(topic.title))
    }
}

private struct GuideEntryRow: View {
    let entry: GuideEntry
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: entry.systemImage)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title)
                        .font(.headline)
                    Text(entry.text)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                if let link = entry.link {
                    NavigationLink(value: link.route) {
                        Label {
                            Text(link.title)
                        } icon: {
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .prominentButtonStyle()
                    .tint(tint)
                    .padding(.top, 4)
                }
                if let demo = entry.demo {
                    GuideDemoView(demo: demo)
                        .padding(.top, 8)
                }
            }
        }
    }
}

extension UserGuide {
    struct SearchResult {
        let topic: GuideTopic
        let entries: [GuideEntry]
    }

    /// Les points dont le titre ou le texte contient la recherche, sans tenir compte des
    /// majuscules ni des accents ; toute la rubrique quand son titre correspond.
    static func search(_ query: String) -> [SearchResult] {
        let words = query.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        func matches(_ text: String) -> Bool {
            words.allSatisfy { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
        return groups.flatMap(\.topics).compactMap { topic in
            if matches(String(localized: topic.title)) {
                return SearchResult(topic: topic, entries: topic.entries)
            }
            let entries = topic.entries.filter {
                matches(String(localized: $0.title) + " " + String(localized: $0.text))
            }
            return entries.isEmpty ? nil : SearchResult(topic: topic, entries: entries)
        }
    }
}

#Preview("Guide") {
    UserGuideView()
        .previewEnvironment()
}

#Preview("Guide — une rubrique") {
    UserGuideTopicView(topic: UserGuide.stop)
        .previewEnvironment()
}
