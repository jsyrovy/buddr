import Testing

@testable import Buddr

struct HerdrSnapshotTests {
    @Test func localSessionsAreNamedAfterTheSession() {
        #expect(HerdrSource.localSession("default").displayName == "local/default")
        #expect(HerdrSource.localSession("work").displayName == "local/work")
    }

    @Test func statusAggregatesTheAgents() {
        #expect(HerdrSnapshot.empty.status == .unknown)
        #expect(HerdrSnapshot(agents: [.stub(.idle), .stub(.done)], failures: []).status == .done)
    }
}
