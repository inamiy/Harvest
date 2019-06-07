import Combine

public protocol HasValue
{
    associatedtype Value
    var value: Value { get }
}

extension CurrentValueSubject: HasValue {}

/// - SeeAlso: https://github.com/inamiy/RxProperty
public final class Property<Output>: Publisher, HasValue
{
    public typealias Failure = Never

    private let currentValue: CurrentValueSubject<Output, Never>

    public init(_ currentValue: CurrentValueSubject<Output, Never>) {
        self.currentValue = currentValue
    }

    public var value: Output {
        return self.currentValue.value
    }

    public func receive<S: Subscriber>(subscriber: S)
        where Failure == S.Failure, Output == S.Input
    {
        return currentValue.receive(subscriber: subscriber)
    }
}
