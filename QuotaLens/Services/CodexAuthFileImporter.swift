import Foundation

struct CodexAuthFileImporter {
    enum ImportError: LocalizedError {
        case invalidJSON
        case missingAccessToken
        case disabled
        case expired

        var errorDescription: String? {
            switch self {
            case .invalidJSON:
                return "认证文件不是有效的 JSON"
            case .missingAccessToken:
                return "认证文件缺少 access_token"
            case .disabled:
                return "这个 Codex 认证文件已被禁用"
            case .expired:
                return "这个 Codex 认证文件已过期，请重新导出或登录"
            }
        }
    }

    func tokenBundle(from data: Data, importedAt: Date = Date()) throws -> NativeOAuthTokenBundle {
        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ImportError.invalidJSON
        }

        guard let object = jsonObject as? [String: Any] else {
            throw ImportError.invalidJSON
        }

        if boolValue(for: "disabled", in: object) == true {
            throw ImportError.disabled
        }

        if boolValue(for: "expired", in: object) == true {
            throw ImportError.expired
        }

        guard let accessToken = stringValue(for: "access_token", in: object) else {
            throw ImportError.missingAccessToken
        }

        let accountID = stringValue(for: "account_id", in: object)
        let accountLabel = stringValue(for: "email", in: object) ?? accountID ?? "Codex"

        return NativeOAuthTokenBundle(
            provider: .codex,
            accessToken: accessToken,
            refreshToken: stringValue(for: "refresh_token", in: object),
            idToken: stringValue(for: "id_token", in: object),
            tokenType: stringValue(for: "type", in: object),
            accountID: accountID,
            accountLabel: accountLabel,
            createdAt: dateValue(for: "last_refresh", in: object) ?? importedAt
        )
    }

    private func stringValue(for key: String, in object: [String: Any]) -> String? {
        guard let value = object[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func boolValue(for key: String, in object: [String: Any]) -> Bool? {
        if let value = object[key] as? Bool {
            return value
        }
        if let value = object[key] as? String {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }

    private func dateValue(for key: String, in object: [String: Any]) -> Date? {
        let value = object[key]
        if let string = value as? String {
            if let date = ISO8601DateFormatter().date(from: string) {
                return date
            }
            if let timestamp = TimeInterval(string) {
                return date(fromTimestamp: timestamp)
            }
        }
        if let number = value as? NSNumber {
            return date(fromTimestamp: number.doubleValue)
        }
        return nil
    }

    private func date(fromTimestamp timestamp: TimeInterval) -> Date {
        let normalized = timestamp > 10_000_000_000 ? timestamp / 1_000 : timestamp
        return Date(timeIntervalSince1970: normalized)
    }
}
