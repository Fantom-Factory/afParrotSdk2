using afConcurrent
using concurrent::Actor
using concurrent::ActorPool
using fwt::Event
using fwt::Key

** Kill me!
class FlightPlan {
	private static const	Log		log		:= Drone#.pod.log

	private Sounds	sounds := Sounds()
	Bool flying
	Drone? drone
	
	Bool? fly(Drone drone) {
		this.drone = drone
//		socket	:= inet::TcpSocket().connect(inet::IpAddr(drone.config.droneIpAddr), drone.config.controlPort)
		
		thisRef := Unsafe(this)
		drone.onNavData			= |navData|			{ thisRef.val->onNavData(navData)				  }
		drone.onStateChange		= |state|			{ log.info("State Change: --> ${state}"); thisRef.val->onStateChange(state)	}
		drone.onBatteryDrain	= |newPercentage|	{ log.info("Battery now at ${newPercentage}%"	) }
		drone.onBatteryLow		= |->|				{ log.warn("   !!! Battery Level Low !!!"		) }
		drone.onEmergency		= |->|				{ log.warn("   !!! EMERGENCY LANDING !!!   "	) }
		drone.onDisconnect		= |abnormal|		{ if (abnormal) log.warn("   !!! DISCONNECTED !!!   "	) }
		
		// initiating pre-flight system checks
		drone.connect
		drone.clearEmergencyLanding
		drone.flatTrim
		
		drone.setEmergencyLanding
		
		return ctrlLoop
		
		
		
//		drone.setOutdoorFlight(false)
//		drone.animateLeds(LedAnimation.blinkGreenRed, 15sec)

//		drone.sendCmd(Cmd.makeCtrl(4, 0))
//		props	:= socket.in.readAllStr {echo("[$it]")}
//		socket.close
			
//		drone.takeOff
//
//		drone.animateFlight(FlightAnimation.theta20degYawM200Deg)
//
//		//		sounds.beep
////		drone.animateFlight(FlightAnimation.turnaround)
////		sounds.beep
////		drone.animateFlight(FlightAnimation.phiM30Deg)
////		sounds.beep
////		drone.animateFlight(FlightAnimation.phi30Deg)
////		sounds.beep
////		drone.animateFlight(FlightAnimation.phiM30Deg)
//
//		drone.land

//		drone.disconnect
		
		return null
	}
		
		
	DroneState? oldState
	NavDataFlags? oldFlags
	Void onNavData(NavData navData) {
		str := navData.flags.dumpChanged(oldFlags)
		if (!str.isEmpty)
			str.splitLines.each { log.debug(it) }
		oldFlags = navData.flags
		
//		if (oldState != navData.demoData?.droneState && navData.demoData?.droneState != null) {
//			log.debug("State Drone Change --> ${navData.demoData?.droneState}")
//			oldState = navData.demoData?.droneState
//		}
	}

	Void onStateChange(FlightState state) {
		switch (state) {
			case FlightState.transTakeOff:
				sounds.takingOff.play
			case FlightState.hovering:
				sounds.hovering.play
				flying = true
			case FlightState.transLanding:
				sounds.landing.play
			case FlightState.landed:
				if (flying)
					sounds.landed.play
				flying = false
		}
	}
	
	Float		power	:= 0.5f
	Key:Bool	keyMap	:= Key:Bool[:] 
	
	Void onKeyDown(Event event) {
		key := event.key
		if (key != null)
			keyMap[key] = true
		
		if (event.keyChar >= '0' && event.keyChar <= '9') {
			power = (event.keyChar == '0' ? 10 : 0) + event.keyChar - '0' / 10f
			echo("Power @ $power%")
		}

		if (key == Key.esc) {
			echo("Emergency!")
			drone.setEmergencyLanding
		}

		if (key == Key.enter) {
			keyMap.clear
			if (drone.state == FlightState.def || drone.state == FlightState.landed) {
				echo("Take Off")
				drone.clearEmergencyLanding
				drone.takeOff(false)
			} else {
				echo("Land")
				drone.land(false)
			}
		}

		if (key == Key.space) {
			echo("Hover")
			keyMap.clear
			drone.hover(false)
		}
		
		if (key == Key.f1)
			drone.animateFlight(FlightAnimation.phi30Deg, null, false)
		if (key == Key.f2)
			drone.animateFlight(FlightAnimation.phiM30Deg, null, false)

		if (key == Key.f3)
			drone.animateFlight(FlightAnimation.theta20degYaw200Deg, null, false)
		if (key == Key.f4)
			drone.animateFlight(FlightAnimation.theta20degYawM200Deg, null, false)

		if (key == Key.f5)
			drone.animateFlight(FlightAnimation.flipRight, null, false)

		if (key == Key.f7)
			drone.animateFlight(FlightAnimation.doublePhiThetaMixed, null, false)
		if (key == Key.f8)

		drone.animateFlight(FlightAnimation.wave, null, false)
	}

	Void onKeyUp(Event event) {
		if (event.key != null)
			keyMap.remove(event.key)
	}
	
	Synchronized thread := Synchronized(ActorPool())
	Bool ctrlLoop() {
		thisRef := Unsafe(this)
		thread.asyncLater(30ms) |->| { thisRef.val->doCtrlLoop }
		return true
	}

	Void doCtrlLoop() {
		vert  := 0f
		yaw   := 0f
		roll  := 0f
		pitch := 0f

		if (keyMap.containsKey(Key.a))		roll  = -power
		if (keyMap.containsKey(Key.d))		roll  =  power
		if (keyMap.containsKey(Key.w))		pitch = -power
		if (keyMap.containsKey(Key.s))		pitch =  power
		if (keyMap.containsKey(Key.down))	vert  = -power
		if (keyMap.containsKey(Key.up))		vert  =  power
		if (keyMap.containsKey(Key.left))	yaw   = -power
		if (keyMap.containsKey(Key.right))	yaw   =  power
		if (keyMap.containsKey(Key.q))		yaw   = -power
		if (keyMap.containsKey(Key.e))		yaw   =  power
		
		drone.move(roll, pitch, vert, yaw, null)
		
		thisRef := Unsafe(this)
		thread.asyncLater(30ms) |->| { thisRef.val->doCtrlLoop }
	}
}
