import Combine
import Harvest
import Quick
import Nimble
import Thresher

class TerminatingSpec: QuickSpec
{
    override func spec()
    {
        typealias Harvester = Harvest.Harvester<MyInput, MyState>
        typealias EffectMapping = Harvester.EffectMapping<BasicEffectQueue, Never>

        var inputs: PassthroughSubject<MyInput, Never>!
        var harvester: Harvester!
        var lastReply: Reply<MyInput, MyState>?
        var lastRepliesCompletion: Subscribers.Completion<Never>?
        var cancellables: Set<AnyCancellable>!

        /// Flag for internal effect `sendInput1And2AfterDelay` disposed.
//        var effectDisposed: Bool?

        var testScheduler: TestScheduler!

        beforeEach {
            inputs = PassthroughSubject()
            lastReply = nil
            lastRepliesCompletion = nil
            cancellables = []
            testScheduler = TestScheduler()
        }

        describe("Deinit") {

            beforeEach {
                let sendInput1And2AfterDelay: AnyPublisher<MyInput, Never> = Just(MyInput.input1)
                    .delay(for: 1, scheduler: testScheduler)
                    .append(
                        Just(MyInput.input1)
                            .delay(for: 2, scheduler: testScheduler)
                    )
                    .eraseToAnyPublisher()

                let mappings: [EffectMapping] = [
                    .input0 | .state0 => .state1 | sendInput1And2AfterDelay,
                    .input1 | .state1 => .state2 | .empty,
                    .input2 | .state2 => .state0 | .empty
                ]

                // strategy = `.merge`
                harvester = Harvester(state: .state0, inputs: inputs, mapping: reduce(mappings))

                harvester.replies
                    .sink(
                        receiveCompletion: { completion in
                            lastRepliesCompletion = completion
                        },
                        receiveValue: { reply in
                            lastReply = reply
                        }
                    )
                    .store(in: &cancellables)
            }

            describe("Harvester deinit") {

                it("harvester deinits before sending input") {
                    expect(harvester.state) == .state0
                    expect(lastReply).to(beNil())
                    expect(lastRepliesCompletion).to(beNil())

                    weak var weakHarvester = harvester
                    harvester = nil

                    expect(weakHarvester).to(beNil())
                    expect(lastReply).to(beNil())
                    expect(lastRepliesCompletion) == .finished
                }

                it("harvester deinits while sending input") {
                    expect(harvester.state) == .state0
                    expect(lastReply).to(beNil())
                    expect(lastRepliesCompletion).to(beNil())
//                    expect(effectDisposed) == false

                    inputs.send(.input0)

                    expect(harvester.state) == .state1
                    expect(lastReply?.input) == .input0
                    expect(lastRepliesCompletion).to(beNil())
//                    expect(effectDisposed) == false

                    // `sendInput1And2AfterDelay` will automatically send `.input1` at this point
                    testScheduler.advance(by: 1)

                    expect(harvester.state) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesCompletion).to(beNil())
//                    expect(effectDisposed) == false

                    weak var weakHarvester = harvester
                    harvester = nil

                    expect(weakHarvester).to(beNil())
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesCompletion).toNot(beNil())  // isCompleting
//                    expect(effectDisposed) == true

                    // If `sendInput1And2AfterDelay` is still alive, it will send `.input2` at this point,
                    // but it's already interrupted because `harvester` is deinited.
                    testScheduler.advance(by: 1)

                    // Last input should NOT change.
                    expect(lastReply?.input) == .input1
                }

            }

            // IMPORTANT:
            // While `sendInput1And2AfterDelay` is still in progress,
            // Combine will cancel on-flight inner publishers.
            describe("inputSignal sendCompleted") {

                it("inputSignal sendCompleted before sending input") {
                    expect(harvester.state) == .state0
                    expect(lastReply).to(beNil())
                    expect(lastRepliesCompletion).to(beNil())

                    inputs.send(completion: .finished)

                    expect(harvester.state) == .state0
                    expect(lastReply).to(beNil())
                    expect(lastRepliesCompletion).toNot(beNil())
                }

                it("inputSignal sendCompleted while sending input") {
                    expect(harvester.state) == .state0
                    expect(lastReply).to(beNil())
                    expect(lastRepliesCompletion).to(beNil())
//                    expect(effectDisposed) == false

                    inputs.send(.input0)

                    expect(harvester.state) == .state1
                    expect(lastReply?.input) == .input0
                    expect(lastRepliesCompletion).to(beNil())
//                    expect(effectDisposed) == false

                    // `sendInput1And2AfterDelay` will automatically send `.input1` at this point.
                    testScheduler.advance(by: 1)

                    expect(harvester.state) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesCompletion).to(beNil())
//                    expect(effectDisposed) == false

                    inputs.send(completion: .finished)

                    // IMPORTANT:
                    // While `sendInput1And2AfterDelay` is still in progress,
                    // Combine will cancel on-flight `delay(2)`.
                    //
                    // NOTE:
                    // In ReactiveSwift and RxSwift,
                    // Not completed yet because `sendInput1And2AfterDelay` is still in progress.
                    //
                    // Expected scenario in ReactiveSwift and RxSwift:
                    //
                    //     expect(harvester.state) == .state2
                    //     expect(lastReply?.input) == .input1
                    //     expect(lastRepliesCompletion).to(beNil())
                    //
                    //     // `sendInput1And2AfterDelay` will automatically send `.input2` at this point.
                    //     testScheduler.advance(by: 2)
                    //
                    //     // Last state & input should change.
                    //     expect(harvester.state) == .state0
                    //     expect(lastReply?.input) == .input2
                    //     expect(lastRepliesCompletion).toNot(beNil())

                    expect(harvester.state) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesCompletion) == .finished

                    testScheduler.advance(by: 2)

                    // Last state & input should NOT change (Combine's spec).
                    expect(harvester.state) == .state2
                    expect(lastReply?.input) == .input1
                    expect(lastRepliesCompletion) == .finished
                }

            }

        }

    }
}
