import Combine
import Harvest
import Quick
import Nimble

/// Tests for `(State, Input) -> State?` mapping.
class MappingSpec: QuickSpec
{
    override func spec()
    {
        typealias Harvester = Harvest.Harvester<AuthState, AuthInput>
        typealias Mapping = Harvester.Mapping

        let inputs = PassthroughSubject<AuthInput, Never>()
        var harvester: Harvester!
        var lastReply: Reply<AuthState, AuthInput>?

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
                harvester = Harvester(state: .loggedOut, inputs: inputs, mapping: reduce(mappings))

                _ = harvester.replies.sink { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(harvester.state.value) == .loggedOut
                expect(lastReply).to(beNil())

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state.value) == .loggingIn

                inputs.send(.loginOK)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(harvester.state.value) == .loggedIn

                inputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggedIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state.value) == .loggingOut

                inputs.send(.logoutOK)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state.value) == .loggedOut
            }

            it("`LoggedOut => LoggingIn ==(ForceLogout)==> LoggingOut => LoggedOut` succeed") {
                expect(harvester.state.value) == .loggedOut
                expect(lastReply).to(beNil())

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state.value) == .loggingIn

                inputs.send(.forceLogout)

                expect(lastReply?.input) == .forceLogout
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state.value) == .loggingOut

                // fails
                inputs.send(.loginOK)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState).to(beNil())
                expect(harvester.state.value) == .loggingOut

                // fails
                inputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState).to(beNil())
                expect(harvester.state.value) == .loggingOut

                inputs.send(.logoutOK)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state.value) == .loggedOut
            }

        }

        describe("Func-based Mapping") {

            beforeEach {
                let mapping: Mapping = { fromState, input in
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

                harvester = Harvester(state: .loggedOut, inputs: inputs, mapping: mapping)

                _ = harvester.replies.sink { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`LoggedOut => LoggingIn => LoggedIn => LoggingOut => LoggedOut` succeed") {
                expect(harvester.state.value) == .loggedOut
                expect(lastReply).to(beNil())

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state.value) == .loggingIn

                inputs.send(.loginOK)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(harvester.state.value) == .loggedIn

                inputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggedIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state.value) == .loggingOut

                inputs.send(.logoutOK)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state.value) == .loggedOut
            }

            it("`LoggedOut => LoggingIn ==(ForceLogout)==> LoggingOut => LoggedOut` succeed") {
                expect(harvester.state.value) == .loggedOut
                expect(lastReply).to(beNil())

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state.value) == .loggingIn

                inputs.send(.forceLogout)

                expect(lastReply?.input) == .forceLogout
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggingOut
                expect(harvester.state.value) == .loggingOut

                // fails
                inputs.send(.loginOK)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState).to(beNil())
                expect(harvester.state.value) == .loggingOut

                // fails
                inputs.send(.logout)

                expect(lastReply?.input) == .logout
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState).to(beNil())
                expect(harvester.state.value) == .loggingOut

                inputs.send(.logoutOK)

                expect(lastReply?.input) == .logoutOK
                expect(lastReply?.fromState) == .loggingOut
                expect(lastReply?.toState) == .loggedOut
                expect(harvester.state.value) == .loggedOut
            }

        }
    }
}
