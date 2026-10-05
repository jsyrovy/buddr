import Testing

@testable import Buddr

struct HideModeTests {
    @Test(arguments: AgentStatus.allCases)
    func neverIsCalm(_ status: AgentStatus) {
        #expect(!HideMode.never.isCalm(status))
    }

    @Test func whenIdleIsCalmOnlyWhileNothingHappens() {
        let calm = AgentStatus.allCases.filter { HideMode.whenIdle.isCalm($0) }
        #expect(Set(calm) == [.idle, .unknown])
    }

    @Test func unlessNeededIsCalmUntilAnAgentWaitsForTheUser() {
        let calm = AgentStatus.allCases.filter { HideMode.unlessNeeded.isCalm($0) }
        #expect(Set(calm) == [.working, .idle, .unknown])
    }
}
