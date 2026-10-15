//
//  CloudSyncTests.swift
//  tpgNextFuncTests
//

import Foundation
import Testing
@testable import tpgNextFunc

@Suite("Synchro iCloud")
struct CloudSyncTests {
    private struct Item: Codable, Equatable {
        var id: String
        var note = ""
    }

    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func at(_ minutes: Double) -> Date { start.addingTimeInterval(minutes * 60) }

    private func snapshot(_ items: [Item], at date: Date) -> CloudSnapshot<Item> {
        var snapshot = CloudSnapshot<Item>()
        snapshot.record(items, now: date, id: \.id, isSame: ==)
        return snapshot
    }

    private func ids(_ snapshot: CloudSnapshot<Item>) -> [String] {
        snapshot.items.map(\.id)
    }

    @Test func additionsOnBothSidesAreKept() {
        var phone = snapshot([Item(id: "a")], at: at(0))
        var pad = phone
        phone.record([Item(id: "a"), Item(id: "b")], now: at(1), id: \.id, isSame: ==)
        pad.record([Item(id: "a"), Item(id: "c")], now: at(2), id: \.id, isSame: ==)

        let merged = phone.merged(with: pad, now: at(3))
        #expect(Set(ids(merged)) == ["a", "b", "c"])
        // Même résultat dans les deux sens.
        #expect(Set(ids(pad.merged(with: phone, now: at(3)))) == ["a", "b", "c"])
    }

    @Test func removalSurvivesAnOlderCopy() {
        var phone = snapshot([Item(id: "a"), Item(id: "b")], at: at(0))
        let pad = phone
        phone.record([Item(id: "a")], now: at(5), id: \.id, isSame: ==)

        #expect(ids(pad.merged(with: phone, now: at(6))) == ["a"])
        #expect(ids(phone.merged(with: pad, now: at(6))) == ["a"])
    }

    @Test func editAfterRemovalBringsItBack() {
        var phone = snapshot([Item(id: "a")], at: at(0))
        var pad = phone
        phone.record([], now: at(1), id: \.id, isSame: ==)
        pad.record([Item(id: "a", note: "modifié")], now: at(2), id: \.id, isSame: ==)

        let merged = phone.merged(with: pad, now: at(3))
        #expect(merged.items == [Item(id: "a", note: "modifié")])
        #expect(merged.removed["a"] == nil)
    }

    @Test func latestEditWins() {
        var phone = snapshot([Item(id: "a")], at: at(0))
        var pad = phone
        pad.record([Item(id: "a", note: "iPad")], now: at(1), id: \.id, isSame: ==)
        phone.record([Item(id: "a", note: "iPhone")], now: at(2), id: \.id, isSame: ==)

        #expect(pad.merged(with: phone, now: at(3)).items == [Item(id: "a", note: "iPhone")])
    }

    @Test func unchangedItemsKeepTheirDate() {
        var phone = snapshot([Item(id: "a"), Item(id: "b")], at: at(0))
        let changed = phone.record([Item(id: "a"), Item(id: "b")], now: at(5), id: \.id, isSame: ==)
        #expect(!changed)
        #expect(phone.entries["a"]?.modified == at(0))
    }

    @Test func latestOrderWins() {
        var phone = snapshot([Item(id: "a"), Item(id: "b")], at: at(0))
        let pad = phone
        phone.record([Item(id: "b"), Item(id: "a")], now: at(1), id: \.id, isSame: ==)
        #expect(ids(pad.merged(with: phone, now: at(2))) == ["b", "a"])
    }

    @Test func itemsUnknownToTheOrderFollow() {
        var phone = snapshot([Item(id: "a"), Item(id: "b")], at: at(0))
        var pad = phone
        pad.record([Item(id: "a"), Item(id: "b"), Item(id: "c")], now: at(1), id: \.id, isSame: ==)
        // L'iPhone réordonne plus tard, sans connaître « c » : son ordre compte, « c » suit.
        phone.record([Item(id: "b"), Item(id: "a")], now: at(2), id: \.id, isSame: ==)
        #expect(ids(phone.merged(with: pad, now: at(3))) == ["b", "a", "c"])
        #expect(ids(pad.merged(with: phone, now: at(3))) == ["b", "a", "c"])
    }

    @Test func firstSyncJoinsWithoutOverwriting() {
        var cloud = snapshot([Item(id: "a"), Item(id: "b")], at: at(0))
        cloud.record([Item(id: "a")], now: at(1), id: \.id, isSame: ==)
        // Un nouvel appareil arrive avec « b », supprimé ailleurs, et « c », qu'il est seul à avoir.
        let newcomer = snapshot([Item(id: "b"), Item(id: "c")], at: .distantPast)

        #expect(ids(newcomer.merged(with: cloud, now: at(2))) == ["a", "c"])
    }

    @Test func oldRemovalsAreForgotten() {
        var phone = snapshot([Item(id: "a")], at: at(0))
        phone.record([], now: at(1), id: \.id, isSame: ==)
        let later = at(1).addingTimeInterval(CloudSnapshot<Item>.removalMemory + 60)
        #expect(phone.merged(with: CloudSnapshot(), now: later).removed.isEmpty)
    }

    @Test func customSamenessIgnoresSnapshots() {
        var phone = snapshot([Item(id: "a", note: "Rive")], at: at(0))
        let changed = phone.record([Item(id: "a", note: "Genève, Rive")], now: at(1),
                                   id: \.id, isSame: { $0.id == $1.id })
        #expect(!changed)
        #expect(phone.items == [Item(id: "a", note: "Genève, Rive")])
    }

    @Test func roundTripsThroughJSON() throws {
        let original = snapshot([Item(id: "a", note: "x")], at: at(0))
        let decoded = try JSONDecoder().decode(CloudSnapshot<Item>.self, from: JSONEncoder().encode(original))
        #expect(decoded.items == original.items)
        #expect(decoded.entries["a"]?.modified == at(0))
    }
}
