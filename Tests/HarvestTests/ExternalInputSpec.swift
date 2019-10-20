import Combine
import Harvest
import Quick
import Nimble
import Thresher

/// Tests for using `ExternalAuthInput` instead of `AuthInput`.
class ExternalInputSpec: QuickSpec
{
    override func spec()
    {
        typealias Harvester = Harvest.Harvester<AuthInput, AuthState>
        typealias EffectMapping = Harvester.EffectMapping<RequestEffectQueue, Never>

        var externalInputs: PassthroughSubject<ExternalAuthInput, Never>!   // NOTE: Using subset `ExternalAuthInput`
        var harvester: Harvester!
        var lastReply: Reply<AuthInput, AuthState>?
        var cancellables: Set<AnyCancellable>!
        var testScheduler: TestScheduler!

        beforeEach {
            externalInputs = PassthroughSubject()
            lastReply = nil
            cancellables = []
            testScheduler = TestScheduler()
        }

        describe("ExternalAuthInput") {

            beforeEach {
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

                // NOTE: predicate style i.e. `T -> Bool` is also available.
                let canForceLogout: (AuthState) -> Bool = [AuthState.loggingIn, .loggedIn].contains

                let mappings: [EffectMapping] = [
                    .login    | .loggedOut  => .loggingIn  | Effect(loginOKPublisher, queue: .request),
                    .loginOK  | .loggingIn  => .loggedIn   | .empty,
                    .logout   | .loggedIn   => .loggingOut | Effect(logoutOKPublisher, queue: .request),
                    .logoutOK | .loggingOut => .loggedOut  | .empty,

                    .forceLogout | canForceLogout => .loggingOut | Effect(logoutOKPublisher, queue: .request)
                ]

                harvester = Harvester(
                    state: .loggedOut,
                    inputs: externalInputs.map(ExternalAuthInput.toInternal),
                    mapping: .reduce(mappings),
                    scheduler: ImmediateScheduler.shared
                )

                harvester.replies
                    .sink { reply in
                        lastReply = reply
                    }
                    .store(in: &cancellables)
            }

            it("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(harvester.state) == .loggedOut
                expect(lastReply).to(beNil())

                externalInputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state) == .loggingIn

//                inputs.send(.loginOK)     // NOTE: Can't send internal input
                testScheduler.advance(by: 1)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(harvester.state) == .loggedIn

                externalInputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggedIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state) == .loggingOut

//                inputs.send(.logoutOK)    // NOTE: Can't send internal input
                testScheduler.advance(by: 1)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state) == .loggedOut
            }

            it("`LoggedOut => LoggingIn ==(ForceLogout)==> LoggingOut => LoggedOut` succeed") {
                expect(harvester.state) == .loggedOut
                expect(lastReply).to(beNil())

                externalInputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state) == .loggingIn

                externalInputs.send(.forceLogout)

                expect(lastReply?.input) == .forceLogout
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state) == .loggingOut

                // fails
                externalInputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState).to(beNil())
                expect(harvester.state) == .loggingOut

                testScheduler.advance(by: 1)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state) == .loggedOut
            }

        }

    }
}
