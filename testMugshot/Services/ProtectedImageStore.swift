import Foundation
import UIKit

/// Decoded pixels are memory-only. A cached image is returned only while the
/// current account has a valid authorization, or after successful renewal.
actor ProtectedImageStore {
    static let shared = ProtectedImageStore()
    struct Receipt { let image: UIImage; let expiresAt: Date }
    private let images = NSCache<NSString, UIImage>()
    private var authorizations: [String: Date] = [:]
    private var flights: [String: Task<Receipt, Error>] = [:]
    private var generation = 0
    private var currentAccount: String?

    private let resolve: (String) async throws -> URL
    private let download: (URL) async throws -> UIImage
    init(resolve: @escaping (String) async throws -> URL = { try await VisitPhotoAccessService.shared.resolvedURL(for: $0) },
         download: @escaping (URL) async throws -> UIImage = { try await RemoteImagePipeline.shared.image(for: $0) }) {
        self.resolve = resolve; self.download = download
        images.totalCostLimit = 64 * 1_024 * 1_024; images.countLimit = 80 }

    func switchAccount(_ account: String) {
        if currentAccount != account { clear(); currentAccount = account }
    }

    func clear() {
        generation += 1
        flights.values.forEach { $0.cancel() }
        flights.removeAll(); authorizations.removeAll(); images.removeAllObjects()
    }

    func load(_ storedValue: String, account: String, renew: Bool = false) async throws -> Receipt {
        switchAccount(account)
        let key = account + "|" + storedValue
        if !renew, let expiry = authorizations[key], expiry > Date(),
           let image = images.object(forKey: key as NSString) {
            return Receipt(image: image, expiresAt: expiry)
        }
        if let flight = flights[key] { return try await flight.value }
        let cached = images.object(forKey: key as NSString)
        let expectedGeneration = generation
        let flight = Task<Receipt, Error> {
            let start = Date()
            let url = try await resolve(storedValue)
            try Task.checkCancellation()
            let image: UIImage
            if let cached { image = cached }
            else { image = try await download(url) }
            try Task.checkCancellation()
            return Receipt(image: image, expiresAt: start.addingTimeInterval(55))
        }
        flights[key] = flight
        do {
            let receipt = try await flight.value
            guard expectedGeneration == generation else { throw CancellationError() }
            flights[key] = nil
            guard receipt.expiresAt > Date() else { throw URLError(.timedOut) }
            authorizations[key] = receipt.expiresAt
            // Keep authorization bookkeeping bounded alongside the pixel cache.
            if authorizations.count > 160 {
                for oldKey in authorizations.sorted(by: { $0.value < $1.value }).prefix(authorizations.count - 160).map(\.key) {
                    authorizations[oldKey] = nil
                    images.removeObject(forKey: oldKey as NSString)
                }
            }
            images.setObject(receipt.image, forKey: key as NSString,
                cost: receipt.image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0)
            return receipt
        } catch {
            if expectedGeneration == generation {
                flights[key] = nil; authorizations[key] = nil
                images.removeObject(forKey: key as NSString)
            }
            throw error
        }
    }
}
