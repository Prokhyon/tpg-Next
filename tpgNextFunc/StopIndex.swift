//
//  StopIndex.swift
//  tpgNextFunc
//
//  Created by Loris Thomas on 26.08.2026.
//

import Foundation
import CoreLocation

/// Index binaire compact de la base des arrêts, à l'usage de l'extension widget.
///
/// La base complète pèse ~6 Mo de JSON pour ~29 000 arrêts. La décoder dans une
/// extension — limite mémoire de l'ordre de 30 Mo — à chaque rafraîchissement de
/// timeline n'est pas tenable. L'app écrit donc cet index une fois dans le conteneur
/// partagé ; le widget le lit en mémoire virtuelle (`mappedIfSafe`) et ne construit
/// de `Stop` que pour les quelques arrêts qu'il retient.
///
/// Format, little-endian :
///   - en-tête, 32 o : magic, version, nombre d'arrêts, offset du blob
///   - n × 20 o : latitude et longitude (`Float32`), offset dans le blob,
///     longueurs du nom, du sloid et du moyen de transport
///   - blob : les trois chaînes concaténées, UTF-8
///
/// Les enregistrements sont triés par latitude croissante : la recherche du plus
/// proche se fait par dichotomie sur une bande de latitude, sans balayer les 29 000.
///
/// `Float32` donne environ 30 cm de précision à nos latitudes, largement suffisant
/// pour départager des arrêts.
public enum StopIndex {
    static let magic: UInt32 = 0x53_47_50_54 // "TPGS" en little-endian
    static let version: UInt32 = 1
    static let headerSize = 32
    static let recordSize = 20

    public static let fileName = "stopIndex.bin"

    /// L'emplacement de l'index dans le conteneur partagé, `nil` sans groupe d'app.
    public static var fileURL: URL? {
        SharedStorage.containerURL?.appendingPathComponent(fileName)
    }

    private static let signatureKey = "widget.stopIndexSignature"

    // MARK: - Écriture (côté app)

    /// Écrit l'index s'il manque ou si la base a changé. Sans effet sinon.
    /// À appeler depuis une file d'arrière-plan : l'encodage prend quelques dizaines
    /// de millisecondes et touche le disque.
    @discardableResult
    public static func ensureIndex(for stops: [Stop]) -> Bool {
        guard let fileURL, !stops.isEmpty else { return false }

        let signature = "v\(version)-\(stops.count)"
        let isUpToDate = SharedStorage.defaults.string(forKey: signatureKey) == signature
            && FileManager.default.fileExists(atPath: fileURL.path)
        guard !isUpToDate else { return false }

        do {
            try encode(stops).write(to: fileURL, options: .atomic)
            SharedStorage.defaults.set(signature, forKey: signatureKey)
            print("StopIndex written: \(stops.count) stops")
            return true
        } catch {
            print("Failed to write stop index: \(error)")
            return false
        }
    }

    /// L'index sérialisé. Exposé séparément pour pouvoir être testé sans conteneur partagé.
    public static func encode(_ stops: [Stop]) -> Data {
        let sorted = stops.sorted { $0.wgs84Coordinates.lat < $1.wgs84Coordinates.lat }

        var records = Data(capacity: headerSize + sorted.count * recordSize)
        var blob = Data(capacity: sorted.count * 40)

        var header = Data(capacity: headerSize)
        header.appendLittleEndian(magic)
        header.appendLittleEndian(version)
        header.appendLittleEndian(UInt32(sorted.count))
        header.appendLittleEndian(UInt32(headerSize + sorted.count * recordSize))
        header.append(Data(count: headerSize - header.count))

        for stop in sorted {
            let name = Array(stop.name.utf8)
            let sloid = Array(stop.sloid.utf8)
            let transport = Array(stop.meansOfTransport.utf8)

            records.appendLittleEndian(Float32(stop.wgs84Coordinates.lat).bitPattern)
            records.appendLittleEndian(Float32(stop.wgs84Coordinates.lon).bitPattern)
            records.appendLittleEndian(UInt32(blob.count))
            records.appendLittleEndian(UInt16(name.count))
            records.appendLittleEndian(UInt16(sloid.count))
            records.appendLittleEndian(UInt16(transport.count))
            records.appendLittleEndian(UInt16(0)) // padding, garde l'enregistrement sur 20 o

            blob.append(contentsOf: name)
            blob.append(contentsOf: sloid)
            blob.append(contentsOf: transport)
        }

        return header + records + blob
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}

/// Lecteur de l'index, conçu pour être créé et jeté à chaque rafraîchissement de widget.
public final class StopIndexReader {
    private let data: Data
    private let count: Int
    private let blobOffset: Int

    /// `nil` si le fichier est absent, tronqué ou d'une version inconnue — dans ce cas
    /// l'appelant doit se rabattre sur l'arrêt configuré plutôt que sur la proximité.
    public init?(url: URL? = StopIndex.fileURL) {
        guard let url, let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count >= StopIndex.headerSize else { return nil }

        let header: (magic: UInt32, version: UInt32, count: UInt32, blob: UInt32) = data.withUnsafeBytes { raw in
            (raw.loadUnaligned(fromByteOffset: 0, as: UInt32.self).littleEndian,
             raw.loadUnaligned(fromByteOffset: 4, as: UInt32.self).littleEndian,
             raw.loadUnaligned(fromByteOffset: 8, as: UInt32.self).littleEndian,
             raw.loadUnaligned(fromByteOffset: 12, as: UInt32.self).littleEndian)
        }

        guard header.magic == StopIndex.magic, header.version == StopIndex.version else { return nil }
        let expectedBlobOffset = StopIndex.headerSize + Int(header.count) * StopIndex.recordSize
        guard Int(header.blob) == expectedBlobOffset, data.count >= expectedBlobOffset else { return nil }

        self.data = data
        self.count = Int(header.count)
        self.blobOffset = expectedBlobOffset
    }

    public var stopCount: Int { count }

    // MARK: - Recherche par proximité

    /// Les `limit` arrêts les plus proches, du plus proche au plus lointain,
    /// avec leur distance en mètres.
    public func nearest(to coordinate: CLLocationCoordinate2D,
                        limit: Int,
                        maxDistance: CLLocationDistance = 1000) -> [(stop: Stop, distance: CLLocationDistance)] {
        guard count > 0, limit > 0 else { return [] }

        let metersPerDegreeLatitude = 111_132.0
        let metersPerDegreeLongitude = 111_320.0 * cos(coordinate.latitude * .pi / 180)
        let latitudeSpan = Float(maxDistance / metersPerDegreeLatitude)
        let minLatitude = Float(coordinate.latitude) - latitudeSpan
        let maxLatitude = Float(coordinate.latitude) + latitudeSpan

        return data.withUnsafeBytes { raw -> [(stop: Stop, distance: CLLocationDistance)] in
            func latitude(at index: Int) -> Float {
                Float(bitPattern: raw.loadUnaligned(fromByteOffset: StopIndex.headerSize + index * StopIndex.recordSize,
                                                    as: UInt32.self).littleEndian)
            }
            func longitude(at index: Int) -> Float {
                Float(bitPattern: raw.loadUnaligned(fromByteOffset: StopIndex.headerSize + index * StopIndex.recordSize + 4,
                                                    as: UInt32.self).littleEndian)
            }

            // Borne inférieure de la bande de latitude : les enregistrements sont triés.
            var low = 0
            var high = count
            while low < high {
                let middle = (low + high) / 2
                if latitude(at: middle) < minLatitude { low = middle + 1 } else { high = middle }
            }

            var best: [(index: Int, distance: CLLocationDistance)] = []
            var index = low
            while index < count, latitude(at: index) <= maxLatitude {
                let deltaY = (Double(latitude(at: index)) - coordinate.latitude) * metersPerDegreeLatitude
                let deltaX = (Double(longitude(at: index)) - coordinate.longitude) * metersPerDegreeLongitude
                let distance = (deltaX * deltaX + deltaY * deltaY).squareRoot()

                if distance <= maxDistance, best.count < limit || distance < best[best.count - 1].distance {
                    let position = best.firstIndex { distance < $0.distance } ?? best.count
                    best.insert((index, distance), at: position)
                    if best.count > limit { best.removeLast() }
                }
                index += 1
            }

            return best.map { (stop(at: $0.index, raw: raw), $0.distance) }
        }
    }

    // MARK: - Recherche par identifiant et par nom

    public func stop(sloid: String) -> Stop? {
        let target = Array(sloidHarmonizer(code: sloid).utf8)
        guard !target.isEmpty else { return nil }

        return data.withUnsafeBytes { raw -> Stop? in
            for index in 0..<count {
                let record = StopIndex.headerSize + index * StopIndex.recordSize
                let sloidLength = Int(raw.loadUnaligned(fromByteOffset: record + 14, as: UInt16.self).littleEndian)
                guard sloidLength == target.count else { continue }

                let nameLength = Int(raw.loadUnaligned(fromByteOffset: record + 12, as: UInt16.self).littleEndian)
                let stringOffset = Int(raw.loadUnaligned(fromByteOffset: record + 8, as: UInt32.self).littleEndian)
                let start = blobOffset + stringOffset + nameLength

                var matches = true
                for offset in 0..<sloidLength where raw[start + offset] != target[offset] {
                    matches = false
                    break
                }
                if matches { return stop(at: index, raw: raw) }
            }
            return nil
        }
    }

    /// Recherche par nom, insensible aux accents et aux tirets, comme celle de l'app.
    public func search(_ query: String, limit: Int = 20) -> [Stop] {
        let needle = query.normalized().lowercased()
        guard !needle.isEmpty else { return [] }

        return data.withUnsafeBytes { raw -> [Stop] in
            var results: [Stop] = []
            for index in 0..<count {
                let record = StopIndex.headerSize + index * StopIndex.recordSize
                let nameLength = Int(raw.loadUnaligned(fromByteOffset: record + 12, as: UInt16.self).littleEndian)
                guard nameLength >= needle.utf8.count else { continue }

                let stringOffset = Int(raw.loadUnaligned(fromByteOffset: record + 8, as: UInt32.self).littleEndian)
                let name = string(raw: raw, offset: blobOffset + stringOffset, length: nameLength)
                guard name.normalized().lowercased().contains(needle) else { continue }

                results.append(stop(at: index, raw: raw))
                if results.count >= limit { break }
            }
            return results.sorted { $0.name < $1.name }
        }
    }

    // MARK: - Décodage

    private func stop(at index: Int, raw: UnsafeRawBufferPointer) -> Stop {
        let record = StopIndex.headerSize + index * StopIndex.recordSize
        let latitude = Float(bitPattern: raw.loadUnaligned(fromByteOffset: record, as: UInt32.self).littleEndian)
        let longitude = Float(bitPattern: raw.loadUnaligned(fromByteOffset: record + 4, as: UInt32.self).littleEndian)
        let stringOffset = Int(raw.loadUnaligned(fromByteOffset: record + 8, as: UInt32.self).littleEndian)
        let nameLength = Int(raw.loadUnaligned(fromByteOffset: record + 12, as: UInt16.self).littleEndian)
        let sloidLength = Int(raw.loadUnaligned(fromByteOffset: record + 14, as: UInt16.self).littleEndian)
        let transportLength = Int(raw.loadUnaligned(fromByteOffset: record + 16, as: UInt16.self).littleEndian)

        let start = blobOffset + stringOffset
        return Stop(
            name: string(raw: raw, offset: start, length: nameLength),
            sloid: string(raw: raw, offset: start + nameLength, length: sloidLength),
            codedidoc: "",
            country: "",
            canton: "",
            meansOfTransport: string(raw: raw, offset: start + nameLength + sloidLength, length: transportLength),
            wgs84Coordinates: Coordinates(lon: Double(longitude), lat: Double(latitude))
        )
    }

    private func string(raw: UnsafeRawBufferPointer, offset: Int, length: Int) -> String {
        guard length > 0, offset + length <= raw.count else { return "" }
        return String(decoding: UnsafeRawBufferPointer(rebasing: raw[offset..<(offset + length)]), as: UTF8.self)
    }
}
