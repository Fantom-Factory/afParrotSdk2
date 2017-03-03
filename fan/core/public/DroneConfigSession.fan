
** Drone config in the Session category.
** These setting are be saved for the current flight session, regardless of application / user.
const class DroneConfigSession {
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
