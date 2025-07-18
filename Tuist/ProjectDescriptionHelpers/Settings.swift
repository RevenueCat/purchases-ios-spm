import ProjectDescription

extension Settings {

    /// Default project settings configuration for RevenueCat projects.
    /// 
    /// This provides a standardized settings configuration that includes:
    /// - Base settings from `.projectBase`
    /// - Debug configuration with incremental compilation
    /// - Release configuration with whole module optimization
    /// - Recommended default settings
    public static var project: Settings {
        return .settings(
            base: .projectBase,
            configurations: [
                .debug(name: "Debug", settings: [
                    "SWIFT_COMPILATION_MODE": "incremental"
                ], xcconfig: .relativeToRoot("Global.xcconfig")),
                .release(name: "Release", settings: [
                    "SWIFT_COMPILATION_MODE": "wholemodule"
                ], xcconfig: .relativeToRoot("Global.xcconfig")),
            ],
            defaultSettings: .recommended
        )
    }

    /// Default target settings configuration for RevenueCat projects.
    /// 
    /// This provides a standardized target settings configuration that includes:
    /// - User script sandboxing enabled for security
    /// - Essential default settings for optimal build performance
    public static var target: Settings {
        return .settings(
            base: [
                "ENABLE_USER_SCRIPT_SANDBOXING": "YES"
            ],
            defaultSettings: .essential
        )
    }

    /// Default framework settings configuration for RevenueCat projects.
    /// 
    /// This provides a standardized framework settings configuration that includes:
    /// - Code signing disabled for internal frameworks
    /// - Optimized settings for framework distribution
    public static var framework: Settings {
        return .settings(
            base: [
                "CODE_SIGNING_ALLOWED": "NO",
                "CODE_SIGNING_REQUIRED": "NO",
                "CODE_SIGN_IDENTITY": ""
            ]
        )
    }
}
