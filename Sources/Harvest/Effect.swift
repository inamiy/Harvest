import Combine

/// Managed side-effect that enqueues `publisher` on `EffectQueue`
/// to perform arbitrary `Queue.flattenStrategy`.
public struct Effect<Input, Queue> where Queue: EffectQueueProtocol
{
    /// "Cold" stream that runs side-effect and sends next `Input`.
    public let publisher: AnyPublisher<Input, Never>

    /// Effect queue that associates with `publisher` to perform various `flattenStrategy`s.
    internal let queue: EffectQueue<Queue>

    /// - Parameter queue: Uses custom queue, or set `nil` as default queue to use `merge` strategy.
    public init(
        _ publisher: AnyPublisher<Input, Never>,
        queue: Queue? = nil
        )
    {
        self.publisher = publisher
        self.queue = queue.map(EffectQueue.custom) ?? .default
    }
}
