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
            typealias EffectMapping = Harvester.EffectMapping<BasicEffectQueue, Never>

            var inputs: PassthroughSubject<CountInput, Never>!
            var harvester: Harvester!

            beforeEach {
                inputs = PassthroughSubject()

                var mappings: [EffectMapping] = [
                    .increment | { $0 + 1 } | .empty
                    // Comment-Out: Type inference is super slow in Swift 4.2... (use `+=` instead)
//                    .decrement | { $0 - 1 } | .empty()
                    ]
                mappings += [ .decrement | { $0 - 1 } | .empty ]

                // strategy = `.merge`
                harvester = Harvester(state: 0, inputs: inputs, mapping: .reduce(mappings))
            }

            it("`.increment` and `.decrement` succeed") {
                expect(harvester.state) == 0
                inputs.send(.increment)

                // NOTE: tvOS fails for some reason...
                #if !os(tvOS)
                expect(harvester.state) == 1
                inputs.send(.increment)
                expect(harvester.state) == 2
                inputs.send(.decrement)
                expect(harvester.state) == 1
                inputs.send(.decrement)
                expect(harvester.state) == 0
                #endif
            }

        }
    }
}
