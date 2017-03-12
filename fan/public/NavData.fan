
** Standard navigation data returned by the drone. 
** Common data can be found with the 'state()' and 'demoData()' methods, whilst a wealth of debug 
** data can be found in the NavOptions and the 'getOption()' method.
** 
** Unfortunately, the NavOption data is not really documented in the Drone SDK so make of it what 
** you may. 
** 
** To tell the drone what data to return, see `DroneAppConfig.navDataOptions` and `DroneConfig.navDataDemo`.
const class NavData {
		
	** The sequence number of the originating UDP packet.
	const Int			seqNum
	
	** Vision flags. (I have no idea!)
	const Int			visionFlag
	
	** State flags wrapped up in handy getter methods.
	const NavDataFlags	flags
	
	** A map of nav options.
	internal const NavOption:LazyNavOptData	_lazyOpts

	** (Advanced)
	@NoDoc
	new make(|This| f) { f(this) }
	
	** Return the 'NavOptionDemo' data (if any) from the nav options.
	** Convenience for:
	** 
	**   syntax: fantom
	**   navData.getOption(NavOption.demo)
	NavOptionDemo? demoData() {
		_lazyOpts[NavOption.demo]?.get
	}
	
	** Returns 'NavOption' data. Example:
	** 
	**   syntax: fantom
	**   demoData := navData[NavOption.demo]
	** 
	** Returns 'null' if it doesn't exist. 
	** 
	** Option data is usually a map of maps using strings as keys. Inspect the data to find out.
	@Operator
	Obj? getOption(NavOption navOpt) {
		_lazyOpts[navOpt]?.get
	}
	
	** Returns a list of options available via 'getOption()'.
	NavOption[] optionKeys() {
		_lazyOpts.keys
	}
}

** Standard state flags returned by the drone.
const class NavDataFlags {
	private static const Method[] flagMethods := NavDataFlags#.methods.findAll { it.returns == Bool# && it.params.isEmpty && it.parent == NavDataFlags# }

	** The raw flags data.
	const Int data

	
	** (Advaned) Used by the 'dump()' methods.
	@NoDoc
	const |Method,Bool?->Str| logFlagValue	:= |Method method, Bool? oldVal -> Str| {
		val := method.callOn(this, null)
		buf := StrBuf(64)
		buf.add(method.name.padr(28, '.'))
		if (oldVal != null)
			buf.add(oldVal).add(" --> ")
		buf.add(val)		
		return buf.toStr
	}
	
	@NoDoc
	new make(Int data, |This|? f := null) {
		this.data = data
		f?.call(this)
	}
	
	** The drone is in the air.
	Bool	flying()					{ data.and(1.shiftl( 0)) != 0 }
	Bool	videoEnabled()				{ data.and(1.shiftl( 1)) != 0 }
	Bool	visionEnabled()				{ data.and(1.shiftl( 2)) != 0 }
	Bool	eulerAnglesControl()		{ data.and(1.shiftl( 3)) == 0 }	// yep - this is correct!
	Bool	angularSpeedControl()		{ data.and(1.shiftl( 3)) != 0 }
	Bool	altitudeControlActive()		{ data.and(1.shiftl( 4)) != 0 }
	Bool	userFeedbackOn()			{ data.and(1.shiftl( 5)) != 0 }
	Bool	controlCommandAck()			{ data.and(1.shiftl( 6)) != 0 }
	Bool	cameraReady()				{ data.and(1.shiftl( 7)) != 0 }
	Bool	travellingEnabled()			{ data.and(1.shiftl( 8)) != 0 }
	Bool	usbReady()					{ data.and(1.shiftl( 9)) != 0 }
	Bool	navDataDemo()				{ data.and(1.shiftl(10)) != 0 }
	** Bootstap mode is on.
	Bool	navDataBootstrap()			{ data.and(1.shiftl(11)) != 0 }
	Bool	motorProblem()				{ data.and(1.shiftl(12)) != 0 }
	Bool	communicationLost()			{ data.and(1.shiftl(13)) != 0 }
	Bool	gyrometersDown()			{ data.and(1.shiftl(14)) != 0 }
	** Battery level is at or below 20%
	Bool	batteryTooLow()				{ data.and(1.shiftl(15)) != 0 }
	** The user initiated an emergency landing (sent an emergency AT*REF command)
	Bool	userEmergencyLanding()		{ data.and(1.shiftl(16)) != 0 }
	Bool	timerElapsed()				{ data.and(1.shiftl(17)) != 0 }
	Bool	magnometerNeedsCalibration(){ data.and(1.shiftl(18)) != 0 }
	** Drone exceeded maximum tilt. This also sets 'emergencyLanding'.
	Bool	anglesOutOufRange()			{ data.and(1.shiftl(19)) != 0 }
	** Too much wind.
	Bool	tooMuchWind()				{ data.and(1.shiftl(20)) != 0 }
	Bool	ultrasonicSensorDeaf()		{ data.and(1.shiftl(21)) != 0 }
	Bool	cutOutDetected()			{ data.and(1.shiftl(22)) != 0 }
	Bool	picVersionNumberOK()		{ data.and(1.shiftl(23)) != 0 }
	Bool	atCodedThreadOn()			{ data.and(1.shiftl(24)) != 0 }
	Bool	navDataThreadOn()			{ data.and(1.shiftl(25)) != 0 }
	Bool	videoThreadOn()				{ data.and(1.shiftl(26)) != 0 }
	Bool	acquisitionThreadOn()		{ data.and(1.shiftl(27)) != 0 }
	Bool	controlWatchdogDelayed()	{ data.and(1.shiftl(28)) != 0 }
	Bool	adcWatchdogDelayed()		{ data.and(1.shiftl(29)) != 0 }
	Bool	comWatchdogProblem()		{ data.and(1.shiftl(30)) != 0 }
	** The drone initiated an emergency landing.
	Bool	emergencyLanding()			{ data.and(1.shiftl(31)) != 0 }
	
	** Dumps all flags out to debug string.
	Str dump() {
		flagMethods.map { logFlagValue(it, null) }.join("\n")
	}
	
	** Dumps to a debug string all flags that are different to the instance passed in.
	** May return an empty string if nothing has changed.
	** 
	** If 'null' is passed in, all old flags are assumed to be 'false'.
	** 
	** Note this ignores changes to common flags 'comWatchdogProblem' and 'controlCommandAck'.
	Str dumpChanged(NavDataFlags? oldFlags) {
		oldFlags = oldFlags ?: NavDataFlags(0)
		if (data.xor(oldFlags.data) == 0)
			return ""
		
		return flagMethods.exclude { it == #comWatchdogProblem || it == #controlCommandAck }.map |method->Str?| {
			oldVal := method.callOn(oldFlags, null)
			newVal := method.callOn(this, null)
			return (newVal == oldVal) ? null : logFlagValue(method, oldVal)
		}.exclude { it == null }.join("\n")
	}
	
	@NoDoc
	override Str toStr() { dump	}
}

** Standard telemetry data returned by the drone.
const class NavOptionDemo {
	** Fly State
	const	DroneState	droneState
	** Control State
	const	FlightState	flightState
	** Battery voltage filtered (mV)
	const	Int			batteryPercentage
	** Pitch in milli-degrees
	const	Float		theta
	** Roll in milli-degrees
	const	Float		phi
	** Yaw in milli-degrees
	const	Float		psi
	** Altitude in metres
	const	Float		altitude
	** Estimated linear velocity
	const	Float		velocityX
	** Estimated linear velocity
	const	Float		velocityY
	** Estimated linear velocity
	const	Float		velocityZ
	** Streamed frame index. Not used -> To integrate in video stage.
	const	Int			frameIndex
	** (Deprecated) Camera parameters computed by detection
	const	Str:Obj		detection
	** (Deprecated) Camera parameters computed by drone
	const	Str:Obj		drone

	@NoDoc
	new make(|This| f) { f(this) }

	** Dumps all fields to debug string.
	Str dump(Bool dumpToStdOut := true) {
		fields	:= typeof.fields.findAll { it.isPublic && it.parent == this.typeof }
		values	:= Str:Obj[:]
		fields.each { values[it.name] = it.get(this) }
		dump	:= values.toStr	// so it looks like the rest of the NavOption maps

		if (dumpToStdOut)
			echo(dump)
		return dump
	}
	
	@NoDoc
	override Str toStr() { dump(false) }
}

** Drone state as returned by 'NavData'.
enum class DroneState {
	ok, lostAlt, lostAltGoDown, altOutZone, combinedYaw, brake, noVision, 		unknown;	// unknown appears to be at index 11
}

** Flight state as returned by 'NavData'.
enum class FlightState {
	def, init, landed, flying, hovering, test, transGotoFix, transTakeOff, transHovering, transLanding, 		transFlipping;	// unknown appears to be at index 10!?
}

