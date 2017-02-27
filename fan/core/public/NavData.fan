
** Standard navigation data returned by the drone. 
** Common data can be found with the 'state()' and 'demoData()' methods. 
const class NavData {
		
	** The sequence number of the originating UDP packet.
	const Int			seqNum
	
	** Vision flags. (I have no idea!)
	const Int			visionFlag
	
	** State flags wrapped up in handy getter methods.
	const NavDataFlags	flags
	
	** A map of nav options.
	// TODO store raw buf here, only convert (AtomicMap cache) when asked for 
	const NavOption:Obj	options

	** (Advanced)
	@NoDoc
	new make(|This| f) { f(this) }
	
	** Convenience method to return the 'NavOptionDemo' data (if any) contained in 'options'. 
	NavOptionDemo? demoData() {
		options[NavOption.demo]
	}
	
	** Convenience method to return 'NavOption' data. Example:
	** 
	**   syntax: fantom
	**   demoData := navData[NavOption.demo] 
	@Operator
	Obj? get(NavOption navOpt) {
		options[navOpt]
	}
}

** Standard state flags returned by the drone.
const class NavDataFlags {
	** The raw flags data.
	const Int stateFlags

	@NoDoc
	new make(Int stateFlags) {
		this.stateFlags = stateFlags
	}
	
	Bool	flying()					{ stateFlags.and(1.shiftl( 0)) != 0 }
	Bool	videoEnabled()				{ stateFlags.and(1.shiftl( 1)) != 0 }
	Bool	visionEnabled()				{ stateFlags.and(1.shiftl( 2)) != 0 }
	Bool	eulerAngelsControl()		{ stateFlags.and(1.shiftl( 3)) == 0 }	// yep - this is correct!
	Bool	angularSpeedControl()		{ stateFlags.and(1.shiftl( 3)) != 0 }
	Bool	altitudeControlActive()		{ stateFlags.and(1.shiftl( 4)) != 0 }
	Bool	userFeedbackOn()			{ stateFlags.and(1.shiftl( 5)) != 0 }
	Bool	controlCommandAck()			{ stateFlags.and(1.shiftl( 6)) != 0 }
	Bool	cameraReady()				{ stateFlags.and(1.shiftl( 7)) != 0 }
	Bool	travellingEnabled()			{ stateFlags.and(1.shiftl( 8)) != 0 }
	Bool	usbReady()					{ stateFlags.and(1.shiftl( 9)) != 0 }
	Bool	navDataDemo()				{ stateFlags.and(1.shiftl(10)) != 0 }
	Bool	navDataBootstrap()			{ stateFlags.and(1.shiftl(11)) != 0 }
	Bool	motorProblem()				{ stateFlags.and(1.shiftl(12)) != 0 }
	Bool	communicationLost()			{ stateFlags.and(1.shiftl(13)) != 0 }
	Bool	gyrometersDown()			{ stateFlags.and(1.shiftl(14)) != 0 }
	Bool	batteryTooLow()				{ stateFlags.and(1.shiftl(15)) != 0 }
	Bool	userEmergencyLanding()		{ stateFlags.and(1.shiftl(16)) != 0 }
	Bool	timerElapsed()				{ stateFlags.and(1.shiftl(17)) != 0 }
	Bool	magnometerNeedsCalibration(){ stateFlags.and(1.shiftl(18)) != 0 }
	Bool	angelsOutOufRange()			{ stateFlags.and(1.shiftl(19)) != 0 }
	Bool	tooMuchWind()				{ stateFlags.and(1.shiftl(20)) != 0 }
	Bool	ultrasonicSensorDeaf()		{ stateFlags.and(1.shiftl(21)) != 0 }
	Bool	cutoutDetected()			{ stateFlags.and(1.shiftl(22)) != 0 }
	Bool	picVersionNumberOK()		{ stateFlags.and(1.shiftl(23)) != 0 }
	Bool	atCodedThreadOn()			{ stateFlags.and(1.shiftl(24)) != 0 }
	Bool	navDataThreadOn()			{ stateFlags.and(1.shiftl(25)) != 0 }
	Bool	videoThreadOn()				{ stateFlags.and(1.shiftl(26)) != 0 }
	Bool	acquisitionThreadOn()		{ stateFlags.and(1.shiftl(27)) != 0 }
	Bool	controlWatchdogDelayed()	{ stateFlags.and(1.shiftl(28)) != 0 }
	Bool	adcWatchdogDelayed()		{ stateFlags.and(1.shiftl(29)) != 0 }
	Bool	comWatchdogProblem()		{ stateFlags.and(1.shiftl(30)) != 0 }
	Bool	emergencyLanding()			{ stateFlags.and(1.shiftl(31)) != 0 }
	
	** Dumps all flags out to debug string.
	Str dump() {
		buf := StrBuf(1536)
		typeof.methods.findAll { it.returns == Bool# && it.params.isEmpty && it.parent == NavDataFlags# }.each {
			buf.add(it.name.padr(28, '.'))
			buf.add(it.callOn(this, null))
			buf.addChar('\n')
		}
		return buf.toStr
	}
	
	@NoDoc
	override Str toStr() { dump	}
}

** Standard telemetry data returned by the drone.
const class NavOptionDemo {
	** Fly State
	const	FlyState	flyState
	** Control State
	const	CtrlState	ctrlState
	** Battery voltage filtered (mV)
	const	Int			batteryPercentage
	** Pitch in milli-degrees
	const	Float		theta
	** Roll in milli-degrees
	const	Float		phi
	** Yaw in milli-degrees
	const	Float		psi
	** Altitude in centimeters
	const	Int			altitude
	** Estimated linear velocity
	const	Float		velocityX
	** Estimated linear velocity
	const	Float		velocityY
	** Estimated linear velocity
	const	Float		velocityZ
	** Streamed frame index. Not used -> To integrate in video stage.
	const	Int			frameIndex
	** (Deprecated) Camera parameters compute by detection
	const	Str:Obj		detection
	** (Deprecated) Camera parameters compute by drone
	const	Str:Obj		drone
	@NoDoc
	new make(|This| f) { f(this) }
}

** Data available from  
enum class NavOption {
	demo, time, rawMeasures, physMeasures, gyrosOffsets, eulerAngles, references, trims, rcReferences, pwm, altitude, visionRaw, visionOf, vision, visionPerf, trackersSend, visionDetect, watchdog, adcDataFrame, videoStream, games, pressureRaw, magneto, windSpeed, kalmanPressure, hdvideoStream, wifi, gps;
}

** Drone state.
enum class FlyState {
	ok, lostAlt, lostAltGoDown, altOutZone, combinedYaw, brake, noVision, 		unknown;
}

** Flight state.
enum class CtrlState {
	def, init, landed, flying, hovering, test, transTakeOff, transGotoFix, transLanding, transLooping;
}

