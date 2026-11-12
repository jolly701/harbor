import Darwin
import Foundation

enum HarborMode: Equatable {
    case loggedOut
    case stopped
    case running
}

enum HarborPort {
    static let preferred = 4141
    private static let searchLimit = 20

    static func availablePort() -> Int? {
        for offset in 0..<searchLimit {
            let port = preferred + offset
            if isAvailable(port) {
                return port
            }
        }
        return nil
    }

    static func serviceBaseURL(port: Int) -> String {
        "http://127.0.0.1:\(port)"
    }

    static func openAIBaseURL(port: Int) -> String {
        "http://127.0.0.1:\(port)/v1"
    }

    static func usageEndpoint(port: Int) -> URL? {
        URL(string: "\(serviceBaseURL(port: port))/usage")
    }

    static func listenerPIDs(port: Int) -> [pid_t] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-t", "-iTCP:\(port)", "-sTCP:LISTEN"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isWhitespace).compactMap { pid_t($0) }
    }

    private static func isAvailable(_ port: Int) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(UInt16(port)).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }
}

enum HarborPaths {
    static let tokenFile: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/copilot-api/github_token")
    }()

    static var vendorRoot: URL {
        if let resources = Bundle.main.resourceURL {
            let bun = resources.appendingPathComponent("bun/bun")
            if FileManager.default.isExecutableFile(atPath: bun.path) {
                return resources
            }
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".build/harbor-runtime")
    }

    static var bunExecutable: URL {
        vendorRoot.appendingPathComponent("bun/bun")
    }

    static var serverEntrypoint: URL {
        vendorRoot.appendingPathComponent("copilot-api/dist/main.js")
    }

    static var serverRoot: URL {
        vendorRoot.appendingPathComponent("copilot-api")
    }

    static func readToken() -> String? {
        guard let text = try? String(contentsOf: tokenFile, encoding: .utf8) else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static var hasToken: Bool {
        readToken() != nil
    }
}

struct GitHubAccount: Equatable {
    var login: String
    var name: String?
    var avatarURL: URL?

    var primary: String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? login : trimmed
    }

    var secondary: String? {
        primary == login ? nil : "@\(login)"
    }

    var menuTitle: String {
        if let secondary {
            return "\(primary) (\(secondary))"
        }
        return "@\(login)"
    }

    static func load(token: String) async -> GitHubAccount? {
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Harbor", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            return nil
        }
        let avatar = payload.avatarURL.flatMap(URL.init(string:))
        let safeAvatar = avatar?.host == "avatars.githubusercontent.com" ? avatar : nil
        return GitHubAccount(login: payload.login, name: payload.name, avatarURL: safeAvatar)
    }

    private struct Payload: Decodable {
        var login: String
        var name: String?
        var avatarURL: String?

        enum CodingKeys: String, CodingKey {
            case login
            case name
            case avatarURL = "avatar_url"
        }
    }
}
