import Foundation

enum RoadmapFeatureFlags {
    /// Production enabled after the additive Home workspace contracts reached
    /// migration `20260916020417`. An explicit stored `false` remains the
    /// rollback switch and never removes saved Home data.
    static let homeRecipes = "MugshotRoadmap.homeRecipes.v1"
    static let homeRecipesEnabledByDefault = true
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
}
