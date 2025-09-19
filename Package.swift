// swift-tools-version: 6.1

import PackageDescription

let package = Package(
	name: "RealtimeAPI",
	platforms: [
		.iOS(.v17),
		.tvOS(.v17),
		.macOS(.v14),
		.visionOS(.v1),
		.macCatalyst(.v17),
	],
	products: [
		.library(name: "RealtimeAPI", targets: ["RealtimeAPI"]),
	],
	dependencies: [
		.package(url: "https://github.com/livekit/webrtc-xcframework.git", .upToNextMajor(from: "137.7151.07")),
		.package(url: "https://github.com/SwiftyLab/MetaCodable.git", .upToNextMajor(from: "1.0.0")),
		.package(url: "https://github.com/qizh/QizhMacroKit.git", exact: "1.1.11"),
	],
	targets: [
		.target(
			name: "Helpers"
		),
		.target(
			name: "Core",
			dependencies: [
				.product(name: "MetaCodable", package: "MetaCodable"),
				.product(name: "HelperCoders", package: "MetaCodable"),
				.product(name: "QizhMacroKit", package: "QizhMacroKit"),
				.product(name: "QizhMacroKitClient", package: "QizhMacroKit"),
				"Helpers",
			]
		),
		.target(
			name: "WebSocket",
			dependencies: [
				"Core",
				"Helpers",
			]
		),
		.target(
			name: "UI",
			dependencies: [
				"Core",
				"WebRTC",
				"Helpers",
			]
		),
		.target(
			name: "RealtimeAPI",
			dependencies: [
				"Core",
				"WebSocket",
				"WebRTC",
				"UI",
				"Helpers",
			]
		),
		.target(
			name: "WebRTC",
			dependencies: [
				"Core",
				"Helpers",
				.product(name: "LiveKitWebRTC", package: "webrtc-xcframework"),
			]
		),
	],
	swiftLanguageModes: [
		.v6,
	]
)
