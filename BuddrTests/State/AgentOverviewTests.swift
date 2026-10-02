import Testing

@testable import Buddr

struct AgentOverviewTests {
    private static let devbox = HerdrSource.machine(id: "m1", label: "Devbox")
    private static let pi = HerdrSource.machine(id: "m2", label: "Pi")

    @Test func sectionsFollowTheQueriedSourcesIncludingEmptyAndFailedOnes() {
        let snapshot = HerdrSnapshot(
            agents: [.stub(.working, source: Self.devbox)],
            failures: [SourceFailure(source: Self.pi, message: "timed out")],
            sources: [.localSession("default"), Self.devbox, Self.pi])
        let overview = AgentOverview(snapshot)

        #expect(overview.sections.map(\.title) == ["This Mac", "Devbox", "Pi"])
        #expect(overview.sections.map(\.failure) == [nil, nil, "timed out"])
        #expect(overview.sections.map(\.workspaces.count) == [0, 1, 0])
    }

    @Test func severalLocalSessionsAreNamed() {
        let snapshot = HerdrSnapshot(
            agents: [], failures: [], sources: [.localSession("default"), .localSession("work"), Self.devbox])

        #expect(AgentOverview(snapshot).sections.map(\.title) == ["This Mac · default", "This Mac · work", "Devbox"])
    }

    @Test func failuresWithoutASourceAreGeneral() {
        let snapshot = HerdrSnapshot(
            agents: [], failures: [SourceFailure(source: nil, message: "herdr not found")], sources: [])
        let overview = AgentOverview(snapshot)

        #expect(overview.generalFailures == ["herdr not found"])
        #expect(overview.sections.isEmpty)
    }

    @Test func workspacesAreOrderedLikeHerdrsSidebar() {
        let snapshot = HerdrSnapshot(
            agents: [
                .stub(.working, workspace: "buddr", number: 5, pane: "a"),
                .stub(.idle, workspace: "loose", pane: "b"),
                .stub(.done, workspace: "dotfiles", number: 3, pane: "c"),
                .stub(.blocked, workspace: "buddr", number: 5, pane: "d"),
                .stub(.idle, workspace: "stray", pane: "e"),
                .stub(.idle, workspace: "temp", number: 1, pane: "f"),
            ], failures: [])
        let workspaces = AgentOverview(snapshot).sections[0].workspaces

        // Numbered ones by number, the rest after them in the order of their first agent.
        #expect(workspaces.map(\.label) == ["temp", "dotfiles", "buddr", "loose", "stray"])
        #expect(workspaces[2].agents.map(\.paneID) == ["a", "d"])
        #expect(workspaces[2].id == .init(source: .localSession("default"), workspaceID: "id-buddr"))
    }

    @Test func workspacesOfDifferentSourcesStaySeparate() {
        let snapshot = HerdrSnapshot(
            agents: [.stub(.working), .stub(.idle, source: Self.devbox)], failures: [])
        let sections = AgentOverview(snapshot).sections

        #expect(sections.map { $0.workspaces.map(\.agents.count) } == [[1], [1]])
        #expect(sections[0].workspaces[0].id != sections[1].workspaces[0].id)
    }

    @Test func idleAgentsAreFoldedOnlyWhenThereAreMany() {
        let few = AgentOverview.WorkspaceGroup(
            id: .init(source: .localSession("default"), workspaceID: "w"), label: "w",
            agents: [.stub(.idle), .stub(.idle), .stub(.working), .stub(.idle)])
        #expect(few.idleCount == 3)
        #expect(!few.foldsIdleAgents)

        let many = AgentOverview.WorkspaceGroup(
            id: few.id, label: "w",
            agents: [
                .stub(.idle, pane: "1"), .stub(.blocked, pane: "2"), .stub(.idle, pane: "3"),
                .stub(.idle, pane: "4"), .stub(.unknown, pane: "5"), .stub(.idle, pane: "6"),
            ])
        #expect(many.idleCount == 4)
        #expect(many.foldsIdleAgents)
        #expect(many.activeAgents.map(\.paneID) == ["2", "5"])
    }

    @Test func statusCountsAreMostUrgentFirstWithoutEmptyStatuses() {
        let snapshot = HerdrSnapshot(
            agents: [.stub(.idle), .stub(.working), .stub(.blocked), .stub(.working)], failures: [])

        #expect(
            AgentOverview(snapshot).statusCounts == [
                .init(status: .blocked, count: 1), .init(status: .working, count: 2), .init(status: .idle, count: 1),
            ])
        #expect(AgentOverview(.empty).statusCounts.isEmpty)
    }

    @Test func displayTitleFallsBackToTheDirectoryAndThePane() {
        #expect(
            AgentRecord.stub(.idle, title: "buddr impl1", cwd: "/Users/me/code/buddr").displayTitle == "buddr impl1")
        #expect(AgentRecord.stub(.idle, title: "", cwd: "/Users/me/code/buddr/").displayTitle == "buddr")
        #expect(AgentRecord.stub(.idle, pane: "wG:p1", title: "", cwd: nil).displayTitle == "wG:p1")
        #expect(AgentRecord.stub(.idle, pane: "wG:p1", title: "", cwd: "/").displayTitle == "wG:p1")
    }
}
