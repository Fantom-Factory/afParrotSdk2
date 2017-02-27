using concurrent::Actor
using concurrent::ActorPool
using fwt::Desktop
using afConcurrent

** Kill me!
class DroneUi {
	private Log				log				:= Drone#.pod.log
	Drone?	drone
	
	Void startup() {
		echo("Hello!")

		drone = Drone()
		drone.addNavDataListener |navData| {
			Desktop.callAsync |->| {
				drone := (DroneUi) Actor.locals["DroneUi"]
				drone.onNavData(navData)
			}
		}
		drone.connect
		
		droneRef := Unsafe(drone)
		Synchronized(ActorPool()).async |->| {
			FlightPlan().fly(droneRef.val)
		}
	}
	
	
	Int oldStateFlags
	Void onNavData(NavData navData) {
		// TODO move to dumpChanged() meth in flags
		if (oldStateFlags.xor(navData.flags.stateFlags) > 0) {
			oldState := NavDataFlags(oldStateFlags)
			buf := StrBuf(1024)
			NavDataFlags#.methods.findAll { it.returns == Bool# && it.params.isEmpty && it.parent == NavDataFlags# }
				.exclude { it == NavDataFlags#comWatchdogProblem || it == NavDataFlags#controlCommandAck }
				.each {
					oldVal := it.callOn(oldState, null)
					newVal := it.callOn(navData.flags, null)
					if (newVal != oldVal) {
						buf.addChar('\n')
						buf.add(it.name.padr(28, '.'))
						buf.add(oldVal).add(" --> ").add(newVal)
					}
				}
			if (!buf.isEmpty)
				log.debug(buf.toStr)
			oldStateFlags = navData.flags.stateFlags
		}
	
	}
	
	Void shutdown() {
		drone.crashLand
		drone.disconnect
		Actor.locals.remove("DroneEvents")
		echo("Goodbye!")
	}
}

