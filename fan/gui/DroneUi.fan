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
		drone.onNavData = |navData| {
			Desktop.callAsync |->| {
				drone := (DroneUi) Actor.locals["DroneUi"]
				drone.onNavData(navData)
			}
		}
		
		droneRef := Unsafe(drone)
		Synchronized(ActorPool()).async |->| {
			FlightPlan().fly(droneRef.val)
		}
	}
	
	NavDataFlags? oldFlags
	Void onNavData(NavData navData) {
		str := navData.flags.dumpChanged(oldFlags)
		if (!str.isEmpty)
			log.debug("\n${str}")
		oldFlags = navData.flags
	}
	
	Void shutdown() {
		drone.crashLand
		drone.disconnect
		Actor.locals.remove("DroneEvents")
		echo("Goodbye!")
	}
}

