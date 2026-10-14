import Testing

@testable import Buddr

struct NamePlateTests {
    private static let devbox = HerdrSource.machine(id: "m1", label: "Devbox")

    @Test func localAgentsShowTheWorkspaceAndTitle() {
        let plate = NamePlate(agent: .stub(.done, workspace: "buddr", title: "test123"), more: 0)
        #expect(plate == NamePlate(machine: nil, workspace: "buddr", title: "test123", more: 0))
        #expect(plate.label(showing: NamePlate.Field.all)?.text == "buddr · test123")
    }

    @Test func remoteAgentsShowTheMachineFirst() {
        let plate = NamePlate(agent: .stub(.done, source: Self.devbox, workspace: "api", title: "fix-login"), more: 2)
        #expect(
            plate.label(showing: NamePlate.Field.all)
                == NamePlate.Label(lead: "Devbox · api · ", title: "fix-login", more: 2))
        #expect(plate.label(showing: NamePlate.Field.all)?.text == "Devbox · api · fix-login  +2")
    }

    @Test func theTitleFallsBackToTheWorkingDirectoryThenThePane() {
        let byDirectory = NamePlate(agent: .stub(.done, title: "", cwd: "/Users/me/code/website"), more: 0)
        #expect(byDirectory.title == "website")
        let byPane = NamePlate(agent: .stub(.done, pane: "wG:p3", title: ""), more: 0)
        #expect(byPane.title == "wG:p3")
    }

    @Test func aTitleRepeatingTheWorkspaceIsDropped() {
        let plate = NamePlate(agent: .stub(.done, workspace: "buddr", title: "", cwd: "/Users/me/code/buddr"), more: 1)
        #expect(plate.label(showing: NamePlate.Field.all) == NamePlate.Label(lead: "buddr", title: "", more: 1))
        #expect(plate.label(showing: NamePlate.Field.all)?.text == "buddr  +1")
    }

    @Test func surroundingWhitespaceOfTheTitleIsTrimmed() {
        #expect(NamePlate(agent: .stub(.done, title: "  fix login\n"), more: 0).title == "fix login")
    }

    // MARK: Fields

    @Test(arguments: [
        ([NamePlate.Field.machine], "Devbox  +2"),
        ([.workspace], "api  +2"),
        ([.title], "fix-login  +2"),
        ([.machine, .workspace], "Devbox · api  +2"),
        ([.machine, .title], "Devbox · fix-login  +2"),
        ([.workspace, .title], "api · fix-login  +2"),
    ])
    func onlyTheChosenPartsAreShown(fields: [NamePlate.Field], text: String) {
        let plate = NamePlate(machine: "Devbox", workspace: "api", title: "fix-login", more: 2)
        #expect(plate.label(showing: Set(fields))?.text == text)
    }

    @Test func aTitleRepeatingAHiddenWorkspaceIsShown() {
        let plate = NamePlate(machine: nil, workspace: "buddr", title: "buddr", more: 0)
        #expect(plate.label(showing: [.title]) == NamePlate.Label(lead: "", title: "buddr", more: 0))
    }

    @Test func noLabelWhenTheChosenPartsHaveNoText() {
        // A local agent has no machine; a title repeating the shown workspace is dropped.
        let plate = NamePlate(machine: nil, workspace: "buddr", title: "buddr", more: 3)
        #expect(plate.label(showing: [.machine]) == nil)
        #expect(plate.label(showing: []) == nil)
        #expect(plate.label(showing: [.machine, .workspace, .title]) != nil)
    }
}
