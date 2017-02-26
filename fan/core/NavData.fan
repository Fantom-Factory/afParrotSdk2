
const class NavData {

	const	Int			stateFlags
	const	Int			seqNum
	const	Int			visionFlag
	const	DroneState	state
	
	// Demo nav data
//	CtrlState	ctrlState
	const Int		battery
	const Float		altitude
	const Float		pitch
	const Float		roll
	const Float		yaw
	const Float		vx
	const Float		vy
	const Float		vz

//	VisionTag[]	visionTags
	
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
		
		stateFlags	= in.readS4
		seqNum		= in.readS4
		visionFlag	= in.readS4
		state		= DroneState(stateFlags)
		
		while (in.avail > 0) {
			optionTag := in.readS2
			optionLen := in.readS2

			switch (optionTag) {
				case 0:		// NAVDATA_DEMO_TAG
					echo("NAVDATA_DEMO_TAG")
				
				case -1:	// NAVDATA_CKS_TAG
					chkSum	 := in.readS4
					myChkSum := 0
					navDataBuf.size = navDataBuf.pos - 8
					navDataBuf.trim
					chkSumIn := navDataBuf.flip.in
					while (chkSumIn.avail > 0) {
						myChkSum += chkSumIn.read
					}
				
					if (chkSum != myChkSum)
						throw IOErr("Invalid NavData checksum; expected 0x${chkSum} got 0x${myChkSum}")
			
				default:
					echo("WARN - wots a 0x${optionTag.toHex(4).upper} tag?")

					// length includes header size (4 bytes)
					if (optionLen < 4) {
						echo("WARN - invalid option length 0x${optionLen.toHex(4).upper}")
						continue
					}
					in.skip(optionLen - 4)
			}
		}
		
	}	
	
	Str dump() {
//		"poo 0x$sequence.toHex.upper 0x$visionFlag.toHex.upper"
		//"poo 0x$seq.toHex.upper "
		
		typeof.methods.findAll { it.returns == Bool# && it.params.isEmpty }.each { echo("${it.name.padr(20)} = ${it.callOn(this, null)}") }
		return ""
	}
	
	static Void main(Str[] args) {
//		dat := NavData(Buf.fromHex("88776655900c804fed0d000000000000ffff08001f040000"))
//		echo(dat.dump)
//		echo("demo = $dat.navDataDemoOnly")
//		echo("boot = $dat.navDataBootstrap")
//
//		
//		dat = NavData(Buf.fromHex("88776655900c804f3309000001000000ffff080062030000"))
//		echo("demo = $dat.navDataDemoOnly")
//		echo("boot = $dat.navDataBootstrap")
//		
//		dat = NavData(Buf.fromHex("88776655900c804f3409000001000000ffff080063030000"))
//		echo("demo = $dat.navDataDemoOnly")
//		echo("boot = $dat.navDataBootstrap")
		

		d := NavData { it.stateFlags = 0x4f800c90 }
		echo(d.dump)

	}
}

//enum class CtrlState {
//	def, init, landed, flying, hovering, test, transTakeoff, transGotofix, transLanding;
//}

//enum class NavDataTag {
//	NAVDATA_DEMO_TAG, NAVDATA_TIME_TAG, NAVDATA_RAW_MEASURES_TAG, 
//	NAVDATA_PHYS_MEASURES_TAG, NAVDATA_GYROS_OFFSETS_TAG, NAVDATA_EULER_ANGLES_TAG, 
//	NAVDATA_REFERENCES_TAG, NAVDATA_TRIMS_TAG, NAVDATA_RC_REFERENCES_TAG, 
//	NAVDATA_PWM_TAG, NAVDATA_ALTITUDE_TAG, NAVDATA_VISION_RAW_TAG, 
//	NAVDATA_VISION_OF_TAG, NAVDATA_VISION_TAG, NAVDATA_VISION_PERF_TAG, 
//	NAVDATA_TRACKERS_SEND_TAG, NAVDATA_VISION_DETECT_TAG, NAVDATA_WATCHDOG_TAG, 
//	NAVDATA_ADC_DATA_FRAME_TAG, NAVDATA_VIDEO_STREAM_TAG, NAVDATA_CKS_TAG;	//(0xFFFF);
//}

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
