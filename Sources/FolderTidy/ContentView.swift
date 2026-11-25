import SwiftUI
import AppKit
import QuickLookUI
import QuickLook

@MainActor
final class OrganizerViewModel: ObservableObject {
    @Published var folder: URL?
    @Published var moves: [PlannedMove] = []
    @Published var query = ""
    @Published var groupByDate = false
    @Published var status = "Choose a folder to begin."
    @Published var journals: [OrganizationJournal]
    @Published var selectedMoveID: UUID?
    var selectedForQuickLook: URL? { moves.first { $0.id == selectedMoveID }?.source }
    let rules = RuleStore()
    private let organizer = FolderOrganizer(), journalStore = JournalStore()
    init() { journals = journalStore.load() }
    var filteredMoves: [PlannedMove] { query.isEmpty ? moves : moves.filter { $0.source.lastPathComponent.localizedCaseInsensitiveContains(query) || $0.category.title.localizedCaseInsensitiveContains(query) } }
    func chooseFolder() { let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false; if panel.runModal() == .OK, let url = panel.url { folder = url; analyze() } }
    func analyze() { guard let folder else { return }; Task { do { moves = try await organizer.preview(folder: folder, rules: rules.rules, groupByDate: groupByDate); status = "\(moves.count) files ready to review." } catch { status = error.localizedDescription } } }
    func organize() { Task { do { let journal = try await organizer.organize(moves); journals = journalStore.load(); status = "Organized \(journal.moves.count) files. You can undo this action."; moves = [] } catch { journals = journalStore.load(); status = error.localizedDescription + " — use Undo to recover any moved files." } } }
    func undoLatest() { guard let journal = journals.first else { return }; Task { do { try await organizer.undo(journal); var updated = try journalStore.loadChecked(); updated.removeAll { $0.id == journal.id }; try journalStore.persist(updated); journals = updated; status = "Organization undone." } catch { status = error.localizedDescription } } }
}

struct ContentView: View {
    @EnvironmentObject private var model: OrganizerViewModel
    @State private var showRules = false
    @State private var confirmOrganize = false
    @State private var previewURL: URL?
    @State private var categoryFilter = "All"
    var body: some View {
        NavigationSplitView {
            List { Section("Folder") { Label(model.folder?.lastPathComponent ?? "No folder selected", systemImage: "folder") ; Button("Choose Folder…") { model.chooseFolder() } }
                Section("Options") { Toggle("Group by date (YYYY-MM)", isOn: $model.groupByDate).onChange(of: model.groupByDate) { _, _ in model.analyze() }; Button("Custom Rules…") { showRules = true } }
                Section("History") { Button("Undo Last Organization") { model.undoLatest() }.disabled(model.journals.isEmpty) }
            }.navigationTitle("Folder Tidy")
        } detail: {
            VStack(spacing: 0) {
                HStack { Text("Preview").font(.title2.bold()); Spacer(); Picker("Category", selection: $categoryFilter) { Text("All").tag("All"); ForEach(FileCategory.allCases) { Text($0.title).tag($0.rawValue) } }.frame(width: 150); TextField("Search files", text: $model.query).textFieldStyle(.roundedBorder).frame(width: 220); Button("Analyze") { model.analyze() }.disabled(model.folder == nil) }.padding()
                Table(model.filteredMoves.filter { categoryFilter == "All" || $0.category.rawValue == categoryFilter }, selection: $model.selectedMoveID) {
                    TableColumn("Include") { move in Toggle("", isOn: Binding(get: { model.moves.first(where: { $0.id == move.id })?.selected ?? false }, set: { value in if let i = model.moves.firstIndex(where: { $0.id == move.id }) { model.moves[i].selected = value } })).labelsHidden() }.width(55)
                    TableColumn("Name") { move in Text(move.source.lastPathComponent) }
                    TableColumn("Destination") { move in TextField("Destination", text: Binding(get: { move.destination.deletingLastPathComponent().lastPathComponent }, set: { value in if let i = model.moves.firstIndex(where: { $0.id == move.id }), let root = model.folder { model.moves[i].destination = root.appending(path: value).appending(path: move.source.lastPathComponent) } })) }
                    TableColumn("Category") { move in Text(move.category.title) }
                }
                Divider(); HStack { Text(model.status).foregroundStyle(.secondary); Spacer(); Button("Quick Look") { previewURL = model.selectedForQuickLook }.disabled(model.selectedForQuickLook == nil); Button("Organize Now") { confirmOrganize = true }.buttonStyle(.borderedProminent).disabled(model.moves.filter(\.selected).isEmpty) }.padding()
            }.frame(minWidth: 820, minHeight: 520)
        }.sheet(isPresented: $showRules, onDismiss: { model.analyze() }) { RulesView(store: model.rules) }
            .quickLookPreview($previewURL)
            .confirmationDialog("Move the selected files to their displayed destinations?", isPresented: $confirmOrganize) { Button("Organize Now") { model.organize() }; Button("Cancel", role: .cancel) {} }
    }
}

struct RulesView: View { @ObservedObject var store: RuleStore; @Environment(\.dismiss) var dismiss; var body: some View { VStack { Text("Custom Rules").font(.title2); List { ForEach($store.rules) { $rule in HStack { Toggle("", isOn: $rule.isEnabled).labelsHidden(); TextField("Rule name", text: $rule.name); TextField("Extensions (comma-separated)", text: Binding(get: { rule.extensions.joined(separator: ",") }, set: { rule.extensions = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() } })); TextField("Destination", text: $rule.destination) } }.onDelete { store.rules.remove(atOffsets: $0) } }; HStack { Button("Add Rule") { store.rules.append(TidyRule(name: "New rule", extensions: [], destination: "Sorted")) }; Spacer(); Button("Done") { dismiss() } } }.padding().frame(width: 720, height: 360) } }
