// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QuillSwiftUI",
    
    platforms: [.iOS(.v15)],
    
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "QuillSwiftUI",
            targets: ["QuillSwiftUI"]),
    ],
    
    dependencies: [
        .package(url: "https://github.com/SwifterSwift/SwifterSwift.git", .upToNextMinor(from: "7.0.0"))
    ],
    
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "QuillSwiftUI", dependencies: [.product(name: "SwifterSwift", package: "SwifterSwift")]),
        .testTarget(
            name: "QuillSwiftUITests",
            dependencies: ["QuillSwiftUI"]),
    ]
)
