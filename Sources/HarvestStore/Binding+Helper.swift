import SwiftUI

extension Binding
{
    /// Transforms `<Value>` to `<SubValue>` using `get` and `set`.
    public func transform<SubValue>(
        get: @escaping (Value) -> SubValue,
        set: @escaping (Value, SubValue) -> Value
    ) -> Binding<SubValue>
    {
        Binding<SubValue>(
            get: { get(self.wrappedValue) },
            set: { self.wrappedValue = set(self.wrappedValue, $0) }
        )
    }

    /// Transforms `<Value>` to `<SubValue>` using `WritableKeyPath`.
    ///
    /// - Note:
    ///   This is almost the same as `subscript(dynamicMember:)` provided by SwiftUI,
    ///   but this implementation can avoid internal `SwiftUI.BindingOperations.ForceUnwrapping` failure crash.
    public subscript<SubValue>(_ keyPath: WritableKeyPath<Value, SubValue>)
        -> Binding<SubValue>
    {
        Binding<SubValue>(
            get: { self.wrappedValue[keyPath: keyPath] },
            set: { self.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}
