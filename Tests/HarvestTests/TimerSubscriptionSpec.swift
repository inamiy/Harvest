import Foundation
import Combine
import Harvest
import Quick
import Nimble
import Thresher

/// Tests for timer subscription.
class TimerSubscriptionSpec: QuickSpec
{
    override func spec()
    {
        typealias Harvester = Harvest.Harvester<TimerInput, Int>
        typealias EffectMapping = Harvester.EffectMapping<BasicEffectQueue, EffectID>
        typealias EffectID = String

        var inputs: PassthroughSubject<TimerInput, Never>!   // NOTE: Using subset `ExternalAuthInput`
        var harvester: Harvester!
        var lastReply: Reply<TimerInput, Int>?
        var cancellables: Set<AnyCancellable>!

        beforeEach {
            inputs = PassthroughSubject()
            lastReply = nil
            cancellables = []
        }

        describe("Timer subscription") {

            let timeInterval: TimeInterval = 0.03
            let leeway: TimeInterval = 0.01

            beforeEach {

                let timerPublisher = Timer.publish(every: timeInterval, on: .main, in: .default)
                    .autoconnect()  // Required
                    .scan(0, { count, _ in count + 1 })
                    .map(TimerInput.tick)
                    .eraseToAnyPublisher()

                let mapping: EffectMapping = .init { input, state in
                    switch input {
                    case .start:
                        return (state, Effect(timerPublisher, id: "timer"))

                    case let .tick(newState):
                        return (newState, .none)

                    case .stop:
                        return (state, Effect.cancel("timer"))
                    }
                }

                harvester = Harvester(
                    state: 0,
                    inputs: inputs,
                    mapping: mapping
                )

                harvester.replies
                    .sink { reply in
                        lastReply = reply
                    }
                    .store(in: &cancellables)
            }

            it("starts ticking and stop") {
                expect(harvester.state) == 0
                expect(lastReply).to(beNil())

                let expectation = self.expectation(description: "timer")

                asyncAfter(timeInterval) {
                    // Not changed because hasn't started yet.
                    expect(harvester.state) == 0
                    expect(lastReply).to(beNil())

                    // Start!
                    inputs.send(.start)
                }

                asyncAfter(timeInterval * 2 + leeway) {
                    expect(lastReply?.fromState) == 0
                    expect(lastReply?.toState) == 1
                }

                asyncAfter(timeInterval * 3 + leeway) {
                    expect(lastReply?.fromState) == 1
                    expect(lastReply?.toState) == 2

                    // Stop!
                    inputs.send(.stop)
                }

                asyncAfter(timeInterval * 4 + leeway) {
                    // State not changed (NOTE: `lastReply` is still sent via `.stop`)
                    expect(lastReply?.fromState) == 2
                    expect(lastReply?.toState) == 2

                    expectation.fulfill()
                }

                self.wait(for: [expectation], timeout: timeInterval * 10)
            }

        }

    }
}

private enum TimerInput
{
    case start
    case tick(Int)
    case stop
}
