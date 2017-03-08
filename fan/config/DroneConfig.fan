using concurrent::AtomicRef

const class DroneConfig {
	private const	Log		log		:= Drone#.pod.log
	private const	Str		defId	:= "00000000"

	** The wrapped drone.
	const Drone 	drone

	private const AtomicRef	sessId	:= AtomicRef(defId)
	private const AtomicRef	userId	:= AtomicRef(defId)
	private const AtomicRef	appId	:= AtomicRef(defId)
	
	new make(Drone drone) {
		this.drone = drone
	}

	internal Void _delSess(Str id) {
		drone.sendConfig("CUSTOM:session_id", id)
		drone.sendConfig("CUSTOM:session_id", defId)
		sessId.val = defId
		drone.config(true)
	}

	internal Void _delUser(Str id) {
		drone.sendConfig("CUSTOM:profile_id", id)
		drone.sendConfig("CUSTOM:profile_id", defId)
		userId.val = defId		
		drone.config(true)
	}
	
	internal Void _delApp(Str id) {
		drone.sendConfig("CUSTOM:application_id", id)
		drone.sendConfig("CUSTOM:application_id", defId)
		appId.val = defId
		drone.config(true)
	}

	Void reset() {
		drone.sendConfig("CUSTOM:application_id", defId)
		appId.val = defId
		drone.sendConfig("CUSTOM:profile_id", defId)
		userId.val = defId		
		drone.sendConfig("CUSTOM:session_id", defId)
		sessId.val = defId
		drone.config(true)
	}
	
	** Gets or makes session config.
	DroneSessionConfig session(Str? sessionName := null) {
		sessConfig := DroneSessionConfig(this, false)
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
	internal DroneUserConfig _userConfig(Str? userName := null) {
		userConfig := DroneUserConfig(session, false)
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
	internal DroneAppConfig _appConfig(Str? appicationName := null) {
		appConfig := DroneAppConfig(session, false)
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

	internal Void _sendMultiConfig(Str key, Str val) {
		drone.sendConfig(key, val, sessId.val, userId.val, appId.val)
	}
}
