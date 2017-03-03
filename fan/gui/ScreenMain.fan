using afFish2
using fwt
using afConcurrent
using concurrent

class ScreenMain : Screen {

	private Synchronized? thread
	
	new make(AnsiTerminal terminal, Drone drone) : super(terminal, drone) { }
	
	override Void onEnter() {
		showLogo(AnsiBuf().fgIdx(2).add("Connected to Drone v${drone.droneVersion}").reset)
		terminal.print("\n")
		terminal.print(AnsiBuf().curSave)
		
		thisRef := Unsafe(this)
		
		drone.onDisconnect = |->| {
			Desktop.callAsync |->| {
				thisRef.val->exit
				ScreenDisconnect(thisRef.val->terminal, thisRef.val->drone).enter
			}
		}
		
		thread = Synchronized(ActorPool())
		thread.asyncLater(30ms) |->| { thisRef.val->controlLoop }
	}
	
	Void controlLoop() {
		thisRef := Unsafe(this)
		Desktop.callAsync |->| { thisRef.val->printScreen }
		
		thread.asyncLater(30ms) |->| { thisRef.val->controlLoop }
	}
	
	override Void onKeyDown(Event e) {
		if (drone.isConnected) {
			exit
		}
	}
	
	Void printScreen() {
//		terminal.print(AnsiBuf().curRestore)
		terminal.print(AnsiBuf().clearScreen)
		showLogo(AnsiBuf().fgIdx(2).add("Connected to Drone v${drone.droneVersion}").reset)
		buf := AnsiBuf().addChar('\n')
		
		navData := drone.navData
		flags	:= navData.flags
		data	:= navData.demoData
		line	:= ""
		pad		:= ""
		
		//Flight Status: Landed       Battery Level : 57%
		status	:= "Flight Status: ${drone.state.name.toDisplayName}"
		battery	:= "Battery Level: ${data.batteryPercentage}%"
		pad		= "".justl(maxWidth - status.size - battery.size)
		buf.print(status).print(pad).print(battery).addChar('\n')
		buf.addChar('\n')
		buf.print("Altitude   : ${data.altitude} cm").addChar('\n')
		
//Orientation : [X] -24.04   [Y]  3.99  [Z] 40.00
//Velocity    : [X] -24.04   [Y]  3.99  [Z] 40.00
		terminal.print(buf)
	}
}
