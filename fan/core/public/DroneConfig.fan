
** Default drone configuration.
const class DroneConfig {
	
	const Str		droneIpAddr			:= "192.168.1.1"

	// // from ARDrone_SDK_2_0_1/ARDroneLib/Soft/Common/config.h
//	const Int		ftpPort				:= 5551	// FTP
//	const Int		authPort			:= 5552	// AUTH
//	const Int		videoRecPort		:= 5553	// VIDEO_RECORDER
	const Int		navDataPort			:= 5554 // NAVDATA
	const Int		videoPort			:= 5555 // VIDEO
	const Int		cmdPort				:= 5556	// AT
//	const Int		capturePort			:= 5557	// CAPTURE
//	const Int		printfPort			:= 5558	// PRINTF
	const Int		controlPort			:= 5559	// CONTROL
	
	const Duration	cmdInterval			:= 25ms

	// TODO add lots more specific timeouts - if nothing else it helps people understand what the lib does
	//	configCmdAckTimeout
	//	configCmdAckClearTimeout
	//	tcp socket stuff
	
	const Duration	udpReceiveTimeout	:= 1sec
	const Duration	defaultTimeout		:= 10sec
	
	** Standard it-block ctor should you wish to change any config.
	** 
	** pre>
	** syntax: fantom
	** config := DroneConfig {
	**     it.droneIpAddr = "2.121.135.58"
	** }
	** <pre
	new make(|This|? f := null) { f?.call(this) }

}
