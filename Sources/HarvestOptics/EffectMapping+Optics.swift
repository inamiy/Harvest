import FunOptics
import Harvest

/// Lifts `EffectMapping` from `PartInput` to `WholeInput`.
public func lift<WholeInput, PartInput, State, Queue, EffectID>(
    input inputTraversal: AffineTraversal<WholeInput, PartInput>
)
    -> (_ mapping: Harvester<PartInput, State>.EffectMapping<Queue, EffectID>)
    -> Harvester<WholeInput, State>.EffectMapping<Queue, EffectID>
{
    return { mapping in
        return .init { wholeInput, state in
            guard let partInput = inputTraversal.tryGet(wholeInput),
                let (newState, effect) = mapping.run(partInput, state) else
            {
                return nil
            }
            return (newState, effect.mapInput { inputTraversal.set(wholeInput, $0) })
        }
    }
}

/// Lifts `EffectMapping` from `PartState` to `WholeState`.
public func lift<WholeState, PartState, Input, Queue, EffectID>(
    state stateTraversal: AffineTraversal<WholeState, PartState>
)
    -> (_ mapping: Harvester<Input, PartState>.EffectMapping<Queue, EffectID>)
    -> Harvester<Input, WholeState>.EffectMapping<Queue, EffectID>
{
    return { mapping in
        return .init { input, wholeState in
            guard let partState = stateTraversal.tryGet(wholeState),
                let (newPartState, effect) = mapping.run(input, partState) else
            {
                return nil
            }

            let newWholeState = stateTraversal.set(wholeState, newPartState)

            return (newWholeState, effect)
        }
    }
}

/// Lifts `EffectMapping` from `<PartInput, PartState>` to `<WholeInput, WholeState>`.
public func lift<WholeInput, PartInput, WholeState, PartState, Queue, EffectID>(
    input inputTraversal: AffineTraversal<WholeInput, PartInput>,
    state stateTraversal: AffineTraversal<WholeState, PartState>
)
    -> (_ mapping: Harvester<PartInput, PartState>.EffectMapping<Queue, EffectID>)
    -> Harvester<WholeInput, WholeState>.EffectMapping<Queue, EffectID>
{
    return { mapping in
        lift(state: stateTraversal)(lift(input: inputTraversal)(mapping))
    }
}
