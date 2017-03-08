using concurrent::AtomicRef

** Drone config in the Common category.
** This is the default category, common to all applications.
const class DroneConfig {
	private const	Log		log		:= Drone#.pod.log
	private const	Str		defId	:= "00000000"

	** The wrapped drone.
	const Drone 	drone

	private const AtomicRef	sessId	:= AtomicRef(defId)
	private const AtomicRef	userId	:= AtomicRef(defId)
	private const AtomicRef	appId	:= AtomicRef(defId)
	
	** Internal because we need to keep track of the multi-config IDs 
	internal new make(Drone drone) {
		this.drone = drone
	}

	Void reset() {
		drone.sendConfig("CUSTOM:application_id", defId)
		appId.val = defId
		drone.sendConfig("CUSTOM:profile_id", defId)
		userId.val = defId		
		drone.sendConfig("CUSTOM:session_id", defId)
		sessId.val = defId
		drone.configMap(true)
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
				drone.configMap(true)
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
				drone.configMap(true)
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
				drone.configMap(true)
			}
		}
		return appConfig
	}
	
	
	
	// ---- Common Configuration ----
	
	** Returns the version of the drone's configuration subsystem, motherboard, and firmware.
	** 
	**   syntax: fantom
	**   versions()  // --> [config:1, firmware:2.4.8, motherboard:34]
	** 
	** Corresponds to the configuration keys:
	**   - 'GENERAL:num_version_config'
	**   - 'GENERAL:num_version_mb'
	**   - 'GENERAL:num_version_soft'
	Str:Version versions() {
		[
			"config"		: Version(getConfig("GENERAL:num_version_config")),
			"motherboard"	: Version(getConfig("GENERAL:num_version_mb")),
			"firmware"		: Version(getConfig("GENERAL:num_version_soft"))
		]
	}
	
	** Serial number of the drone.
	** 
	** Corresponds to the 'GENERAL:drone_serial' configuration key.
	Str serialNumber {
		get { getConfig("GENERAL:drone_serial") }
		private set { }
	}
	
	** Date of drone firmware compilation.
	** 
	** Corresponds to the 'GENERAL:soft_build_date' configuration key.
	DateTime firmwareBuildDate {
		get { DateTime.fromLocale(getConfig("GENERAL:soft_build_date"), "YYYY-MM-DD hh:mm") }
		private set { }
	}
	
	** Returns the versions of the drone's motor's hardware, software, and supplier.
	** 
	**   syntax: fantom
	**   versions()  // --> [hardware:6.0, software:1.43, supplier:1.1]
	** 
	** The motor number should be between 1 and 4.
	** 
	** Corresponds to the configuration keys:
	**   - 'GENERAL:motorX_hard'
	**   - 'GENERAL:motorX_soft'
	**   - 'GENERAL:motorX_supplier'
	Str:Version motorVersions(Int num) {
		if (num < 1 || num > 4)
			throw ArgErr("Motor num should be between 1 - 4, not ${num}")
		return [
			"hardware"	: Version(getConfig("GENERAL:motor${num}_hard")),
			"software"	: Version(getConfig("GENERAL:motor${num}_soft")),
			"supplier"	: Version(getConfig("GENERAL:motor${num}_supplier"))
		]
	}
	
	** Name of the drone. This name may be used by video games developer to assign a default
	** name to a player. Note this is not related to the Wi-Fi SSID name.
	** 
	** Corresponds to the 'GENERAL:ardrone_name' configuration key.
	Str droneName {
		get { getConfig("GENERAL:ardrone_name") }
		set { setConfig("GENERAL:ardrone_name", it) }
	}

	** Time spent by the drone in a flying state in its whole lifetime.
	** 
	** Corresponds to the 'GENERAL:flying_time' configuration key.
	Duration totalFlightTime {
		get { Duration(getConfig("GENERAL:flying_time").toInt * 1_000_000_000) }
		private set { }		
	}
	
	** The drone can either send a reduced set of navigation data (navdata) to its clients, or send 
	** all the available information which contain many debugging information that are useless for everyday flights.
	** 
	** If this parameter is set to 'true', the reduced set is sent by the drone.
	** If this parameter is set to 'false', all the available data is sent.
	** 
	** Corresponds to the 'GENERAL:navdata_demo' configuration key.
	Bool navDataDemo {
		get { Bool(getConfig("GENERAL:navdata_demo").lower) }
		set { setConfig("GENERAL:navdata_demo", it.toStr.upper) }		
	}

	** Minimum battery level before the drone lands automatically.
	** 
	** Corresponds to the 'GENERAL:vbat_min' configuration key.
	Int minBatteryLevel {
		get { getConfig("GENERAL:vbat_min").toInt }
		set { setConfig("GENERAL:vbat_min", it.toStr) }		
	}

	** Maximum drone altitude in meters.
	** A typical value for *unlimited* altitude is 100 meters.
	**
	** Corresponds to the 'CONTROL:altitude_max' configuration key.
	Float maxAltitude {
		get { getConfig("CONTROL:altitude_max").toInt / 1000f }
		set { setConfig("CONTROL:altitude_max", (it * 1000).toInt.toStr) }		
	}

	** Minimum drone altitude in meters.
	** Should be left to the default value, for control stabilities issues.
	**
	** Corresponds to the 'CONTROL:altitude_min' configuration key.
	Float minAltitude {
		get { getConfig("CONTROL:altitude_min").toInt / 1000f }
		set { setConfig("CONTROL:altitude_min", (it * 1000).toInt.toStr) }		
	}

	// sensitivitySettings / Profile
	** Sets profiles for indoor / outdoor use. Loads values for:
	**  - 'indoor/outdoor_control_yaw'
	**  - 'indoor/outdoor_euler_angle_max'
	**  - 'indoor/outdoor_control_vz_max'
	** 
	** Note : This setting also enables the wind estimator of the AR.Drone 2.0, and thus should 
	** always be enabled when flying outside.
	**  
	** Corresponds to the 'CONTROL:outdoor' configuration key.
	Bool useOutdoorProfile {
		get { Bool(getConfig("CONTROL:outdoor").lower) }
		set { setConfig("CONTROL:outdoor", it.toStr.upper) }			
	}

	** Tells the drone it is wearing the outdoor shell. Deactivate it when flying with the indoor shell.
	** 
	** This setting is not linked with 'useOutdoorProfile', both have different effects on the drone.
	**  
	** Corresponds to the 'CONTROL:flight_without_shell' configuration key.
	Bool useOutdoorShell {
		get { Bool(getConfig("CONTROL:flight_without_shell").lower) }
		set { setConfig("CONTROL:flight_without_shell", it.toStr.upper) }			
	}

	** The network SSID. Changes are applied on reboot.
	**  
	** Corresponds to the 'NETWORK:ssid_single_player' configuration key.
	Str networkSsid {
		get { getConfig("NETWORK:ssid_single_player") }
		set { setConfig("NETWORK:ssid_single_player", it) }
	}

	** Mode of the Wi-Fi network. Possible values are:
	** 
	**   0 = The drone is the access point of the network
	**   1 = The drone creates (or join) the network in Ad-Hoc mode
	**   2 = The drone tries to join the network as a station
	**  
	** Corresponds to the 'NETWORK:wifi_mode' configuration key.
	Int networkWifiMode {
		get { getConfig("NETWORK:wifi_mode").toInt }
		set { setConfig("NETWORK:wifi_mode", it.toStr) }		
	}

	** Mac address paired with the drone. Set to '00:00:00:00:00:00' to un-pair with the drone.
	**  
	** Corresponds to the 'NETWORK:owner_mac' configuration key.
	Str networkPairedMac {
		get { getConfig("NETWORK:owner_mac") }
		set { setConfig("NETWORK:owner_mac", it) }
	}
	
	** Ultrasound frequency used to measure altitude.
	** Using two different frequencies for two drones can significantly reduce the ultrasound 
	** perturbations.
	** 
	**   7 = Ultrasound at 22.22 Hz
	**   8 = Ultrasound at 25.00 Hz
	**  
	** Corresponds to the 'PIC:ultrasound_freq' configuration key.
	Int picUltrasoundFreq {
		get { getConfig("PIC:ultrasound_freq").toInt }
		set { setConfig("PIC:ultrasound_freq", it.toStr) }		
	}

	** The software version of the Nav-board.
	** 
	** Corresponds to the 'PIC:pic_version' configuration key.
	Version picVersion {
		get { Version(getConfig("PIC:pic_version")) }
		private set { }
	}

	** Returns read only video info. Returned keys are:
	** 
	**  - 'fps' - Current FPS of the video interface. This may be different than the actual framerate.
	**  - 'bufferDepth' - Buffer depth for the video interface.
	**  - 'noOfTrackers' - Number of tracking points used for optical speed estimation.
	**  - 'storageSpace' - Size of the wifi video record buffer.
	**  - 'fileIndex' - Number of the last recorded video ( 'video_XXX.mp4' ) on USB key.
	** 
	**   syntax: fantom
	**   videoInfo()  // --> ["fps": 30, "bufferDepth": 2, "noOfTrackers": 12, "storageSpace": 20480, "fileIndex": 1]
	Str:Int videoInfo() {
		[
			"fps"			: getConfig("VIDEO:camif_fps").toInt,
			"bufferDepth"	: getConfig("VIDEO:camif_buffers").toInt,
			"noOfTrackers"	: getConfig("VIDEO:num_trackers").toInt,
			"storageSpace"	: getConfig("VIDEO:video_storage_space").toInt,
			"fileIndex"		: getConfig("VIDEO:video_file_index").toInt
		]
	}

	** If a USB key with > 100Mb of freespace is connected, the video stream will be recorded on the USB key.
	**  
	** In all other cases, the record stream is sent to the controlling device, which will be in 
	** charge of the actual recording.
	** 
	** Corresponds to the 'VIDEO:video_on_usb' configuration key.
	Bool videoOnUsb {
		get { Bool(getConfig("VIDEO:video_on_usb").lower) }
		set { setConfig("VIDEO:video_on_usb", it.toStr.upper) }			
	}

	** The color of the hulls you want to detect. Possible values are:
	** 
	**   1 = Green
	**   2 = Yellow
	**   3 = Blue
	** 
	** Note : This config is only used for standard tag / hull detection. 
	** Roundel detection doesn't use it.
	** 
	** Corresponds to the 'DETECT:enemy_colors' configuration key.
	Int detectEmemyColours {
		get { getConfig("DETECT:enemy_colors").toInt }
		set { setConfig("DETECT:enemy_colors", it.toStr) }		
	}

	** Activate to detect outdoor hulls. Deactivate to detect indoor hulls.
	**  
	** Corresponds to the 'DETECT:enemy_without_shell' configuration key.
	Bool detectEmemyOutdoorShell {
		get { getConfig("DETECT:enemy_without_shell").toInt == 0 }
		set { setConfig("DETECT:enemy_without_shell", it ? "0" : "1") }			
	}

	** Dumps all fields to debug string.
	Str dump(Bool dumpToStdOut := true) {
		fields := typeof.fields.findAll { it.isPublic && it.parent == this.typeof }
		names  := (Str[]) fields.map { it.name.toDisplayName }.add("motorVersions(x)")
		width  := names.max |p1, p2| { p1.size <=> p2.size }.size
		values := fields.map |field, i| { names[i].padr(width, '.') + "..." + field.get(this).toStr }
		meths  := Str:Str[:] { it.ordered = true }
			.add("versions",			versions.toStr)
			.add("motorVersions(1)",	motorVersions(1).toStr)
			.add("motorVersions(2)",	motorVersions(2).toStr)
			.add("motorVersions(3)",	motorVersions(3).toStr)
			.add("motorVersions(4)",	motorVersions(4).toStr)
			.add("videoInfo", 			videoInfo.toStr)
		methVal := meths.map |val, key| { key.padr(width, '.') + "..." + val }.vals
		dump    := methVal.addAll(values).join("\n")
		if (dumpToStdOut)
			echo(dump)
		return dump

	}
	
	
	
	// ---- Internal Methods ----

	internal Void _delSess(Str id) {
		drone.sendConfig("CUSTOM:session_id", id)
		drone.sendConfig("CUSTOM:session_id", defId)
		sessId.val = defId
		drone.configMap(true)
	}

	internal Void _delUser(Str id) {
		drone.sendConfig("CUSTOM:profile_id", id)
		drone.sendConfig("CUSTOM:profile_id", defId)
		userId.val = defId		
		drone.configMap(true)
	}
	
	internal Void _delApp(Str id) {
		drone.sendConfig("CUSTOM:application_id", id)
		drone.sendConfig("CUSTOM:application_id", defId)
		appId.val = defId
		drone.configMap(true)
	}

	internal Void _sendMultiConfig(Str key, Str val) {
		drone.sendConfig(key, val, sessId.val, userId.val, appId.val)
	}
	
	private Str getConfig(Str key) {
		drone.configMap[key] ?: throw UnknownKeyErr(key)
	}
	
	private Void setConfig(Str key, Str val) {
		drone.sendConfig(key, val)
		drone._updateConfig(key, val)
	}
}
