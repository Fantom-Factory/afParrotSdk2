using fwt
using afConcurrent
using concurrent

class ScreenMain : Screen {
	private static const	Log		log		:= Drone#.pod.log

	ActorPool		actorPool	:= ActorPool()
	Synchronized?	thread
	Float			maxPower	:= 0.5f
	Key:Int			keyMap		:= Key:Int[:] 
	
	new make(Label screen, Drone drone) : super(screen, drone) { }
	
	override Void onEnter() {
		thisRef := Unsafe(this)
		drone.onDisconnect = |abnormal| {
			Desktop.callAsync |->| {
				if (abnormal) log.warn("   !!! DISCONNECTED !!!   "	)
				thisRef.val->actorPool->stop
				thisRef.val->exit
				ScreenDisconnect(thisRef.val->screen, thisRef.val->drone).enter
			}
		}
		
		thread = Synchronized(actorPool)
		thread.asyncLater(30ms) |->| { thisRef.val->controlLoop }
	}
	
	Void controlLoop() {
		thisRef := Unsafe(this)
		Desktop.callAsync |->| { thisRef.val->printScreen }
		
		if (!actorPool.isStopped)
			thread.asyncLater(30ms) |->| { thisRef.val->controlLoop }
	}

	
	Void printScreen() {
		showLogo("Connected to Drone v${drone.droneVersion}")
		buf := StrBuf(1024 * 2)
		
		navData := drone.navData
		flags	:= navData.flags
		data	:= navData.demoData
		line	:= ""
		pad		:= ""
		
		buf.addChar('\n')
		status	:= "Flight Status: ${drone.state.name.toDisplayName}"
		battery	:= "Battery Level: ${data.batteryPercentage}%"
		pad		= "".justl(maxWidth - status.size - battery.size)
		buf.add(status).add(pad).add(battery).addChar('\n')
		buf.addChar('\n')
		buf.add("Altitude   : ${data.altitude} cm").addChar('\n')
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
		
		pow := maxPower.multInt(100).toInt
		buf.addChar('\n')
		buf.add("Power : ")
		buf.add("=" * ((maxWidth - 8 - pow.toStr.size - 2) * maxPower).toInt)
		buf.addChar(' ')
		buf.add(pow)
		buf.addChar('%')
		buf.addChar('\n')
		buf.addChar('\n')
		
		keyW := (keyMap.get(Key.w,     0) * maxPower).toInt
		keyA := (keyMap.get(Key.a,     0) * maxPower).toInt
		keyS := (keyMap.get(Key.s,     0) * maxPower).toInt
		keyD := (keyMap.get(Key.d,     0) * maxPower).toInt
		up   := (keyMap.get(Key.up,    0) * maxPower).toInt
		down := (keyMap.get(Key.down,  0) * maxPower).toInt
		left := (keyMap.get(Key.left,  0) * maxPower).toInt
		righ := (keyMap.get(Key.right, 0) * maxPower).toInt
		left  = (keyMap.get(Key.q,     0) * maxPower).toInt.max(left)
		righ  = (keyMap.get(Key.e,     0) * maxPower).toInt.max(righ)

		lin1 := "    ${keyStr(keyW)}                                   ${keyStr(up)}    "
		lin2 := centre(flags.flying ? "--- Flying ---" : "", lin1.size)
		merge(buf, lin1, lin2)

		emer := flags.emergencyLanding ? "*** EMERGENCY ***" : ""
		emer  = flags.userEmergencyLanding ? "*** USER EMERGENCY ***" : emer
		lin1 = "  ${keyStr(keyA)}  ${keyStr(keyD)}                               ${keyStr(left)}  ${keyStr(righ)}  "
		lin2 = centre(emer, lin1.size)
		merge(buf, lin1, lin2)
		
		lin1 = "    ${keyStr(keyS)}                                   ${keyStr(down)}    "
		lin2 = centre(flags.batteryTooLow ? "*** BATTERY LOW ***" : "", lin1.size)
		merge(buf, lin1, lin2)
		
		
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

		screen.text += buf.toStr
		vpad
	}
	
	Str keyStr(Int val) {
		val == 0 ? "--" : val.toHex(2).upper
	}
	
	Void merge(StrBuf buf, Str lin1, Str lin2) {
		b := StrBuf(buf.size)
		lin1.each |c1, i| {
			c2 := lin2[i]
			b.addChar(c1.isSpace ? c2 : c1)
		}
		buf.add(centre(b.toStr))
		buf.addChar('\n')
	}
	
	Void printNum(StrBuf buf, Str str, Float num) {
		buf.add("[").add(str).add("]")
		buf.add(num.toLocale("0.00").justr(7))
		buf.add("   ")
	}

	override Void onKeyUp(Event event) {
		if (event.key != null)
			keyMap.remove(event.key)
	}

	override Void onKeyDown(Event event) {
		key := event.key
		if (key != null)
			keyMap[key] = 0xFF
		
		if (event.keyChar >= '0' && event.keyChar <= '9') {
			maxPower = ((event.keyChar == '0' ? 10 : 0) + event.keyChar - '0') / 10f
		}

		if (key == Key.esc) {
			drone.setEmergencyLanding
		}

		if (key == Key.enter) {
			keyMap.clear
			if (drone.state == FlightState.def || drone.state == FlightState.landed) {
				drone.clearEmergencyLanding
				drone.takeOff(false)
			} else {
				drone.land(false)
			}
		}

		if (key == Key.space) {
			keyMap.clear
			drone.hover(false)
		}
		
//		if (key == Key.f1)
//			drone.animateFlight(FlightAnimation.phi30Deg, null, false)
//		if (key == Key.f2)
//			drone.animateFlight(FlightAnimation.phiM30Deg, null, false)
//
//		if (key == Key.f3)
//			drone.animateFlight(FlightAnimation.theta20degYaw200Deg, null, false)
//		if (key == Key.f4)
//			drone.animateFlight(FlightAnimation.theta20degYawM200Deg, null, false)
//
//		if (key == Key.f5)
//			drone.animateFlight(FlightAnimation.flipRight, null, false)
//
//		if (key == Key.f7)
//			drone.animateFlight(FlightAnimation.doublePhiThetaMixed, null, false)
//		if (key == Key.f8)
//
//		drone.animateFlight(FlightAnimation.wave, null, false)
	}
}
