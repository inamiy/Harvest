import Combine
import Harvest
import Quick
import Nimble

/// EffectMapping tests with `strategy = .latest`.
class EffectMappingLatestSpec: QuickSpec
{
    override func spec()
    {
        typealias Harvester = Harvest.Harvester<AuthState, AuthInput>
        typealias EffectMapping = Harvester.EffectMapping<Queue, Never>

        let inputs = PassthroughSubject<AuthInput, Never>()
        var harvester: Harvester?
        var lastReply: Reply<AuthState, AuthInput>?

        describe("strategy = `.latest`") {

            var testScheduler: TestScheduler!

            beforeEach {
                testScheduler = TestScheduler()

                /// Sends `.loginOK` after delay, simulating async work during `.loggingIn`.
                let loginOKProducer =
                    Publishers.Just(AuthInput.loginOK)
                        .delay(for: 1, scheduler: testScheduler)
                        .eraseToAnyPublisher()

                /// Sends `.logoutOK` after delay, simulating async work during `.loggingOut`.
                let logoutOKProducer =
                    Publishers.Just(AuthInput.logoutOK)
                        .delay(for: 1, scheduler: testScheduler)
                        .eraseToAnyPublisher()

                let mappings: [EffectMapping] = [
                    .login    | .loggedOut  => .loggingIn  | Effect(loginOKProducer, queue: .request),
                    .loginOK  | .loggingIn  => .loggedIn   | nil,
                    .logout   | .loggedIn   => .loggingOut | Effect(logoutOKProducer, queue: .request),
                    .logoutOK | .loggingOut => .loggedOut  | nil
                ]

                harvester = Harvester(state: .loggedOut, inputs: inputs, mapping: reduce(mappings))

                _ = harvester?.replies.sink { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            /// - Todo: TestScheduler
            xit("`strategy = .latest` should not interrupt inner effects when transition fails") {
                expect(harvester?.state.value) == .loggedOut
                expect(lastReply).to(beNil())

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester?.state.value) == .loggingIn

                testScheduler.advanceByInterval(0.1)

                // fails (`loginOKProducer` will not be interrupted)
                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState).to(beNil())
                expect(harvester?.state.value) == .loggingIn

                // `loginOKProducer` will automatically send `.loginOK`
                testScheduler.advanceByInterval(1)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(harvester?.state.value) == .loggedIn
            }

        }

    }
}

// MARK: - Private

private enum Queue: EffectQueueProtocol
{
    case request

    var flattenStrategy: FlattenStrategy
    {
        return .latest
    }
}
