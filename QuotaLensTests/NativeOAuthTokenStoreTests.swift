import Security
import XCTest
@testable import QuotaLens

@MainActor
final class NativeOAuthTokenStoreTests: XCTestCase {
    func testFallsBackToProtectedLocalFileWhenKeychainIsUnavailable() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuotaLensTokenStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let store = NativeOAuthTokenStore(
            service: "com.kogeki.QuotaLens.tests.\(UUID().uuidString)",
            keychain: UnavailableKeychain(),
            fallbackDirectoryURL: directory
        )
        let bundle = NativeOAuthTokenBundle(
            id: "codex-test-token",
            provider: .codex,
            accessToken: "access-token",
            refreshToken: "refresh-token",
            idToken: "id-token",
            tokenType: "Bearer",
            accountLabel: "coder@example.com",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        try store.save(bundle)
        let loaded = try store.load(provider: .codex)

        XCTAssertEqual(loaded, [bundle])
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("codex.json").path))
    }

    func testStoreErrorExposesReadableKeychainStatus() {
        let message = NativeOAuthTokenStore.StoreError.keychain(errSecMissingEntitlement).localizedDescription

        XCTAssertTrue(message.contains("OSStatus"))
        XCTAssertTrue(message.contains("\(errSecMissingEntitlement)"))
        XCTAssertFalse(message.contains("StoreError"))
    }
}

private final class UnavailableKeychain: KeychainStoring {
    func copyMatching(_ query: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        errSecMissingEntitlement
    }

    func update(_ query: CFDictionary, attributes: CFDictionary) -> OSStatus {
        errSecMissingEntitlement
    }

    func add(_ attributes: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        errSecMissingEntitlement
    }
}
