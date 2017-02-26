using concurrent::Actor
using concurrent::ActorPool
using fwt::Desktop
using afConcurrent

class DroneEvents {
	private Log				log				:= Drone#.pod.log
	Drone?	drone
	
	Void startup() {
		echo("Hello!")

		drone = Drone()
		drone.addNavDataListener |navData| {
			Desktop.callAsync |->| {
				drone := (DroneEvents) Actor.locals["DroneEvents"]
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
		if (oldStateFlags.xor(navData.stateFlags) > 0) {
			oldState := DroneState(oldStateFlags)
			buf := StrBuf(1024)
			DroneState#.methods.findAll { it.returns == Bool# && it.params.isEmpty && it.parent == DroneState# }
				.exclude { it == DroneState#comWatchdogProblem }
				.each {
					oldVal := it.callOn(oldState, null)
					newVal := it.callOn(navData.state, null)
					if (newVal != oldVal) {
						buf.addChar('\n')
						buf.add(it.name.padr(28, '.'))
						buf.add(oldVal).add(" --> ").add(newVal)
					}
				}
			if (!buf.isEmpty)
				log.debug(buf.toStr)
			oldStateFlags = navData.stateFlags
		}
	
	}
	
	Void shutdown() {
		drone.crashLand
		drone.disconnect
		Actor.locals.remove("DroneEvents")
		echo("Goodbye!")
	}
}

