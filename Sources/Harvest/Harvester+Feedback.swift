import Combine

extension Harvester
{
    /// Initializer using `feedback` for injecting side-effects.
    ///
    /// - Parameters:
    ///   - state: Initial state.
    ///   - input: External "hot" input stream that `Harvester` receives.
    ///   - mapping: Simple `Mapping` that designates next state only (no additional effect).
    ///   - feedback: `Publisher` transformer that performs side-effect and emits next input.
    public convenience init<Inputs: Publisher>(
        state initialState: State,
        inputs inputSignal: Inputs,
        mapping: @escaping Mapping,
        feedback: Feedback<Reply<Input, State>.Success, Input>
        )
        where Inputs.Output == Input, Inputs.Failure == Never
    {
        self.init(
            state: initialState,
            inputs: inputSignal,
            makeSignals: { from -> MakeSignals in
                let mapped = from
                    .map { input, fromState in
                        return (input, fromState, mapping(input, fromState))
                    }

                let replies = mapped
                    .map { input, fromState, mapped -> Reply<Input, State> in
                        if let toState = mapped {
                            return .success((input, fromState, toState))
                        }
                        else {
                            return .failure((input, fromState))
                        }
                    }
                    .share()
                    .eraseToAnyPublisher()

                let effects = feedback.transform(replies.compactMap { $0.success }.eraseToAnyPublisher())

                return (replies, effects)
            }
        )
    }
}
