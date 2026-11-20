import SwiftUI

@main
struct EveryMango2App: App {
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Fonts.register()
        Notifier.shared.install()
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.store)
                .environment(\.skin, model.skin)
                .preferredColorScheme(model.store.prefs.darkSkin ? .dark : .light)
                .tint(model.skin.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                model.calendar.refreshStatus()
                model.store.tickFocus()
            } else {
                model.saveNow()
            }
        }
    }
}
