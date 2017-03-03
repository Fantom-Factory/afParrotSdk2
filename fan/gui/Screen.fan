using fwt

class Screen {
	Label	screen
	Drone	drone
	Int		maxWidth() { (screen.bounds.w / screen.font.width("W") - 4).max(48) }
	
	private	|Event| onKeyDownListener	:= #onKeyDown.func.bind([this])
	private	|Event| onKeyUpListener		:= #onKeyUp.func.bind([this])

	new make(Label screen, Drone drone) {
		this.screen	= screen
		this.drone	= drone
	}
	
	Void enter() {
		screen.window.onKeyDown.add(onKeyDownListener)
		screen.window.onKeyUp.add	(onKeyUpListener)
		onEnter
	}
	
	Void exit() {
		screen.window.onKeyDown.remove(onKeyDownListener)
		screen.window.onKeyUp.remove  (onKeyUpListener)
		onExit
	}
	
	Void showLogo(Str text := "") {
		title	 := "A.R. Drone Controller ${typeof.pod.version}"
		titlePad := "".justl(maxWidth - 9 - title.size)
		textPad  := "".justl(maxWidth - 9 - text.size)
		logo	 := 
			"  _____  \n" +
			" /X | X\\ " + titlePad + title + "\n" + 
			"|__\\|/__|" + "by Alien-Factory".justr(maxWidth - 9) + "\n" + 
			"|  /|\\  |" + "\n" + 
			" \\X_|_X/ " + textPad + text + "\n"
		
		screen.text = logo
	}
	
	Str centre(Str txt, Int width := maxWidth) {
		("".justl((width - txt.size) / 2) + txt).justl(width)
	}
	
	Void vpad() {
		(20 - screen.text.numNewlines).times { screen.text += "\n" }
	}
	
	virtual Void onKeyDown(Event e) { }
	virtual Void onKeyUp(Event e) { }
	virtual Void onEnter() { }
	virtual Void onExit() { }
}
