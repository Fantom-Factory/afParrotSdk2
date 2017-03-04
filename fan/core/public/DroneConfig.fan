using concurrent::AtomicRef

const class DroneConfig {
	private const	Log		log		:= Drone#.pod.log

	** The wrapped drone.
	const Drone 	drone

	private const AtomicRef	appId	:= AtomicRef("00000000")
	private const AtomicRef	userId	:= AtomicRef("00000000")
	private const AtomicRef	sessId	:= AtomicRef("00000000")
	
	new make(Drone drone) {
		this.drone = drone
	}

	** Gets or makes application config.
	DroneConfigApplication applicationConfig(Str? appicationName := null) {
		appConfig := DroneConfigApplication(this, false)
		if (appicationName != null) {
			id := appicationName.toBuf.crc("CRC-32-Adler").toHex(8).upper
			if (id != appId.val) {
				_sendMultiConfig("CUSTOM:application_id", id)
//				drone.sendConfig("CUSTOM:application_id", id)
				appId.val = id
				_sendMultiConfig("CUSTOM:application_desc", appicationName)
				drone.config(true)
			}
		}
		return appConfig
	}

	// FIXME delete?
	** Sets or clears config and profiles relating to indoor / outdoor flight.
	** See:
	**  - 'control:outdoor'
	**  - 'control:flight_without_shell'
	Void setOutdoorFlight(Bool outdoors := true) {
		drone.sendConfig("control:outdoor", outdoors)
		drone.sendConfig("control:flight_without_shell", outdoors)
	}

	internal Void _sendMultiConfig(Str key, Str val) {
//		drone.sendConfig(key, val, sessId.val, userId.val, appId.val)

		drone.sendCmd(Cmd.makeConfigIds(sessId.val, userId.val, appId.val))
		drone.sendConfig(key, val)
	}
}
