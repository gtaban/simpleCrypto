// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


#if os(Linux)
    var dependencies: [Package.Dependency] = [
        .package(url: "https://github.com/IBM-Swift/OpenSSL.git", from: "0.0.0")
    ]
#else
    var dependencies: [Package.Dependency] = [
        .package(url: "https://github.com/IBM-Swift/OpenSSL-OSX.git", from: "0.0.0")
    ]
#endif

let package = Package(
    name: "simpleRSA",
    dependencies: dependencies,
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "simpleRSA",
            dependencies: []
        ),
    ]
)
