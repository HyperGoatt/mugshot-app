import XCTest
@testable import testMugshot

final class VisitDisplayLocationNameTests: XCTestCase {
    
    func testDisplayLocationName_CafeVisit_UsesCafeName() {
        let cafeId = UUID()
        let cafe = Cafe(id: cafeId, name: "Needle & Bean", address: "", city: nil, country: nil)
        
        let visit = Visit(
            id: UUID(),
            cafeId: cafeId,
            userId: UUID(),
            drinkType: .coffee,
            caption: "Great latte",
            contextType: .cafe
        )
        
        let name = visit.displayLocationName { id in
            XCTAssertEqual(id, cafeId)
            return cafe
        }
        
        XCTAssertEqual(name, "Needle & Bean")
    }
    
    func testDisplayLocationName_CafeVisit_NoCafeFound_FallsBackToUnknownCafe() {
        let cafeId = UUID()
        let visit = Visit(
            id: UUID(),
            cafeId: cafeId,
            userId: UUID(),
            drinkType: .coffee,
            caption: "Great latte",
            contextType: .cafe
        )
        
        let name = visit.displayLocationName { _ in nil }
        XCTAssertEqual(name, "Unknown Cafe")
    }
    
    func testDisplayLocationName_CraftSip_UsesLocationName() {
        let visit = Visit(
            id: UUID(),
            cafeId: nil,
            userId: UUID(),
            drinkType: .coffee,
            caption: "Home brew",
            contextType: .home,
            locationName: "Home Espresso Bar"
        )
        
        let name = visit.displayLocationName { _ in XCTFail("Should not look up cafe for craft sip"); return nil }
        XCTAssertEqual(name, "Home Espresso Bar")
    }
    
    func testDisplayLocationName_CraftSip_NoLocationName_FallsBackToCraftSip() {
        let visit = Visit(
            id: UUID(),
            cafeId: nil,
            userId: UUID(),
            drinkType: .coffee,
            caption: "Home brew",
            contextType: .home,
            locationName: nil
        )
        
        let name = visit.displayLocationName { _ in XCTFail("Should not look up cafe for craft sip"); return nil }
        XCTAssertEqual(name, "Craft Sip")
    }
    
    func testDisplayLocationName_CafeVisit_DoesNotUseLocationNameEvenIfPresent() {
        let cafeId = UUID()
        let cafe = Cafe(id: cafeId, name: "Cafe Grumpy", address: "", city: nil, country: nil)
        
        let visit = Visit(
            id: UUID(),
            cafeId: cafeId,
            userId: UUID(),
            drinkType: .coffee,
            caption: "At a cafe",
            contextType: .cafe,
            locationName: "Should Not Use"
        )
        
        let name = visit.displayLocationName { id in
            XCTAssertEqual(id, cafeId)
            return cafe
        }
        
        XCTAssertEqual(name, "Cafe Grumpy")
    }
}

