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
    internal let kind: Kind

    internal init(kind: Kind)
    {
        self.kind = kind
    }

    /// Managed side-effect that enqueues `publisher` on `EffectQueue`
    /// to perform arbitrary `Queue.flattenStrategy`.
    ///
    /// - Parameters:
    ///   - producer: "Cold" stream that runs side-effect and sends next `Input`.
    ///   - queue: Uses custom queue, or set `nil` as default queue to use `merge` strategy.
    ///   - id: Effect identifier for cancelling running `producer`.
    public init(
        _ publisher: AnyPublisher<Input, Never>,
        queue: Queue = .defaultEffectQueue,
        id: ID? = nil
        )
    {
        self.init(kind: .publisher(
            _Publisher(
                publisher: publisher,
                queue: queue,
                id: id
            )
        ))
    }

    /// Cancels running `publisher` by specifying `identifiers`.
    public static func cancel(
        _ identifiers: @escaping (ID) -> Bool
        ) -> Effect<Input, Queue, ID>
    {
        return Effect(kind: .cancel(identifiers))
    }

    /// Cancels running `publisher` by specifying `identifier`.
    public static func cancel(
        _ identifier: ID
        ) -> Effect<Input, Queue, ID>
    {
        return Effect(kind: .cancel { $0 == identifier })
    }

    /// Empty side-effect.
    public static var none: Effect<Input, Queue, ID>
    {
        return Effect(.empty)
    }

    // MARK: - Functor

    public func mapInput<Input2>(_ f: @escaping (Input) -> Input2) -> Effect<Input2, Queue, ID>
    {
        switch self.kind {
        case let .publisher(publisher):
            return .init(kind: .publisher(Effect<Input2, Queue, ID>._Publisher(
                publisher: publisher.publisher.map(f).eraseToAnyPublisher(),
                queue: publisher.queue,
                id: publisher.id
            )))
        case let .cancel(predicate):
            return .cancel(predicate)
        }
    }

    public func mapQueue<Queue2>(_ f: @escaping (Queue) -> Queue2) -> Effect<Input, Queue2, ID>
    {
        switch self.kind {
        case let .publisher(publisher):
            return .init(kind: .publisher(Effect<Input, Queue2, ID>._Publisher(
                publisher: publisher.publisher,
                queue: f(publisher.queue),
                id: publisher.id
            )))
        case let .cancel(predicate):
            return .cancel(predicate)
        }
    }

    public func invmapID<ID2>(
        _ forward: @escaping (ID) -> ID2,
        _ backword: @escaping (ID2) -> ID
    ) -> Effect<Input, Queue, ID2>
    {
        switch self.kind {
        case let .publisher(publisher):
            return .init(kind: .publisher(Effect<Input, Queue, ID2>._Publisher(
                publisher: publisher.publisher,
                queue: publisher.queue,
                id: publisher.id.map(forward)
            )))
        case let .cancel(predicate):
            return .cancel { predicate(backword($0)) }
        }
    }
}

extension Effect: ExpressibleByNilLiteral
{
    public init(nilLiteral: ())
    {
        self = .none
    }
}

extension Effect
{
    internal var publisher: _Publisher?
    {
        guard case let .publisher(value) = self.kind else { return nil }
        return value
    }

    internal var cancel: ((ID) -> Bool)?
    {
        guard case let .cancel(value) = self.kind else { return nil }
        return value
    }
}

// MARK: - Inner Types

extension Effect
{
    internal enum Kind
    {
        case publisher(_Publisher)
        case cancel((ID) -> Bool)
    }

    internal struct _Publisher
    {
        /// "Cold" stream that runs side-effect and sends next `Input`.
        internal let publisher: AnyPublisher<Input, Never>

        /// Effect queue that associates with `publisher` to perform various `flattenStrategy`s.
        internal let queue: Queue

        /// Effect identifier for cancelling running `publisher`.
        internal let id: ID?
    }
}
