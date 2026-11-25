import SwiftUI

@main
struct FolderTidyApp: App {
    @StateObject private var model = OrganizerViewModel()
    @AppStorage("language") private var language = "system"

    private var locale: Locale { language == "system" ? .autoupdatingCurrent : Locale(identifier: language) }

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(model).environment(\.locale, locale)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Choose Folder…") { model.chooseFolder() }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
        Settings {
            SettingsView().environmentObject(model).environment(\.locale, locale)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: OrganizerViewModel
    @AppStorage("language") private var language = "system"
    var body: some View {
        TabView {
            Form {
                Picker("Language", selection: $language) {
                    Text("System Default").tag("system")
                    Text("English").tag("en"); Text("Italiano").tag("it")
                    Text("Français").tag("fr"); Text("Deutsch").tag("de")
                    Text("Español").tag("es"); Text("Português").tag("pt")
                    Text("日本語").tag("ja"); Text("简体中文").tag("zh-Hans")
                }
                Toggle("Group by date (YYYY-MM)", isOn: $model.groupByDate)
                    .onChange(of: model.groupByDate) { _, _ in model.analyze() }
            }.padding().tabItem { Label("General", systemImage: "gear") }
            VStack(spacing: 12) {
                Image(systemName: "folder.badge.gearshape").font(.system(size: 52)).foregroundStyle(.tint)
                Text("Folder Tidy").font(.title.bold())
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0")")
                Text("Created by cialu.net")
                Link("cialu.net", destination: URL(string: "https://cialu.net")!)
            }.padding(30).tabItem { Label("About", systemImage: "info.circle") }
        }.frame(width: 440, height: 270)
    }
}
