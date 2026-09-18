import Foundation

enum RoadmapFeatureFlags {
    /// Production enabled after the additive Home workspace contracts reached
    /// migration `20260916020417`. An explicit stored `false` remains the
    /// rollback switch and never removes saved Home data.
    static let homeRecipes = "MugshotRoadmap.homeRecipes.v1"
    static let homeRecipesEnabledByDefault = true
    /// Controls only the central Log a Sip route. Turning it off restores the
    /// prior Home library handoff without deleting V3 recipes or attempts.
    static let homeSipV3Route = "MugshotRoadmap.homeSipV3Route.v1"
    static let homeSipV3RouteEnabledByDefault = true
    static let phase2CanonicalJournal = "MugshotRoadmap.phase2CanonicalJournal.v1"
    static let phase3ExplainableTasteGraph = "MugshotRoadmap.phase3ExplainableTasteGraph.v1"
    static let phase4LightweightFriends = "MugshotRoadmap.phase4LightweightFriends.v1"
    static let phase5Reflections = "MugshotRoadmap.phase5Reflections.v1"
    static let phase6OwnershipAndSystemEntry = "MugshotRoadmap.phase6OwnershipAndSystemEntry.v1"
    static let cafeSessionsAndPulse = "MugshotRoadmap.cafeSessionsAndPulse.v1"
    static let journalHeaderProfileAction = "MugshotRoadmap.journalHeaderProfileAction.v1"

    static func isHomeRecipesEnabled(in defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: homeRecipes) != nil else {
            return homeRecipesEnabledByDefault
        }
        return defaults.bool(forKey: homeRecipes)
    }

    static func isHomeSipV3RouteEnabled(in defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: homeSipV3Route) != nil else {
            return homeSipV3RouteEnabledByDefault
        }
        return defaults.bool(forKey: homeSipV3Route)
    }
}
