using concurrent::Actor

** Kill me!
class FlightPlan {
	private static const	Log		log		:= Drone#.pod.log

	Void fly(Drone drone) {
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

		drone.takeOff
		Actor.sleep(5sec)
		drone.land

		drone.disconnect
	}
}
