import AppKit

/// Blurs whatever is behind a window with an adjustable radius.
///
/// Uses `CGSSetWindowBackgroundBlurRadius`, a private CoreGraphics call:
/// the public `NSVisualEffectView` has a fixed strength. If the call ever
/// disappears, `apply` returns false and the caller falls back to
/// `NSVisualEffectView`.
@MainActor
enum WindowBlur {
    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SetBackgroundBlurRadius = @convention(c) (Int32, Int32, Int32) -> Int32

    private static let frameworkPath = "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"

    /// Works before the window is shown, so it never appears unblurred.
    static func apply(radius: Int, to window: NSWindow) -> Bool {
        guard
            let handle = dlopen(frameworkPath, RTLD_LAZY),
            let connectionSymbol = dlsym(handle, "CGSMainConnectionID"),
            let blurSymbol = dlsym(handle, "CGSSetWindowBackgroundBlurRadius")
        else { return false }

        let mainConnection = unsafeBitCast(connectionSymbol, to: MainConnectionID.self)
        let setBlurRadius = unsafeBitCast(blurSymbol, to: SetBackgroundBlurRadius.self)
        return setBlurRadius(mainConnection(), Int32(window.windowNumber), Int32(radius)) == 0
    }
}
