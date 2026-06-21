import SwiftUI

@main
struct KikuDictateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("Kiku Dictate") {
            MainView(viewModel: viewModel)
        }
        .defaultSize(width: 740, height: 520)
    }
}
