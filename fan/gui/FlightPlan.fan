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

		echo("take off")
		drone.takeOff
		
		Actor.sleep(5sec)

		echo("land")
		drone.land
	}
}
