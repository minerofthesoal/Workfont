// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GlyphCrafterDeps",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "GlyphCrafterDeps", targets: ["GlyphCrafterDeps"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.21.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", branch: "main"),
    ],
    targets: [
        .target(
            name: "GlyphCrafterDeps",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
            ]
        ),
    ]
)
