// swift-tools-version: 6.0

import PackageDescription

let package = Package(
	name: "TokenInputField",
	platforms: [
		.macOS(.v15)
	],
	products: [
		.library(
			name: "TokenInputField",
			targets: ["TokenInputField"]
		)
	],
	targets: [
		.target(
			name: "TokenInputField"
		)
	]
)
