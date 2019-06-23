import Combine

/// Managed side-effect that enqueues `publisher` on `EffectQueue`
/// to perform arbitrary `Queue.flattenStrategy`.
///
/// This type also handles effect cancellation via `cancel`.
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
        queue: Queue? = nil,
        id: ID? = nil
        )
    {
        self.init(kind: .publisher(
            Publisher(
                publisher: publisher,
                queue: queue.map(EffectQueue.custom) ?? .default,
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
    internal var publisher: Publisher?
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
        case publisher(Publisher)
        case cancel((ID) -> Bool)
    }

    internal struct Publisher
    {
        /// "Cold" stream that runs side-effect and sends next `Input`.
        internal let publisher: AnyPublisher<Input, Never>

        /// Effect queue that associates with `publisher` to perform various `flattenStrategy`s.
        internal let queue: EffectQueue<Queue>

        /// Effect identifier for cancelling running `publisher`.
        internal let id: ID?
    }
}
