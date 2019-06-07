public enum Reply<State, Input>
{
    /// Transition success, i.e. `(input, fromState, toState)`.
    case success(Input, State, State)

    /// Transition failure, i.e. `(input, fromState)`.
    case failure(Input, State)

    public var input: Input
    {
        switch self {
        case let .success(input, _, _): return input
        case let .failure(input, _): return input
        }
    }

    public var fromState: State
    {
        switch self {
        case let .success(_, fromState, _): return fromState
        case let .failure(_, fromState): return fromState
        }
    }

    public var toState: State?
    {
        switch self {
        case let .success(_, _, toState): return toState
        case .failure: return nil
        }
    }
}
