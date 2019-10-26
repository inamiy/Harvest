import Combine

/// Managed side-effect that enqueues `publisher` on `EffectQueue`
/// to perform arbitrary `Queue.flattenStrategy`.
///
/// This type also handles effect cancellation via `cancel`.
///
/// - Note: Set `ID = Never` if not interested in cancellation.
public struct Effect<Input, Queue, ID>
    where Queue: EffectQueueProtocol, ID: Equatable
{
    public let kinds: [Kind]

    public init(kinds: [Kind] = [])
    {
        self.kinds = kinds
    }

    /// Managed side-effect that enqueues `publisher` on `EffectQueue`
    /// to perform arbitrary `Queue.flattenStrategy`.
    ///
    /// - Parameters:
    ///   - producer: "Cold" stream that runs side-effect and sends next `Input`.
    ///   - queue: Uses custom queue, or set `nil` as default queue to use `merge` strategy.
    ///   - id: Effect identifier for cancelling running `producer`.
    public init<P: Publisher>(
        _ publisher: P,
        queue: Queue = .defaultEffectQueue,
        id: ID? = nil
    ) where P.Output == Input, P.Failure == Never
    {
        self.init(kinds: [.task(
            Task(
                publisher: publisher,
                queue: queue,
                id: id
            )
        )])
    }

    /// Cancels running `publisher`s by specifying `identifiers`.
    public static func cancel(
        _ identifiers: @escaping (ID) -> Bool
        ) -> Effect<Input, Queue, ID>
    {
        return Effect(kinds: [.cancel(identifiers)])
    }

    /// Cancels running `publisher` by specifying `identifier`.
    public static func cancel(
        _ identifier: ID
        ) -> Effect<Input, Queue, ID>
    {
        return Effect(kinds: [.cancel { $0 == identifier }])
    }

    // MARK: - Monoid

    public static var empty: Effect<Input, Queue, ID>
    {
        return Effect()
    }

    public static func + (l: Effect, r: Effect) -> Effect
    {
        return .init(kinds: l.kinds + r.kinds)
    }

    // MARK: - Functor

    public func mapInput<Input2>(_ f: @escaping (Input) -> Input2) -> Effect<Input2, Queue, ID>
    {
        .init(kinds: self.kinds.map { kind in
            switch kind {
            case let .task(publisher):
                return .task(Effect<Input2, Queue, ID>.Task(
                    publisher: publisher.publisher.map(f).eraseToAnyPublisher(),
                    queue: publisher.queue,
                    id: publisher.id
                ))
            case let .cancel(predicate):
                return .cancel(predicate)
            }
        })
    }

    public func mapQueue<Queue2>(_ f: @escaping (Queue) -> Queue2) -> Effect<Input, Queue2, ID>
    {
        .init(kinds: self.kinds.map { kind in
            switch kind {
            case let .task(publisher):
                return .task(Effect<Input, Queue2, ID>.Task(
                    publisher: publisher.publisher,
                    queue: f(publisher.queue),
                    id: publisher.id
                ))
            case let .cancel(predicate):
                return .cancel(predicate)
            }
        })
    }

}

extension Effect
{
    internal var tasks: [Task]
    {
        self.kinds.compactMap { $0.task }
    }

    internal var cancels: [(ID) -> Bool]
    {
        self.kinds.compactMap { $0.cancel }
    }
}

// MARK: - Inner Types

extension Effect
{
    public enum Kind
    {
        case task(Task)
        case cancel((ID) -> Bool)

        internal var task: Task?
        {
            guard case let .task(value) = self else { return nil }
            return value
        }

        internal var cancel: ((ID) -> Bool)?
        {
            guard case let .cancel(value) = self else { return nil }
            return value
        }
    }

    public struct Task
    {
        /// "Cold" stream that runs side-effect and sends next `Input`.
        public let publisher: AnyPublisher<Input, Never>

        /// Effect queue that associates with `publisher` to perform various `flattenStrategy`s.
        public let queue: Queue

        /// Effect identifier for cancelling running `publisher`.
        public let id: ID?

        public init<P: Publisher>(
            publisher: P,
            queue: Queue,
            id: ID? = nil
        ) where P.Output == Input, P.Failure == Never
        {
            self.publisher = publisher.eraseToAnyPublisher()
            self.queue = queue
            self.id = id
        }
    }
}
