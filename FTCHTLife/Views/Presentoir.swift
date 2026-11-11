import SwiftUI

// Fenêtres (messages, cartes de choix) demandées par des morceaux d'écran rangés dans une `List`.
//
// Pourquoi : une `.alert` ou une `.sheet` posée sur une ligne ou une section de `List` est fermée
// dès que la liste se redessine. Or chaque action change le joueur, donc la liste se redessine
// tout de suite, et la fenêtre « apparaît puis disparaît direct » (ex. « Passer une nuit ensemble »
// dans la fiche de sa copine). On remonte donc ces fenêtres à la racine de l'écran, hors de la liste.
//
// Usage :
//   - l'écran qui contient la liste : `List { … }.presentoirRacine()`
//   - la section dans la liste : `@Environment(\.presentoir) private var presentoir`
//     puis `presentoir?.montrer(texte)` ou `presentoir?.ouvrir(MaCarte())`.

final class Presentoir: ObservableObject {
    struct Message: Identifiable {
        let id = UUID()
        let titre: String
        let texte: String
    }

    struct Fenetre: Identifiable {
        let id = UUID()
        let contenu: AnyView
    }

    @Published var message: Message?
    @Published var fenetre: Fenetre?

    /// Affiche un texte de résultat (rien si le texte est vide).
    func montrer(_ texte: String?, titre: String = "FTCHTLife") {
        guard let t = texte, !t.isEmpty else { return }
        message = Message(titre: titre, texte: t)
    }

    /// Ouvre une fenêtre (carte de choix…) par-dessus l'écran.
    func ouvrir<V: View>(_ vue: V) {
        fenetre = Fenetre(contenu: AnyView(vue))
    }
}

private struct PresentoirCle: EnvironmentKey {
    static let defaultValue: Presentoir? = nil
}

extension EnvironmentValues {
    /// Le présentoir de l'écran en cours (nil si l'écran n'en a pas posé).
    var presentoir: Presentoir? {
        get { self[PresentoirCle.self] }
        set { self[PresentoirCle.self] = newValue }
    }
}

private struct PresentoirRacine: ViewModifier {
    @EnvironmentObject var engine: GameEngine
    @StateObject private var presentoir = Presentoir()

    func body(content: Content) -> some View {
        content
            .environment(\.presentoir, presentoir)
            .alert(presentoir.message?.titre ?? "FTCHTLife",
                   isPresented: Binding(get: { presentoir.message != nil },
                                        set: { if !$0 { presentoir.message = nil } })) {
                Button("OK") { presentoir.message = nil }
            } message: {
                Text(presentoir.message?.texte ?? "")
            }
            .sheet(item: $presentoir.fenetre) { f in
                f.contenu
                    .environmentObject(engine)
                    // La fenêtre a son propre présentoir : on ne présente jamais depuis un écran déjà occupé.
                    .presentoirRacine()
                    .interactiveDismissDisabled()
                    .presentationDetents([.medium, .large])
            }
    }
}

extension View {
    /// À poser sur l'écran qui contient la liste (hors de la liste).
    func presentoirRacine() -> some View { modifier(PresentoirRacine()) }
}
