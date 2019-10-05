import Combine
import Harvest
import Quick
import Nimble

/// Tests for `(Input, State) -> (State, Effect?)?` mapping.
class EffectMappingSpec: QuickSpec
{
    override func spec()
    {
        typealias Harvester = Harvest.Harvester<AuthInput, AuthState>
        typealias EffectMapping = Harvester.EffectMapping<Never, Never>

        let inputs = PassthroughSubject<AuthInput, Never>()
        var harvester: Harvester!
        var lastReply: Reply<AuthInput, AuthState>?
        var cancellables: Set<AnyCancellable>!
        var testScheduler: TestScheduler!

        beforeEach {
            lastReply = nil
            cancellables = []
        }

        describe("Syntax-sugar EffectMapping") {

            beforeEach {
                testScheduler = TestScheduler()

                /// Sends `.loginOK` after delay, simulating async work during `.loggingIn`.
                let loginOKPublisher =
                    Just(AuthInput.loginOK)
                        .delay(for: 1, scheduler: testScheduler)
                        .eraseToAnyPublisher()

                /// Sends `.logoutOK` after delay, simulating async work during `.loggingOut`.
                let logoutOKPublisher =
                    Just(AuthInput.logoutOK)
                        .delay(for: 1, scheduler: testScheduler!)
                        .eraseToAnyPublisher()

                let mappings: [EffectMapping] = [
                    .login    | .loggedOut  => .loggingIn  | loginOKPublisher,
                    .loginOK  | .loggingIn  => .loggedIn   | .empty,
                    .logout   | .loggedIn   => .loggingOut | logoutOKPublisher,
                    .logoutOK | .loggingOut => .loggedOut  | .empty,
                ]

                // strategy = `.merge`
                harvester = Harvester(state: .loggedOut, inputs: inputs, mapping: reduce(mappings))

                harvester.replies
                    .sink { reply in
                        lastReply = reply
                    }
                    .store(in: &cancellables)
            }

            /// - Todo: TestScheduler
            xit("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(harvester.state.value) == .loggedOut
                expect(lastReply).to(beNil())

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state.value) == .loggingIn

                // `loginOKPublisher` will automatically send `.loginOK`
                testScheduler.advanceByInterval(1)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(harvester.state.value) == .loggedIn

                inputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggedIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state.value) == .loggingOut

                // `logoutOKPublisher` will automatically send `.logoutOK`
                testScheduler.advanceByInterval(1)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state.value) == .loggedOut
            }

        }

        describe("Func-based EffectMapping") {

            beforeEach {
                testScheduler = TestScheduler()

                /// Sends `.loginOK` after delay, simulating async work during `.loggingIn`.
                let loginOKPublisher =
                    Just(AuthInput.loginOK)
                        .delay(for: 1, scheduler: testScheduler)
                        .eraseToAnyPublisher()

                /// Sends `.logoutOK` after delay, simulating async work during `.loggingOut`.
                let logoutOKPublisher =
                    Just(AuthInput.logoutOK)
                        .delay(for: 1, scheduler: testScheduler)
                        .eraseToAnyPublisher()

                let mapping: EffectMapping = { input, fromState in
                    switch (fromState, input) {
                        case (.loggedOut, .login):
                            return (.loggingIn, .init(loginOKPublisher))
                        case (.loggingIn, .loginOK):
                            return (.loggedIn, nil)
                        case (.loggedIn, .logout):
                            return (.loggingOut, .init(logoutOKPublisher))
                        case (.loggingOut, .logoutOK):
                            return (.loggedOut, nil)
                        default:
                            return nil
                    }
                }

                // strategy = `.merge`
                harvester = Harvester(state: .loggedOut, inputs: inputs, mapping: mapping)

                harvester.replies
                    .sink { reply in
                        lastReply = reply
                    }
                    .store(in: &cancellables)
            }

            /// - Todo: TestScheduler
            xit("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(harvester.state.value) == .loggedOut
                expect(lastReply).to(beNil())

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state.value) == .loggingIn

                // `loginOKPublisher` will automatically send `.loginOK`
                testScheduler.advanceByInterval(1)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(harvester.state.value) == .loggedIn

                inputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggedIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state.value) == .loggingOut

                // `logoutOKPublisher` will automatically send `.logoutOK`
                testScheduler.advanceByInterval(1)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state.value) == .loggedOut
            }

        }

        /// https://github.com/inamiy/RxAutomaton/issues/3
        describe("Additional effect should be called only once per input") {

            var effectCallCount = 0

            beforeEach {
                testScheduler = TestScheduler()
                effectCallCount = 0

                /// Sends `.loginOK` after delay, simulating async work during `.loggingIn`.
                let loginOKPublisher =
                    Future<AuthInput, Never> { callback in
                        effectCallCount += 1
                        testScheduler.schedule {
                            callback(.success(.loginOK))
                        }
//                        return testScheduler.scheduleRelative((), dueTime: 0.1, action: { () -> Disposable in
//                            callback(.success(.loginOK))
//                        })
                    }
                        .eraseToAnyPublisher()

                let mappings: [EffectMapping] = [
                    .login    | .loggedOut  => .loggingIn  | loginOKPublisher,
                    .loginOK  | .loggingIn  => .loggedIn   | .empty,
                ]

                // strategy = `.merge`
                harvester = Harvester(state: .loggedOut, inputs: inputs, mapping: reduce(mappings))

                harvester.replies
                    .sink { reply in
                        lastReply = reply
                    }
                    .store(in: &cancellables)
            }

            /// - Todo: TestScheduler
            xit("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(harvester.state.value) == .loggedOut
                expect(lastReply).to(beNil())
                expect(effectCallCount) == 0

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state.value) == .loggingIn
                expect(effectCallCount) == 1

                // `loginOKPublisher` will automatically send `.loginOK`
                testScheduler.advanceByInterval(1)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(harvester.state.value) == .loggedIn
                expect(effectCallCount) == 1
            }

        }

    }
}
