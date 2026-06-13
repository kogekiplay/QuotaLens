import Foundation
import Security

protocol KeychainStoring {
    func copyMatching(_ query: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    func update(_ query: CFDictionary, attributes: CFDictionary) -> OSStatus
    func add(_ attributes: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
}

struct SystemKeychain: KeychainStoring {
    func copyMatching(_ query: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        SecItemCopyMatching(query, result)
    }

    func update(_ query: CFDictionary, attributes: CFDictionary) -> OSStatus {
        SecItemUpdate(query, attributes)
    }

    func add(_ attributes: CFDictionary, result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        SecItemAdd(attributes, result)
    }
}

final class NativeOAuthTokenStore: NativeOAuthTokenStoring {
    enum StoreError: LocalizedError {
        case encodingFailed(Error)
        case decodingFailed(Error)
        case keychain(OSStatus)
        case fileStorage(Error)

        var errorDescription: String? {
            switch self {
            case .encodingFailed(let error):
                return "本地 OAuth 凭证编码失败：\(error.localizedDescription)"
            case .decodingFailed(let error):
                return "本地 OAuth 凭证读取失败：\(error.localizedDescription)"
            case .keychain(let status):
                return "无法访问本地钥匙串凭证（OSStatus \(status)）"
            case .fileStorage(let error):
                return "本地 OAuth 凭证文件保存失败：\(error.localizedDescription)"
            }
        }
    }

    private let service: String
    private let keychain: KeychainStoring
    private let fileManager: FileManager
    private let fallbackDirectoryURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        service: String = "com.kogeki.QuotaLens.native-oauth",
        keychain: KeychainStoring = SystemKeychain(),
        fileManager: FileManager = .default,
        fallbackDirectoryURL: URL? = nil
    ) {
        self.service = service
        self.keychain = keychain
        self.fileManager = fileManager
        self.fallbackDirectoryURL = fallbackDirectoryURL ?? Self.defaultFallbackDirectoryURL(fileManager: fileManager)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func save(_ bundle: NativeOAuthTokenBundle) throws {
        var bundles = try load(provider: bundle.provider)
        bundles.removeAll { $0.id == bundle.id || $0.accountLabel == bundle.accountLabel }
        bundles.append(bundle)
        try save(bundles, provider: bundle.provider)
    }

    func loadAll() throws -> [NativeOAuthTokenBundle] {
        try NativeOAuthProvider.browserProviders.flatMap { try load(provider: $0) }
    }

    func load(provider: NativeOAuthProvider) throws -> [NativeOAuthTokenBundle] {
        do {
            return try loadFromKeychain(provider: provider)
        } catch StoreError.keychain(let status) where Self.shouldUseFileFallback(for: status) {
            return try loadFromFile(provider: provider)
        } catch StoreError.keychain(let status) where status == errSecItemNotFound {
            return try loadFromFile(provider: provider)
        }
    }

    private func loadFromKeychain(provider: NativeOAuthProvider) throws -> [NativeOAuthTokenBundle] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = keychain.copyMatching(query as CFDictionary, result: &result)
        guard status == errSecSuccess else {
            throw StoreError.keychain(status)
        }
        guard let data = result as? Data else {
            throw StoreError.decodingFailed(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Keychain item did not contain Data.")))
        }
        do {
            return try decoder.decode([NativeOAuthTokenBundle].self, from: data)
        } catch {
            throw StoreError.decodingFailed(error)
        }
    }

    private func save(_ bundles: [NativeOAuthTokenBundle], provider: NativeOAuthProvider) throws {
        let data: Data
        do {
            data = try encoder.encode(bundles)
        } catch {
            throw StoreError.encodingFailed(error)
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = keychain.update(query as CFDictionary, attributes: attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if Self.shouldUseFileFallback(for: updateStatus) {
            try saveToFile(data, provider: provider)
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw StoreError.keychain(updateStatus)
        }

        var addQuery = query
        addQuery.merge(attributes) { _, new in new }
        let addStatus = keychain.add(addQuery as CFDictionary, result: nil)
        if addStatus == errSecSuccess {
            return
        }
        if Self.shouldUseFileFallback(for: addStatus) {
            try saveToFile(data, provider: provider)
            return
        }
        throw StoreError.keychain(addStatus)
    }

    private func loadFromFile(provider: NativeOAuthProvider) throws -> [NativeOAuthTokenBundle] {
        let url = fileURL(for: provider)
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([NativeOAuthTokenBundle].self, from: data)
        } catch {
            throw StoreError.decodingFailed(error)
        }
    }

    private func saveToFile(_ data: Data, provider: NativeOAuthProvider) throws {
        let directory = fallbackDirectoryURL
        let url = fileURL(for: provider)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try fileManager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: directory.path)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            throw StoreError.fileStorage(error)
        }
    }

    private func fileURL(for provider: NativeOAuthProvider) -> URL {
        fallbackDirectoryURL.appendingPathComponent("\(provider.rawValue).json", isDirectory: false)
    }

    private static func shouldUseFileFallback(for status: OSStatus) -> Bool {
        status == errSecMissingEntitlement || status == errSecNotAvailable
    }

    private static func defaultFallbackDirectoryURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL
            .appendingPathComponent("QuotaLens", isDirectory: true)
            .appendingPathComponent("NativeOAuthTokens", isDirectory: true)
    }
}
