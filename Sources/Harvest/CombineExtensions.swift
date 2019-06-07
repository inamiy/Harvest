import Combine

extension Publisher
{
    public static var empty: AnyPublisher<Output, Failure> {
        return AnyPublisher(Publishers.Empty(completeImmediately: true))
    }

    public static var never: AnyPublisher<Output, Failure> {
        return AnyPublisher(Publishers.Empty(completeImmediately: false))
    }
}
