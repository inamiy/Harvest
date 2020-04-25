import FunOptics
import Harvest

extension Harvest.Effect
{
    /// Transforms `Effect` from `ID` to `WholeID`.
    public func transform<WholeID>(
        id prism: Prism<WholeID, ID>
    ) -> Effect<World, Input, Queue, WholeID>
    {
        self.transformID(prism.inject, prism.tryGet)
    }
}
