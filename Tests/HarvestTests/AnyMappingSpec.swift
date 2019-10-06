import Combine
import Harvest
import Quick
import Nimble

/// Tests for `anyState`/`anyInput` (predicate functions).
class AnyMappingSpec: QuickSpec
{
    override func spec()
    {
        typealias Harvester = Harvest.Harvester<MyInput, MyState>

        var inputs: PassthroughSubject<MyInput, Never>!
        var harvester: Harvester!
        var lastReply: Reply<MyInput, MyState>?
        var cancellables: Set<AnyCancellable>!

        beforeEach {
            inputs = PassthroughSubject()
            lastReply = nil
            cancellables = []
        }

        describe("`anyState`/`anyInput` mapping") {

            beforeEach {
                let mappings: [Harvester.Mapping] = [
                    .input0 | any => .state1,
                    any     | .state1 => .state2
                ]

                harvester = Harvester(state: .state0, inputs: inputs, mapping: reduce(mappings))

                harvester.replies
                    .sink { reply in
                        lastReply = reply
                    }
                    .store(in: &cancellables)
            }

            it("`anyState`/`anyInput` succeeds") {
                expect(harvester.state) == .state0
                expect(lastReply).to(beNil())

                // try any input (fails)
                inputs.send(.input2)

                expect(lastReply?.input) == .input2
                expect(lastReply?.fromState) == .state0
                expect(lastReply?.toState).to(beNil())
                expect(harvester.state) == .state0

                // try `.login` from any state
                inputs.send(.input0)

                expect(lastReply?.input) == .input0
                expect(lastReply?.fromState) == .state0
                expect(lastReply?.toState) == .state1
                expect(harvester.state) == .state1

                // try any input
                inputs.send(.input2)

                expect(lastReply?.input) == .input2
                expect(lastReply?.fromState) == .state1
                expect(lastReply?.toState) == .state2
                expect(harvester.state) == .state2
            }

        }
    }
}
