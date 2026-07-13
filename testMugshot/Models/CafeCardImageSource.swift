import Foundation

enum CafeCardImageSource: Equatable {
    case personalJournal(path: String)
    case place(url: String)
    case community(url: String)
    case placeholder

    static func preferred(
        personalJournalPath: String?,
        placePhotoURL: String?,
        communityPhotoURL: String?
    ) -> CafeCardImageSource {
        if let personalJournalPath = personalJournalPath?.remoteTrimmedNonEmpty {
            return .personalJournal(path: personalJournalPath)
        }
        if let placePhotoURL = placePhotoURL?.remoteTrimmedNonEmpty {
            return .place(url: placePhotoURL)
        }
        if let communityPhotoURL = communityPhotoURL?.remoteTrimmedNonEmpty {
            return .community(url: communityPhotoURL)
        }
        return .placeholder
    }
}
