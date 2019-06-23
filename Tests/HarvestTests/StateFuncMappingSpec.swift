import Combine
import Harvest
import Quick
import Nimble

/// Tests for state-change function mapping.
class StateFuncMappingSpec: QuickSpec
{
    override func spec()
    {
        describe("State-change function mapping") {

            typealias Harvester = Harvest.Harvester<CountInput, CountState>
            typealias EffectMapping = Harvester.EffectMapping<Never, Never>

            let inputs = PassthroughSubject<CountInput, Never>()
            var harvester: Harvester!

            beforeEach {
                var mappings: [EffectMapping] = [
                    .increment | { $0 + 1 } | .empty
                    // Comment-Out: Type inference is super slow in Swift 4.2... (use `+=` instead)
//                    .decrement | { $0 - 1 } | .empty()
                    ]
                mappings += [ .decrement | { $0 - 1 } | .empty ]

                // strategy = `.merge`
                harvester = Harvester(state: 0, inputs: inputs, mapping: reduce(mappings))
            }

            it("`.increment` and `.decrement` succeed") {
                expect(harvester.state.value) == 0
                inputs.send(.increment)
                expect(harvester.state.value) == 1
                inputs.send(.increment)
                expect(harvester.state.value) == 2
                inputs.send(.decrement)
                expect(harvester.state.value) == 1
                inputs.send(.decrement)
                expect(harvester.state.value) == 0
            }

        }
    }
}
