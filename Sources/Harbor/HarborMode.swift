import Foundation

enum HarborMode: Equatable {
    case loggedOut
    case stopped
    case running
}

enum HarborPaths {
    static let tokenFile: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/copilot-api/github_token")
    }()

    static let usagePage = URL(
        string: "https://ericc-ch.github.io/copilot-api?endpoint=http://localhost:4141/usage"
    )!

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
            .appendingPathComponent("Vendor")
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

    static var hasToken: Bool {
        guard let text = try? String(contentsOf: tokenFile, encoding: .utf8) else {
            return false
        }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
