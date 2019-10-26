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

        public init(state: Binding<State>, send: @escaping (Input) -> Void)
        {
            self._state = state
            self.send = send
        }

        /// Transforms `<Input, State>` to `<Input, SubState>` using keyPath `@dynamicMemberLookup`.
        public subscript<SubState>(
            dynamicMember keyPath: WritableKeyPath<State, SubState>
        ) -> Store<Input, SubState>.Proxy
        {
            .init(state: self.$state[dynamicMember: keyPath], send: self.send)
        }

        /// Transforms `Input` to `Input2`.
        public func contramapInput<Input2>(_ f: @escaping (Input2) -> Input)
            -> Store<Input2, State>.Proxy
        {
            .init(state: self.$state, send: { self.send(f($0)) })
        }

        // MARK: - To Binding

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
