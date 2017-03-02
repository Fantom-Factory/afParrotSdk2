using concurrent::Actor
using concurrent::ActorPool
using gfx::Color
using gfx::Size
using fwt
using afConcurrent::Synchronized

** Kill me!
class Frame {
	private Log				log				:= Drone#.pod.log
	Drone?		drone
	Window?		window
	FlightPlan?	flight
	Widget?		butt
	
	Void attack() {
		Drone#.pod.log.level = LogLevel.debug
		
		Window {
			this.window = it
			it.title = "A.R. Drone Attack Dog 2.0"
			it.size = Size(480, 320)
			
			it.onOpen.add |->| {
				Actor.locals["DroneUi"] = this
				startup()
				window.focus
			}
			it.onClose.add |->| {
				Actor.locals.remove("DroneUi")
				shutdown()
			}
			it.add(InsetPane(16) {
					butt = Text {
						it.text = "A.R. Drone"
						it.font = Desktop.sysFont.toSize(64)
						it.editable = false
					},
//					Button {
//						it.text = "Land!"
//						it.font = Desktop.sysFont.toSize(64)
//						it.onAction.add |->| { drone.land(false) }
//					},
				}
			)
			butt.onKeyDown.add	|e| { flight.onKeyDown(e) }
			butt.onKeyUp.add	|e| { flight.onKeyUp(e) }
		}.open
	}
	
	Void startup() {
		drone = Drone()
		flight = FlightPlan()
		droneRef  := Unsafe(drone)
		windowRef := Unsafe(window)
		flightRef := Unsafe(flight)
		Synchronized(ActorPool()).async |->| {
			v := flightRef.val->fly(droneRef.val)
			if (v != true)
				Desktop.callAsync |->| { windowRef.val->close }
		}
	}
	
	Void shutdown() {
		drone.disconnect
	}
}

