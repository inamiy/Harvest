import Combine
import Harvest
import Quick
import Nimble
import Thresher

class FeedbackSpec: QuickSpec
{
    override func spec()
    {
        typealias Harvester = Harvest.Harvester<AuthInput, AuthState>
        typealias Mapping = Harvester.Mapping
        typealias Feedback = Harvest.Feedback<Reply<AuthInput, AuthState>.Success, AuthInput>

        var inputs: PassthroughSubject<AuthInput, Never>!
        var harvester: Harvester!
        var lastReply: Reply<AuthInput, AuthState>?
        var cancellables: Set<AnyCancellable>!
        var testScheduler: TestScheduler!

        beforeEach {
            inputs = PassthroughSubject()
            lastReply = nil
            cancellables = []
            testScheduler = TestScheduler()
        }

        describe("Feedback") {

            beforeEach {
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
                    mapping: .reduce(mappings),
                    feedback: reduce([
                        Feedback(
                            filter: { $0.input == AuthInput.login },
                            produce: { _ in loginOKProducer }
                        ),
                        Feedback(
                            filter: { $0.input == AuthInput.logout },
                            produce: { _ in logoutOKProducer }
                        )
                    ]),
                    scheduler: ImmediateScheduler.shared
                )

                harvester.replies
                    .sink { reply in
                        lastReply = reply
                    }
                    .store(in: &cancellables)
            }

            it("`LoggedOut (auto) => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(harvester.state) == .loggedOut
                expect(lastReply).to(beNil())

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state) == .loggingIn

                // `loginOKProducer` will automatically send `.loginOK`
                testScheduler.advance(by: 1)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(harvester.state) == .loggedIn

                inputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggedIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state) == .loggingOut

                // `logoutOKProducer` will automatically send `.logoutOK`
                testScheduler.advance(by: 1)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state) == .loggedOut
            }

        }

    }
}
