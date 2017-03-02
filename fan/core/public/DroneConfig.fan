using inet::IpAddr

// TODO rename to DroneTimeouts / DroneSys / NetworkConfig ??? ports may be hardcoded - they're not gonna change
** Default network configuration when communicating with the drone.
const class DroneConfig {
	
	** The drone's IP address.
	const IpAddr	droneIpAddr			:= IpAddr("192.168.1.1")

	
	
	// ---- Drone Comms Ports ----
	// taken from ARDrone_SDK_2_0_1/ARDroneLib/Soft/Common/config.h
	
	** Used to retrieve 'version.txt' on drone connect. 
	const Int	ftpPort				:= 5551	// FTP

	// Not used
//	const Int	authPort			:= 5552	// AUTH
	
	// Not used
//	const Int	videoRecPort		:= 5553	// VIDEO_RECORDER
	
	** The port that UDP NavData packets are received on.
	const Int	navDataPort			:= 5554 // NAVDATA
	
	** The port that TCP Video data is received on.
	const Int	videoPort			:= 5555 // VIDEO

	** The port that UDP Command packets are transmitted on.
	const Int	cmdPort				:= 5556	// AT
	
	// Not used
//	const Int	capturePort			:= 5557	// CAPTURE

	// Not used
//	const Int	printfPort			:= 5558	// PRINTF
	
	** The port that TCP config data is received on.
	const Int	controlPort			:= 5559	// CONTROL

	
	
	// ---- Interval and Timeouts ----
	
	** The interval to wait in between sending repeated commands to the drone, such as 'takeOff' 
	** or 'moveLeft'. 
	const Duration	cmdInterval				:= 25ms
	
	** The timeout used when waiting for a config command acknowledgement.
	** See 'NavDataFlags.controlCommandAck'.
	const Duration	configCmdAckTimeout		:= 1sec

	** The timeout used when waiting for the config command acknowledgement flag to clear.
	** See 'NavDataFlags.controlCommandAck'.
	const Duration	configCmdAckClearTimeout:= 1sec

	** The timeout used when opening a TCP connection.
	const Duration	tcpConnectTimeout		:= 2sec
	
	** The timeout used when waiting to receive data on a TCP port.
	const Duration	tcpReceiveTimeout		:= 1sec
	
	** The timeout used when waiting to receive data on a UDP port.
	const Duration	udpReceiveTimeout		:= 1sec
	
	** The timeout used when waiting for actions to complete, such as 'takeOff' or 'hover'.
	const Duration	actionTimeout			:= 10sec
	
	// ----
	
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
