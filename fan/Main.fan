using concurrent::Actor
using gfx::Size
using fwt::Window

class Main {
	
	Void main() {
		Drone#.pod.log.level = LogLevel.debug
		
		Window {
			win  := it
			it.title = "A.R. Drone 2.0"
			it.size = Size(480, 320)
			
			it.onOpen.add |->| {
				startup()
			}
			it.onClose.add |->| {
				shutdown()
			}
		}.open
	}
	
	Void startup() {
		drone := DroneEvents()
		Actor.locals["DroneEvents"] = drone
		drone.startup
	}
	
	Void shutdown() {
		drone := (DroneEvents) Actor.locals["DroneEvents"]
		drone.shutdown
	}	
}
