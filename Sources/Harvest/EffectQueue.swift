// MARK: - EffectQueueProtocol

/// `Effect` queueing protocol to split event-flows into queues
/// and each will be flattened using `flattenStrategy`,
/// which are then merged as a next input of `Harvester`.
///
/// For example:
///
///     enum EffectQueue: EffectQueueProtocol {
///         case `default`
///         case request
///
///         var flattenStrategy: FlattenStrategy {
///             switch self {
///             case .default: return .merge
///             case .request: return .latest
///             }
///         }
///
///         static var defaultEffectQueue: EffectQueue {
///             .default
///         }
///     }
///
/// - Note: Use built-in `BasicEffectQueue` for simplest merging scenario.
public protocol EffectQueueProtocol: Equatable, CaseIterable
{
    var flattenStrategy: FlattenStrategy { get }

    static var defaultEffectQueue: Self { get }
}

// MARK: - BasicEffectQueue

/// Basic single effect queue with `.merge` strategy.
public struct BasicEffectQueue: EffectQueueProtocol
{
    public static var allCases: [BasicEffectQueue]
    {
        [.init()]
    }

    public var flattenStrategy: FlattenStrategy
    {
        .merge
    }

    public static var defaultEffectQueue: Self
    {
        .init()
    }
}
