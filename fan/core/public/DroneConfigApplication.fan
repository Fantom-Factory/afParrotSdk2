
** Drone config in the Application category.
** These settings are be saved for the current application.
const class DroneConfigApplication {
	private const Drone drone
	
	** Creates a wrapper around the given drone.
	new make(Drone drone) {
		this.drone = drone
	}

	** When using 'navDataDemo', this configuration allows the application to ask for other navData packets.
	** Most common example is the 'default_navdata_options' macro defined in the 'config_key.h' file.
	** The full list of the possible navData packets can be found in the 'navdata_common.h' file.
	// TODO map to navdata_options enum / flags
	Int navDataOptions {
		get { getConfig("GENERAL:navdata_options").toInt }
		set { setConfig("GENERAL:navdata_options", it.toStr) }		
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
