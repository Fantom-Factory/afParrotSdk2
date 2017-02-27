using concurrent::Actor
using gfx::Size
using fwt::Window

internal class Main {

	Void main() {
		
		FlightPlan().fly(Drone())
		
	}
	
//	Void main() {
//		Drone#.pod.log.level = LogLevel.debug
//		
//		Window {
//			win  := it
//			it.title = "A.R. Drone 2.0"
//			it.size = Size(480, 320)
//			
//			it.onOpen.add |->| {
//				startup()
//			}
//			it.onClose.add |->| {
//				shutdown()
//			}
//		}.open
//	}
	
	Void startup() {
		drone := DroneUi()
		Actor.locals["DroneUi"] = drone
		drone.startup
	}
	
	Void shutdown() {
		drone := (DroneUi) Actor.locals["DroneUi"]
		drone.shutdown
	}	
}
