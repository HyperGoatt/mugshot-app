import SwiftUI
import Testing
@testable import testMugshot

@MainActor
struct HomeEditorControlTests {
    @Test func editingAfterReorderStillChangesTheSameIngredient() {
        let first = HomeRecipeIngredient(name: "Milk")
        let second = HomeRecipeIngredient(name: "Sugar")
        var values = [first, second]
        let collection = Binding(get: { values }, set: { values = $0 })
        let milk = HomeEditorBindings.item(first, in: collection)
        values.swapAt(0, 1)
        milk.wrappedValue.name = "Oat milk"
        #expect(values.map(\.name) == ["Sugar", "Oat milk"])
        #expect(values[1].id == first.id)
    }

    @Test func lateFieldEditCannotRecreateADeletedIngredientOrChangeItsNeighbor() {
        let first = HomeRecipeIngredient(name: "Milk")
        let second = HomeRecipeIngredient(name: "Sugar")
        var values = [first, second]
        let collection = Binding(get: { values }, set: { values = $0 })
        let milk = HomeEditorBindings.item(first, in: collection)
        values.removeAll { $0.id == first.id }
        milk.wrappedValue.name = "Late edit"
        #expect(values == [second])
        #expect(milk.wrappedValue.id == first.id)
    }
}
