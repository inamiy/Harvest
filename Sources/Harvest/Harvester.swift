import Combine

/// Deterministic finite state machine that receives "input"
/// and with "current state" transform to "next state" & "output (additional effect)".
public final class Harvester<Input, State>
{
    private let _state: CurrentValueSubject<State, Never>
    private let _replies: PassthroughSubject<Reply<Input, State>, Never> = .init()
    private let _cancelBag = CancelBag()

    /// Initializer using `Mapping`.
    ///
    /// - Parameters:
    ///   - state: Initial state.
    ///   - input: External "hot" input stream that `Harvester` receives.
    ///   - mapping: Simple `Mapping` that designates next state only (no additional effect).
    public convenience init<Inputs: Publisher>(
        state initialState: State,
        inputs inputSignal: Inputs,
        mapping: @escaping Mapping
        )
        where Inputs.Output == Input, Inputs.Failure == Never
    {
        self.init(
            state: initialState,
            inputs: inputSignal,
            mapping: { mapping($0, $1).map { ($0, Effect<Input, Never, Never>.none) } }
        )
    }

    /// Initializer using `EffectMapping`.
    ///
    /// - Parameters:
    ///   - state: Initial state.
    ///   - effect: Initial effect.
    ///   - input: External "hot" input stream that `Harvester` receives.
    ///   - mapping: `EffectMapping` that designates next state and also generates additional effect.
    public convenience init<Inputs: Publisher, Queue: EffectQueueProtocol, EffectID>(
        state initialState: State,
        effect initialEffect: Effect<Input, Queue, EffectID> = .none,
        inputs inputSignal: Inputs,
        mapping: @escaping EffectMapping<Queue, EffectID>
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
                        if let (toState, _) = mapped {
                            return .success((input, fromState, toState))
                        }
                        else {
                            return .failure((input, fromState))
                        }
                    }
                    .eraseToAnyPublisher()

                let effects = mapped
                    .compactMap { _, _, mapped -> Effect<Input, Queue, EffectID> in
                        guard case let .some(_, effect) = mapped else { return .none }
                        return effect
                    }
                    .prepend(initialEffect)
                    .eraseToAnyPublisher()

                let publishers = effects.compactMap { $0.publisher }
                let cancels = effects.compactMap { $0.cancel }

                let effectInputs = Publishers.MergeMany(
                    EffectQueue<Queue>.allCases.map { queue in
                        publishers
                            .filter { $0.queue == queue }
                            .flatMap(queue.flattenStrategy) { publisher -> AnyPublisher<Input, Never> in
                                guard let publisherID = publisher.id else {
                                    return publisher.publisher
                                }

                                let until = cancels.filter { $0(publisherID) }.map { _ in }
                                return publisher.publisher.prefix(untilOutputFrom: until)
                                    .eraseToAnyPublisher()
                            }
                    }
                )
                    .eraseToAnyPublisher()

                return (replies, effectInputs)
            }
        )
    }

    internal init<Inputs: Publisher>(
        state initialState: State,
        inputs inputSignal: Inputs,
        makeSignals: (AnyPublisher<(Input, State), Never>) -> MakeSignals
        )
        where Inputs.Output == Input, Inputs.Failure == Never
    {
        let stateProperty = CurrentValueSubject<State, Never>(initialState)
        self._state = stateProperty

        let effectInputs = PassthroughSubject<Input, Never>()

        let mergedInputs = Publishers.Merge(inputSignal, effectInputs)

        let mapped = mergedInputs
            .map { input -> (Input, State) in
                let fromState = stateProperty.value    // TODO: Use withLatestFrom when supported
                return (input, fromState)
            }
            .share()
            .eraseToAnyPublisher()

        let (replies, effects) = makeSignals(mapped)

        replies.compactMap { $0.toState }
            .assign(to: \.value, on: self._state)
            .cancelled(by: self._cancelBag)

        replies.sink(receiveValue: self._replies.send)
            .cancelled(by: self._cancelBag)

        let effectCancellable = effects.subscribe(effectInputs)

        effectCancellable
            .cancelled(by: self._cancelBag)

        inputSignal
            .sink(receiveCompletion: { [_replies] _ in
                effectCancellable.cancel()
                _replies.send(completion: .finished)
                effectInputs.send(completion: .finished)
            }, receiveValue: { _ in })
            .cancelled(by: self._cancelBag)
    }

    deinit
    {
        self._replies.send(completion: .finished)
    }
}

extension Harvester
{
    internal typealias MakeSignals = (
        replies: AnyPublisher<Reply<Input, State>, Never>,
        effects: AnyPublisher<Input, Never>
    )
}

// MARK: - Public

extension Harvester
{
    /// - Todo: `some Publisher & HasCurrentValue <.Output == State, .Failure == Never>` in future Swift
    public var state: Property<State>
    {
        return Property(self._state)
    }

    /// `Reply` signal that notifies either `.success` or `.failure` of state-transition on every input.
    /// - Todo: `some Publisher <.Output == Reply<Input, State>, .Failure == Never>` in future Swift
    public var replies: AnyPublisher<Reply<Input, State>, Never>
    {
        return AnyPublisher(self._replies)
    }
}

extension Harvester {

    /// Basic state-transition function type.
    public typealias Mapping = (Input, State) -> State?

    /// Transducer (input & output) mapping with
    /// **cold publisher** (additional effect) as output,
    /// which may emit next input values for continuous state-transitions.
    public typealias EffectMapping<Queue, EffectID> = (Input, State) -> (State, Effect<Input, Queue, EffectID>)?
        where Queue: EffectQueueProtocol, EffectID: Equatable

}
