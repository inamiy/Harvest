import Combine

/// FRP-driven publisher transformer that is used
/// as an alternative side-effect & feedback system in `Harvester`.
///
/// - Note: `Harvester` supports `Effect` and `EffectQueue` as a primary system.
///
/// - SeeAlso: https://github.com/Babylonpartners/ReactiveFeedback
/// - SeeAlso: https://github.com/NoTests/RxFeedback
public struct Feedback<Input, Output>
{
    internal let transform: (AnyPublisher<Input, Never>) -> AnyPublisher<Output, Never>

    public init(transform: @escaping (AnyPublisher<Input, Never>) -> AnyPublisher<Output, Never>)
    {
        self.transform = transform
    }

    public init(produce: @escaping (Input) -> AnyPublisher<Output, Never>)
    {
        self.init(transform: { $0 }, produce: produce)
    }

    public init<U>(
        transform: @escaping (AnyPublisher<Input, Never>) -> AnyPublisher<U, Never>,
        produce: @escaping (U) -> AnyPublisher<Output, Never>,
        strategy: FlattenStrategy = .latest
        )
    {
        self.transform = {
            transform($0)
                .flatMap(strategy) { produce($0) }
                .eraseToAnyPublisher()
        }
    }

    /// Either `produce` or sends `.empty` based on `tryGet`.
    public init<U>(
        tryGet: @escaping (Input) -> U?,
        produce: @escaping (U) -> AnyPublisher<Output, Never>
        )
    {
        self.init(
            transform: { $0.map(tryGet).eraseToAnyPublisher() },
            produce: { $0.map(produce) ?? .empty }
        )
    }

    public init(
        filter: @escaping (Input) -> Bool,
        produce: @escaping (Input) -> AnyPublisher<Output, Never>
        )
    {
        self.init(
            transform: { $0.filter(filter).eraseToAnyPublisher() },
            produce: produce
        )
    }
}

// MARK: - Functions

/// Folds multiple `Feedback`s into one.
public func reduce<Input, Output>(_ feedbacks: [Feedback<Input, Output>]) -> Feedback<Input, Output>
{
    return Feedback<Input, Output>(transform: { publisher in
        Publishers.MergeMany(feedbacks.map { $0.transform(publisher) })
            .eraseToAnyPublisher()
    })
}
