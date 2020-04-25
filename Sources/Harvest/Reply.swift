/// `Harvester`'s reply to state transition.
public enum Reply<Input, State>
{
    /// Transition success, i.e. `(input, fromState, toState)`.
    case success(Success)

    /// Transition failure, i.e. `(input, fromState)`.
    case failure(Failure)

    public var success: Success?
    {
        guard case let .success(value) = self else { return nil }
        return value
    }

    public var failure: Failure?
    {
        guard case let .failure(value) = self else { return nil }
        return value
    }

    public var input: Input
    {
        switch self {
        case let .success((input, _, _)): return input
        case let .failure((input, _)): return input
        }
    }

    public var fromState: State
    {
        switch self {
        case let .success((_, fromState, _)): return fromState
        case let .failure((_, fromState)): return fromState
        }
    }

    public var toState: State?
    {
        switch self {
        case let .success((_, _, toState)): return toState
        case .failure: return nil
        }
    }
}

extension Reply
{
    /// State-transition success values.
    public typealias Success = (input: Input, fromState: State, toState: State)

    /// State-transition failure values.
    public typealias Failure = (input: Input, fromState: State)
}
