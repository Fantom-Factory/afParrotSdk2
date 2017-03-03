
** Drone config in the Common category.
** This is the default category, common to all applications.
const class DroneConfigCommon {
	private const Drone drone
	
	** Creates a wrapper around the given drone.
	new make(Drone drone) {
		this.drone = drone
	}

	** Version of the configuration subsystem.
	Version configVersion {
		get { Version(getConfig("GENERAL:num_version_config")) }
		private set { }
	}
	
	** Hardware version of the drone motherboard.
	Version motherboardVersion {
		get { Version(getConfig("GENERAL:num_version_mb")) }
		private set { }
	}
	
	** Firmware version of the drone.
	Version firmwareVersion {
		get { Version(getConfig("GENERAL:num_version_soft")) }
		private set { }
	}
	
	** Serial number of the drone.
	Str serialNumber {
		get { getConfig("GENERAL:drone_serial") }
		private set { }
	}
	
	** Date of drone firmware compilation.
	DateTime firmwareBuildData {
		get { DateTime.fromLocale(getConfig("GENERAL:soft_build_date"), "YYYY-MM-DD hh:mm") }
		private set { }
	}
	
	** Software version of the motor 1 board.
	Version motor1SoftwareVersion {
		get { Version(getConfig("GENERAL:motor1_soft")) }
		private set { }
	}
	
	** Harware version of the motor 1 board.
	Version motor1HardwareVersion {
		get { Version(getConfig("GENERAL:motor1_hard")) }
		private set { }
	}
	
	** Supplier version of the motor 1 board.
	Version motor1Supplier {
		get { Version(getConfig("GENERAL:motor1_supplier")) }
		private set { }
	}
	
	** Software version of the motor 2 board.
	Version motor2SoftwareVersion {
		get { Version(getConfig("GENERAL:motor2_soft")) }
		private set { }
	}
	
	** Harware version of the motor 2 board.
	Version motor2HardwareVersion {
		get { Version(getConfig("GENERAL:motor2_hard")) }
		private set { }
	}
	
	** Supplier version of the motor 2 board.
	Version motor2Supplier {
		get { Version(getConfig("GENERAL:motor2_supplier")) }
		private set { }
	}
	
	** Software version of the motor 3 board.
	Version motor3SoftwareVersion {
		get { Version(getConfig("GENERAL:motor3_soft")) }
		private set { }
	}
	
	** Harware version of the motor 3 board.
	Version motor3HardwareVersion {
		get { Version(getConfig("GENERAL:motor3_hard")) }
		private set { }
	}
	
	** Supplier version of the motor 3 board.
	Version motor3Supplier {
		get { Version(getConfig("GENERAL:motor3_supplier")) }
		private set { }
	}
	
	** Software version of the motor 4 board.
	Version motor4SoftwareVersion {
		get { Version(getConfig("GENERAL:motor4_soft")) }
		private set { }
	}
	
	** Harware version of the motor 4 board.
	Version motor4HardwareVersion {
		get { Version(getConfig("GENERAL:motor4_hard")) }
		private set { }
	}
	
	** Supplier version of the motor 4 board.
	Version motor4Supplier {
		get { Version(getConfig("GENERAL:motor4_supplier")) }
		private set { }
	}

	** Name of the AR.Drone. This name may be used by video games developper to assign a default
	** name to a player, and is not related to the Wi-Fi SSID name.
	Str droneName {
		get { getConfig("GENERAL:ardrone_name") }
		set { setConfig("GENERAL:ardrone_name", it) }
	}

	** Time spent by the drone in a flying state in its whole lifetime.
	Duration flyingTime {
		get { Duration(getConfig("GENERAL:flying_time").toInt * 1_000_000_000) }
		private set { }		
	}
	
	** The drone can either send a reduced set of navigation data (navdata) to its clients, or send 
	** all the available information which contain many debugging information that are useless for everyday flights.
	** 
	** If this parameter is set to 'true', the reduced set is sent by the drone.
	** If this parameter is set to 'false', all the available data is sent.
	Bool navDataDemo {
		get { Bool(getConfig("GENERAL:navdata_demo").lower) }
		set { setConfig("GENERAL:navdata_demo", it.toStr.upper) }		
	}

//	** Time the drone can wait without receiving any command from a client program. Beyond this 
//	** delay, the drone will enter in a *Com Watchdog triggered* state and hover on top a fixed point.
//	** 
//	** Note : This setting is currently disabled. The drone uses a fixed delay of 250 ms.
//	Int navDataOptions {
//		get { getConfig("GENERAL:com_watchdog").toInt }
//		set { setConfig("GENERAL:com_watchdog", it.toStr) }		
//	}

//	** Reserved for future use. The default value is TRUE, setting it to FALSE can lead to unexpected behaviour.
//	Bool videoEnable {
//		get { Bool(getConfig("GENERAL:video_enable").lower) }
//		set { setConfig("GENERAL:video_enable", it.toStr.upper) }		
//	}

//	** Reserved for future use. The default value is TRUE, setting it to FALSE can lead to unexpected behaviour.
//	Bool visionEnable {
//		get { Bool(getConfig("GENERAL:vision_enable").lower) }
//		set { setConfig("GENERAL:vision_enable", it.toStr.upper) }		
//	}

	** Minimum battery level before the drone automatically shuts down.
	Int minBatteryLevel {
		get { getConfig("GENERAL:vbat_min").toInt }
		set { setConfig("GENERAL:vbat_min", it.toStr) }		
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
