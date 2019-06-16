// MARK: - EffectQueueProtocol

/// `Effect` queueing protocol to split event-flows into queues
/// and each will be flattened using `flattenStrategy`, then merged.
public protocol EffectQueueProtocol: Equatable, CaseIterable
{
    var flattenStrategy: FlattenStrategy { get }
}

extension Never: EffectQueueProtocol
{
    public static var allCases: [Never]
    {
        return [Never]()
    }

    public var flattenStrategy: FlattenStrategy
    {
        return .merge
    }
}

// MARK: - EffectQueue

/// Main effect queue that has `default` queue.
internal enum EffectQueue<Queue>: EffectQueueProtocol
    where Queue: EffectQueueProtocol
{
    case `default`
    case custom(Queue)

    public static var allCases: [EffectQueue]
    {
        return [.default] + Queue.allCases.map(EffectQueue.custom)
    }

    public var flattenStrategy: FlattenStrategy
    {
        switch self {
        case .default:
            return .merge
        case let .custom(custom):
            return custom.flattenStrategy
        }
    }
}
