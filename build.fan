using build

class Build : BuildPod {

	new make() {
		podName = "afArDroneSdk"
		summary = "A pure Fantom implementation of the Parrot AR Drone 2.0 SDK"
		version = Version("0.0.1")

		meta = [
			"pod.dis"		: "Parrot Drone",
		]

		depends = [
			"sys         1.0.69 - 1.0",
			"inet        1.0.69 - 1.0",
			"concurrent  1.0.69 - 1.0",

			"fwt  1.0.69 - 1.0",
			"gfx  1.0.69 - 1.0",

			"afConcurrent 1.0.17 - 1.0", 
		]

		srcDirs = [`fan/`, `fan/core/`, `fan/core/advanced/`, `fan/core/internal/`, `fan/core/public/`, `fan/gamecontroller/`, `fan/gui/`]
		resDirs = [`res/`]
	}
}
