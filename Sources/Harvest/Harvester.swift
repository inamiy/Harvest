import Combine

/// Deterministic finite state machine that receives "input"
/// and with "current state" transform to "next state" & "output (additional effect)".
public final class Harvester<Input, State>
{
    /// Current state.
    @Published
    public private(set) var state: State

    private let _replies: PassthroughSubject<Reply<Input, State>, Never> = .init()
    private var _cancellables: [AnyCancellable] = []

    /// Initializer using `Mapping`.
    ///
    /// - Parameters:
    ///   - state: Initial state.
    ///   - input: External "hot" input stream that `Harvester` receives.
    ///   - mapping: Simple `Mapping` that designates next state only (no additional effect).
    ///   - scheduler: Scheduler for `inputs` and next inputs from `Effect`.
    ///   - options: `scheduler` options.
    public convenience init<Inputs: Publisher, S: Scheduler>(
        state initialState: State,
        inputs inputSignal: Inputs,
        mapping: Mapping,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    )
        where Inputs.Output == Input, Inputs.Failure == Never
    {
        self.init(
            state: initialState,
            inputs: inputSignal,
            mapping: .init { mapping.run($0, $1).map { ($0, Effect<Input, BasicEffectQueue, Never>.empty) } },
            scheduler: scheduler,
            options: options
        )
    }

    /// Initializer using `EffectMapping`.
    ///
    /// - Parameters:
    ///   - state: Initial state.
    ///   - effect: Initial effect.
    ///   - input: External "hot" input stream that `Harvester` receives.
    ///   - mapping: `EffectMapping` that designates next state and also generates additional effect.
    ///   - scheduler: Scheduler for `inputs` and next inputs from `Effect`.
    ///   - options: `scheduler` options.
    public convenience init<Inputs: Publisher, Queue: EffectQueueProtocol, EffectID, S: Scheduler>(
        state initialState: State,
        effect initialEffect: Effect<Input, Queue, EffectID> = .empty,
        inputs inputSignal: Inputs,
        mapping: EffectMapping<Queue, EffectID>,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    )
        where Inputs.Output == Input, Inputs.Failure == Never
    {
        self.init(
            state: initialState,
            inputs: inputSignal,
            makeSignals: { from -> MakeSignals in
                let mapped = from
                    .map { input, fromState in
                        return (input, fromState, mapping.run(input, fromState))
                    }
                    .share()

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
                        guard case let .some(_, effect) = mapped else { return .empty }
                        return effect
                    }
                    .prepend(initialEffect)
                    .share()

                let publishers = effects.compactMap { $0.publisher }
                let cancels = effects.compactMap { $0.cancel }

                let effectInputs = Publishers.MergeMany(
                    Queue.allCases.map { queue in
                        publishers
                            .filter { $0.queue == queue }
                            .flatMap(queue.flattenStrategy) { publisher -> AnyPublisher<Input, Never> in
                                guard let publisherID = publisher.id else {
                                    return publisher.publisher
                                }

                                let until = cancels
                                    .filter { $0(publisherID) }
                                    .map { _ in }

                                return publisher.publisher
                                    .prefix(untilOutputFrom: until)
                                    .eraseToAnyPublisher()
                            }
                    }
                )
                    .eraseToAnyPublisher()

                return (replies, effectInputs)
            },
            scheduler: scheduler,
            options: options
        )
    }

    internal init<Inputs: Publisher, S: Scheduler>(
        state initialState: State,
        inputs inputSignal: Inputs,
        makeSignals: (AnyPublisher<(Input, State), Never>) -> MakeSignals,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    )
        where Inputs.Output == Input, Inputs.Failure == Never
    {
        self._state = Published(initialValue: initialState)

        let effectInputs = PassthroughSubject<Input, Never>()

        let mapped = Publishers.Merge(inputSignal, effectInputs)
            .receive(on: scheduler, options: options)
            .map { [unowned self] input -> (Input, State) in
                let fromState = self.state
                return (input, fromState)
            }
            .eraseToAnyPublisher()

        let (replies, effects) = makeSignals(mapped)

        replies.compactMap { $0.toState }
            .sink { [unowned self] state in
                self.state = state
            }
            .store(in: &self._cancellables)

        replies.sink(receiveValue: self._replies.send)
            .store(in: &self._cancellables)

        let effectCancellable = effects
            .subscribe(effectInputs)

        effectCancellable
            .store(in: &self._cancellables)

        inputSignal
            .sink(receiveCompletion: { [_replies] _ in
                effectCancellable.cancel()
                _replies.send(completion: .finished)
                effectInputs.send(completion: .finished)
            }, receiveValue: { _ in })
            .store(in: &self._cancellables)
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
    /// `Reply` signal that notifies either `.success` or `.failure` of state-transition on every input.
    public var replies: AnyPublisher<Reply<Input, State>, Never>
    {
        AnyPublisher(self._replies)
    }
}

extension Harvester: ObservableObject
{
    public var objectWillChange: Published<State>.Publisher
    {
        self.$state
    }
}
