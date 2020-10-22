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
    ///   - inputs: External "hot" input stream that `Harvester` receives.
    ///   - mapping: Simple `Mapping` that designates next state only (no additional effect).
    ///   - scheduler: Scheduler for next inputs from `Effect`. (NOTE: This should be on the same thread as `inputs`)
    ///   - options: `scheduler` options.
    public convenience init<Inputs: Publisher, S: Scheduler>(
        state initialState: State,
        inputs: Inputs,
        mapping: Mapping,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    )
        where Inputs.Output == Input, Inputs.Failure == Never
    {
        self.init(
            state: initialState,
            inputs: inputs,
            mapping: EffectMapping { input, state, world in
                mapping.run(input, state).map { ($0, Effect<Input, BasicEffectQueue, Never>.empty) }
            },
            world: (),
            scheduler: scheduler,
            options: options
        )
    }

    /// Initializer using `EffectMapping`.
    ///
    /// - Parameters:
    ///   - state: Initial state.
    ///   - effect: Initial effect.
    ///   - inputs: External "hot" input stream that `Harvester` receives.
    ///   - mapping: `EffectMapping` that designates next state and also generates additional effect.
    ///   - world: External real-world state dependency that interacts with `Effect`s.
    ///   - scheduler: Scheduler for next inputs from `Effect`. (NOTE: This should be on the same thread as `inputs`)
    ///   - options: `scheduler` options.
    public convenience init<World, Inputs: Publisher, Queue: EffectQueueProtocol, EffectID, S: Scheduler>(
        state initialState: State,
        effect initialEffect: Effect<Input, Queue, EffectID> = .empty,
        inputs: Inputs,
        mapping: EffectMapping<World, Queue, EffectID>,
        world: World,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    )
        where Inputs.Output == Input, Inputs.Failure == Never
    {
        self.init(
            state: initialState,
            inputs: inputs,
            makePublishers: { from -> RepliesAndEffects in
                let mapped = from
                    .map { input, fromState in
                        return (input, fromState, mapping.run(input, fromState, world))
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
                        guard let (_, effect) = mapped else { return .empty }
                        return effect
                    }
                    .prepend(initialEffect)
                    .share()

                let tasks = effects.map { $0.tasks }
                    .flatMap(Publishers.Sequence.init(sequence:))

                let cancels = effects.map { $0.cancels }
                    .flatMap(Publishers.Sequence.init(sequence:))

                let effectInputs = Publishers.MergeMany(
                    Queue.allCases.map { queue in
                        tasks
                            .filter { $0.queue == queue }
                            .flatMap(queue.flattenStrategy) { task -> AnyPublisher<Input, Never> in
                                guard let publisherID = task.id else {
                                    return task.publisher
                                }

                                let until = cancels
                                    .filter { $0(publisherID) }
                                    .map { _ in }

                                return task.publisher
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
        inputs: Inputs,
        makePublishers: (AnyPublisher<(Input, State), Never>) -> RepliesAndEffects,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    )
        where Inputs.Output == Input, Inputs.Failure == Never
    {
        self._state = Published(initialValue: initialState)

        let effectInputs = PassthroughSubject<Input, Never>()

        // NOTE:
        // `inputs` synchronously updates `self.state` without delay (e.g. for UI update),
        // so it should not use `scheduler`.
        let mapped = Publishers.Merge(
            inputs,
            effectInputs.receive(on: scheduler, options: options)
        )
            .map { [unowned self] input -> (Input, State) in
                let fromState = self.state
                return (input, fromState)
            }
            .eraseToAnyPublisher()

        let (replies, effects) = makePublishers(mapped)

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

        inputs
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
    internal typealias RepliesAndEffects = (
        replies: AnyPublisher<Reply<Input, State>, Never>,
        effects: AnyPublisher<Input, Never>
    )
}

// MARK: - Public

extension Harvester
{
    /// `Reply` publisher that notifies either `.success` or `.failure` of state-transition on every input.
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

// MARK: - Void World Initializer

extension Harvester
{
    public convenience init<Inputs: Publisher, Queue: EffectQueueProtocol, EffectID, S: Scheduler>(
        state initialState: State,
        effect initialEffect: Effect<Input, Queue, EffectID> = .empty,
        inputs: Inputs,
        mapping: EffectMapping<Void, Queue, EffectID>,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    )
        where Inputs.Output == Input, Inputs.Failure == Never
    {
        self.init(
            state: initialState,
            inputs: inputs,
            mapping: mapping,
            world: (),
            scheduler: scheduler,
            options: options
        )
    }
}
