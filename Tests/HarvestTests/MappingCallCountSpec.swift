import Combine
import Harvest
import Quick
import Nimble

/// Tests for `mapping` and `reply` call count.
class MappingCallCountSpec: QuickSpec
{
    override func spec()
    {
        typealias Harvester = Harvest.Harvester<CountInput, CountState>
        typealias Mapping = Harvester.Mapping

        var inputs: PassthroughSubject<CountInput, Never>!
        var harvester: Harvester!
        var lastReply: Reply<CountInput, CountState>?
        var cancellables: Set<AnyCancellable>!

        var mappingCallCount = 0
        var replyCallCount = 0

        beforeEach {
            inputs = PassthroughSubject()
            lastReply = nil
            cancellables = []
        }

        describe("Mapping & Reply call count") {

            beforeEach {
                mappingCallCount = 0

                let mapping: Mapping = { input, state in
                    mappingCallCount += 1

                    switch input {
                    case .increment: return state + 1
                    case .decrement: return state - 1
                    }
                }

                harvester = Harvester(state: 0, inputs: inputs, mapping: mapping)

                harvester.replies
                    .sink { reply in
                        replyCallCount += 1
                        lastReply = reply
                    }
                    .store(in: &cancellables)
            }

            it("should call `mapping` only once per input sent") {
                expect(harvester.state) == 0
                expect(lastReply).to(beNil())
                expect(mappingCallCount) == 0
                expect(replyCallCount) == 0

                inputs.send(.increment)

                expect(harvester.state) == 1
                expect(lastReply?.input) == .increment
                expect(mappingCallCount) == 1
                expect(replyCallCount) == 1
            }

        }
    }
}
