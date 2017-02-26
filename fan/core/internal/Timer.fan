
internal class Timer {
	private static const Log	log	:= Drone#.pod.log
	private Duration start
	
	new make() { start = Duration.now }
	
	Void finish(Str msg) {
		log.info("$msg in " + (Duration.now - start).toLocale)
	}
}
