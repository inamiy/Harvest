import Foundation
import Combine
import Harvest
import Quick
import Nimble
import Thresher

/// Tests for `World` injection.
class WorldSpec: QuickSpec
{
    override func spec()
    {
        typealias Harvester = Harvest.Harvester<Input, State>
        typealias EffectMapping = Harvester.EffectMapping<World, BasicEffectQueue, EffectID>
        typealias EffectID = Never

        var inputs: PassthroughSubject<Input, Never>!
        var harvester: Harvester!
        var lastReply: Reply<Input, State>?
        var cancellables: Set<AnyCancellable>!
        var testScheduler: TestScheduler!

        beforeEach {
            inputs = PassthroughSubject()
            lastReply = nil
            cancellables = []
            testScheduler = TestScheduler()
        }

        describe("World") {

            let mockedDate = Date(timeIntervalSince1970: 2019)

            beforeEach {
                let world = World(date: { mockedDate })

                let mapping: EffectMapping = .makeInout { input, state in
                    switch input {
                    case .getDate:
                        return Effect { world in
                            Deferred { Just(world.date()) }
                                .map(Input._didGetDate)
                                .eraseToAnyPublisher()
                        }

                    case let ._didGetDate(date):
                        state = date.timeIntervalSince1970
                        return .empty
                    }
                }

                harvester = Harvester(
                    state: .init(),
                    inputs: inputs,
                    mapping: mapping,
                    world: world,
                    scheduler: testScheduler
                )

                harvester.replies
                    .sink { reply in
                        lastReply = reply
                    }
                    .store(in: &cancellables)
            }

            it("gets mocked date") {
                expect(harvester.state) == 0
                expect(lastReply).to(beNil())

                inputs.send(.getDate)
                testScheduler.advance()

                expect(harvester.state) == mockedDate.timeIntervalSince1970
                expect(lastReply?.fromState) == 0
                expect(lastReply?.toState) == mockedDate.timeIntervalSince1970
            }

        }

    }
}

private struct World
{
    let date: () -> Date
}

private enum Input
{
    case getDate
    case _didGetDate(Date)
}

private typealias State = TimeInterval
