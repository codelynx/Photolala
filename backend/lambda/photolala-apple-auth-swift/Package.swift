// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "photolala-apple-auth",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PhotolalaAppleAuth", targets: ["PhotolalaAppleAuth"])
    ],
    dependencies: [
        // AWS Lambda Runtime
        .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git", from: "1.0.0"),
        // AWS SDK for Swift
        .package(url: "https://github.com/awslabs/aws-sdk-swift.git", from: "0.36.0"),
        // JWT decoding
        .package(url: "https://github.com/vapor/jwt-kit.git", from: "4.0.0"),
        // Async HTTP Client
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.19.0")
    ],
    targets: [
        .executableTarget(
            name: "PhotolalaAppleAuth",
            dependencies: [
                .product(name: "AWSLambdaRuntime", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSLambdaEvents", package: "swift-aws-lambda-runtime"),
                .product(name: "AWSS3", package: "aws-sdk-swift"),
                .product(name: "JWTKit", package: "jwt-kit"),
                .product(name: "AsyncHTTPClient", package: "async-http-client")
            ]
        )
    ]
)