import Foundation
import SwiftUI
import Combine
import Harvest

/// Store of `Harvester` optimized for SwiftUI's 2-way binding.
public final class Store<Input, State>: ObservableObject
{
    private let harvester: Harvester<BindableInput, State>

    private let inputs = PassthroughSubject<BindableInput, Never>()

    private var cancellable = Set<AnyCancellable>()

    public init<Queue: EffectQueueProtocol, EffectID>(
        state initialState: State,
        effect initialEffect: Effect<Input, Queue, EffectID> = .none,
        mapping: @escaping Harvester<Input, State>.EffectMapping<Queue, EffectID>
    )
    {
        harvester = Harvester(
            state: initialState,
            effect: initialEffect.mapInput(Store<Input, State>.BindableInput.input),
            inputs: inputs,
            mapping: lift(effectMapping: mapping)
        )
    }

    /// Current state.
    public var state: State
    {
        self.harvester.state
    }

    /// Sends input.
    public func send(_ input: Input)
    {
        self.inputs.send(.input(input))
    }

    /// Direct state binding.
    public var binding: Binding<State>
    {
        return Binding<State>(
            get: {
                self.harvester.state
            },
            set: {
                self.inputs.send(.state($0))
            }
        )
    }

    /// Indirect state-to-input conversion binding.
    public func binding(to toInput: @escaping (State) -> Input) -> Binding<State>
    {
        return Binding<State>(
            get: {
                self.harvester.state
            },
            set: {
                self.inputs.send(.input(toInput($0)))
            }
        )
    }

    public var objectWillChange: Published<State>.Publisher
    {
        self.harvester.$state
    }
}

// MARK: - Store.BindableInput

extension Store
{
    /// `input` as indirect messaging, or `state` that can directly replace `harvester.state` via SwiftUI 2-way binding.
    public enum BindableInput
    {
        case input(Input)
        case state(State)
    }
}

// MARK: - Private

extension Store
{
    fileprivate typealias EffectMapping<Queue, EffectID> = (BindableInput, State) -> (State, Effect<BindableInput, Queue, EffectID>)?
        where Queue: EffectQueueProtocol, EffectID: Equatable
}

/// Lifts from `Harvester.EffectMapping` to `Store.EffectMapping`, converting from `Input` to `Store.BindableInput`.
private func lift<Input, State, Queue: EffectQueueProtocol, EffectID>(
    effectMapping: @escaping Harvester<Input, State>.EffectMapping<Queue, EffectID>
) -> Store<Input, State>.EffectMapping<Queue, EffectID>
{
    { input, state in
        switch input {
        case let .input(innerInput):
            guard let (newState, effect) = effectMapping(innerInput, state) else {
                return nil
            }
            return (newState, effect.mapInput(Store<Input, State>.BindableInput.input))

        case let .state(state):
            return (state, nil)
        }
    }
}
