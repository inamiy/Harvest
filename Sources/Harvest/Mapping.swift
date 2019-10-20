// MARK: - Mapping

extension Harvester
{
    /// Basic state-transition function type.
    public struct Mapping
    {
        public let run: (Input, State) -> State?

        public init(_ run: @escaping (Input, State) -> State?)
        {
            self.run = run
        }

        /// `inout`-function initializer.
        /// - Note: Added different name than `init` to disambiguate.
        /// - Note: `(Input, inout State) -> Void` rather than `-> Void?` leads state-transition to be always successful.
        public static func makeInout(_ run: @escaping (Input, inout State) -> Void)
            -> Mapping
        {
            return .init { input, state in
                var state = state
                run(input, &state)

                // NOTE:
                // Below code is ideal, but `(Input, inout State) -> Void?` type signature tends to become
                // hard to implement, so in this method's `run`, we ignore return type's `Optional`.
//                if let _ = run(input, &state) {
//                    return state
//                }
//                else {
//                    return nil
//                }

                return state
            }
        }

        /// Converts `Mapping` to `EffectMapping`.
        public func toEffectMapping<Queue, EffectID>() -> EffectMapping<Queue, EffectID>
        {
            .init { input, state in
                if let toState = self.run(input, state) {
                    return (toState, .empty)
                }
                else {
                    return nil
                }
            }
        }

        /// Folds multiple `Harvester.Mapping`s into one (preceding mapping has higher priority).
        public static func reduce<Mappings: Sequence>(_ mappings: Mappings) -> Harvester<Input, State>.Mapping
            where Mappings.Iterator.Element == Harvester<Input, State>.Mapping
        {
            return .init { input, fromState in
                for mapping in mappings {
                    if let toState = mapping.run(input, fromState) {
                        return toState
                    }
                }
                return nil
            }
        }
    }
}

// MARK: - EffectMapping

extension Harvester
{
    /// Transducer (input & output) mapping with
    /// **cold publisher** (additional effect) as output,
    /// which may emit next input values for continuous state-transitions.
    public struct EffectMapping<Queue, EffectID>
        where Queue: EffectQueueProtocol, EffectID: Equatable
    {
        public let run: (Input, State) -> (State, Effect<Input, Queue, EffectID>)?

        public init(_ run: @escaping (Input, State) -> (State, Effect<Input, Queue, EffectID>)?)
        {
            self.run = run
        }

        /// `inout`-function initializer.
        /// - Note: Added different name than `init` to disambiguate.
        public static func makeInout(_ run: @escaping (Input, inout State) -> Effect<Input, Queue, EffectID>?)
            -> EffectMapping<Queue, EffectID>
        {
            return .init { input, state in
                var state = state
                if let effect = run(input, &state) {
                    return (state, effect)
                }
                else {
                    return nil
                }
            }
        }

        public func mapQueue<Queue2>(_ f: @escaping (Queue) -> Queue2)
            -> Harvester<Input, State>.EffectMapping<Queue2, EffectID>
        {
            return .init { input, state in
                guard let (newState, effect) = self.run(input, state) else { return nil }
                let effect2 = effect.mapQueue(f)
                return (newState, effect2)
            }
        }

        public func invmapID<EffectID2>(
            _ forward: @escaping (EffectID) -> EffectID2,
            _ backward: @escaping (EffectID2) -> EffectID
        ) -> Harvester<Input, State>.EffectMapping<Queue, EffectID2>
        {
            return .init { input, state in
                guard let (newState, effect) = self.run(input, state) else { return nil }
                let effect2 = effect.invmapID(forward, backward)
                return (newState, effect2)
            }
        }

        /// Folds multiple `Harvester.EffectMapping`s into one (preceding mapping has higher priority).
        public static func reduce<Mappings: Sequence, Queue, EffectID>(
            _ mappings: Mappings
        ) -> Harvester<Input, State>.EffectMapping<Queue, EffectID>
            where Mappings.Iterator.Element == Harvester<Input, State>.EffectMapping<Queue, EffectID>
        {
            return .init { input, fromState in
                for mapping in mappings {
                    if let tuple = mapping.run(input, fromState) {
                        return tuple
                    }
                }
                return nil
            }
        }

    }
}
