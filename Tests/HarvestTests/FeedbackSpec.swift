import Combine
import Harvest
import Quick
import Nimble

class FeedbackSpec: QuickSpec
{
    override func spec()
    {
        typealias Harvester = Harvest.Harvester<AuthInput, AuthState>
        typealias Mapping = Harvester.Mapping
        typealias Feedback = Harvest.Feedback<Reply<AuthInput, AuthState>.Success, AuthInput>

        let inputs = PassthroughSubject<AuthInput, Never>()
        var harvester: Harvester?
        var lastReply: Reply<AuthInput, AuthState>?
        var testScheduler: TestScheduler!

        describe("Feedback") {

            beforeEach {
                testScheduler = TestScheduler()

                /// Sends `.loginOK` after delay, simulating async work during `.loggingIn`.
                let loginOKProducer =
                    Just(AuthInput.loginOK)
                        .delay(for: 1, scheduler: testScheduler)
                        .eraseToAnyPublisher()

                /// Sends `.logoutOK` after delay, simulating async work during `.loggingOut`.
                let logoutOKProducer =
                    Just(AuthInput.logoutOK)
                        .delay(for: 1, scheduler: testScheduler)
                        .eraseToAnyPublisher()

                let mappings: [Mapping] = [
                    .login    | .loggedOut  => .loggingIn,
                    .loginOK  | .loggingIn  => .loggedIn,
                    .logout   | .loggedIn   => .loggingOut,
                    .logoutOK | .loggingOut => .loggedOut
                ]

                harvester = Harvester(
                    state: .loggedOut,
                    inputs: inputs,
                    mapping: reduce(mappings),
                    feedback: reduce([
                        Feedback(
                            filter: { $0.input == AuthInput.login },
                            produce: { _ in loginOKProducer }
                        ),
                        Feedback(
                            filter: { $0.input == AuthInput.logout },
                            produce: { _ in logoutOKProducer }
                        )
                    ])
                )

                _ = harvester?.replies.sink { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            /// - Todo: TestScheduler
            xit("`LoggedOut (auto) => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(harvester?.state.value) == .loggedOut
                expect(lastReply).to(beNil())

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester?.state.value) == .loggingIn

                // `loginOKProducer` will automatically send `.loginOK`
                testScheduler.advanceByInterval(1)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(harvester?.state.value) == .loggedIn

                inputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggedIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester?.state.value) == .loggingOut

                // `logoutOKProducer` will automatically send `.logoutOK`
                testScheduler.advanceByInterval(1)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester?.state.value) == .loggedOut
            }

        }

    }
}
