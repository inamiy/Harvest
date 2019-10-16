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

        /// Converts `Mapping` to `EffectMapping`.
        public func toEffectMapping<Queue, EffectID>() -> EffectMapping<Queue, EffectID>
        {
            .init { input, state in
                if let toState = self.run(input, state) {
                    return (toState, .none)
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
