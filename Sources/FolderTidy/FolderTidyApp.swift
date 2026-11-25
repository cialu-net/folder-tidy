import SwiftUI

@main
struct FolderTidyApp: App {
    @StateObject private var model = OrganizerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(model)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Choose Folder…") { model.chooseFolder() }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
