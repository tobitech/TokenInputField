// swift-tools-version: 6.0

import PackageDescription

let package = Package(
	name: "PromptComposer",
	platforms: [
		.macOS(.v15)
	],
	products: [
		.library(
			name: "PromptComposer",
			targets: ["PromptComposer"]
		)
	],
	targets: [
		.target(
			name: "PromptComposer"
		)
	]
)
