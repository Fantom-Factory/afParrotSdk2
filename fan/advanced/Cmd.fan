
** (Advanced)
@NoDoc
const class Cmd {
    const Str?	id
    const Obj[]	params

	** (Advanced) Creates a Cmd with the given id and params.
	** Param values must be either an 'Int', 'Float', or 'Str'.
	@NoDoc
	new make(Str id, Obj[] params, |This|? f := null) {
		this.id		= id
		this.params	= params
		f?.call(this)
	}
	
	// ---- Cmd Factories ----
	
	** Makes a 'CALIB' cmd. 
	static Cmd makeCalib(Int deviceNum) {
		Cmd("CALIB", [deviceNum])
	}
	
	** Makes a 'CONFIG' cmd with the given name / value pair. 
	static Cmd makeConfig(Str name, Str value) {
		Cmd("CONFIG", [name.lower, value])
	}
	
	** Makes a 'CONFIG_IDS' cmd with the given IDs. 
	static Cmd makeConfigIds(Str sessionId, Str userId, Str applicationId) {
		Cmd("CONFIG_IDS", [sessionId, userId, applicationId])
	}

	** Makes a 'CTRL' cmd.
	** 
	** Possible states of the drone 'control' thread.
	** 
	** pre>
	** typedef enum {
	**   NO_CONTROL_MODE = 0,          /*<! Doing nothing */
	**   ARDRONE_UPDATE_CONTROL_MODE,  /*<! Not used */
	**   PIC_UPDATE_CONTROL_MODE,      /*<! Not used */
	**   LOGS_GET_CONTROL_MODE,        /*<! Not used */
	**   CFG_GET_CONTROL_MODE,         /*<! Send active configuration file to a client through the 'control' socket UDP 5559 */
	**   ACK_CONTROL_MODE,             /*<! Reset command mask in navdata */
	**   CUSTOM_CFG_GET_CONTROL_MODE   /*<! Requests the list of custom configuration IDs */
	** } ARDRONE_CONTROL_MODE;
	** <pre
	static Cmd makeCtrl(Int controlMode, Int otherMode) {
		Cmd("CTRL", [controlMode, otherMode])
	}
	
	** Makes a 'REF' cmd.
	static Cmd makeEmergency() {
		makeRef(1.shiftl(8))
	}
	
	** Makes a 'FTRIM' cmd.
	static Cmd makeFlatTrim() {
		Cmd("FTRIM", Obj#.emptyList)
	}
	
	** Makes a 'PCMD' cmd.
	static Cmd makeHover() {
		makePcmd(0, 0f, 0f, 0f, 0f)
	}
	
	** Makes a 'COMWDG' cmd.
	static Cmd makeKeepAlive() {
		Cmd("COMWDG", Obj#.emptyList)
	}

	** Makes a 'REF' cmd.
	static Cmd makeLand() {
		makeRef(0)
	}

	** Makes an 'ANIM' cmd.
	static Cmd makePlayAnim(Int animNo, Duration duration) {
		Cmd("ANIM", [animNo, duration.toMillis])
	}
	
	** Makes a 'LED' cmd.
	static Cmd makePlayLed(Int animNo, Float frequency, Duration duration) {
		Cmd("LED", [animNo, frequency, duration.toMillis])
	}
	
	** Makes a 'PCMD' cmd.
	static Cmd makeMove(Float leftRightTilt, Float frontBackTilt, Float verticalSpeed, Float angularSpeed, Bool combinedYawMode, Bool absoluteMode) {
		mode := 1
		if (combinedYawMode)
			mode = mode.or(0x2)
		if (absoluteMode)
			mode = mode.or(0x4)
		return makePcmd(mode, leftRightTilt, frontBackTilt, verticalSpeed, angularSpeed)
	}

	** Makes a 'REF' cmd.
	static Cmd makeTakeOff() {
		makeRef(1.shiftl(9))
	}

	// ---- 

	** Makes a 'REF' cmd.
	private static Cmd makeRef(Int val) {
		Cmd("REF", [val.or(1.shiftl(18)).or(1.shiftl(20)).or(1.shiftl(22)).or(1.shiftl(24)).or(1.shiftl(28))])
	}

	// TODO experiment with PCMD_MAG cmds and different absolute / progressive modes
	
	** Makes a 'PCMD' cmd.
	private static Cmd makePcmd(Int mode, Float leftRightTilt, Float frontBackTilt, Float verticalSpeed, Float angularSpeed) {
		Cmd("PCMD", [mode, leftRightTilt, frontBackTilt, verticalSpeed, angularSpeed])
	}
	
	// ---- 
	
	** Returns the cmd string to send to the drone.
	Str cmdStr(Int seq) {
		params.isEmpty
			? "AT*${id}=${seq}\r"
			: "AT*${id}=${seq},${encodeParams(params)}\r"
	}
	
	internal static Str encodeParams(Obj[] params) {
		params.join(",") |p->Str| {
			if (p is Int)	return ((Int  ) p).toStr
			if (p is Float)	return ((Float) p).bits32.toStr
			if (p is Str)	return ((Str  ) p).toCode('"')
			throw ArgErr("Param should be an Int, Float, or Str - not ${p.typeof} -> ${p}")
		}
	}

	** Returns the `cmdStr` with a seq of '0'.
	override Str toStr() { cmdStr(0) }
}
