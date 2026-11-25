import SwiftUI
import AppKit
import QuickLookUI

@MainActor
final class OrganizerViewModel: ObservableObject {
    @Published var folder: URL?
    @Published var moves: [PlannedMove] = []
    @Published var query = ""
    @Published var groupByDate = false
    @Published var status = "Choose a folder to begin."
    @Published var journals: [OrganizationJournal]
    @Published var selectedForQuickLook: URL?
    let rules = RuleStore()
    private let organizer = FolderOrganizer(), journalStore = JournalStore()
    init() { journals = journalStore.load() }
    var filteredMoves: [PlannedMove] { query.isEmpty ? moves : moves.filter { $0.source.lastPathComponent.localizedCaseInsensitiveContains(query) || $0.category.title.localizedCaseInsensitiveContains(query) } }
    func chooseFolder() { let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false; if panel.runModal() == .OK, let url = panel.url { folder = url; analyze() } }
    func analyze() { guard let folder else { return }; Task { do { moves = try await organizer.preview(folder: folder, rules: rules.rules, groupByDate: groupByDate); status = "\(moves.count) files ready to review." } catch { status = error.localizedDescription } } }
    func organize() { Task { do { let journal = try await organizer.organize(moves); journals.insert(journal, at: 0); journalStore.save(journals); status = "Organized \(journal.moves.count) files. You can undo this action."; moves = [] } catch { status = error.localizedDescription } } }
    func undoLatest() { guard let journal = journals.first else { return }; Task { do { try await organizer.undo(journal); journals.removeFirst(); journalStore.save(journals); status = "Organization undone." } catch { status = error.localizedDescription } } }
}

struct ContentView: View {
    @EnvironmentObject private var model: OrganizerViewModel
    @State private var showRules = false
    var body: some View {
        NavigationSplitView {
            List { Section("Folder") { Label(model.folder?.lastPathComponent ?? "No folder selected", systemImage: "folder") ; Button("Choose Folder…") { model.chooseFolder() } }
                Section("Options") { Toggle("Group by date (YYYY-MM)", isOn: $model.groupByDate).onChange(of: model.groupByDate) { _, _ in model.analyze() }; Button("Custom Rules…") { showRules = true } }
                Section("History") { Button("Undo Last Organization") { model.undoLatest() }.disabled(model.journals.isEmpty) }
            }.navigationTitle("Folder Tidy")
        } detail: {
            VStack(spacing: 0) {
                HStack { Text("Preview").font(.title2.bold()); Spacer(); TextField("Search files", text: $model.query).textFieldStyle(.roundedBorder).frame(width: 220); Button("Analyze") { model.analyze() }.disabled(model.folder == nil) }.padding()
                Table(model.filteredMoves, selection: $model.selectedForQuickLook) { TableColumn("Name") { move in Text(move.source.lastPathComponent) }; TableColumn("Destination") { move in Text(move.destination.path.replacingOccurrences(of: (model.folder?.path ?? "") + "/", with: "")) }; TableColumn("Category") { move in Text(move.category.title) } }
                Divider(); HStack { Text(model.status).foregroundStyle(.secondary); Spacer(); Button("Quick Look") { if let url = model.selectedForQuickLook { QLPreviewPanel.shared()?.makeKeyAndOrderFront(nil); QLPreviewPanel.shared()?.dataSource = PreviewDataSource(url: url) } }.disabled(model.selectedForQuickLook == nil); Button("Organize Now") { model.organize() }.buttonStyle(.borderedProminent).disabled(model.moves.filter(\.selected).isEmpty) }.padding()
            }.frame(minWidth: 820, minHeight: 520)
        }.sheet(isPresented: $showRules) { RulesView(store: model.rules) }
    }
}

final class PreviewDataSource: NSObject, QLPreviewPanelDataSource { let url: URL; init(url: URL) { self.url = url }; func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { 1 }; func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! { url as NSURL } }

struct RulesView: View { @ObservedObject var store: RuleStore; @Environment(\.dismiss) var dismiss; var body: some View { VStack { Text("Custom Rules").font(.title2); List { ForEach($store.rules) { $rule in HStack { Toggle("", isOn: $rule.isEnabled).labelsHidden(); TextField("Rule name", text: $rule.name); TextField("Extensions (comma-separated)", text: Binding(get: { rule.extensions.joined(separator: ",") }, set: { rule.extensions = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() } })); TextField("Destination", text: $rule.destination) } }.onDelete { store.rules.remove(atOffsets: $0) } }; HStack { Button("Add Rule") { store.rules.append(TidyRule(name: "New rule", extensions: [], destination: "Sorted")) }; Spacer(); Button("Done") { dismiss() } } }.padding().frame(width: 720, height: 360) } }
