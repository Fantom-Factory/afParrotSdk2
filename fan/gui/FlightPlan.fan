using concurrent::Actor

** Kill me!
class FlightPlan {
	private static const	Log		log		:= Drone#.pod.log

	Void fly(Drone drone) {
		thisRef := Unsafe(this)
		drone.onNavData			= |navData|			{ thisRef.val -> onNavData(navData)				  }
		drone.onStateChange		= |state|			{ log.info("State Change: --> ${state}"			) }
		drone.onBatteryDrain	= |newPercentage|	{ log.info("Battery now at ${newPercentage}%"	) }
		drone.onBatteryLow		= |->|				{ log.warn("   !!! Battery Level Low !!!"		) }
		drone.onEmergency		= |->|				{ log.warn("   !!! EMERGENCY LANDING !!!   "	) }
		
		drone.connect
		drone.clearEmergencyMode
		drone.flatTrim
		drone.setOutdoorFlight(false)

		drone.animateLeds(LedAnimation.standard, 10f, 10sec)
//		Actor.sleep(11sec)

//		drone.takeOff
//		drone.spinClockwise(0.5f)
//		Actor.sleep(5sec)
//		drone.land

		drone.disconnect
	}
		
		
	NavDataFlags? oldFlags
	Void onNavData(NavData navData) {
		str := navData.flags.dumpChanged(oldFlags)
		if (!str.isEmpty)
			log.debug("\n${str}")
		oldFlags = navData.flags
	}
}
