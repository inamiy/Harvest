import FunOptics
import Harvest

extension Harvester.EffectMapping
{
    /// Transforms `EffectMapping` from `Input` to `WholeInput`.
    public func transform<WholeInput>(
        input inputTraversal: AffineTraversal<WholeInput, Input>
    ) -> Harvester<WholeInput, State>.EffectMapping<Queue, EffectID>
    {
        return .init { wholeInput, state in
            guard let partInput = inputTraversal.tryGet(wholeInput),
                let (newState, effect) = self.run(partInput, state) else
            {
                return nil
            }
            return (newState, effect.mapInput { inputTraversal.set(wholeInput, $0) })
        }
    }

    /// Transforms `EffectMapping` from `State` to `WholeState`.
    public func transform<WholeState>(
        state stateTraversal: AffineTraversal<WholeState, State>
    ) -> Harvester<Input, WholeState>.EffectMapping<Queue, EffectID>
    {
        return .init { input, wholeState in
            guard let partState = stateTraversal.tryGet(wholeState),
                let (newPartState, effect) = self.run(input, partState) else
            {
                return nil
            }

            let newWholeState = stateTraversal.set(wholeState, newPartState)

            return (newWholeState, effect)
        }
    }

}
