import Testing

@testable import Buddr

struct NamePlateTests {
    private static let devbox = HerdrSource.machine(id: "m1", label: "Devbox")

    @Test func localAgentsShowTheWorkspaceAndTitle() {
        let plate = NamePlate(agent: .stub(.done, workspace: "buddr", title: "test123"), more: 0)
        #expect(plate == NamePlate(prefix: "buddr", title: "test123", more: 0))
        #expect(plate.text == "buddr · test123")
    }

    @Test func remoteAgentsShowTheMachineFirst() {
        let plate = NamePlate(agent: .stub(.done, source: Self.devbox, workspace: "api", title: "fix-login"), more: 2)
        #expect(plate.prefix == "Devbox · api")
        #expect(plate.text == "Devbox · api · fix-login  +2")
    }

    @Test func theTitleFallsBackToTheWorkingDirectoryThenThePane() {
        let byDirectory = NamePlate(agent: .stub(.done, title: "", cwd: "/Users/me/code/website"), more: 0)
        #expect(byDirectory.title == "website")
        let byPane = NamePlate(agent: .stub(.done, pane: "wG:p3", title: ""), more: 0)
        #expect(byPane.title == "wG:p3")
    }

    @Test func aTitleRepeatingTheWorkspaceIsDropped() {
        let plate = NamePlate(agent: .stub(.done, workspace: "buddr", title: "", cwd: "/Users/me/code/buddr"), more: 1)
        #expect(plate.title == "")
        #expect(plate.text == "buddr  +1")
    }

    @Test func surroundingWhitespaceOfTheTitleIsTrimmed() {
        #expect(NamePlate(agent: .stub(.done, title: "  fix login\n"), more: 0).title == "fix login")
    }
}
