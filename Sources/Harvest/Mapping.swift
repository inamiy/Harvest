extension Harvester {

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
    }

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
    }

}
