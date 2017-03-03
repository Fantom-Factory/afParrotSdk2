using gfx
using fwt
using afFish2

class ScreenIntro : Screen {
	
	new make(AnsiTerminal text, Drone drone) : super(text, drone) { }
	
	override Void onEnter() {
		try {
			drone.connect
		} catch {
			exit
			ScreenDisconnect(terminal, drone).enter
			return
		}

		showLogo(AnsiBuf().fgIdx(10).add("Connected to Drone v${drone.droneVersion}").reset)
		terminal.print("\n")
		terminal.print(centre("--- KEYS ----")).print("\n")
		terminal.print("\n")
		terminal.print(centre("ESC ......... Initiate Emergency Landing")).print("\n")
		terminal.print(centre("ENTER ....... Take off / Land           ")).print("\n")
		terminal.print(centre("SPACE ....... Hover                     ")).print("\n")
		terminal.print("\n")
		terminal.print(centre("1-9 ......... Max Power / Tilt Angle    ")).print("\n")
		terminal.print(centre("WASD ........ Move                      ")).print("\n")
		terminal.print(centre("Q E ......... Spin                      ")).print("\n")
		terminal.print(centre("Up / Down ... Altitude                  ")).print("\n")
		terminal.print("\n")
		terminal.print(centre(".... press any key to continue...")).print("\n")
	}
	
	override Void onKeyUp(Event e) {
		if (drone.isConnected) {
			exit
			ScreenMain(terminal, drone).enter
		}
	}
}

class ScreenDisconnect : Screen {
	new make(AnsiTerminal text, Drone drone) : super(text, drone) { }
	
	override Void onEnter() {
		showLogo(AnsiBuf().fg(terminal.errStyle.fg).add("!!! DISCONNECTED !!!").reset)
		terminal.printErr("\n" + centre(" --- check your wifi settings ---") + "\n")
	}
}
