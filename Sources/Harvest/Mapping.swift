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

        // MARK: - Conversion

        /// Converts `Mapping` to `EffectMapping`.
        public func toEffectMapping<World, Queue, EffectID>() -> EffectMapping<World, Queue, EffectID>
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

        // MARK: - Monoid

        public static var zero: Mapping
        {
            .init { input, state in nil }
        }

        public static var one: Mapping
        {
            .init { input, state in state }
        }

        public static func + (l: Mapping, r: Mapping) -> Mapping
        {
            .init { input, state in
                l.run(input, state) ?? r.run(input, state)
            }
        }

        public static func * (l: Mapping, r: Mapping) -> Mapping
        {
            .init { input, state in
                l.run(input, state).flatMap { r.run(input, $0) }
            }
        }

        // MARK: - Foldable

        /// Folds multiple `Harvester.Mapping`s into one.
        public static func reduce<Mappings: Sequence>(
            _ strategy: ReduceStrategy,
            _ mappings: Mappings
        ) -> Mapping
            where Mappings.Iterator.Element == Mapping
        {
            strategy.reduce(AnySequence(mappings))
        }

        /// Strategy for various ways of reducing mappings into a single value.
        public struct ReduceStrategy
        {
            fileprivate let reduce: (AnySequence<Mapping>) -> Mapping

            private init(
                reduce: @escaping (AnySequence<Mapping>) -> Mapping
            )
            {
                self.reduce = reduce
            }

            /// Chooses a first non-`nil`-returning mapping from given mappings.
            public static var first: ReduceStrategy
            {
                .init { mappings in
                    mappings.reduce(into: .zero, { $0 = $0 + $1 })
                }
            }

            /// Tries applying all mappings sequentially,
            /// and succeeds only if all mappings don't have `nil`-return.
            public static var tryAll: ReduceStrategy
            {
                .init { mappings in
                    mappings.reduce(into: .one, { $0 = $0 * $1 })
                }
            }

            /// Applies all mappings sequentially, skipping `nil`-return mapping.
            /// If all mappings's transitions failed, then returned mapping
            /// will also be marked as transition failure.
            public static var all: ReduceStrategy
            {
                .init { mappings in
                    // Comment-Out: Need to track all transition failures.
                    //mappings.reduce(into: .one, { $0 = $0 * ($1 + .one) })

                    Mapping { input, state in
                        var state = state
                        var isTransitionSucceeded = false

                        for mapping in mappings {
                            if let newState = mapping.run(input, state) {
                                state = newState
                                isTransitionSucceeded = true
                            }
                        }

                        return isTransitionSucceeded ? state : nil
                    }
                }
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
    public struct EffectMapping<World, Queue, EffectID>
        where Queue: EffectQueueProtocol, EffectID: Equatable
    {
        public let run: (Input, State) -> (State, Effect<World, Input, Queue, EffectID>)?

        public init(_ run: @escaping (Input, State) -> (State, Effect<World, Input, Queue, EffectID>)?)
        {
            self.run = run
        }

        /// `inout`-function initializer.
        /// - Note: Added different name than `init` to disambiguate.
        public static func makeInout(_ run: @escaping (Input, inout State) -> Effect<World, Input, Queue, EffectID>?)
            -> EffectMapping<World, Queue, EffectID>
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

        // MARK: - Monoid

        public static var zero: EffectMapping
        {
            .init { input, state in nil }
        }

        public static var one: EffectMapping
        {
            .init { input, state in (state, .empty) }
        }

        public static func + (l: EffectMapping, r: EffectMapping) -> EffectMapping
        {
            .init { input, state in
                l.run(input, state) ?? r.run(input, state)
            }
        }

        public static func * (l: EffectMapping, r: EffectMapping) -> EffectMapping
        {
            .init { input, state in
                l.run(input, state).flatMap { state2, effect in
                    r.run(input, state2).map { state3, effect2 in
                        (state3, effect + effect2)
                    }
                }
            }
        }

        // MARK: - Functor

        public func mapQueue<Queue2>(_ f: @escaping (Queue) -> Queue2)
            -> EffectMapping<World, Queue2, EffectID>
        {
            return .init { input, state in
                guard let (newState, effect) = self.run(input, state) else { return nil }
                let effect2 = effect.mapQueue(f)
                return (newState, effect2)
            }
        }

        public func contramapWorld<World2>(_ f: @escaping (World2) -> World)
            -> EffectMapping<World2, Queue, EffectID>
        {
            return .init { input, state in
                guard let (newState, effect) = self.run(input, state) else { return nil }
                let effect2 = effect.contramapWorld(f)
                return (newState, effect2)
            }
        }

        // MARK: - Foldable

        /// Folds multiple `Harvester.EffectMapping`s into one.
        public static func reduce<Mappings: Sequence>(
            _ strategy: ReduceStrategy,
            _ mappings: Mappings
        ) -> EffectMapping
            where Mappings.Iterator.Element == EffectMapping
        {
            strategy.reduce(AnySequence(mappings))
        }

        /// Strategy for various ways of reducing mappings into a single value.
        public struct ReduceStrategy
        {
            fileprivate let reduce: (AnySequence<EffectMapping>) -> EffectMapping

            private init(
                reduce: @escaping (AnySequence<EffectMapping>) -> EffectMapping
            )
            {
                self.reduce = reduce
            }

            /// Chooses a first non-`nil`-returning mapping from given mappings.
            public static var first: ReduceStrategy
            {
                .init { mappings in
                    mappings.reduce(into: .zero, { $0 = $0 + $1 })
                }
            }

            /// Tries applying all mappings sequentially,
            /// and succeeds only if all mappings don't have `nil`-return.
            public static var tryAll: ReduceStrategy
            {
                .init { mappings in
                    mappings.reduce(into: .one, { $0 = $0 * $1 })
                }
            }

            /// Applies all mappings sequentially, skipping `nil`-return mapping.
            /// If all mappings's transitions failed, then returned mapping
            /// will also be marked as transition failure.
            public static var all: ReduceStrategy
            {
                .init { mappings in
                    // Comment-Out: Need to track all transition failures.
                    //mappings.reduce(into: .one, { $0 = $0 * ($1 + .one) })

                    EffectMapping { input, state in
                        var state = state
                        var effect = Effect<World, Input, Queue, EffectID>.empty
                        var isTransitionSucceeded = false

                        for mapping in mappings {
                            if let (newState, newEffect) = mapping.run(input, state) {
                                state = newState
                                effect = effect + newEffect
                                isTransitionSucceeded = true
                            }
                        }

                        return isTransitionSucceeded ? (state, effect) : nil
                    }
                }
            }
        }

    }
}
