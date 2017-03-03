using concurrent::Actor
using concurrent::ActorPool
using gfx
using fwt
using afConcurrent::Synchronized
using afFish2

** Kill me!
class Frame {
	private Log				log				:= Drone#.pod.log

	Drone?			drone
	Window?			window
	Widget?			text
	AnsiTerminal?	terminal
	
	Void boot() {
		Drone#.pod.log.level = LogLevel.debug
		
		terminal := AnsiTerminal()
		
		Window {
			this.window = it
			it.title = "A.R. Drone SDK Demo for Fantom"
			it.size = Size(440, 340)
//			it.resizable = false
			
			it.onOpen.add |->| {
				drone = Drone()
				terminal.print("Connecting to drone...")
				Desktop.callLater(50ms) |->| {
					ScreenIntro(terminal, drone).enter
				}
			}
			it.onClose.add |->| {
				drone.disconnect
			}
			it.add(
				terminal.richText
			)
		}.open
	}
}

