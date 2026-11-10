import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: GameEngine

    var body: some View {
        Group {
            if let j = engine.joueur {
                if j.vivant || engine.evenementEnCours != nil {
                    MainView()
                } else {
                    DeathView()
                }
            } else {
                NewLifeView()
            }
        }
        .suiviTrophees()
        .preferredColorScheme(.light)
    }
}
