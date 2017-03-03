using fwt
using afFish2

class Screen {
	AnsiTerminal	terminal
	Drone			drone
	Int				maxWidth() { terminal.cols.max(48) }
	
	private	|Event| onKeyDownListener	:= #onKeyDown.func.bind([this])
	private	|Event| onKeyUpListener		:= #onKeyUp.func.bind([this])

	new make(AnsiTerminal terminal, Drone drone) {
		this.terminal	= terminal
		this.drone		= drone
	}
	
	Void enter() {
		terminal.richText.onVerifyKey.add	(onKeyDownListener)
		terminal.richText.onKeyUp.add	(onKeyUpListener)
		terminal.clear
		onEnter
	}
	
	Void exit() {
		terminal.richText.onKeyDown.remove	(onKeyDownListener)
		terminal.richText.onKeyUp.remove	(onKeyUpListener)
		onExit
	}
	
	Void showLogo(Obj text := "") {
		str		 := text.toStr
		title	 := "A.R. Drone Controller ${typeof.pod.version}"
		titlePad := "".justl(maxWidth - 9 - title.size)
		textPad  := "".justl(maxWidth - 9 - AnsiBuf(str).toPlain.size)
		buf := AnsiBuf().clearScreen.add(
			"  _____  \n" +
			" /X | X\\ " + titlePad).underline.add(title).underline(false).add("\n" + 
			"|__\\|/__|" + "by Alien-Factory".justr(maxWidth - 9) + "\n" + 
			"|  /|\\  |" + "\n" + 
			" \\X_|_X/ " + textPad + str + "\n")
		terminal.print(buf.toAnsi)
	}
	
	Str centre(Str txt) {
		"".justl((maxWidth - txt.size) / 2) + txt
	}
	
	virtual Void onKeyDown(Event e) { }
	virtual Void onKeyUp(Event e) { }
	virtual Void onEnter() { }
	virtual Void onExit() { }
}
