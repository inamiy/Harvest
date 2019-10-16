import Foundation
import SwiftUI
import Combine
import Harvest

/// Store of `Harvester` optimized for SwiftUI's 2-way binding.
public final class Store<Input, State>: ObservableObject
{
    private let harvester: Harvester<BindableInput, State>

    private let inputs = PassthroughSubject<BindableInput, Never>()

    public init<Queue: EffectQueueProtocol, EffectID>(
        state initialState: State,
        effect initialEffect: Effect<Input, Queue, EffectID> = .none,
        mapping: @escaping Harvester<Input, State>.EffectMapping<Queue, EffectID>
    )
    {
        self.harvester = Harvester(
            state: initialState,
            effect: initialEffect.mapInput(Store<Input, State>.BindableInput.input),
            inputs: self.inputs,
            mapping: lift(effectMapping: mapping)
        )

        self._state = Binding<State>(
            get: { [harvester] in
                harvester.state
            },
            set: { [inputs] in
                inputs.send(.state($0))
            }
        )
    }

    /// Current state.
    @Binding
    public private(set) var state: State

    /// Sends input.
    public func send(_ input: Input)
    {
        self.inputs.send(.input(input))
    }

    /// Lightweight `Store` proxy without duplicating internal state.
    public var proxy: Proxy
    {
        Proxy(state: self.$state, send: self.send)
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
    fileprivate enum BindableInput
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
