import FunOptics
import Harvest

extension Harvest.Effect
{
    /// Transforms `Effect` from `ID` to `WholeID`.
    public func transform<WholeID>(
        id prism: Prism<WholeID, ID>
    ) -> Effect<Input, Queue, WholeID>
    {
        .init(kinds: self.kinds.map { kind in
            switch kind {
            case let .task(task):
                return .task(.init(
                    publisher: task.publisher,
                    queue: task.queue,
                    id: task.id.map(prism.inject)
                ))
            case let .cancel(predicate):
                return .cancel {
                    prism.tryGet($0).map(predicate) ?? false
                }
            }
        })
    }
}
