
internal class Main {

	Void main() {
		Drone#.pod.log.level = LogLevel.debug

//		AttackDog().attack()
		
		FlightPlan().fly(Drone())
	}
	
}
