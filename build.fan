using build

class Build : BuildPod {

	new make() {
		podName = "afParrotSdk2"
		summary = "An SDK for remotely piloting the Parrot AR Drone 2.0 quadcopter"
		version = Version("0.0.3")

		meta = [
			"pod.dis"			: "Parrot Drone SDK 2",
			"repo.tags"			: "misc",
			"repo.public"		: "true"
		]

		depends = [
			"sys          1.0.69 - 1.0",
			"inet         1.0.69 - 1.0",
			"concurrent   1.0.69 - 1.0",
			"afConcurrent 1.0.18 - 1.0",
		]

		srcDirs = [`fan/`, `fan/advanced/`, `fan/config/`, `fan/internal/`, `fan/public/`]
		resDirs = [`doc/`]
	}
}
