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
		drone.clearEmergencyMode
		drone.flatTrim
		drone.setOutdoorFlight(false)
		drone.animateLeds(LedAnimation.blinkGreenRed, 15sec)

//		drone.sendCmd(Cmd.makeCtrl(4, 0))
//		drone.sendCmd(Cmd.makeCtrl(4, 0))
//		drone.sendCmd(Cmd.makeCtrl(4, 0))
//		drone.sendCmd(Cmd.makeCtrl(4, 0))
//		props	:= socket.in.readAllStr {echo("[$it]")}
//		socket.close
//			
//		drone.takeOff
//
		Actor.sleep(400sec)
//
////		drone.spinClockwise(-1f, 5sec)
////		sounds.beep
////		drone.animateFlight(FlightAnimation.phi30Deg, 2sec)
////		Actor.sleep(1sec)
////		sounds.beep
////		drone.animateFlight(FlightAnimation.phiM30Deg, 2sec)
////		Actor.sleep(1sec)
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
