//using afParrotSdk2

class SimpleExample {
	Void main() {
		drone := Drone().connect
		drone.clearEmergency
		
		// handle feedback events
		drone.onEmergency = |->| {
			echo("!!! EMERGENCY LANDING !!!")
		}
		
		// control the drone
		drone.takeOff
		drone.spinClockwise(0.5f, 3sec)
		drone.moveForward  (1.0f, 2sec)
		drone.animateFlight(FlightAnimation.flipBackward)
		drone.land
		
		drone.disconnect
	}
}
