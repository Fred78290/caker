// swift-tools-version:6.0

import PackageDescription
import Foundation

// App Store builds must not depend on or link Sparkle.framework, since it is
// excluded from the app bundle (Sparkle isn't permitted on the Mac App Store).
let isAppStoreBuild = ProcessInfo.processInfo.environment["APPSTORE"] == "1"

let package = Package(
	name: "Caker",
	platforms: [
		.macOS(.v15)
	],
	products: [
		.executable(name: "caked", targets: ["caked"]),
		.executable(name: "Caker", targets: ["caker"]),
		.executable(name: "cakectl", targets: ["cakectl"]),
		.library(name: "CakedLib", targets: ["CakedLib"]),
		.library(name: "GRPCLib", targets: ["GRPCLib"]),
	],
	dependencies: [
		.package(url :"https://github.com/Fred78290/FileMonitor.git", revision: "82bf1ff8dbaccac3359cfd6b49f30db690c8dc38"),
		.package(url :"https://github.com/Fred78290/royalvnc.git", revision: "9d88e35a1a1ccc2e9a0a4d6fc6faeb266559a7c7"),
		.package(url: "https://github.com/Fred78290/cakeagent.git", revision: "2b36972fc696773d2f68ffd3e27d0b2758005f66"),
		.package(url: "https://github.com/Fred78290/containerization", revision: "c829f8d7b56b405c2e80b0b5e29fdde679dc73cc"),
		.package(url: "https://github.com/Fred78290/GzipSwift", branch: "main"),
		.package(url: "https://github.com/Fred78290/Multipart.git", revision: "9901ef8f452ed13e176c49e4b079f2daada76bde"),
		.package(url: "https://github.com/Fred78290/Shout.git", revision: "9bd074b3d0943e391021cf7a86360fd5f82268cc"),
		.package(url: "https://github.com/Fred78290/swift-nio-portforwarding.git", revision: "a7d76da446dbaf1652061990874517b0e7af8fe4"),
		.package(url: "https://github.com/Fred78290/swift-argument-parser", revision: "d554955e8c280aa4c4a05a039a968f0205656e77"),
		.package(url :"https://github.com/Fred78290/SwiftTerm.git", revision: "6c0bec1dc8db9e07a7738b06f380998a670e1fbc"),

		.package(url: "https://github.com/amodm/iso9660-swift", branch: "main"),
		.package(url: "https://github.com/antlr/antlr4", exact: "4.13.2"),
		.package(url: "https://github.com/apple/swift-algorithms", exact: "1.2.1"),
		.package(url: "https://github.com/apple/swift-async-algorithms", branch: "main"),
		.package(url: "https://github.com/apple/swift-atomics.git", exact: "1.3.0"),
		.package(url: "https://github.com/apple/swift-certificates.git", exact: "1.17.0"),
		.package(url: "https://github.com/apple/swift-crypto.git", exact: "3.15.1"),
		.package(url: "https://github.com/apple/swift-log.git", exact: "1.10.1"),
		.package(url: "https://github.com/apple/swift-nio-extras.git", exact: "1.34.0"),
		.package(url: "https://github.com/apple/swift-nio-http2.git", exact: "1.43.0"),
		.package(url: "https://github.com/apple/swift-nio-ssh.git", exact: "0.13.0"),
		.package(url: "https://github.com/apple/swift-nio-ssl.git", exact: "2.37.0"),
		.package(url: "https://github.com/apple/swift-nio.git", exact: "2.99.0"),
		.package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.35.0"),
		.package(url: "https://github.com/Appracatappra/SwiftletUtilities.git", exact: "2.0.6"),
		.package(url: "https://github.com/asam139/Steps.git", exact: "0.3.9"),
		.package(url: "https://github.com/cfilipov/TextTable", branch: "master"),
		.package(url: "https://github.com/fumoboy007/swift-retry", exact: "0.2.4"),
		.package(url: "https://github.com/getsentry/sentry-cocoa", exact: "8.49.2"),
		.package(url: "https://github.com/groue/Semaphore", exact: "0.0.8"),
		.package(url: "https://github.com/grpc/grpc-swift.git", exact: "1.27.2"),
		.package(url: "https://github.com/vapor/vapor.git", from: "4.121.4"),
		.package(url: "https://github.com/jozefizso/swift-xattr", exact: "3.0.0"),
		.package(url: "https://github.com/jpsim/Yams", exact: "5.1.3"),
		.package(url: "https://github.com/malcommac/SwiftDate", exact: "7.0.0"),
		.package(url: "https://github.com/mhdhejazi/Dynamic", branch: "master"),
		.package(url: "https://github.com/nicklockwood/SwiftFormat", exact: "0.53.6"),
		.package(url: "https://github.com/orchetect/SwiftRadix", exact: "1.3.1"),
		.package(url: "https://github.com/sersoft-gmbh/swift-sysctl.git", exact: "1.8.0"),
		//.package(url: "https://github.com/swiftlang/swift-subprocess.git", revision: "7928f39b374b3403224c3a243da6326bdf7c918a"),
		.package(url: "https://github.com/swiftlang/swift-subprocess.git", exact: "0.5.0"),
		//.package(url :"https://github.com/utmapp/CocoaSpice.git", revision: "ac641bd7b88e14b4107dcdb508d9779c49b69617"),
		//.package(url: "https://github.com/apple/swift-collections.git", exact: "1.2.1"),
		//.package(url: "https://github.com/apple/swift-nio-transport-services.git", exact: "1.24.0"),
		//.package(url: "https://github.com/the-swift-collective/zlib", branch: "main")
	] + (isAppStoreBuild ? [] : [
		.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1"),
	]),
	targets: [
		.target(
			name: "VirtualInstallSPI",
			dependencies: [
				.target(name: "GRPCLib"),
			],
			path: "Sources/VirtualInstallSPI",
			publicHeadersPath: "include",
			cSettings: [
				.headerSearchPath("include"),
				.define("USE_VIRTUAL_INSTALL_BACKEND")
			],
			linkerSettings: [
				.linkedFramework("Virtualization", .when(platforms: [.macOS]))
			]
		),
		.target(name: "GRPCLib", dependencies: [
			.product(name: "ArgumentParser", package: "swift-argument-parser"),
			.product(name: "Dynamic", package: "Dynamic"),
			.product(name: "GRPC", package: "grpc-swift"),
			.product(name: "CakeAgentLib", package: "CakeAgent"),
			.product(name: "NIOPortForwarding", package: "swift-nio-portforwarding")
		],
		path: "Sources/grpc",
		exclude: [
			"generate.sh",
			"service.proto",
		]),
		.target(name: "CakedLib", dependencies: [
			.target(name: "GRPCLib"),
			.target(name: "VirtualInstallSPI"),
			.product(name: "Algorithms", package: "swift-algorithms"),
			.product(name: "Antlr4Static", package: "Antlr4"),
			.product(name: "ArgumentParser", package: "swift-argument-parser"),
			.product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
			.product(name: "Atomics", package: "swift-atomics"),
			.product(name: "CakeAgentLib", package: "CakeAgent"),
			.product(name: "Crypto", package: "swift-crypto"),
			.product(name: "DMRetry", package: "swift-retry"),
			.product(name: "Dynamic", package: "Dynamic"),
			.product(name: "FileMonitor", package: "FileMonitor"),
			.product(name: "GRPC", package: "grpc-swift"),
			.product(name: "Gzip", package: "GzipSwift"),
			.product(name: "ISO9660", package: "iso9660-swift"),
			.product(name: "Logging", package: "swift-log"),
			.product(name: "NIOCore", package: "swift-nio"),
			.product(name: "NIOEmbedded", package: "swift-nio"),
			.product(name: "NIOExtras", package: "swift-nio-extras"),
			.product(name: "NIOFoundationCompat", package: "swift-nio"),
			.product(name: "NIOHTTP1", package: "swift-nio"),
			.product(name: "NIOHTTP2", package: "swift-nio-http2"),
			.product(name: "NIOPortForwarding", package: "swift-nio-portforwarding"),
			.product(name: "NIOPosix", package: "swift-nio"),
			.product(name: "NIOSSH", package: "swift-nio-ssh"),
			.product(name: "NIOSSL", package: "swift-nio-ssl"),
			.product(name: "NIOTLS", package: "swift-nio"),
			.product(name: "Semaphore", package: "Semaphore"),
			.product(name: "Sentry", package: "sentry-cocoa"),
			.product(name: "Shout", package: "Shout"),
			.product(name: "SwiftDate", package: "SwiftDate"),
			.product(name: "SwiftRadix", package: "SwiftRadix"),
			.product(name: "Sysctl", package: "swift-sysctl"),
			.product(name: "TextTable", package: "TextTable"),
			.product(name: "X509", package: "swift-certificates"),
			.product(name: "XAttr", package: "swift-xattr"),
			.product(name: "Yams", package: "Yams"),
			.product(name: "Multipart", package: "multipart"),
			.product(name: "Containerization", package: "containerization"),
			.product(name: "ContainerizationEXT4", package: "containerization"),
			.product(name: "ContainerizationIO", package: "containerization"),
			.product(name: "ContainerizationExtras", package: "containerization"),
			.product(name: "ContainerizationArchive", package: "containerization"),
			.product(name: "ContainerizationOCI", package: "containerization"),
			.product(name: "RoyalVNCKitStatic", package: "royalvnc"),
			.product(name: "Subprocess", package: "swift-subprocess"),
			.product(name: "SwiftTerm", package: "SwiftTerm"),
			//.product(name: "ZLib", package: "ZLib"),
			],
		path: "Sources/cakedlib",
		exclude: [
			"VMRunService/GRPC/generate.sh",
			"VMRunService/GRPC/mount.proto",
			"VMNet/generate.sh",
			"VMNet/vmnet.proto",
			"VNCLib/README.md",
			"VNCLib/VNCAuthExample.swift"
		]),
		.executableTarget(name: "caker", dependencies: [
			.target(name: "GRPCLib"),
			.target(name: "CakedLib"),
			.product(name: "ArgumentParser", package: "swift-argument-parser"),
			.product(name: "GRPC", package: "grpc-swift"),
			.product(name: "CakeAgentLib", package: "CakeAgent"),
			.product(name: "NIOPortForwarding", package: "swift-nio-portforwarding"),
			.product(name: "Steps", package: "Steps"),
			.product(name: "Subprocess", package: "swift-subprocess"),
			.product(name: "SwiftTerm", package: "SwiftTerm"),
			.product(name: "FileMonitor", package: "FileMonitor"),
			.product(name: "RoyalVNCKitStatic", package: "royalvnc"),
			.product(name: "SwiftletUtilities", package: "SwiftletUtilities"),
		] + (isAppStoreBuild ? [] : [
			.product(name: "Sparkle", package: "Sparkle"),
		]),
		resources: [
			.process("Resources"),
		],
		linkerSettings: [
			.unsafeFlags([
				"-Xlinker", "-rpath",
				"-Xlinker", "@executable_path/../Frameworks"
			])
		]),
		.executableTarget(name: "caked", dependencies: [
			.target(name: "GRPCLib"),
			.target(name: "CakedLib"),
			.product(name: "ArgumentParser", package: "swift-argument-parser"),
			.product(name: "GRPC", package: "grpc-swift"),
			.product(name: "CakeAgentLib", package: "CakeAgent"),
			.product(name: "NIOPortForwarding", package: "swift-nio-portforwarding"),
			.product(name: "RoyalVNCKitStatic", package: "royalvnc"),
			.product(name: "Vapor", package: "vapor"),
		]),
		.executableTarget(name: "cakectl", dependencies: [
			.target(name: "GRPCLib"),
			.target(name: "CakedLib"),
			.product(name: "Algorithms", package: "swift-algorithms"),
			.product(name: "Antlr4Static", package: "Antlr4"),
			.product(name: "ArgumentParser", package: "swift-argument-parser"),
			.product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
			.product(name: "Atomics", package: "swift-atomics"),
			.product(name: "CakeAgentLib", package: "CakeAgent"),
			.product(name: "Crypto", package: "swift-crypto"),
			.product(name: "DMRetry", package: "swift-retry"),
			.product(name: "Dynamic", package: "Dynamic"),
			.product(name: "GRPC", package: "grpc-swift"),
			.product(name: "ISO9660", package: "iso9660-swift"),
			.product(name: "NIOCore", package: "swift-nio"),
			.product(name: "NIOEmbedded", package: "swift-nio"),
			.product(name: "NIOExtras", package: "swift-nio-extras"),
			.product(name: "NIOFoundationCompat", package: "swift-nio"),
			.product(name: "NIOHTTP1", package: "swift-nio"),
			.product(name: "NIOHTTP2", package: "swift-nio-http2"),
			.product(name: "NIOPortForwarding", package: "swift-nio-portforwarding"),
			.product(name: "NIOPosix", package: "swift-nio"),
			.product(name: "NIOSSL", package: "swift-nio-ssl"),
			.product(name: "NIOTLS", package: "swift-nio"),
			.product(name: "Semaphore", package: "Semaphore"),
			.product(name: "Sentry", package: "sentry-cocoa"),
			.product(name: "SwiftDate", package: "SwiftDate"),
			.product(name: "SwiftRadix", package: "SwiftRadix"),
			.product(name: "Sysctl", package: "swift-sysctl"),
			.product(name: "TextTable", package: "TextTable"),
			.product(name: "X509", package: "swift-certificates"),
			.product(name: "XAttr", package: "swift-xattr"),
			.product(name: "Yams", package: "Yams"),
		]),
		.testTarget(name: "CakerTests", dependencies: [
			"GRPCLib",
			"CakedLib",
			"caked",
			"cakectl"
		], exclude: [
			"echo.py",
			"TestPlan.xctestplan",
		])
	],
	swiftLanguageModes: [
		.v5
	]
)
