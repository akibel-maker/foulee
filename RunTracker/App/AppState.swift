import Foundation
import Observation

enum AppTab: Hashable {
    case run, routes, history, stats, daily
}

/// État partagé entre les onglets (onglet actif, itinéraire choisi pour la prochaine course).
@MainActor
@Observable
final class AppState {
    var selectedTab: AppTab = .run
    var plannedRoute: SuggestedRoute?
}
