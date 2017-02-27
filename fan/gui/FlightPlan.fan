using concurrent::Actor

** Kill me!
class FlightPlan {
	
	Void fly(Drone drone) {
		drone.clearEmergencyMode
		drone.flatTrim
		drone.setOutdoorFlight(false)

		drone.animateLeds(LedAnimation.fire, 10f, 10sec)
		Actor.sleep(11sec)

//		drone.takeOff
//		Actor.sleep(5sec)
//		drone.land
	}
}
