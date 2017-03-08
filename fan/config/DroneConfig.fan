using concurrent::AtomicRef

@NoDoc
const class DroneConfig {
	private const	Log		log		:= Drone#.pod.log
	private const	Str		defId	:= "00000000"

	** The wrapped drone.
	const Drone 	drone

	private const AtomicRef	appId	:= AtomicRef(defId)
	private const AtomicRef	userId	:= AtomicRef(defId)
	private const AtomicRef	sessId	:= AtomicRef(defId)
	
	new make(Drone drone) {
		this.drone = drone
	}

	Void setSess(Str id) {
		drone.sendConfig("CUSTOM:session_id", id)
//		if (id.startsWith("-"))
//			drone.sendConfig("CUSTOM:session_id", defId)
		sessId.val = defId
	}
	
	Void setUser(Str id) {
		drone.sendConfig("CUSTOM:profile_id", id)
//		if (id.startsWith("-"))
//			drone.sendConfig("CUSTOM:profile_id", defId)
		userId.val = defId		
	}
	
	Void setApp(Str id) {
		drone.sendConfig("CUSTOM:application_id", id)
//		if (id.startsWith("-"))
//			drone.sendConfig("CUSTOM:application_id", defId)
		appId.val = defId		
	}
	
	Void reset() {
		setSess(defId)
		setUser(defId)
		setApp(defId)
	}

	** Gets or makes session config.
	DroneConfigSession sessionConfig(Str? sessionName := null) {
		sessConfig := DroneConfigSession(this, false)
		if (sessionName != null) {
			id := Int.random.and(0xFFFFFFFF).toHex(8).upper
			if (id != sessId.val) {
				drone.sendConfig("CUSTOM:session_id", id)
				sessId.val = id
				userId.val = defId
				appId.val  = defId
				_sendMultiConfig("CUSTOM:session_desc", sessionName)
				drone.config(true)
			}
		}
		return sessConfig
	}

	** Gets or makes user config.
	DroneConfigUser userConfig(Str? userName := null) {
		userConfig := DroneConfigUser(this, false)
		if (userName != null) {
			id := userName.toBuf.crc("CRC-32-Adler").toHex(8).upper
			if (id != userId.val) {
				drone.sendConfig("CUSTOM:profile_id", id)
				userId.val = id
				_sendMultiConfig("CUSTOM:profile_desc", userName)
				drone.config(true)
			}
		}
		return userConfig
	}

	** Gets or makes application config.
	** If 'null' is passed, this just returns the current config.
	DroneConfigApplication applicationConfig(Str? appicationName := null) {
		appConfig := DroneConfigApplication(this, false)
		if (appicationName != null) {
			id := appicationName.toBuf.crc("CRC-32-Adler").toHex(8).upper
			if (id != appId.val) {
				drone.sendConfig("CUSTOM:application_id", id)
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
		drone.sendConfig(key, val, sessId.val, userId.val, appId.val)
	}
}
