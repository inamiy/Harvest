import Combine

/// Managed side-effect that interacts with `World` to create `publisher`,
/// enqueueing on `Queue` to perform arbitrary `Queue.flattenStrategy`.
///
/// This type also handles effect cancellation via `cancel`.
///
/// - Note: Set `ID = Never` if not interested in cancellation.
public struct Effect<Input, Queue, ID>
    where Queue: EffectQueueProtocol, ID: Equatable
{
    internal let kinds: [Kind]

    internal init(kinds: [Kind] = [])
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
            case let .task(task):
                return .task(.init(
                    publisher: task.publisher.map(f).eraseToAnyPublisher(),
                    queue: task.queue,
                    id: task.id
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
            case let .task(task):
                return .task(.init(
                    publisher: task.publisher,
                    queue: f(task.queue),
                    id: task.id
                ))

            case let .cancel(predicate):
                return .cancel(predicate)
            }
        })
    }

    public func transformID<WholeID>(
        _ inject: @escaping (ID) -> WholeID,
        _ tryGet: @escaping (WholeID) -> ID?
    ) -> Effect<Input, Queue, WholeID>
    {
        .init(kinds: self.kinds.map { kind in
            switch kind {
            case let .task(task):
                return .task(.init(
                    publisher: task.publisher,
                    queue: task.queue,
                    id: task.id.map(inject)
                ))
            case let .cancel(predicate):
                return .cancel {
                    tryGet($0).map(predicate) ?? false
                }
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
    internal enum Kind
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

    internal struct Task
    {
        /// "Cold" stream that runs side-effect and sends next `Input`.
        internal let publisher: AnyPublisher<Input, Never>

        /// Effect queue that associates with `publisher` to perform various `flattenStrategy`s.
        internal let queue: Queue

        /// Effect identifier for cancelling running `publisher`.
        internal let id: ID?

        internal init<P: Publisher>(
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

// MARK: - toEffect / toResultEffect

extension Publisher where Failure == Never
{
    public func toEffect<Queue, ID>(
        queue: Queue = .defaultEffectQueue,
        id: ID? = nil
    ) -> Effect<Output, Queue, ID>
    {
        Effect(self, queue: queue, id: id)
    }
}

extension Publisher
{
    public func toResultEffect<Queue, ID>(
        queue: Queue = .defaultEffectQueue,
        id: ID? = nil
    ) -> Effect<Result<Output, Failure>, Queue, ID>
    {
        self.map(Result.success)
            .catch { Just(.failure($0)) }
            .toEffect(queue: queue, id: id)
    }
}
