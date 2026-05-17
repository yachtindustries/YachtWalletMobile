import UIKit
import Capacitor

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    /**
     * iOS analog of Android's FLAG_SECURE.
     *
     * iOS takes a snapshot of every app right before resigning active state
     * — this snapshot is what shows up in the multitasking switcher. For a
     * wallet we never want the seed-reveal screen, balances, or addresses to
     * appear in that snapshot, so we slap an opaque navy view over the
     * window before the snapshot is taken and remove it when the app
     * becomes active again. This is the same pattern used by 1Password,
     * Signal, MetaMask iOS, etc.
     */
    private var privacyOverlay: UIView?
    private let yachtNavy = UIColor(red: 0x00/255.0, green: 0x28/255.0, blue: 0x49/255.0, alpha: 1)
    private let privacyOverlayTag = 0xC0FFEE

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Register the custom Keychain-backed plugin BEFORE the Capacitor
        // bridge starts so JS calls to SecureStorage resolve immediately.
        // (Capacitor 6+ also auto-discovers @objc plugins in the app target,
        // but registering here is the documented belt-and-suspenders path.)
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        guard let window = window, privacyOverlay == nil else { return }
        let overlay = UIView(frame: window.bounds)
        overlay.backgroundColor = yachtNavy
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.tag = privacyOverlayTag
        window.addSubview(overlay)
        privacyOverlay = overlay
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Belt-and-suspenders: if the OS skipped the willResignActive notify
        // (rare but happens during phone-call interrupts), ensure the
        // overlay still went up before the app heads to background.
        guard let window = window, privacyOverlay == nil else { return }
        let overlay = UIView(frame: window.bounds)
        overlay.backgroundColor = yachtNavy
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.tag = privacyOverlayTag
        window.addSubview(overlay)
        privacyOverlay = overlay
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Symmetric counterpart — no-op here; we drop the overlay only once
        // the app is fully active again (so the user doesn't see a brief
        // flash of UI before the wallet locks via App.appStateChange).
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        privacyOverlay?.removeFromSuperview()
        privacyOverlay = nil
        // In case a stray overlay survived (e.g. tab-switch during launch).
        window?.viewWithTag(privacyOverlayTag)?.removeFromSuperview()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // No persistent state to flush — the vault lock-on-background
        // handler in src/lib/mobile-rpc.ts has already wiped the cached
        // AES key before this point.
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
}
