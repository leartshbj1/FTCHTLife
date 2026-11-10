import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: GameEngine

    var body: some View {
        Group {
            if let j = engine.joueur {
                if j.vivant {
                    MainView()
                } else if engine.evenementEnCours == nil {
                    DeathView()
                } else {
                    MainView()
                }
            } else {
                NewLifeView()
            }
        }
        .preferredColorScheme(.light)
    }
}
