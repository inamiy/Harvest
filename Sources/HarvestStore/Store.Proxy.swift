import SwiftUI

extension Store
{
    /// Lightweight `Store` proxy that is state-bindable and input-sendable without duplicating internal state.
    @dynamicMemberLookup
    public struct Proxy
    {
        @Binding
        public private(set) var state: State

        public let send: (Input) -> Void

        /// Transforms `<Input, State>` to `<Input, SubState>` using keyPath `@dynamicMemberLookup`.
        public subscript<SubState>(
            dynamicMember keyPath: WritableKeyPath<State, SubState>
        ) -> Store<Input, SubState>.Proxy
        {
            .init(state: self.$state[dynamicMember: keyPath], send: self.send)
        }

        /// Indirect state-to-input conversion binding to create `Binding<State>`.
        public func stateBinding(
            onChange: @escaping (State) -> Input?
        ) -> Binding<State>
        {
            self.stateBinding(get: { $0 }, onChange: onChange)
        }

        /// Indirect state-to-input conversion binding to create `Binding<SubState>`.
        public func stateBinding<SubState>(
            get: @escaping (State) -> SubState,
            onChange: @escaping (SubState) -> Input?
        ) -> Binding<SubState>
        {
            Binding<SubState>(
                get: {
                    get(self.state)
                },
                set: {
                    if let input = onChange($0) {
                        self.send(input)
                    }
                }
            )
        }
    }
}
