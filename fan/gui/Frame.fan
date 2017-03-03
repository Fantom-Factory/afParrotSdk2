using gfx
using fwt

** Kill me!
class Frame {
	private Log				log				:= Drone#.pod.log

	Drone?	drone
	Window?	window
	Label?	screen
	
	Void boot() {
		Drone#.pod.log.level = LogLevel.debug
		
		Window {
			this.window = it
			it.title = "A.R. Drone SDK Demo for Fantom"
			it.size = Size(440, 340)
			
			it.onOpen.add |->| {
				drone = Drone()
				screen.text = "Connecting to drone..."
				ScreenIntro(screen, drone).vpad
				window.focus
				Desktop.callLater(50ms) |->| {
					ScreenIntro(screen, drone).enter
				}
			}
			it.onClose.add |->| {
				drone.disconnect
			}
			it.add(
				screen = Label {
					it.font = Font { name = "Consolas"; size = 10}
					it.bg	= Color(0x202020)
					it.fg	= Color(0x31E722)
				}
			)
		}.open
	}
}

