using gfx
using fwt

class ScreenIntro : Screen {
	
	new make(Label screen, Drone drone) : super(screen, drone) { }
	
	override Void onEnter() {
		try {
			StateLogger().start(drone)
			drone.connect
			drone.clearEmergencyLanding
			drone.flatTrim

		} catch(Err err) {
			err.trace
			exit
			ScreenDisconnect(screen, drone).enter
			return
		}

		showLogo("Connected to Drone v${drone.droneVersion}")
		text := ""
		text += "\n"
		text += centre("--- KEYS ----") + "\n"
		text += "\n"
		text += centre("ESC ......... Initiate Emergency Landing") + "\n"
		text += centre("ENTER ....... Take off / Land           ") + "\n"
		text += centre("SPACE ....... Hover                     ") + "\n"
		text += "\n"
		text += centre("1-9 ......... Max Power / Tilt Angle    ") + "\n"
		text += centre("WASD ........ Move                      ") + "\n"
		text += centre("Q E ......... Spin                      ") + "\n"
		text += centre("Up / Down ... Altitude                  ") + "\n"
		text += "\n"
		text += centre(".... press any key to continue...") + "\n"
		
		screen.text += text
		vpad
	}
	
	override Void onKeyUp(Event e) {
		if (drone.isConnected) {
			exit
			ScreenMain(screen, drone).enter
		}
	}
}

