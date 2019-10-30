import FunOptics
import Harvest

extension Harvester.EffectMapping
{
    /// Transforms `EffectMapping` from `Input` to `WholeInput`.
    public func transform<WholeInput>(
        input inputTraversal: AffineTraversal<WholeInput, Input>
    ) -> Harvester<WholeInput, State>.EffectMapping<World, Queue, EffectID>
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
    ) -> Harvester<Input, WholeState>.EffectMapping<World, Queue, EffectID>
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

    /// Transforms `EffectMapping` from `ID` to `WholeID`.
    public func transform<WholeEffectID>(
        id prism: Prism<WholeEffectID, EffectID>
    ) -> Harvester<Input, State>.EffectMapping<World, Queue, WholeEffectID>
    {
        return .init { input, state in
            guard let (newState, effect) = self.run(input, state) else { return nil }
            let effect2 = effect.transform(id: prism)
            return (newState, effect2)
        }
    }

}
