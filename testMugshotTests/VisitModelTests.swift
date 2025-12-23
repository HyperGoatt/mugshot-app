import XCTest
import Foundation
@testable import testMugshot

final class VisitModelTests: XCTestCase {
    
    func testVisitWithOptionalCafeId() {
        // Test that we can create a visit with nil cafeId (locationless)
        let visit = Visit(
            id: UUID(),
            cafeId: nil,
            userId: UUID(),
            drinkType: .coffee,
            caption: "Home brew",
            contextType: .home,
            locationName: "Home Kitchen"
        )
        
        XCTAssertNil(visit.cafeId)
        XCTAssertTrue(visit.isLocationless)
        XCTAssertEqual(visit.locationName, "Home Kitchen")
        XCTAssertEqual(visit.contextType, .home)
    }
    
    func testVisitWithCafeId() {
        // Test that we can create a visit with a cafeId
        let cafeId = UUID()
        let visit = Visit(
            id: UUID(),
            cafeId: cafeId,
            userId: UUID(),
            drinkType: .coffee,
            caption: "Cafe visit",
            contextType: .cafe
        )
        
        XCTAssertEqual(visit.cafeId, cafeId)
        XCTAssertFalse(visit.isLocationless)
        XCTAssertEqual(visit.contextType, .cafe)
    }
    
    func testVisitCodableWithOptionalCafeId() throws {
        // Test JSON encoding/decoding with nil cafeId
        let visit = Visit(
            id: UUID(),
            cafeId: nil,
            userId: UUID(),
            drinkType: .coffee,
            caption: "Home brew",
            contextType: .home,
            locationName: "Home Kitchen"
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(visit)
        let decodedVisit = try decoder.decode(Visit.self, from: data)
        
        XCTAssertNil(decodedVisit.cafeId)
        XCTAssertEqual(decodedVisit.id, visit.id)
        XCTAssertEqual(decodedVisit.caption, visit.caption)
        XCTAssertEqual(decodedVisit.contextType, visit.contextType)
        XCTAssertEqual(decodedVisit.locationName, visit.locationName)
    }
}
