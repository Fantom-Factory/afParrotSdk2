using concurrent::Actor
class FlightPlan {
	
	Void fly(Drone drone) {
		echo("Waiting for Ready")
		drone.waitUntilReady
		
		echo("clear emergency")
		drone.clearEmergencyMode

		echo("flat trim")
		drone.flatTrim

		Actor.sleep(500ms)

		drone.animateLeds(LedAnimation.redSnake, 2f, 10sec)
		
		Actor.sleep(11sec)

//		echo("take off")
//		drone.takeOff
//		
//		Actor.sleep(5sec)
//
//		echo("land")
//		drone.land
	}
}
