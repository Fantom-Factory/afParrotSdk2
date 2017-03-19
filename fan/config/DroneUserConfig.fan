
** Drone config in the User category.
** This config contains preferences for individual human users, so is largely based on controller 
** sensitivity profiles.
**  
** Create a new user by means of:
** 
**   syntax: fantom
**   drone.config.session.user("My User Name")
**
** Future code may then access the same user by **not** passing a user name:
**    
**   syntax: fantom
**   prof := drone.config.session.user.currentProfile
** 
const class DroneUserConfig {
	private const Log					log		:= Drone#.pod.log
	private const DroneSessionConfig	config
	
	** Creates a wrapper around the given drone.
	** Internal because we need to keep track of the multi-config IDs 
	internal new make(DroneSessionConfig config, Bool reReadConfig := true) {
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
	
	** Deletes this user profile from the drone.
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

	** Returns the current sensitivity profile. 
	** These are the absolute values allowed by the drone.
	** All drone move commands pertain to a percentage of the max values detailed here. 
	** 
	**   syntax: fantom
	**   drone.config.session.user.currentProfile()
	**     // --> [maxEulerAngle:20, maxVerticalSpeed:1000, maxYawSpeed:200]
	** 
	** This method will return either the indoor or outdoor profile dependent on the 
	** 'drone.config.useOutdoorProfile' setting.
	** 
	**  - 'maxEulerAngle' is the maximum bending angle for the drone in degrees, for both pitch and roll angles.
	**    Recommended values are 0 - 30 degrees.
	**  - 'maxVerticalSpeed' is the maximum vertical speed of the drone in milimeters per second.
	**    Recommended values are 200 - 2000.
	**  - 'maxYawSpeed' is the maximum yaw (spin) speed of the drone in degrees per second.
	**    Recommanded values are 40 - 350.
	** 
	** Corresponds to the configuration keys:
	**   - 'CONTROL:euler_angle_max'
	**   - 'CONTROL:control_vz_max'
	**   - 'CONTROL:control_yaw'
	Str:Int currentProfile {
		get {
			[
				"maxEulerAngle"		: getConfig("CONTROL:euler_angle_max").toFloat.toDegrees.round.toInt,
				"maxVerticalSpeed"	: getConfig("CONTROL:control_vz_max").toFloat.toInt,
				"maxYawSpeed"		: getConfig("CONTROL:control_yaw").toFloat.toDegrees.round.toInt
			]
		}
		private set { }
	}

	** Sensitivity profile for indoor use.
	** To use this profile, set the following:
	** 
	**   syntax: fantom
	**   drone.config.useOutdoorProfile = false
	** 
	** See `currentProfile` for value details.
	** 
	**   syntax: fantom
	**   drone.config.session.user.indoorProfile()
	**     // --> [maxEulerAngle:12, maxVerticalSpeed:700, maxYawSpeed:100]
	** 
	** When setting values, all unknown values are ignored. 
	** To change, pass in a map with just the values you wish to update.
	** 
	** Corresponds to the configuration keys:
	**   - 'CONTROL:indoor_euler_angle_max'
	**   - 'CONTROL:indoor_control_vz_max'
	**   - 'CONTROL:indoor_control_yaw'
	Str:Int indoorProfile {
		get {
			[
				"maxEulerAngle"		: getConfig("CONTROL:indoor_euler_angle_max").toFloat.toDegrees.round.toInt,
				"maxVerticalSpeed"	: getConfig("CONTROL:indoor_control_vz_max").toFloat.toInt,
				"maxYawSpeed"		: getConfig("CONTROL:indoor_control_yaw").toFloat.toDegrees.round.toInt
			]
		}
		set {
			setConfig("CONTROL:indoor_euler_angle_max"	, it["maxEulerAngle"	]?.toFloat?.toRadians)
			setConfig("CONTROL:indoor_control_vz_max"	, it["maxVerticalSpeed"	]?.toFloat)
			setConfig("CONTROL:indoor_control_yaw"		, it["maxYawSpeed"	 	]?.toFloat?.toRadians)
		}
	}

	** Sensitivity profile for outdoor use.
	** To use this profile, set the following:
	** 
	**   syntax: fantom
	**   drone.config.useOutdoorProfile = true
	** 
	** See `currentProfile` for value details.
	** 
	**   syntax: fantom
	**   drone.config.session.user.outdoorProfile()
	**     // --> [maxEulerAngle:20, maxVerticalSpeed:1000, maxYawSpeed:200]
	** 
	** When setting values, all unknown values are ignored. 
	** To change, pass in a map with just the values you wish to update.
	** 
	** Corresponds to the configuration keys:
	**   - 'CONTROL:outdoor_euler_angle_max'
	**   - 'CONTROL:outdoor_control_vz_max'
	**   - 'CONTROL:outdoor_control_yaw'
	Str:Int outdoorProfile {
		get {
			[
				"maxEulerAngle"		: getConfig("CONTROL:outdoor_euler_angle_max").toFloat.toDegrees.round.toInt,
				"maxVerticalSpeed"	: getConfig("CONTROL:outdoor_control_vz_max").toFloat.toInt,
				"maxYawSpeed"		: getConfig("CONTROL:outdoor_control_yaw").toFloat.toDegrees.round.toInt
			]
		}
		set {
			setConfig("CONTROL:outdoor_euler_angle_max"	, it["maxEulerAngle"	]?.toFloat?.toRadians)
			setConfig("CONTROL:outdoor_control_vz_max"	, it["maxVerticalSpeed"	]?.toFloat)
			setConfig("CONTROL:outdoor_control_yaw"		, it["maxYawSpeed"	 	]?.toFloat?.toRadians)			
		}
	}
	
	** Dumps all fields to debug string.
	Str dump(Bool dumpToStdOut := true) {
		fields := typeof.fields.findAll { it.isPublic && it.parent == this.typeof }
		names  := (Str[]) fields.map { it.name.toDisplayName }
		width  := names.max |p1, p2| { p1.size <=> p2.size }.size
		values := fields.map |field, i| { names[i].padr(width, '.') + "..." + field.get(this).toStr }
		dump   := values.join("\n")

		dump	= "USER CONFIG\n===========\n" + dump + "\n\n"

		if (dumpToStdOut)
			echo(dump)
		return dump
	}
	
	@NoDoc
	override Str toStr() { dump	}
	
	private Str getConfig(Str key) {
		config.drone.configMap[key] ?: throw UnknownKeyErr(key)
	}
	
	private Void setConfig(Str key, Float? val) {
		if (val != null) {
			config._config.sendMultiConfig(key, val.toStr)
			config.drone._updateConfig(key, val.toStr)
		}
	}
}
