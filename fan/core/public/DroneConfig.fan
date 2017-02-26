
const class DroneConfig {
	
	const Str		droneIpAddr			:= "192.168.1.1"

	const Int		navDataPort			:= 5554
	const Int		videoPort			:= 5555
	const Int		controlPort			:= 5556
	
	const Duration	udpReceiveTimeout	:= 1sec
	
	const Duration	defaultTimeout		:= 10sec
}
