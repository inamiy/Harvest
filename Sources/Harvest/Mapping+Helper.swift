import Combine

/// "From-" and "to-" states represented as `.state1 => .state2` or `anyState => .state3`.
public struct Transition<State>
{
    public let fromState: (State) -> Bool
    public let toState: State
}

// MARK: - Custom Operators

// MARK: `=>` (Transition constructor)

precedencegroup TransitionPrecedence {
    associativity: left
    higherThan: AdditionPrecedence
}
infix operator => : TransitionPrecedence    // higher than `|`

public func => <State>(left: @escaping (State) -> Bool, right: State) -> Transition<State>
{
    return Transition(fromState: left, toState: right)
}

public func => <State: Equatable>(left: State, right: State) -> Transition<State>
{
    return { $0 == left } => right
}

// MARK: `|` (Harvester.Mapping constructor)

//infix operator | { associativity left precedence 140 }   // Comment-Out: already built-in

public func | <Input, State>(
    inputFunc: @escaping (Input) -> Bool,
    transition: Transition<State>
    ) -> Harvester<Input, State>.Mapping
{
    return .init { input, fromState in
        if inputFunc(input) && transition.fromState(fromState) {
            return transition.toState
        }
        else {
            return nil
        }
    }
}

public func | <Input: Equatable, State>(
    input: Input,
    transition: Transition<State>
    ) -> Harvester<Input, State>.Mapping
{
    return { $0 == input } | transition
}

public func | <Input, State>(
    inputFunc: @escaping (Input) -> Bool,
    transition: @escaping (State) -> State
    ) -> Harvester<Input, State>.Mapping
{
    return .init { input, fromState in
        if inputFunc(input) {
            return transition(fromState)
        }
        else {
            return nil
        }
    }
}

public func | <Input: Equatable, State>(
    input: Input,
    transition: @escaping (State) -> State
    ) -> Harvester<Input, State>.Mapping
{
    return { $0 == input } | transition
}

// MARK: `|` (Harvester.EffectMapping constructor)

public func | <World, P: Publisher, Input, State, Queue, EffectID>(
    mapping: Harvester<Input, State>.Mapping,
    publisher: P
) -> Harvester<Input, State>.EffectMapping<World, Queue, EffectID>
    where P.Output == Input, P.Failure == Never
{
    return mapping | Effect(publisher)
}

public func | <World, Input, State, Queue, EffectID>(
    mapping: Harvester<Input, State>.Mapping,
    effect: Effect<World, Input, Queue, EffectID>
    ) -> Harvester<Input, State>.EffectMapping<World, Queue, EffectID>
{
    return .init { input, fromState in
        if let toState = mapping.run(input, fromState) {
            return (toState, effect)
        }
        else {
            return nil
        }
    }
}

// MARK: Functions

/// Helper for "any state" or "any input" mappings, e.g.
/// - `let mapping = .input0 | any => .state1`
/// - `let mapping = any | .state1 => .state2`
public func any<T>(_: T) -> Bool
{
    return true
}
