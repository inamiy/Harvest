import Combine
import Harvest
import Quick
import Nimble

/// Tests for `(Input, State) -> State?` mapping.
class MappingSpec: QuickSpec
{
    override func spec()
    {
        typealias Harvester = Harvest.Harvester<AuthInput, AuthState>
        typealias Mapping = Harvester.Mapping

        var inputs: PassthroughSubject<AuthInput, Never>!
        var harvester: Harvester!
        var lastReply: Reply<AuthInput, AuthState>?
        var cancellables: Set<AnyCancellable>!

        beforeEach {
            inputs = PassthroughSubject()
            lastReply = nil
            cancellables = []
        }

        describe("Syntax-sugar Mapping") {

            beforeEach {

                // NOTE: predicate style i.e. `T -> Bool` is also available.
                let canForceLogout: (AuthState) -> Bool = [AuthState.loggingIn, .loggedIn].contains

                let mappings: [Mapping] = [
                    .login    | .loggedOut  => .loggingIn,
                    .loginOK  | .loggingIn  => .loggedIn,
                    .logout   | .loggedIn   => .loggingOut,
                    .logoutOK | .loggingOut => .loggedOut,

                    .forceLogout | canForceLogout => .loggingOut
                ]

                // NOTE: Use `concat` to combine all mappings.
                harvester = Harvester(
                    state: .loggedOut,
                    inputs: inputs,
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

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state) == .loggingIn

                inputs.send(.loginOK)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(harvester.state) == .loggedIn

                inputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggedIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state) == .loggingOut

                inputs.send(.logoutOK)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state) == .loggedOut
            }

            it("`LoggedOut => LoggingIn ==(ForceLogout)==> LoggingOut => LoggedOut` succeed") {
                expect(harvester.state) == .loggedOut
                expect(lastReply).to(beNil())

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state) == .loggingIn

                inputs.send(.forceLogout)

                expect(lastReply?.input) == .forceLogout
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state) == .loggingOut

                // fails
                inputs.send(.loginOK)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState).to(beNil())
                expect(harvester.state) == .loggingOut

                // fails
                inputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState).to(beNil())
                expect(harvester.state) == .loggingOut

                inputs.send(.logoutOK)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state) == .loggedOut
            }

        }

        describe("Func-based Mapping") {

            beforeEach {
                let mapping: Mapping = .init { input, fromState in
                    switch (fromState, input) {
                        case (.loggedOut, .login):
                            return .loggingIn
                        case (.loggingIn, .loginOK):
                            return .loggedIn
                        case (.loggedIn, .logout):
                            return .loggingOut
                        case (.loggingOut, .logoutOK):
                            return .loggedOut

                        // ForceLogout
                        case (.loggingIn, .forceLogout), (.loggedIn, .forceLogout):
                            return .loggingOut

                        default:
                            return nil
                    }
                }

                harvester = Harvester(
                    state: .loggedOut,
                    inputs: inputs,
                    mapping: mapping,
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

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state) == .loggingIn

                inputs.send(.loginOK)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(harvester.state) == .loggedIn

                inputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggedIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state) == .loggingOut

                inputs.send(.logoutOK)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state) == .loggedOut
            }

            it("`LoggedOut => LoggingIn ==(ForceLogout)==> LoggingOut => LoggedOut` succeed") {
                expect(harvester.state) == .loggedOut
                expect(lastReply).to(beNil())

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state) == .loggingIn

                inputs.send(.forceLogout)

                expect(lastReply?.input) == .forceLogout
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state) == .loggingOut

                // fails
                inputs.send(.loginOK)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState).to(beNil())
                expect(harvester.state) == .loggingOut

                // fails
                inputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState).to(beNil())
                expect(harvester.state) == .loggingOut

                inputs.send(.logoutOK)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state) == .loggedOut
            }

        }

        describe("Inout-Func-based Mapping") {

            beforeEach {
                let mapping: Mapping = .makeInout { input, state in
                    switch (state, input) {
                    case (.loggedOut, .login):
                        state = .loggingIn
                    case (.loggingIn, .loginOK):
                        state = .loggedIn
                    case (.loggedIn, .logout):
                        state = .loggingOut
                    case (.loggingOut, .logoutOK):
                        state = .loggedOut

                    // ForceLogout
                    case (.loggingIn, .forceLogout), (.loggedIn, .forceLogout):
                        state = .loggingOut

                    default:
                        break
                    }
                }

                harvester = Harvester(
                    state: .loggedOut,
                    inputs: inputs,
                    mapping: mapping,
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

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state) == .loggingIn

                inputs.send(.loginOK)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(harvester.state) == .loggedIn

                inputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggedIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state) == .loggingOut

                inputs.send(.logoutOK)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state) == .loggedOut
            }

            it("`LoggedOut => LoggingIn ==(ForceLogout)==> LoggingOut => LoggedOut` succeed") {
                expect(harvester.state) == .loggedOut
                expect(lastReply).to(beNil())

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state) == .loggingIn

                inputs.send(.forceLogout)

                expect(lastReply?.input) == .forceLogout
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state) == .loggingOut

                // fails
                inputs.send(.loginOK)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingOut
                //expect(lastReply?.toState).to(beNil())
                expect(lastReply?.toState) == .loggingOut // Transition succeeds without changing state.
                expect(harvester.state) == .loggingOut

                // fails
                inputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggingOut
                //expect(lastReply?.toState).to(beNil())
                expect(lastReply?.toState) == .loggingOut // Transition succeeds without changing state.
                expect(harvester.state) == .loggingOut

                inputs.send(.logoutOK)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state) == .loggedOut
            }

        }
    }
}
