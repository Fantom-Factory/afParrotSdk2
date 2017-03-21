using afParrotSdk2
using fwt::Desktop
using fwt::Label
using fwt::Window
using gfx::Color
using gfx::Font
using gfx::Size
using concurrent::Actor
using concurrent::ActorPool

** Uses the Drone's onNavData event to display basic telemetry data.
class NavDataViewer {
	Drone	drone	:= Drone()
	Label?	screen
	
	Void main() {
		thisRef	:= Unsafe(this)
		Window {
			it.title	= "Parrot SDK 2.0 - NavData Demo"
			it.size		= Size(440, 300)
			it.onOpen.add |->| {
				drone.onNavData = |NavData navData| {
					// always UI stuff (i.e. print data) in the UI thread
					Desktop.callAsync |->| { thisRef.val->printNavData(navData) }
				}
				
				// fly drone in it's own thread
				Actor(ActorPool(), |->| { thisRef.val->fly }).send(null)
			}
			it.onClose.add |->| {
				drone.disconnect
			}
			it.add(
				screen = Label {
					it.font = Font { name = "Consolas"; size = 10}
					it.bg	= Color(0x202020)
					it.fg	= Color(0x31E722)
					it.text = "Connecting to drone..."
				}
			)
		}.open
	}
	
	Void fly() {
		drone.connect

		drone.takeOff
		drone.spinClockwise(0.5f, 3sec)
		drone.moveForward  (1.0f, 2sec)
		drone.animateFlight(FlightAnimation.flipBackward)
		drone.land
		
		drone.disconnect
	}
	
	Void printNavData(NavData navData) {
		if (navData.demoData == null) return

		logo	:= showLogo("Connected to Drone v${drone.droneVersion}")
		buf		:= StrBuf(1024 * 2).add(logo)
		flags	:= navData.flags
		data	:= navData.demoData
		line	:= ""
		pad		:= ""
		
		buf.addChar('\n')
		status	:= "Flight Status: ${drone.flightState.name.toDisplayName}"
		battery	:= "Battery Level: ${data.batteryPercentage}%"
		pad		= "".justl(maxWidth - status.size - battery.size)
		buf.add(status).add(pad).add(battery).addChar('\n')
		buf.addChar('\n')
		buf.add("Altitude   : " + data.altitude.toLocale("0.00") + " m").addChar('\n')
		buf.add("Orientation: ")
		printNum(buf, "X", data.phi)
		printNum(buf, "Y", data.theta)
		printNum(buf, "Z", data.psi)
		buf.addChar('\n')
		buf.add("Velocity   : ")
		printNum(buf, "X", data.velocityX)
		printNum(buf, "Y", data.velocityY)
		printNum(buf, "Z", data.velocityZ)
		buf.addChar('\n')
		buf.addChar('\n')		

		buf.add(centre(flags.flying ? "--- Flying ---" : "")).addChar('\n')		
		emer := flags.emergencyLanding ? "*** EMERGENCY ***" : ""
		emer  = flags.userEmergencyLanding ? "*** USER EMERGENCY ***" : emer
		buf.add(centre(emer)).addChar('\n')		
		buf.add(centre(flags.batteryTooLow ? "*** BATTERY LOW ***" : "")).addChar('\n')		
		
		[NavDataFlags#motorProblem,
		NavDataFlags#gyrometersDown,
		NavDataFlags#magnometerNeedsCalibration,
		NavDataFlags#anglesOutOufRange,
		NavDataFlags#tooMuchWind,
		NavDataFlags#ultrasonicSensorDeaf,
		NavDataFlags#cutOutDetected].each {
			if (it.call(flags) == true)
				buf.add(centre("!!! ${it.name.toDisplayName} !!!")).addChar('\n')
		}

		screen.text = buf.toStr
	}
	
	Str showLogo(Str text) {
		title	 := "Fantom Drone SDK Demo"
		titlePad := "".justl(maxWidth - 9 - title.size)
		textPad  := "".justl(maxWidth - 9 - text.size)
		logo	 := 
			"         \n" +
			"  X ‖ X  " + titlePad + title + "\n" + 
			"   \\#/   " + "by Alien-Factory".justr(maxWidth - 9) + "\n" + 
			"   /#\\   " + "\n" + 
			"  X   X  " + textPad + text + "\n"
		
		return logo
	}
	
	Void printNum(StrBuf buf, Str str, Float num) {
		buf.add("[").add(str).add("]")
		buf.add(num.toLocale("0.00").justr(7))
		buf.add("   ")
	}

	Str centre(Str txt, Int width := maxWidth) {
		("".justl((width - txt.size) / 2) + txt).justl(width)
	}

	Int	maxWidth() { (screen.bounds.w / screen.font.width("W") - 1).max(48) }
}