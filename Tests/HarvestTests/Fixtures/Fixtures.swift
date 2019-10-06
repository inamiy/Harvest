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
