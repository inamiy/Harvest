import Combine

/// Managed side-effect that interacts with `World` to create `publisher`,
/// enqueueing on `Queue` to perform arbitrary `Queue.flattenStrategy`.
///
/// This type also handles effect cancellation via `cancel`.
///
/// - Note: Set `World = Void` if not interested in dependency injection.
/// - Note: Set `ID = Never` if not interested in cancellation.
public struct Effect<World, Input, Queue, ID>
    where Queue: EffectQueueProtocol, ID: Equatable
{
    public let kinds: [Kind]

    public init(kinds: [Kind] = [])
    {
        self.kinds = kinds
    }

    /// Managed side-effect that enqueues `publisher` on `Queue` to perform arbitrary `Queue.flattenStrategy`.
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
                publisher: { _ in publisher },
                queue: queue,
                id: id
            )
        )])
    }

    /// Managed side-effect that enqueues `publisher` on `Queue` to perform arbitrary `Queue.flattenStrategy`.
    ///
    /// - Parameters:
    ///   - producer: A closure from `World` to "Cold" stream that runs side-effect and sends next `Input`.
    ///   - queue: Uses custom queue, or set `nil` as default queue to use `merge` strategy.
    ///   - id: Effect identifier for cancelling running `producer`.
    public init<P: Publisher>(
        queue: Queue = .defaultEffectQueue,
        id: ID? = nil,
        _ publisher: @escaping (World) -> P
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
        ) -> Effect<World, Input, Queue, ID>
    {
        return Effect(kinds: [.cancel(identifiers)])
    }

    /// Cancels running `publisher` by specifying `identifier`.
    public static func cancel(
        _ identifier: ID
        ) -> Effect<World, Input, Queue, ID>
    {
        return Effect(kinds: [.cancel { $0 == identifier }])
    }

    // MARK: - Monoid

    public static var empty: Effect<World, Input, Queue, ID>
    {
        return Effect()
    }

    public static func + (l: Effect, r: Effect) -> Effect
    {
        return .init(kinds: l.kinds + r.kinds)
    }

    // MARK: - Functor

    public func mapInput<Input2>(_ f: @escaping (Input) -> Input2) -> Effect<World, Input2, Queue, ID>
    {
        .init(kinds: self.kinds.map { kind in
            switch kind {
            case let .task(task):
                return .task(Effect<World, Input2, Queue, ID>.Task(
                    publisher: { task.publisher($0).map(f).eraseToAnyPublisher() },
                    queue: task.queue,
                    id: task.id
                ))

            case let .cancel(predicate):
                return .cancel(predicate)
            }
        })
    }

    public func mapQueue<Queue2>(_ f: @escaping (Queue) -> Queue2) -> Effect<World, Input, Queue2, ID>
    {
        .init(kinds: self.kinds.map { kind in
            switch kind {
            case let .task(task):
                return .task(Effect<World, Input, Queue2, ID>.Task(
                    publisher: task.publisher,
                    queue: f(task.queue),
                    id: task.id
                ))

            case let .cancel(predicate):
                return .cancel(predicate)
            }
        })
    }

    public func contramapWorld<World2>(_ f: @escaping (World2) -> World) -> Effect<World2, Input, Queue, ID>
    {
        .init(kinds: self.kinds.map { kind in
            switch kind {
            case let .task(task):
                return .task(Effect<World2, Input, Queue, ID>.Task(
                    publisher: { task.publisher(f($0)) },
                    queue: task.queue,
                    id: task.id
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
        public let publisher: (World) -> AnyPublisher<Input, Never>

        /// Effect queue that associates with `publisher` to perform various `flattenStrategy`s.
        public let queue: Queue

        /// Effect identifier for cancelling running `publisher`.
        public let id: ID?

        public init<P: Publisher>(
            publisher: @escaping (World) -> P,
            queue: Queue,
            id: ID? = nil
        ) where P.Output == Input, P.Failure == Never
        {
            self.publisher = { publisher($0).eraseToAnyPublisher() }
            self.queue = queue
            self.id = id
        }
    }
}
