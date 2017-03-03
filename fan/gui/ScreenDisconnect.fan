using fwt

class ScreenDisconnect : Screen {
	new make(Label text, Drone drone) : super(text, drone) { }
	
	override Void onEnter() {
		showLogo("!!! DISCONNECTED !!!")
		screen.text += "\n" + centre("--- check your wifi settings ---") + "\n"
		screen.text += "\n" + centre("... press any key to quit ...") + "\n"
		vpad
	}
	
	override Void onKeyUp(Event e) {
		screen.window.close
	}
}