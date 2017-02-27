using concurrent::Actor

** Kill me!
class FlightPlan {
	private static const	Log		log		:= Drone#.pod.log

	Sounds	sounds := Sounds()
	Bool flying
	
	Void fly(Drone drone) {
		
		thisRef := Unsafe(this)
		drone.onNavData			= |navData|			{ thisRef.val->onNavData(navData)				  }
		drone.onStateChange		= |state|			{ log.info("State Change: --> ${state}"); thisRef.val->onStateChange(state)	}
		drone.onBatteryDrain	= |newPercentage|	{ log.info("Battery now at ${newPercentage}%"	) }
		drone.onBatteryLow		= |->|				{ log.warn("   !!! Battery Level Low !!!"		) }
		drone.onEmergency		= |->|				{ log.warn("   !!! EMERGENCY LANDING !!!   "	) }
		
		// initiating pre-flight system checks
		drone.connect
		drone.clearEmergencyMode
		drone.flatTrim
		drone.setOutdoorFlight(false)
		drone.animateLeds(LedAnimation.standard, 1f, 1sec)
		
//		Actor.sleep(11sec)

		drone.takeOff

		drone.spinClockwise(1f, 5sec)
//		sounds.beep
		
//		drone.animateFlight(FlightAnimation.yawShake, 4sec)
//		Actor.sleep(5sec)
		
		drone.land

		drone.disconnect
	}
		
		
	FlyState? oldState
	NavDataFlags? oldFlags
	Void onNavData(NavData navData) {
		str := navData.flags.dumpChanged(oldFlags)
		if (!str.isEmpty)
			log.debug("\n${str}")
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
