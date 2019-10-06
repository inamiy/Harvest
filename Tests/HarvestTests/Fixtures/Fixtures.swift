import Combine
import Harvest

// MARK: AuthState/Input

enum AuthState: String, CustomStringConvertible
{
    case loggedOut
    case loggingIn
    case loggedIn
    case loggingOut

    var description: String { return self.rawValue }
}

/// - Note:
/// `LoginOK` and `LogoutOK` should only be used internally
/// (but Swift can't make them as `private case`)
enum AuthInput: String, CustomStringConvertible
{
    case login
    case loginOK
    case logout
    case forceLogout
    case logoutOK

    var description: String { return self.rawValue }
}

/// Subset of `AuthInput` that can be sent from external.
enum ExternalAuthInput
{
    case login
    case logout
    case forceLogout

    static func toInternal(externalInput: ExternalAuthInput) -> AuthInput
    {
        switch externalInput {
        case .login:
            return .login
        case .logout:
            return .logout
        case .forceLogout:
            return .forceLogout
        }
    }
}

// MARK: CountState/Input

typealias CountState = Int

enum CountInput: String, CustomStringConvertible
{
    case increment
    case decrement

    var description: String { return self.rawValue }
}

// MARK: MyState/Input

enum MyState
{
    case state0, state1, state2
}

enum MyInput
{
    case input0, input1, input2
}

// MARK: - RequestEffectQueue

enum RequestEffectQueue: EffectQueueProtocol
{
    case `default`
    case request

    var flattenStrategy: FlattenStrategy
    {
        switch self {
        case .default: return .merge
        case .request: return .latest
        }
    }

    static var defaultEffectQueue: RequestEffectQueue
    {
        .default
    }
}
