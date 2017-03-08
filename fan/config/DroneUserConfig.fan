
** Drone config in the User category.
** These settings are be saved for the current user / profile, regardless of the application.
const class DroneUserConfig {
	private const Log					log		:= Drone#.pod.log
	private const DroneSessionConfig	config
	
	** Creates a wrapper around the given drone.
	new make(DroneSessionConfig config, Bool reReadConfig := true) {
		this.config = config
		if (reReadConfig)
			config.drone.configMap(true)
	}

	// ---- Identity ----
	
	** The current user ID.
	**  
	** Corresponds to the 'CUSTOM:user_id' configuration key.
	Str id {
		get { getConfig("CUSTOM:profile_id") }
		private set { }
	}
	
	** The current user name.
	** 
	** Corresponds to the 'CUSTOM:user_desc' configuration key.
	Str name {
		get { getConfig("CUSTOM:profile_desc") }
		private set { }
	}
	
	** Deletes this user data from the drone.
	Void deleteMe() {
		id := id
		if (id == "00000000") {
			log.warn("Will not delete default data!")	// don't know what might happen if we try this!?
			return
		}
		config._config._delUser("-${id}")
	}

	** Deletes **ALL** user data from the drone.
	** Use with caution.
	Void deleteAll() {
		log.warn("Deleting ALL user data!")
		config._config._delUser("-all")
	}

	// ---- Other Cmds ----

//CONTROL:euler_angle_max
//CAT_USER | Read/Write
//Description :
//Maximum bending angle for the drone in radians, for both pitch and roll angles.
//The progressive command function and its associated AT command refer to a percentage of this value. Note : For
//AR.Drone 2.0 , the new progressive command function is preferred (with the corresponding AT command).
//This parameter is a positive floating-point value between 0 and 0.52 (ie. 30deg). Higher values might be available
//on a specific drone but are not reliable and might not allow the drone to stay at the same altitude.
//This value will be saved to indoor/outdoor_euler_angle_max, according to the CONFIG:outdoor setting.	
//	
//CONTROL:control_vz_max
//CAT_USER | Read/Write
//Description :
//Maximum vertical speed of the AR.Drone, in milimeters per second.
//Recommanded values goes from 200 to 2000. Others values may cause instability.
//This value will be saved to indoor/outdoor_control_vz_max, according to the CONFIG:outdoor setting.
//	
//CONTROL:control_yaw
//CAT_USER | Read/Write
//Description :
//Maximum yaw speed of the AR.Drone, in radians per second.
//Recommanded values goes from 40/s to 350/s (approx 0.7rad/s to 6.11rad/s). Others values may cause instability.
//This value will be saved to indoor/outdoor_control_yaw, according to the CONFIG:outdoor setting.
//	
//CONTROL:indoor_euler_angle_max
//CAT_USER | Read/Write
//Description :
//This setting is used when CONTROL:outdoor is false. See the CONTROL:euler_angle_max description for further
//informations.
//
//CONTROL:indoor_control_vz_max
//CAT_USER | Read/Write
//Description :
//This setting is used when CONTROL:outdoor is false. See the CONTROL:control_vz_max description for further
//informations.
//
//CONTROL:indoor_control_yaw
//CAT_USER | Read/Write
//Description :
//This setting is used when CONTROL:outdoor is false. See the CONTROL:control_yaw description for further infor-
//mations.
//
//CONTROL:outdoor_euler_angle_max
//CAT_USER | Read/Write
//Description :
//This setting is used when CONTROL:outdoor is true. See the CONTROL:euler_angle_max description for further
//informations.
//
//CONTROL:outdoor_control_vz_max
//CAT_USER | Read/Write
//Description :
//This setting is used when CONTROL:outdoor is true. See the CONTROL:control_vz_max description for further in-
//formations.
//
//CONTROL:outdoor_control_yaw
//CAT_USER | Read/Write
//Description :
//This setting is used when CONTROL:outdoor is true. See the CONTROL:control_yaw description for further informa-
//tions.
	

	
	** Dumps all fields to debug string.
	Str dump() {
		fields := typeof.fields.findAll { it.isPublic && it.parent == this.typeof }
		names  := (Str[]) fields.map { it.name.toDisplayName }
		width  := names.max |p1, p2| { p1.size <=> p2.size }.size
		values := fields.map |field, i| { names[i].padr(width, '.') + "..." + field.get(this).toStr }
		return values.join("\n")
	}
	
	private Str getConfig(Str key) {
		config.drone.configMap[key] ?: throw UnknownKeyErr(key)
	}
	
	private Void setConfig(Str key, Str val) {
		config._config._sendMultiConfig(key, val)
		config.drone._updateConfig(key, val)
	}
}
