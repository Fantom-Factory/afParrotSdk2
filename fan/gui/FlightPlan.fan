using concurrent::Actor

internal class FlightPlan {
	
	Void fly(Drone drone) {
		drone.clearEmergencyMode
		drone.flatTrim
		drone.setOutdoorFlight(false)

		Actor.sleep(500ms)

		drone.animateLeds(LedAnimation.fire, 2f, 10sec)
		
//		Actor.sleep(11sec)

//		echo("take off")
		drone.takeOff
//		
//		Actor.sleep(5sec)
//
//		echo("land")
		drone.land
	}
}
