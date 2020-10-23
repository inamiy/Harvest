import Combine
import Dispatch

/// Describes how a stream of inner streams should be flattened into a stream of values.
/// - SeeAlso: https://github.com/ReactiveCocoa/ReactiveSwift/blob/6.0.0/Sources/Flatten.swift
public struct FlattenStrategy
{
    internal let kind: Kind

    private init(kind: Kind)
    {
        self.kind = kind
    }

    public static let merge = FlattenStrategy(kind: .concurrent(maxPublishers: .unlimited))
    public static let concat = FlattenStrategy(kind: .concurrent(maxPublishers: .max(1)))

    public static func concurrent(maxPublishers: Subscribers.Demand) -> FlattenStrategy
    {
        return FlattenStrategy(kind: .concurrent(maxPublishers: maxPublishers))
    }

    public static let latest = FlattenStrategy(kind: .latest)

    public static func throttle(interval: Double /* seconds */, latest: Bool) -> FlattenStrategy
    {
        return FlattenStrategy(kind: .throttle(interval: interval, latest: latest))
    }

    public static func debounce(time: Double /* seconds */) -> FlattenStrategy
    {
        return FlattenStrategy(kind: .debounce(time: time))
    }
}

// MARK: - FlattenStrategy.Kind

extension FlattenStrategy
{
    internal enum Kind
    {
        case concurrent(maxPublishers: Subscribers.Demand)
        case latest
        case throttle(interval: Double /* seconds */, latest: Bool)
        case debounce(time: Double /* seconds */)
    }
}

// MARK: - Publisher.flatMap(strategy)

extension Publisher
{
    public func flatMap<T, P>(
        _ strategy: FlattenStrategy,
        transform: @escaping (Output) -> P
        ) -> Publishers.FlatMapStrategy<P, Self>
        where T == P.Output, P: Publisher, Self.Failure == P.Failure
    {
        return Publishers.FlatMapStrategy(upstream: self, strategy: strategy, transform: transform)
    }
}

extension Publishers
{
    public struct FlatMapStrategy<P, Upstream> : Publisher
        where P: Publisher, Upstream: Publisher, P.Failure == Upstream.Failure
    {
        public typealias Output = P.Output
        public typealias Failure = Upstream.Failure

        public let upstream: Upstream
        public let transform: (Upstream.Output) -> P
        public let strategy: FlattenStrategy

        init(upstream: Upstream, strategy: FlattenStrategy, transform: @escaping (Upstream.Output) -> P)
        {
            self.upstream = upstream
            self.strategy = strategy
            self.transform = transform
        }

        public func receive<S>(subscriber: S)
            where S: Subscriber, P.Output == S.Input, Upstream.Failure == S.Failure
        {
            switch strategy.kind {
            case let .concurrent(maxPublishers):
                self.upstream
                    .flatMap(maxPublishers: maxPublishers, self.transform)
                    .receive(subscriber: subscriber)

            case .latest:
                self.upstream
                    .map(self.transform)
                    .switchToLatest()
                    .receive(subscriber: subscriber)

            case let .throttle(interval, latest):
                self.upstream
                    .map(self.transform)
                    .throttle(for: .seconds(interval), scheduler: DispatchQueue.global(), latest: latest)
                    .flatMap { $0 }
                    .receive(subscriber: subscriber)

            case let .debounce(time):
                self.upstream
                    .map(self.transform)
                    .debounce(for: .seconds(time), scheduler: DispatchQueue.global())
                    .flatMap { $0 }
                    .receive(subscriber: subscriber)
            }
        }
    }
}
