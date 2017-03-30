
** Drone config in the Application category.
** App config encapsulates config an application may require. 
** 
** Create a new application by means of:
** 
**   syntax: fantom
**   drone.config.app("My App Name")
**
** Future code may then access the same app by **not** passing an app name:
**    
**   syntax: fantom
**   drone.config.app.combinedYawMode = true
** 
const class DroneAppConfig {
	private const Log			_log	:= Drone#.pod.log
	private const DroneConfig	_config
	
	** Creates a new 'DroneAppConfig' instance for the given Drone. 
	** Note this class holds no state.
	new make(Drone drone) {
		this._config = DroneConfig(drone)
	}

	// ---- Identity ----
	
	** The current application ID.
	**  
	** Corresponds to the 'CUSTOM:application_id' configuration key.
	Int id {
		get { _config._appId }
		private set { }
	}
	
	** The current application's name.
	** 
	** Corresponds to the 'CUSTOM:application_desc' configuration key.
	Str name {
		get { getConfig("CUSTOM:application_desc") }
		private set { }
	}
	
	** Deletes this application data from the drone.
	Void deleteMe() {
		id := id
		if (id == DroneConfig.defId) {
			_log.warn("Will not delete default data!")	// don't know what might happen if we try this!?
			return
		}
		_config._delApp("-${id.toHex(8)}")
	}

	** Deletes **ALL** application data from the drone.
	** Use with caution.
	Void deleteAll() {
		_log.warn("Deleting ALL application data!")
		_config._delApp("-all")
	}

	// ---- Other Cmds ----

	** Allows the drone to send other packets of NavData.
	** 
	** Use the flag values of the `NavOption` enum to add / or flags values together. Example:
	** 
	**   syntax: fantom
	**   drone.config.session.app.navDataOptions = NavOption.demo.flag + NavOption.visionDetect.flag 
	** 
	** To receive all option data:
	** 
	**   syntax: fantom
	**   drone.config.session.app.navDataOptions = 0x0FFF_FFFF
	** 
	** Corresponds to the 'GENERAL:navdata_options' configuration key.
	Int navDataOptions {
		get { getConfig("GENERAL:navdata_options").toInt }
		set { setConfig("GENERAL:navdata_options", it.toStr) }
	}	

	** If 'true' then roll commands ('moveLeft()' & 'moveRight()') generate roll + yaw based turns 
	** so the drone banks like an aeroplane / leans into the corners.
	** This is an easier control mode for racing games.
	** 
	** Note, unlike other SDKs, to enable 'combinedYawMode' you need only set this config to 'true'.
	** The move commands are automatically updated for you. 
	** 
	** Corresponds to the 'CONTROL:control_level' configuration key.
	Bool combinedYawMode {
		get { getConfig("CONTROL:control_level").toInt.and(0x02) > 0 }
		set { setConfig("CONTROL:control_level", (it ? 0x02 : 0).or(0x01).toStr) }
	}	
	
	** Sets the bitrate of the video transmission (kilobits per second) when 'videoBitrateControlMode'
	** is set to 'MANUAL'. Typical values range from 500 to 4000 kbps.
	** 
	** Can only be set with a non-default application ID. Throws an Err if this is not the case.
	** 
	** Corresponds to the 'VIDEO:bitrate' configuration key.
	Int videoBitrate {
		get { getConfig("VIDEO:bitrate").toInt }
		set {
			_checkId("change video bitrate")
			setConfig("VIDEO:bitrate", it.toStr)
		}		
	}
	
	** Enables the automatic bitrate control of the video stream. Enabling this configuration reduces 
	** bandwidth used by the video stream under bad Wi-Fi conditions, reducing the commands latency.
	** 
	**   0 = DISABLED - Bitrate set to videoMaxBitrate session config
	**   1 = DYNAMIC  - Video bitrate varies between [250 - videoMaxBitrate] kbps
	**   2 = MANUAL   - Video stream bitrate is fixed to videoBitrate
	** 
	** Can only be set with a non-default application ID. Throws an Err if this is not the case.
	** 
	** Corresponds to the 'VIDEO:bitrate_control_mode' configuration key.
	Int videoBitrateControlMode {
		get { getConfig("VIDEO:bitrate_control_mode", false)?.toInt ?: 0}
		set {
			_checkId("change video bitrate control")
			setConfig("VIDEO:bitrate_control_mode", it.toStr)
		}		
	}

	** The bitrate (kilobits per second) of the recording stream, both for USB and WiFi record.
	** 
	** Corresponds to the 'VIDEO:bitrate_storage' configuration key.
	Int videoBitrateStorage {
		get { getConfig("VIDEO:bitrate_storage").toInt }
		private set { }		
	}
	
	** Dumps all fields to debug string.
	Str dump(Bool dumpToStdOut := true) {
		fields := typeof.fields.findAll { it.isPublic && it.parent == this.typeof }
		names  := (Str[]) fields.map { it.name.toDisplayName }
		width  := names.max |p1, p2| { p1.size <=> p2.size }.size
		values := fields.map |field, i| { names[i].padr(width, '.') + "..." + field.get(this).toStr }
		dump   := values.join("\n")
		dump	= "APP CONFIG\n==========\n" + dump + "\n\n"
		if (dumpToStdOut)
			echo(dump)
		return dump
	}
	
	@NoDoc
	override Str toStr() { dump	}

	internal Void _checkId(Str what) {
		if (id == DroneConfig.defId)
			throw Err("Can not ${what} with default application ID: $id")
	}

	private Str? getConfig(Str key, Bool checked := true) {
		_config.drone.configMap[key] ?: (checked ? throw UnknownKeyErr(key) : null)
	}
	
	private Void setConfig(Str key, Obj val) {
		_config.sendConfig(key, val)
	}
}
