
internal class Timer {
	private static const Log	log	:= Drone#.pod.log
	private Duration start
	
	new make() { start = Duration.now }
	
	Void finish(Str msg) {
		if (msg.trimToNull != null)
			log.info("$msg in " + (Duration.now - start).toLocale)
	}
	
	static Obj? time(Str msg, |->Obj?| f) {
		timer := Timer()
		res	  := f()
		timer.finish(msg)
		return res
	}
}
