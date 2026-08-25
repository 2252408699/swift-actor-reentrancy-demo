import Foundation

struct Token: Sendable {
    let value: String
    let expiresAt: Date
    var isExpired: Bool { expiresAt <= Date() }
}

actor FakeTokenAPI {
    private var requestCount = 0

    func refreshToken() async throws -> Token {
        requestCount += 1
        let id = requestCount
        print("  API request #\(id) started")
        try await Task.sleep(for: .milliseconds(250))
        print("  API request #\(id) finished")
        return Token(value: "token-\(id)", expiresAt: Date().addingTimeInterval(60))
    }

    func count() -> Int { requestCount }
}

actor BrokenTokenStore {
    private var token: Token?
    private let api: FakeTokenAPI
    init(api: FakeTokenAPI) { self.api = api }

    func validToken() async throws -> Token {
        if let token, !token.isExpired { return token }
        let refreshed = try await api.refreshToken()
        token = refreshed
        return refreshed
    }
}

actor FixedTokenStore {
    private var token: Token?
    private var refreshTask: Task<Token, Error>?
    private let api: FakeTokenAPI
    init(api: FakeTokenAPI) { self.api = api }

    func validToken() async throws -> Token {
        if let token, !token.isExpired { return token }
        if let refreshTask { return try await refreshTask.value }

        let api = self.api
        let task = Task { try await api.refreshToken() }
        refreshTask = task
        defer { refreshTask = nil }

        let refreshed = try await task.value
        token = refreshed
        return refreshed
    }
}

func runTwoRequests<Store: Sendable>(
    _ store: Store,
    operation: @escaping @Sendable (Store) async throws -> Token
) async throws {
    async let first = operation(store)
    async let second = operation(store)
    let values = try await [first, second]
    print("  returned values: \(values.map(\.value))")
}

@main
struct Demo {
    static func main() async throws {
        print("\n1. Broken implementation")
        let brokenAPI = FakeTokenAPI()
        let broken = BrokenTokenStore(api: brokenAPI)
        try await runTwoRequests(broken) { try await $0.validToken() }
        print("  total API calls: \(await brokenAPI.count()) (expected: 2)\n")

        print("2. Fixed implementation with a shared in-flight Task")
        let fixedAPI = FakeTokenAPI()
        let fixed = FixedTokenStore(api: fixedAPI)
        try await runTwoRequests(fixed) { try await $0.validToken() }
        print("  total API calls: \(await fixedAPI.count()) (expected: 1)")
    }
}
