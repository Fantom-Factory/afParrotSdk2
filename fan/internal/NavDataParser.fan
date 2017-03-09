using concurrent::AtomicRef

** Creates a 'NavData' instance from the contents of a UDP payload. 
internal class NavDataParser {
	private const Log		log	:= Drone#.pod.log

	// It appears there are 2 header numbers
	// see https://github.com/felixge/node-ar-drone/blob/master/lib/navdata/parseNavdata.js#L592
	private static const Int navDataHeader1	:= 0x55667788
	private static const Int navDataHeader2	:= 0x55667789
	
	NavData parse(Buf navDataBuf) {
		in := navDataBuf.in
		in.endian = Endian.little
		
		header := in.readS4
		if (header != navDataHeader1 && header != navDataHeader2)
			throw Err("Nav Data Magic Number [${header}] does not equal 0x${navDataHeader1.toHex.upper}")
		
		flags		:= NavDataFlags(in.readU4)
		seqNum		:= in.readU4
		visionFlag	:= in.readU4
		options		:= NavOption:LazyNavOptData[:]
		
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
			
			navOption	:= (NavOption) NavOption.vals[optionId]
			parseMethod	:= navOption.parseMethod 	//typeof.method("parse${navOption.name.capitalize}", false)
			if (parseMethod == null) {
				log.warn("No parse method for NavOption ${navOption}")
				in.skip(optionLen - 4)
			} else {
				rawOpt := in.readBufFully(null, optionLen - 4) { it.endian = Endian.little }
				options[navOption] = LazyNavOptData(rawOpt, parseMethod)
			}
		}
		
		return NavData {
			it.flags		= flags
			it.seqNum		= seqNum
			it.visionFlag	= visionFlag
			it._lazyOpts	= options
		}
	}
}

internal const class LazyNavOptData {
	private const Buf		optRaw
	private const Method	parseMethod
	private const AtomicRef	optRef	:= AtomicRef(null)

	new make(Buf optRaw, Method parseMethod) {
		this.optRaw = optRaw.toImmutable
		this.parseMethod = parseMethod
	}
	
	Obj get() {
		if (optRef.val == null)
			optRef.val  = parseMethod.call(optRaw.in { endian = Endian.little })
		return optRef.val
	}
}

//** Data options returned from the drone.
enum class NavOption {
	demo(#parseDemo),
	time, rawMeasures, physMeasures, gyrosOffsets, eulerAngles, references, trims, rcReferences, pwm, altitude, visionRaw, visionOf, vision, visionPerf, trackersSend,
	visionDetect(#parseVisionDetect),
	watchdog, adcDataFrame, videoStream, games, pressureRaw, magneto, windSpeed, kalmanPressure, hdvideoStream, wifi, gps;
	
	internal const Method? parseMethod
	
	private new make(Method? parseMethod := null) {
		this.parseMethod = parseMethod
	}
	
	static internal NavOptionDemo parseDemo(InStream in) {
		NavOptionDemo {
			it.droneState			= DroneState.vals.getSafe(in.readU2, DroneState.unknown)
			it.flightState			= FlightState.vals[in.readU2]
			it.batteryPercentage	= in.readU4
			it.theta				= Float.makeBits32(in.readU4) / 1000
			it.phi					= Float.makeBits32(in.readU4) / 1000
			it.psi					= Float.makeBits32(in.readU4) / 1000
			it.altitude				= in.readS4 / 1000f
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
	
	static internal Obj parseVisionDetect(InStream in) {
		return 3
	}
}
