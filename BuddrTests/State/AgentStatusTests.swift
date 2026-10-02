import Foundation
import Testing

@testable import Buddr

struct AgentStatusTests {
    @Test func noAgentsAggregateToUnknown() {
        #expect(AgentStatus.aggregate([]) == .unknown)
    }

    @Test(arguments: [
        ([AgentStatus.idle, .working, .blocked, .done, .unknown], AgentStatus.blocked),
        ([.idle, .working, .done, .unknown], .done),
        ([.idle, .working, .unknown, .idle], .working),
        ([.unknown, .idle], .idle),
        ([.unknown, .unknown], .unknown),
        ([.done], .done),
    ])
    func aggregateTakesTheMostUrgentStatus(statuses: [AgentStatus], expected: AgentStatus) {
        #expect(AgentStatus.aggregate(statuses) == expected)
        #expect(AgentStatus.aggregate(statuses.reversed()) == expected)
    }

    @Test func priorityOrderIsBlockedDoneWorkingIdleUnknown() {
        let ordered = AgentStatus.allCases.sorted(by: >)
        #expect(ordered == [.blocked, .done, .working, .idle, .unknown])
    }

    @Test func decodesKnownStatuses() throws {
        let data = Data(#"["idle","working","blocked","done","unknown"]"#.utf8)
        #expect(
            try JSONDecoder().decode([AgentStatus].self, from: data) == [.idle, .working, .blocked, .done, .unknown])
    }

    @Test func decodesFutureStatusesAsUnknown() throws {
        let data = Data(#"["napping"]"#.utf8)
        #expect(try JSONDecoder().decode([AgentStatus].self, from: data) == [.unknown])
    }

    @Test func snapshotStatusAggregatesItsAgents() {
        let record = { (status: AgentStatus) in
            AgentRecord(
                source: .localSession("default"), workspace: "w", paneID: "p", agent: nil, status: status, title: "",
                cwd: nil)
        }
        #expect(HerdrSnapshot.empty.status == .unknown)
        #expect(HerdrSnapshot(agents: [record(.idle), record(.done)], failures: []).status == .done)
    }
}
