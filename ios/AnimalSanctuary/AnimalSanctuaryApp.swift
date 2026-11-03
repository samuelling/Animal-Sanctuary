import SwiftUI
import AVFoundation

/// Animal Sanctuary for iPhone and iPad: the web game, bundled with the app and run full screen.
@main
struct AnimalSanctuaryApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Game music and sound effects follow the silent switch and mix with other audio, like most games.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    var body: some Scene {
        WindowGroup {
            GameView()
                .ignoresSafeArea()
                .background(Color(uiColor: .sanctuaryNight))
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
        .onChange(of: scenePhase) { _, phase in
            // Write any save that is still waiting on its short delay before iOS suspends the app.
            if phase != .active { SaveStore.shared.flush() }
        }
    }
}

extension UIColor {
    /// The game's night-sky background (--night in index.html).
    static let sanctuaryNight = UIColor(red: 0x12 / 255.0, green: 0x0e / 255.0, blue: 0x1c / 255.0, alpha: 1)
}
