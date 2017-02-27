using concurrent::Actor
using concurrent::ActorPool
using gfx::Color
using gfx::Size
using fwt::Desktop
using fwt::Window
using fwt::Button
using fwt::InsetPane
using afConcurrent::Synchronized

** Kill me!
class AttackDog {
	private Log				log				:= Drone#.pod.log
	Drone?	drone
	
	Void attack() {
		Drone#.pod.log.level = LogLevel.debug
		
		Window {
			win  := it
			it.title = "A.R. Drone Attack Dog 2.0"
			it.size = Size(480, 320)
			
			it.onOpen.add |->| {
				Actor.locals["DroneUi"] = this
				startup()
			}
			it.onClose.add |->| {
				Actor.locals.remove("DroneUi")
				shutdown()
			}
			it.add(InsetPane(16) {
					Button {
						it.text = "Kill Switch!"
						it.font = Desktop.sysFont.toSize(48)
						it.fg	= Color.red
						it.onAction.add |->| { win.close }
					},
				}
			)
		}.open
	}
	
	Void startup() {
		drone = Drone()
		droneRef := Unsafe(drone)
		Synchronized(ActorPool()).async |->| {
			FlightPlan().fly(droneRef.val)
		}
	}
	
	Void shutdown() {
		drone.disconnect
	}
}

