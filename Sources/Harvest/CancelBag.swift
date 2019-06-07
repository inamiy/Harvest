import Combine

/// - Todo: Mutex
final class CancelBag: Cancellable
{
    private var _cancellables: [Cancellable] = []
    private var _isCancelled: Bool = false

    init() {}

    func insertOrCancel<C: Cancellable>(_ cancellable: C)
    {
        if self._isCancelled {
            cancellable.cancel()
        }

        self._cancellables.append(cancellable)
    }

    func cancel()
    {
        self._cancellables.removeAll(keepingCapacity: false)
        self._isCancelled = true
    }

    deinit
    {
        self.cancel()
    }
}

extension Cancellable
{
    func cancelled(by bag: CancelBag)
    {
        bag.insertOrCancel(self)
    }
}
