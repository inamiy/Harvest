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

    public let objectWillChange: AnyPublisher<State, Never>

    public init<World, Queue: EffectQueueProtocol, EffectID>(
        state initialState: State,
        effect initialEffect: Effect<Input, Queue, EffectID> = .empty,
        mapping: Harvester<Input, State>.EffectMapping<World, Queue, EffectID>,
        world: World
    )
    {
        self.harvester = Harvester(
            state: initialState,
            effect: initialEffect.mapInput(Store<Input, State>.BindableInput.input),
            inputs: self.inputs,
            mapping: lift(effectMapping: mapping),
            world: world,
            scheduler: DispatchQueue.main
        )

        self.objectWillChange = self.harvester.$state
            .eraseToAnyPublisher()

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
    fileprivate typealias EffectMapping<World, Queue, EffectID> =
        Harvester<BindableInput, State>.EffectMapping<World, Queue, EffectID>
        where Queue: EffectQueueProtocol, EffectID: Equatable
}

/// Lifts from `Harvester.EffectMapping` to `Store.EffectMapping`, converting from `Input` to `Store.BindableInput`.
private func lift<World, Input, State, Queue: EffectQueueProtocol, EffectID>(
    effectMapping: Harvester<Input, State>.EffectMapping<World, Queue, EffectID>
) -> Store<Input, State>.EffectMapping<World, Queue, EffectID>
{
    .init { input, state, world in
        switch input {
        case let .input(innerInput):
            guard let (newState, effect) = effectMapping.run(innerInput, state, world) else {
                return nil
            }
            return (newState, effect.mapInput(Store<Input, State>.BindableInput.input))

        case let .state(state):
            return (state, .empty)
        }
    }
}
