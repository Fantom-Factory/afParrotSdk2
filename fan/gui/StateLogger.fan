
class StateLogger {
	private static const	Log		log		:= Drone#.pod.log

	private Sounds	sounds 		:= Sounds()
	Bool 			flying

	Void start(Drone drone) {
		thisRef := Unsafe(this)
		drone.onNavData			= |navData|			{ thisRef.val->onNavData(navData)				  }
		drone.onStateChange		= |state|			{ log.info("State Change: --> ${state}"); thisRef.val->onStateChange(state)	}
		drone.onBatteryDrain	= |newPercentage|	{ log.info("Battery now at ${newPercentage}%"	) }
		drone.onBatteryLow		= |->|				{ log.warn("   !!! Battery Level Low !!!"		) }
		drone.onEmergency		= |->|				{ log.warn("   !!! EMERGENCY LANDING !!!   "	) }
	}
	
	DroneState? oldState
	NavDataFlags? oldFlags
	Void onNavData(NavData navData) {
		str := navData.flags.dumpChanged(oldFlags)
		if (!str.isEmpty)
			str.splitLines.each { log.debug(it) }
		oldFlags = navData.flags
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
}
