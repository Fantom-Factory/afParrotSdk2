using concurrent::Actor

** Kill me!
class FlightPlan {
	private static const	Log		log		:= Drone#.pod.log

	private Sounds	sounds := Sounds()
	Bool flying
	
	Void fly(Drone drone) {
		
		thisRef := Unsafe(this)
		drone.onNavData			= |navData|			{ thisRef.val->onNavData(navData)				  }
		drone.onStateChange		= |state|			{ log.info("State Change: --> ${state}"); thisRef.val->onStateChange(state)	}
		drone.onBatteryDrain	= |newPercentage|	{ log.info("Battery now at ${newPercentage}%"	) }
		drone.onBatteryLow		= |->|				{ log.warn("   !!! Battery Level Low !!!"		) }
		drone.onEmergency		= |->|				{ log.warn("   !!! EMERGENCY LANDING !!!   "	) }
		drone.onDisconnect		= |abnormal|		{ if (abnormal) log.warn("   !!! DISCONNECTED !!!   "	) }
		
		// initiating pre-flight system checks
		drone.connect
		drone.clearEmergencyMode
		drone.flatTrim
//		drone.setOutdoorFlight(false)
		drone.animateLeds(LedAnimation.snakeRed, 2f, 15sec)

//		drone.sendCmd(Cmd.makeCtrl(4, 0))
		drone.controlReader.read
//		drone.controlReader.read
//		drone.controlReader.read
		
		Actor.sleep(4sec)

//		drone.takeOff
//		drone.spinClockwise(-1f, 5sec)
//		sounds.beep
//		drone.animateFlight(FlightAnimation.phi30Deg, 2sec)
//		Actor.sleep(1sec)
//		sounds.beep
//		drone.animateFlight(FlightAnimation.phiM30Deg, 2sec)
//		Actor.sleep(1sec)
//		drone.land

		drone.disconnect
	}
		
		
	FlyState? oldState
	NavDataFlags? oldFlags
	Void onNavData(NavData navData) {
		str := navData.flags.dumpChanged(oldFlags)
		if (!str.isEmpty)
			str.splitLines.each { log.debug(it) }
		oldFlags = navData.flags
		
		if (oldState != navData.demoData?.flyState && navData.demoData?.flyState != null) {
			log.debug("State FLY Change --> ${navData.demoData?.flyState}")
			oldState = navData.demoData?.flyState
		}
	}

	Void onStateChange(CtrlState state) {
		switch (state) {
			case CtrlState.transTakeOff:
				sounds.takingOff.play
			case CtrlState.hovering:
				sounds.takeOff.play
				flying = true
			case CtrlState.transLanding:
				sounds.landing.play
			case CtrlState.landed:
				if (flying)
					sounds.landed.play
		}
	}
}
