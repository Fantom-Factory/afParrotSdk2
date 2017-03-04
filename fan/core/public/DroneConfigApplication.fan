
** Drone config in the Application category.
** These settings are be saved for the current application.
const class DroneConfigApplication {
	private const Log			log		:= Drone#.pod.log
	private const DroneConfig	config
	
	** Creates a wrapper around the given drone.
	new make(DroneConfig config, Bool reReadConfig := true) {
		this.config = config
		if (reReadConfig)
			config.drone.config(true)
	}

	** The current application ID.
	**  
	** Corresponds to the 'CUSTOM:application_id' configuration command.
	Str id {
		get { getConfig("CUSTOM:application_id") }
		private set { }
	}
	
	** The current application's name.
	** 
	** Corresponds to the 'CUSTOM:application_desc' configuration command.
	Str name {
		get { getConfig("CUSTOM:application_desc") }
		private set { }
	}
	
	** Deletes this application data from the drone.
	Void deleteMe() {
		id := id
		if (id == "00000000") {
			log.warn("Will not delete default data!")	// don't know what might happen if we try this!?
			return
		}
		setConfig("CUSTOM:application_id", "-${id}")
	}

	** Deletes **ALL** application data from the drone.
	** Use with caution.
	Void deleteAll(Str appicationName) {
		log.warn("Deleting ALL application data!")
		setConfig("CUSTOM:application_id", "-all")
	}
	
	** When using 'navDataDemo', this configuration allows the application to ask for other navData packets.
	** Most common example is the 'default_navdata_options' macro defined in the 'config_key.h' file.
	** The full list of the possible navData packets can be found in the 'navdata_common.h' file.
	** 
	** Corresponds to the 'GENERAL:navdata_options' configuration command.
	// TODO map to navdata_options enum / flags
	Int navDataOptions {
		get { getConfig("GENERAL:navdata_options").toInt }
		set { setConfig("GENERAL:navdata_options", it.toStr) }		
	}	

	** If 'true' then roll commands ('moveLeft()' & 'moveRight()') generate roll + yaw based turns 
	** so the drone banks like an aeroplane. This is an easier control mode for racing games.
	** 
	** To activate the combined yaw mode, you must set both the bit 1 of the control_level 
	** configuration, and the bit 1 of the function parameters.
	** 
	** Note : This configuration does not need to be changed to use the new Absolute Control mode. 
	** 
	** Corresponds to the 'CONTROL:control_level' configuration command.
	// TODO try this out!
	Bool combinedYawMode {
		get { getConfig("CONTROL:control_level").toInt.and(0x02) > 0 }
		set { setConfig("CONTROL:control_level", (it ? 2 : 0).or(0x01).toStr) }
	}	
	
	** Sets the bitrate of the video transmission (kilobits per second) when 'videoBitrateControlMode'
	** is set to 'MANUAL'. Typical values range from 500 to 4000 kbps.
	** 
	** Corresponds to the 'VIDEO:bitrate' configuration command.
	Int videoBitrate {
		get { getConfig("VIDEO:bitrate").toInt }
		set { setConfig("VIDEO:bitrate", it.toStr) }		
	}
	
	** Enables the automatic bitrate control of the video stream. Enabling this configuration reduces 
	** bandwith used by the video stream under bad Wi-Fi conditions, reducing the commands latency.
	** 
	**   0 = DISABLED - Bitrate set to videoMaxBitrate session config
	**   1 = DYNAMIC  - Video bitrate varies between [250 - videoMaxBitrate] kbps
	**   2 = MANUAL   - Video stream bitrate is fixed to videoBitrate
	** 
	** Corresponds to the 'VIDEO:bitrate_control_mode' configuration command.
	Int videoBitrateControlMode {
		get { getConfig("VIDEO:bitrate_control_mode", false)?.toInt ?: 0}
		set { setConfig("VIDEO:bitrate_control_mode", it.toStr) }		
	}

	** The bitrate (kbps) of the recording stream, both for USB and WiFi record.
	** 
	** Corresponds to the 'VIDEO:bitrate_storage' configuration command.
	Int videoBitrateStorage {
		get { getConfig("VIDEO:bitrate_storage").toInt }
		private set { }		
	}
	
	** Dumps all fields to debug string.
	Str dump() {
		fields := typeof.fields.findAll { it.isPublic && it.parent == this.typeof }
		names  := (Str[]) fields.map { it.name.toDisplayName }
		width  := names.max |p1, p2| { p1.size <=> p2.size }.size
		values := fields.map |field, i| { names[i].padr(width, '.') + "..." + field.get(this).toStr }
		return values.join("\n")
	}
	
	private Str? getConfig(Str key, Bool checked := true) {
		config.drone.config[key] ?: (checked ? throw UnknownKeyErr(key) : null)
	}
	
	private Void setConfig(Str key, Str val) {
		config._sendMultiConfig(key, val)
		config.drone._updateConfig(key, val)
	}
}
