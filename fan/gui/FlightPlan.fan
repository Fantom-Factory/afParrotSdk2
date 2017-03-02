using concurrent::Actor

** Kill me!
class FlightPlan {
	private static const	Log		log		:= Drone#.pod.log

	private Sounds	sounds := Sounds()
	Bool flying
	
	Void fly(Drone drone) {
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
//		drone.clearEmergencyMode
		drone.flatTrim
		
		Actor.sleep(0.5sec)
		drone.setEmergencyLanding
//		drone.sendCmd(Cmd.makeEmergency)
//		drone.sendCmd(Cmd.makeEmergency2)
//		drone.crashLand
//		drone.crashLand
		
		Actor.sleep(0.5sec)

		drone.clearEmergencyLanding
		
//		drone.setOutdoorFlight(false)
//		drone.animateLeds(LedAnimation.blinkGreenRed, 15sec)

//		drone.sendCmd(Cmd.makeCtrl(4, 0))
//		props	:= socket.in.readAllStr {echo("[$it]")}
//		socket.close
			
//		drone.takeOff
//
////		drone.moveUp(0.5f, 2sec)
////		drone.spinClockwise(1f, 6sec)
//
//		drone.animateFlight(FlightAnimation.theta20degYawM200Deg)
//		drone.animateFlight(FlightAnimation.theta20degYawM200Deg)
//		drone.animateFlight(FlightAnimation.theta20degYawM200Deg)
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

		drone.disconnect
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
}
