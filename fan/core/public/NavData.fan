
const class NavData {
	private const Log		log	:= Drone#.pod.log
	const	Int				stateFlags
	const	Int				seqNum
	const	Int				visionFlag
	const	DroneState		state
	const	NavOption:Obj	options

	// It appears there are 2 header numbers
	// see https://github.com/felixge/node-ar-drone/blob/master/lib/navdata/parseNavdata.js#L592
	private static const Int navDataHeader1	:= 0x55667788
	private static const Int navDataHeader2	:= 0x55667789
	
	new make(|This| f) { f(this) }
	
	new makeBuf(Buf navDataBuf) {
		in := navDataBuf.in
		in.endian = Endian.little
		
		header := in.readS4
		if (header != navDataHeader1 && header != navDataHeader2)
			throw Err("Nav Data Magic Number [${header}] does not equal 0x${navDataHeader1.toHex.upper}")
		
		stateFlags	= in.readU4
		seqNum		= in.readU4
		visionFlag	= in.readU4
		state		= DroneState(stateFlags)
		options		:= NavOption:Obj[:]
		
		while (in.avail > 0) {
			optionId  := in.readU2
			optionLen := in.readU2

			if (optionId == 0xFFFF) {
				chkSum	 := in.readU4
				navDataBuf.size = navDataBuf.pos - 8
				navDataBuf.trim
				chkSumIn := navDataBuf.flip.in
				myChkSum := 0
				while (chkSumIn.avail > 0) { myChkSum += chkSumIn.read }
			
				if (chkSum != myChkSum)
					throw IOErr("Invalid NavData checksum; expected 0x${chkSum} got 0x${myChkSum}")
				continue
			}
			
			navOption	:= NavOption.vals[optionId]
			parseMethod	:= typeof.method("parse${navOption.name.capitalize}", false)
			if (parseMethod == null) {
				log.warn("No parse method for NavOption ${navOption}")
				in.skip(optionLen - 4)
			} else
				options[navOption] = parseMethod.call(in, optionLen)
		}
		this.options = options
	}
	
	NavOptionDemo? demoData() {
		options[NavOption.demo]
	}
	
	@Operator
	Obj? get(NavOption navOpt) {
		options[navOpt]
	}
	
	static internal NavOptionDemo parseDemo(InStream in) {
		NavOptionDemo {
			it.flyState				= FlyState.vals[in.readU2]
			it.ctrlState			= CtrlState.vals[in.readU2]
			it.batteryPercentage	= in.readU4
			it.theta				= Float.makeBits32(in.readU4) / 1000
			it.phi					= Float.makeBits32(in.readU4) / 1000
			it.psi					= Float.makeBits32(in.readU4) / 1000
			it.altitude				= in.readS4 / 1000
			it.velocityX			= Float.makeBits32(in.readU4)
			it.velocityY			= Float.makeBits32(in.readU4)
			it.velocityZ			= Float.makeBits32(in.readU4)
			it.frameIndex			= in.readU4
				detection			:= Str:Obj[
				"camera"	: Str:Obj[
					"rotation"		: [0, 0, 0, 0, 0, 0, 0, 0, 0].map |v->Float| { Float.makeBits32(in.readU4) },
					"translation"	: [0, 0, 0].map |v->Float| { Float.makeBits32(in.readU4) }
				],
				"tagIndex"	: in.readU4
			]
				detection["camera"]->set("type", in.readU4)
			it.detection			= detection
			it.drone				= Str:Obj[
				"camera"	: Str:Obj[
					"rotation"		: [0, 0, 0, 0, 0, 0, 0, 0, 0].map |v->Float| { Float.makeBits32(in.readU4) },
					"translation"	: [0, 0, 0].map |v->Float| { Float.makeBits32(in.readU4) }
				]
			]
		}
	}
	
	static internal Obj parseVisionDetect(InStream in, Int optLen) {
		in.skip(optLen - 4)
		return 3
	}
}

** see /ARDrone_SDK_2_0_1/ARDroneLib/Soft/Common/config.h
const class DroneState {
	private const Int stateFlags

	internal new make(Int stateFlags) {
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
	
	Str dump() {
		buf := StrBuf(1536)
		typeof.methods.findAll { it.returns == Bool# && it.params.isEmpty && it.parent == DroneState# }.each {
			buf.add(it.name.padr(28, '.'))
			buf.add(it.callOn(this, null))
			buf.addChar('\n')
		}
		return buf.toStr
	}
	
	@NoDoc
	override Str toStr() { dump	}
}

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

enum class NavOption {
	demo, time, rawMeasures, physMeasures, gyrosOffsets, eulerAngles, references, trims, rcReferences, pwm, altitude, visionRaw, visionOf, vision, visionPerf, trackersSend, visionDetect, watchdog, adcDataFrame, videoStream, games, pressureRaw, magneto, windSpeed, kalmanPressure, hdvideoStream, wifi, gps;
}

enum class FlyState {
	ok, lostAlt, lostAltGoDown, altOutZone, combinedYaw, brake, noVision;
}

enum class CtrlState {
	def, init, landed, flying, hovering, test, transTakeOff, transGotoFix, transLanding, transLooping;
}

