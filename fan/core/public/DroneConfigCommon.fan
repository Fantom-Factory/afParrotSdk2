
** Drone config in the Common category.
** This is the default category, common to all applications.
const class DroneConfigCommon {
	private const Drone drone
	
	** Creates a wrapper around the given drone.
	new make(Drone drone) {
		this.drone = drone
	}

	** Version of the configuration subsystem.
	** 
	** Corresponds to the 'GENERAL:num_version_config' configuration command.
	Version configVersion {
		get { Version(getConfig("GENERAL:num_version_config")) }
		private set { }
	}
	
	** Hardware version of the drone motherboard.
	** 
	** Corresponds to the 'GENERAL:num_version_mb' configuration command.
	Version motherboardVersion {
		get { Version(getConfig("GENERAL:num_version_mb")) }
		private set { }
	}
	
	** Firmware version of the drone.
	** 
	** Corresponds to the 'GENERAL:num_version_soft' configuration command.
	Version firmwareVersion {
		get { Version(getConfig("GENERAL:num_version_soft")) }
		private set { }
	}
	
	** Serial number of the drone.
	** 
	** Corresponds to the 'GENERAL:drone_serial' configuration command.
	Str serialNumber {
		get { getConfig("GENERAL:drone_serial") }
		private set { }
	}
	
	** Date of drone firmware compilation.
	** 
	** Corresponds to the 'GENERAL:soft_build_date' configuration command.
	DateTime firmwareBuildDate {
		get { DateTime.fromLocale(getConfig("GENERAL:soft_build_date"), "YYYY-MM-DD hh:mm") }
		private set { }
	}
	
	** Software version of the motor 1 board.
	** 
	** Corresponds to the 'GENERAL:motor1_soft' configuration command.
	Version motor1SoftwareVersion {
		get { Version(getConfig("GENERAL:motor1_soft")) }
		private set { }
	}
	
	** Hardware version of the motor 1 board.
	** 
	** Corresponds to the 'GENERAL:motor1_hard' configuration command.
	Version motor1HardwareVersion {
		get { Version(getConfig("GENERAL:motor1_hard")) }
		private set { }
	}
	
	** Supplier version of the motor 1 board.
	** 
	** Corresponds to the 'GENERAL:motor1_supplier' configuration command.
	Version motor1Supplier {
		get { Version(getConfig("GENERAL:motor1_supplier")) }
		private set { }
	}
	
	** Software version of the motor 2 board.
	** 
	** Corresponds to the 'GENERAL:motor2_soft' configuration command.
	Version motor2SoftwareVersion {
		get { Version(getConfig("GENERAL:motor2_soft")) }
		private set { }
	}
	
	** Harware version of the motor 2 board.
	** 
	** Corresponds to the 'GENERAL:motor2_hard' configuration command.
	Version motor2HardwareVersion {
		get { Version(getConfig("GENERAL:motor2_hard")) }
		private set { }
	}
	
	** Supplier version of the motor 2 board.
	** 
	** Corresponds to the 'GENERAL:motor2_supplier' configuration command.
	Version motor2Supplier {
		get { Version(getConfig("GENERAL:motor2_supplier")) }
		private set { }
	}
	
	** Software version of the motor 3 board.
	** 
	** Corresponds to the 'GENERAL:motor3_soft' configuration command.
	Version motor3SoftwareVersion {
		get { Version(getConfig("GENERAL:motor3_soft")) }
		private set { }
	}
	
	** Harware version of the motor 3 board.
	** 
	** Corresponds to the 'GENERAL:motor3_hard' configuration command.
	Version motor3HardwareVersion {
		get { Version(getConfig("GENERAL:motor3_hard")) }
		private set { }
	}
	
	** Supplier version of the motor 3 board.
	** 
	** Corresponds to the 'GENERAL:motor3_supplier' configuration command.
	Version motor3Supplier {
		get { Version(getConfig("GENERAL:motor3_supplier")) }
		private set { }
	}
	
	** Software version of the motor 4 board.
	** 
	** Corresponds to the 'GENERAL:motor4_soft' configuration command.
	Version motor4SoftwareVersion {
		get { Version(getConfig("GENERAL:motor4_soft")) }
		private set { }
	}
	
	** Harware version of the motor 4 board.
	** 
	** Corresponds to the 'GENERAL:motor4_hard' configuration command.
	Version motor4HardwareVersion {
		get { Version(getConfig("GENERAL:motor4_hard")) }
		private set { }
	}
	
	** Supplier version of the motor 4 board.
	** 
	** Corresponds to the 'GENERAL:motor4_supplier' configuration command.
	Version motor4Supplier {
		get { Version(getConfig("GENERAL:motor4_supplier")) }
		private set { }
	}

	** Name of the drone. This name may be used by video games developer to assign a default
	** name to a player, and is not related to the Wi-Fi SSID name.
	** 
	** Corresponds to the 'GENERAL:ardrone_name' configuration command.
	Str droneName {
		get { getConfig("GENERAL:ardrone_name") }
		set { setConfig("GENERAL:ardrone_name", it) }
	}

	** Time spent by the drone in a flying state in its whole lifetime.
	** 
	** Corresponds to the 'GENERAL:flying_time' configuration command.
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
	** Corresponds to the 'GENERAL:navdata_demo' configuration command.
	Bool navDataDemo {
		get { Bool(getConfig("GENERAL:navdata_demo").lower) }
		set { setConfig("GENERAL:navdata_demo", it.toStr.upper) }		
	}

	** Minimum battery level before the drone automatically shuts down.
	** 
	** Corresponds to the 'GENERAL:vbat_min' configuration command.
	Int minBatteryLevel {
		get { getConfig("GENERAL:vbat_min").toInt }
		set { setConfig("GENERAL:vbat_min", it.toStr) }		
	}

	** Maximum drone altitude in meters.
	** A typical value for *unlimited* altitude is 100 meters.
	**
	** Corresponds to the 'CONTROL:altitude_max' configuration command.
	Float maxAltitude {
		get { getConfig("CONTROL:altitude_max").toInt / 1000f }
		set { setConfig("CONTROL:altitude_max", (it * 1000).toInt.toStr) }		
	}

	** Minimum drone altitude in meters.
	** Should be left to the default value, for control stabilities issues.
	**
	** Corresponds to the 'CONTROL:altitude_min' configuration command.
	Float minAltitude {
		get { getConfig("CONTROL:altitude_min").toInt / 1000f }
		set { setConfig("CONTROL:altitude_min", (it * 1000).toInt.toStr) }		
	}

	** Sets profiles for indoor / outdoor use. Loads values for:
	**  - 'indoor/outdoor_control_yaw'
	**  - 'indoor/outdoor_euler_angle_max'
	**  - 'indoor/outdoor_control_vz_max'
	** 
	** Note : This setting also enables the wind estimator of the AR.Drone 2.0, and thus should 
	** always be enabled when flying outside.
	**  
	** Corresponds to the 'CONTROL:outdoor' configuration command.
	Bool useOutdoorProfile {
		get { Bool(getConfig("CONTROL:outdoor").lower) }
		set { setConfig("CONTROL:outdoor", it.toStr.upper) }			
	}

	** Tells the drone it is wearing the outdoor shell. Deactivate it when flying with the indoor shell.
	** 
	** This setting is not linked with 'useOutdoorProfile',  both have different effects on the drone.
	**  
	** Corresponds to the 'CONTROL:flight_without_shell' configuration command.
	Bool useOutdoorShell {
		get { Bool(getConfig("CONTROL:flight_without_shell").lower) }
		set { setConfig("CONTROL:flight_without_shell", it.toStr.upper) }			
	}

	** The network SSID. Changes are applied on reboot.
	**  
	** Corresponds to the 'NETWORK:ssid_single_player' configuration command.
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
	** Corresponds to the 'NETWORK:wifi_mode' configuration command.
	Int networkWifiMode {
		get { getConfig("NETWORK:wifi_mode").toInt }
		set { setConfig("NETWORK:wifi_mode", it.toStr) }		
	}

	** Mac address paired with the drone. Set to '00:00:00:00:00:00' to un-pair with the drone.
	**  
	** Corresponds to the 'NETWORK:owner_mac' configuration command.
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
	** Corresponds to the 'PIC:ultrasound_freq' configuration command.
	Int picUltrasoundFreq {
		get { getConfig("PIC:ultrasound_freq").toInt }
		set { setConfig("PIC:ultrasound_freq", it.toStr) }		
	}

	** The software version of the Nav-board.
	** 
	** Corresponds to the 'PIC:pic_version' configuration command.
	Version picVersion {
		get { Version(getConfig("PIC:pic_version")) }
		private set { }
	}

	** Current FPS of the video interface. This may be different than the actual framerate.
	**  
	** Corresponds to the 'VIDEO:camif_fps' configuration command.
	Int videoInterfaceFps {
		get { getConfig("VIDEO:camif_fps").toInt }
		private set { }
	}

	** Buffer depth for the video interface.
	**  
	** Corresponds to the 'VIDEO:camif_buffers' configuration command.
	Int videoInterfaceBufferDepth {
		get { getConfig("VIDEO:camif_buffers").toInt }
		private set { }
	}

	** Number of tracking point for the speed estimation.
	**  
	** Corresponds to the 'VIDEO:num_trackers' configuration command.
	Int videoTrackers {
		get { getConfig("VIDEO:num_trackers").toInt }
		private set { }
	}

	** Size of the wifi video record buffer.
	**  
	** Corresponds to the 'VIDEO:video_storage_space' configuration command.
	Int videoStorageSpace {
		get { getConfig("VIDEO:video_storage_space").toInt }
		private set { }
	}

	** If a USB key with > 100Mb of freespace is connected, the video stream will be recorded on the USB key.
	**  
	** In all other cases, the record stream is sent to the controlling device, which will be in 
	** charge of the actual recording.
	** 
	** Corresponds to the 'VIDEO:video_on_usb' configuration command.
	Bool videoOnUsb {
		get { Bool(getConfig("VIDEO:video_on_usb").lower) }
		set { setConfig("VIDEO:video_on_usb", it.toStr.upper) }			
	}

	** Number of the last recorded video ( 'video_XXX.mp4' ) on USB key.
	** 
	** Corresponds to the 'VIDEO:video_file_index' configuration command.
	Int videoFileIndex {
		get { getConfig("VIDEO:video_file_index").toInt }
		private set { }
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
	** Corresponds to the 'DETECT:enemy_colors' configuration command.
	Int detectEmemyColours {
		get { getConfig("DETECT:enemy_colors").toInt }
		set { setConfig("DETECT:enemy_colors", it.toStr) }		
	}

	** Activate to detect outdoor hulls. Deactivate to detect indoor hulls.
	**  
	** Corresponds to the 'DETECT:enemy_without_shell' configuration command.
	Bool detectEmemyOutdoorShell {
		get { getConfig("DETECT:enemy_without_shell").toInt == 0 }
		set { setConfig("DETECT:enemy_without_shell", it ? "0" : "1") }			
	}

	** Dumps all fields to debug string.
	Str dump() {
		fields := typeof.fields.findAll { it.isPublic && it.parent == this.typeof }
		names  := (Str[]) fields.map { it.name.toDisplayName }
		width  := names.max |p1, p2| { p1.size <=> p2.size }.size
		values := fields.map |field, i| { names[i].padr(width, '.') + "..." + field.get(this).toStr }
		return values.join("\n")
	}
	
	private Str getConfig(Str key) {
		drone.config[key] ?: throw UnknownKeyErr(key)
	}
	
	private Void setConfig(Str key, Str val) {
		drone.sendConfig(key, val)
		drone._updateConfig(key, val)
	}
}
