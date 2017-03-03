using build

class Build : BuildPod {

	new make() {
		podName = "afParrotSdk2"
		summary = "A pure Fantom implementation of the Parrot Drone SDK 2.0"
		version = Version("0.0.1")

		meta = [
			"pod.dis"		: "Parrot Drone SDK 2.0.1",
		]

		depends = [
			"sys          1.0.69 - 1.0",
			"inet         1.0.69 - 1.0",
			"concurrent   1.0.69 - 1.0",
			"afConcurrent 1.0.17 - 1.0",
		]

		srcDirs = [`fan/`, `fan/core/`, `fan/core/advanced/`, `fan/core/internal/`, `fan/core/public/`]
		resDirs = [,]
	}
}
