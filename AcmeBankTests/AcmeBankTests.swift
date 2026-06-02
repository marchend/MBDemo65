import XCTest
@testable import AcmeBank

final class AcmeBankTests: XCTestCase {
    /// Bootstrap proof-of-life: test target compiles + links against the app
    /// module. Real behaviour tests belong in feature stories. We
    /// instantiate the composition root (`AcmeBankApp`) and the post-auth
    /// landing screen so a future agent breaking either type's `init`
    /// gets a fast unit-test failure rather than only a UI-test failure.
    func test_appRoot_initializes() {
        _ = AcmeBankApp()
    }

    func test_landingView_initializes() {
        _ = LandingView(
            session: UserSession(
                userId: "test-sub",
                displayName: "Test User",
                email: "test@example.com",
                accessToken: "test-access-token",
                authTimestamp: Date(timeIntervalSince1970: 0),
                deviceName: "Test Device"
            )
        )
    }
}
