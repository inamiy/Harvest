import Combine
import Harvest
import Quick
import Nimble
import Thresher

/// EffectMapping tests with `strategy = .latest`.
class EffectMappingLatestSpec: QuickSpec
{
    override func spec()
    {
        typealias Harvester = Harvest.Harvester<AuthInput, AuthState>
        typealias EffectMapping = Harvester.EffectMapping<Void, RequestEffectQueue, Never>

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

        describe("strategy = `.latest`") {

            beforeEach {
                /// Sends `.loginOK` after delay, simulating async work during `.loggingIn`.
                let loginOKProducer =
                    Just(AuthInput.loginOK)
                        .delay(for: 1, scheduler: testScheduler)

                /// Sends `.logoutOK` after delay, simulating async work during `.loggingOut`.
                let logoutOKProducer =
                    Just(AuthInput.logoutOK)
                        .delay(for: 1, scheduler: testScheduler)

                let mappings: [EffectMapping] = [
                    .login    | .loggedOut  => .loggingIn  | Effect(loginOKProducer, queue: .request),
                    .loginOK  | .loggingIn  => .loggedIn   | .empty,
                    .logout   | .loggedIn   => .loggingOut | Effect(logoutOKProducer, queue: .request),
                    .logoutOK | .loggingOut => .loggedOut  | .empty
                ]

                harvester = Harvester(
                    state: .loggedOut,
                    inputs: inputs,
                    mapping: .reduce(.first, mappings),
                    scheduler: ImmediateScheduler.shared
                )

                harvester.replies
                    .sink { reply in
                        lastReply = reply
                    }
                    .store(in: &cancellables)
            }

            it("`strategy = .latest` should not interrupt inner effects when transition fails") {
                expect(harvester.state) == .loggedOut
                expect(lastReply).to(beNil())

                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggedOut
                expect(lastReply?.toState) == .loggingIn
                expect(harvester.state) == .loggingIn

                testScheduler.advance(by: 0.1)

                // fails (`loginOKProducer` will not be interrupted)
                inputs.send(.login)

                expect(lastReply?.input) == .login
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState).to(beNil())
                expect(harvester.state) == .loggingIn

                // `loginOKProducer` will automatically send `.loginOK`
                testScheduler.advance(by: 1)

                expect(lastReply?.input) == .loginOK
                expect(lastReply?.fromState) == .loggingIn
                expect(lastReply?.toState) == .loggedIn
                expect(harvester.state) == .loggedIn
            }

        }

    }
}
