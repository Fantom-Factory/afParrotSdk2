using concurrent::Actor
using fwt::Desktop

class DroneEvents {
	
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
		
//		drone.flatTrim
//		
//		drone.takeOff
//		
//		Actor.sleep(5sec)
//
//		drone.land
	}
	
	
	Int oldStateFlags
	Void onNavData(NavData navData) {
		if (oldStateFlags.xor(navData.stateFlags) > 0) {
			echo("  StateChange: ${navData.stateFlags.toHex(8).upper}")
			
			oldState := DroneState(oldStateFlags)
			buf := StrBuf(1024)
			DroneState#.methods.findAll { it.returns == Bool# && it.params.isEmpty && it.parent == DroneState# }.each {
				oldVal := it.callOn(oldState, null)
				newVal := it.callOn(navData.state, null)
				if (newVal != oldVal) {
					buf.add(it.name.padr(28, '.'))
					buf.add(oldVal).add(" --> ").add(newVal)
					buf.addChar('\n')
				}
			}
			echo(buf.toStr)
			oldStateFlags = navData.stateFlags
		}
	
	}
	
	Void shutdown() {
		drone.disconnect
		Actor.locals.remove("DroneEvents")
		echo("Goodbye!")
	}
}
