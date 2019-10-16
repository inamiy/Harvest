import Foundation
import SwiftUI
import Combine
import Harvest

/// Store of `Harvester` optimized for SwiftUI's 2-way binding.
public final class Store<Input, State>: ObservableObject
{
    private let harvester: Harvester<BindableInput, State>

    private let inputs = PassthroughSubject<BindableInput, Never>()

//    @Binding
//    public private(set) var state: State

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

        // Comment-out:
        // Stored binding doesn't work in SwiftUI for some reason.
        // Use `stateBinding` (computed property) instead.
        //
//        self._state = Binding<State>(
//            get: { [harvester] in
//                harvester.state
//            },
//            set: { [inputs] in
//                inputs.send(.state($0))
//            }
//        )
    }

    /// Lightweight `Store` proxy without duplicating internal state.
    public var proxy: Proxy
    {
        Proxy(state: self.stateBinding, send: self.send)
    }

    public var objectWillChange: Published<State>.Publisher
    {
        self.harvester.$state
    }

}

// MARK: - Private

// NOTE:
// These are marked as `private` since passing `Store.Proxy` instead of `Store`
// to SwiftUI's `View`s is preferred.
// To call these methods, use `proxy` instead.
extension Store
{
    private func send(_ input: Input)
    {
        self.inputs.send(.input(input))
    }

    private var stateBinding: Binding<State>
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
}

extension Store
{
    /// `input` as indirect messaging, or `state` that can directly replace `harvester.state` via SwiftUI 2-way binding.
    fileprivate enum BindableInput
    {
        case input(Input)
        case state(State)
    }
}

extension Store
{
    fileprivate typealias EffectMapping<Queue, EffectID> =
        (BindableInput, State) -> (State, Effect<BindableInput, Queue, EffectID>)?
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