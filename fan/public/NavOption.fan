
** Data options returned from the drone, see `NavData`.
** Unfortunately, NavOption data is not really documented in the Drone SDK so make of it what you may. 
** 
** To tell the drone what data to return, see `DroneAppConfig.navDataOptions`.
enum class NavOption {
	demo			(#parseDemo),
	time			(#parseTime),
	rawMeasures		(#parseRawMeasures),
	physMeasures	(#parsePhysMeasures), 
	gyrosOffsets	(#parseGyrosOffsets),
	eulerAngles		(#parseEulerAngles),
	references		(#parseReferences), 
	trims			(#parseTrims), 
	rcReferences	(#parseRcReferences), 
	pwm				(#parsePwm), 
	altitude		(#parseAltitude), 
	visionRaw		(#parseVisionRaw), 
	visionOf		(#parseVisionOf), 
	vision			(#parseVision), 
	visionPerf		(#parseVisionPerf), 
	trackersSend	(#parseTrackersSend),
	visionDetect	(#parseVisionDetect),
	watchdog		(#parseWatchdog), 
	adcDataFrame	(#parseAdcDataFrame), 
	videoStream		(#parseVideoStream), 
	games			(#parseGames), 
	pressureRaw		(#parsePressureRaw), 
	magneto			(#parseMagneto), 
	windSpeed		(#parseWindSpeed), 
	kalmanPressure	(#parseKalmanPressure), 
	hdvideoStream	(#parseHdVideoStream), 
	wifi			(#parseWifi), 
	gps				(#parseGps),
	unknown1		(#parseUnknown),
	unknown2		(#parseUnknown);
	
	internal const Method parseMethod
	
	private new make(Method parseMethod) {
		this.parseMethod = parseMethod
	}
	
	Int flag() {
		1.shiftl(this.ordinal)
	}
	
	static internal NavOptionDemo parseDemo(InStream in) {
		NavOptionDemo {
			it.droneState			= DroneState.vals.getSafe(uint16(in), DroneState.unknown)
			it.flightState			= FlightState.vals[uint16(in)]
			it.batteryPercentage	= uint32 (in)
			it.theta				= float32(in) / 1000
			it.phi					= float32(in) / 1000
			it.psi					= float32(in) / 1000
			it.altitude				= int32  (in) / 1000f
			it.velocityX			= float32(in)
			it.velocityY			= float32(in)
			it.velocityZ			= float32(in)
			it.frameIndex			= uint32 (in)
			detection				:= Str:Obj[
				"camera"			: Str:Obj[
					"rotation"		: matrix3x3(in),
					"translation"	: vector3x1(in)
				],
				"tagIndex"			: uint32(in)
			]
			detection["camera"]->set("type", uint32(in))
			it.detection			= detection
			it.drone				= Str:Obj[
				"camera"			: Str:Obj[
					"rotation"		: matrix3x3(in),
					"translation"	: vector3x1(in)
				]
			]
		}
	}
	
	static internal Duration parseTime(InStream in) {
		droneTime(in.readU4)
	}
	
	static internal Str:Obj parseRawMeasures(InStream in) {
		Str:Obj[
			"accelerometers"		: ["x": uint16(in), "y": uint16(in), "z": uint16(in)],	// [LSB] filtered accelerometers
			"gyroscopes"			: ["x": uint16(in), "y": uint16(in), "z": uint16(in)],	// [LSB] filtered gyrometers
			"gyroscopes110"			: ["x": uint16(in), "y": uint16(in)],					// [LSB] x/y 110 deg/s
			"batteryMilliVolt"		: uint32(in),			// [mV] battery voltage raw
			"usEcho"				: Str:Int[
				"start"				: uint16(in),			// [LSB]
				"end"				: uint16(in),			// [LSB]
				"association"		: uint16(in),			// [LSB?]
				"distance"			: uint16(in),			// [LSB]
			],
			"usCurve"				: Str:Int[
				"time"				: uint16(in),			// [LSB]
				"value"				: uint16(in),			// [LSB]
				"ref"				: uint16(in),			// [LSB]
			],
			"echo"					: Str:Int[
				"flagIni"			: uint16(in),			// [LSB]
				"num"				: uint16(in),			// [LSB] (is key 'num' OR 'name'?)
				"sum"				: uint32(in),			// [LSB]
			],
			"altTemp"				: uint32(in),			// [mm]
			"gradient"				: uint16(in)
		]
	}
	
	static internal Str:Obj parsePhysMeasures(InStream in) {
		Str:Obj[
			"temperature"			: Str:Num[
				"accelerometer"		: float32(in),			// [K]
				"gyroscope"			: uint16(in),			// [LSB]
			],
			"accelerometers"		: vector3x1(in),		// [mg]
			"gyroscopes"			: vector3x1(in),		// [deg/s]
			"alim3V3"				: uint32(in),			// 3.3volt alim [LSB]
			"vrefEpson"				: uint32(in),			// ref volt Epson gyro [LSB]
			"vrefIDG"				: uint32(in)			// ref volt IDG gyro [LSB]
		]
	}
	
	static internal Str:Float parseGyrosOffsets(InStream in) {
		vector3x1(in)
	}
	
	static internal Str:Float parseEulerAngles(InStream in) {
		Str:Float[
			"theta"					: float32(in),			// [mdeg?]
			"phi"					: float32(in)			// [mdeg?]
		]
	}

	static internal Str:Obj parseReferences(InStream in) {
		Str:Obj[
			"theta"					: uint32(in),			// [mdeg]
			"phi"					: uint32(in),			// [mdeg]
			"thetaI"				: uint32(in),			// [mdeg]
			"phiI"					: uint32(in),			// [mdeg]
			"pitch"					: uint32(in),			// [mdeg]
			"roll"					: uint32(in),			// [mdeg]
			"yaw"					: uint32(in),			// [mdeg/s]
			"psi"					: uint32(in),			// [mdeg]

			"vx"					: float32(in),
			"vy"					: float32(in),
			"thetaMod"				: float32(in),
			"phiMod"				: float32(in),
			
			"kVX"					: float32(in),
			"kVY"					: float32(in),
			"kMode"					: uint16(in),
			
			"ui"					: Str:Num[
				"time"				: float32(in),
				"theta"				: float32(in),
				"phi"				: float32(in),
				"psi"				: float32(in),
				"psiAccuracy"		: float32(in),
				"seq"				: uint32(in),
			]
		]
	}

	static internal Str:Obj parseTrims(InStream in) {
		Str:Obj[
			"angularRates"			: Str:Float[
				"r"					: float32(in)
			],
			"eulerAngles"			: Str:Float[
				"theta"				: float32(in),			// [mdeg?]
				"phi"				: float32(in)			// [mdeg?]
			]
		]
	}
	
	static internal Str:Int parseRcReferences(InStream in) {
		Str:Int[
			"pitch"					: int32(in),			// [mdeg?]
			"roll"					: int32(in),			// [mdeg?]
			"yaw"					: int32(in),			// [mdeg/s?]
			"gaz"					: int32(in),			// [mdeg?]
			"ag"					: int32(in)
		]
	}
	
	static internal Str:Obj parsePwm(InStream in) {
		Str:Obj[
			"motors"				: x(4) { uint8(in) },	// [PWM]
			"satMotors"				: x(4) { uint8(in) },	// [PWM]
			"gazFeedForward"		: float32(in),			// [PWM]
			"gazAltitude"			: float32(in),			// [PWM]
			"altitudeIntegral"		: float32(in),			// [mm/s]
			"vzRef"					: float32(in),			// [mm/s]
			"uPitch"				: int32(in),			// [PWM]
			"uRoll"					: int32(in),			// [PWM]
			"uYaw"					: int32(in),			// [PWM]
			"yawUI"					: float32(in),			// [PWM] yaw_u_I
			"uPitchPlanif"			: int32(in),			// [PWM]
			"uRollPlanif"			: int32(in),			// [PWM]
			"uYawPlanif"			: int32(in),			// [PWM]
			"uGazPlanif"			: float32(in),			// [PWM]
			"motorCurrents"			: x(4) { uint16(in) },	// [mA]
			"altitudeProp"			: float32(in),			// [PWM]
			"altitudeDer"			: float32(in)			// [PWM]
		]
	}

	static internal Str:Obj parseAltitude(InStream in) {
		Str:Obj[
			"vision"				: int32(in),			// [mm]
			"vz"					: float32(in),			// [mm/s]
			"ref"					: int32(in),			// [mm]
			"raw"					: int32(in),			// [mm]
			"observer"				: Str:Obj[
				"acceleration"		: float32(in),			// [m/s2]
				"altitude"			: float32(in),			// [m]
				"x"					: vector3x1(in),
				"state"				: uint32(in)
			],
			"estimated"				: Str:Obj[
				"vb"				: vector2x1(in),
				"state"				: uint32(in)
			]
		]
	}
	
	static internal Str:Obj parseVisionRaw(InStream in) {
		Str:Obj[
			"tx"					: float32(in),
			"ty"					: float32(in),
			"tz"					: float32(in)
		]		
	}
	
	static internal Str:Obj parseVisionOf(InStream in) {
		Str:Obj[
			"dx"					: x(5) { float32(in) },
			"dy"					: x(5) { float32(in) }
		]		
	}
	
	static internal Str:Obj parseVision(InStream in) {
		Str:Obj[
			"state"					: uint32(in),
			"misc"					: int32(in),
			"phi"					: Str:Float[
				"trim"				: float32(in),			// [rad]
				"refProp"			: float32(in)			// [rad]
			],
			"theta"					: Str:Float[
				"trim"				: float32(in),			// [rad]
				"refProp"			: float32(in)			// [rad]
			],
			"newRawPicture"			: int32(in),
			"capture"				: Str:Obj[
				"theta"				: float32(in),
				"phi"				: float32(in),
				"psi"				: float32(in),
				"altitude"			: int32(in),
				"time"				: droneTime(uint32(in))
			],
			"bodyV"					: vector3x1(in),
			"delta"					: Str:Float[
				"theta"				: float32(in),
				"phi"				: float32(in),
				"psi"				: float32(in),
			],
			"gold"					: Str:Num[
				"defined"			: uint32(in),
				"reset"				: uint32(in),
				"phi"				: float32(in),
				"psi"				: float32(in),
			]			
		]		
	}
	
	static internal Str:Obj parseVisionPerf(InStream in) {
		Str:Obj[
			"szo"					: float32(in),
			"corners"				: float32(in),
			"compute"				: float32(in),
			"tracking"				: float32(in),
			"trans"					: float32(in),
			"update"				: float32(in),
			"custom"				: x(20) { float32(in) }
		]		
	}

	static internal Str:Obj parseTrackersSend(InStream in) {
		Str:Obj[
			"locked"				: x(30) { int32(in) },
			"point"					: x(30) { screenPoint(in) }
		]		
	}

	static internal Str:Obj parseVisionDetect(InStream in) {
		Str:Obj[
			"nbDetected"			: uint32(in),			// number of detected tags or oriented roundel
			"type"					: x(4) { uint32(in) },	// Type of the detected tag or oriented roundel; see the CAD_TYPE enumeration
			"xc"					: x(4) { uint32(in) },	// X and Y coordinates of detected tag or oriented roundel inside the picture, 
			"yc"					: x(4) { uint32(in) },	// with (0,0) being the top-left corner, and (1000,1000) the right-bottom corner regardless the picture resolution or the source camera
			"width"					: x(4) { uint32(in) },	// Width and height of the detection bounding-box (tag or oriented roundel), when applicable
			"height"				: x(4) { uint32(in) },
			"dist"					: x(4) { uint32(in) },	// Distance from camera to detected tag or oriented roundel in centimeters, when applicable
			"orientationAngle"		: x(4) { float32(in) },	// Angle of the oriented roundel in degrees in the screen, when applicable
			"rotation"				: x(4) { matrix3x3(in) },	//  Reserved for future use
			"translation"			: x(4) { vector3x1(in) },	//  Reserved for future use
			"cameraSource"			: x(4) { uint32(in) }	// Camera Source which detected tag or oriented roundel
		]
	}
	
	static internal Int parseWatchdog(InStream in) {
		uint32(in)
	}
	
	static internal Str:Obj parseAdcDataFrame(InStream in) {
		Str:Obj[
			"version"				: uint32(in),
			"dataFrame"				: x(32) { uint8(in) }
		]
	}
	
	static internal Str:Obj parseVideoStream(InStream in) {
		Str:Obj[
			"quant"					: uint8(in),			// quantizer reference used to encode frame [1:31]
			"frame"					: Str:Int[
				"size"				: uint32(in),			// frame size (bytes)
				"number"			: uint32(in)			// frame index
			],
			"atcmd"					: Str:Num[
				"sequence"			: uint32(in),			// atmcd ref sequence number
				"meanGap"			: uint32(in),			// mean time between two consecutive atcmd_ref (ms)
				"varGap"			: float32(in),
				"quality"			: uint32(in)			// estimator of atcmd link quality
			],
			"bitrate"				: Str:Int[
				"out"				: uint32(in),			// measured out throughput from the video tcp socket
				"desired"			: uint32(in)			// last frame size generated by the video encoder
			],
			"data"					: x(5) { int32(in) },	// misc temporary data
			"tcpQueueLevel"			: uint32(in),
			"fifoQueueLevel"		: uint32(in)
		]
	}
	
	static internal Str:Obj parseGames(InStream in) {
		Str:Obj[
			"doubleTap"				: uint32(in),
			"finishLine"			: uint32(in)
		]
	}

	static internal Str:Obj parsePressureRaw(InStream in) {
		Str:Obj[
			"up"				: int32(in),			// [LSB] (UP?)
			"ut"				: int16(in),			// [LSB] (UT?)
			"temperature"		: int32(in),			// [0_1C]
			"pressure"			: int32(in)				// [Pa]
		]
	}

	static internal Str:Obj parseMagneto(InStream in) {
		Str:Obj[
			"mx"				: int16(in),			// [LSB]
			"my"				: int16(in),			// [LSB]
			"mz"				: int16(in),			// [LSB]
			"raw"				: vector3x1(in),		// [mG]	magneto in the body frame, in mG
			"rectified"			: vector3x1(in),		// [mG]
			"offset"			: vector3x1(in),		// [mG]
			"heading"			: Str:Float[
				"unwrapped"		: float32(in),			// [deg]
				"gyroUnwrapped"	: float32(in),			// [deg]
				"fusionUnwrapped": float32(in)			// [mdeg]
			],
			"ok"				: uint8(in),
			"state"				: uint32(in),			// [SU]
			"radius"			: float32(in),			// [mG]
			"error"				: Str:Float[
				"mean"			: float32(in),			// [mG]
				"variance"		: float32(in)			// [mG2]
			]
		]
	}
	
	static internal Str:Obj parseWindSpeed(InStream in) {
		Str:Obj[
			"speed"				: float32(in),			// [m/s] estimated wind speed
			"angle"				: float32(in),			// [rad] estimated wind direction in North-East frame, e.g. if wind_angle is pi/4, wind is from South-West to North-East
			"compensation"		: Str:Float[
				"theta"			: float32(in),			// [rad]
				"phi"			: float32(in)			// [mG2]
			],
			"stateX"			: x(6) { float32(in) },	// [SU]
			"debug"				: x(3) { float32(in) }
		]
	}


	static internal Str:Obj parseKalmanPressure(InStream in) {
		Str:Obj[
			"offsetPressure"	: float32(in),			// [Pa]
			"estimated"			: Str:Obj[
				"altitude"		: float32(in),			// [mm]
				"velocity"		: float32(in),			// [m/s]
				"angle"			: Str:Float[
					"pwm"		: float32(in),			// [m/s2]
					"pressure"	: float32(in)			// [Pa]
				],
				"us"			: Str:Float[
					"offset"	: float32(in),			// [m]
					"prediction": float32(in)			// [mm]
				],
				"covariance"	: Str:Float[
					"alt"		: float32(in),			// [m]
					"pwm"		: float32(in),
					"velocity"	: float32(in)			// [m/s]
				],
				"groundEffect"	: bool(in),				// [SU]
				"sum"			: float32(in),			// [mm]
				"reject"		: bool(in),				// [SU]
				"uMultisinus"	: float32(in),
				"gazAltitude"	: float32(in),
				"flagMultisinus": bool(in),
				"flagMultisinusStart": bool(in)
			]
		]
	}
	
	static internal Str:Obj parseHdVideoStream(InStream in) {
		val := Str:Obj[
			"hdvideoState"		: uint32(in),
			"storageFifo"		: Str:Int[
				"nbPackets"		: uint32(in),
				"size"			: uint32(in)
			],
			"usbkey"			: Str:Int[
				"size"			: uint32(in),			// [KB] USB key in kbytes - 0 if no key present
				"freespace"		: uint32(in),			// [KB] USB key free space in kbytes - 0 if no key present
			],
			"frameNumber"		: uint32(in),			// 'frame_number' PaVE field of the frame starting to be encoded for the HD stream 
		]
		val["usbkey"]->set("remainingTime", uint32(in))	// [sec] time in seconds
		return val
	}

	static internal Str:Float parseWifi(InStream in) {
		Str:Float[
			// from ARDrone_SDK_2_0/ControlEngine/iPhone/Classes/Controllers/MainViewController.m
			"linkQuality"		: 1 - (float32(in))
		]
	}

	static internal Str:Obj parseGps(InStream in) {
		Str:Obj[
			"latitude"			: double64(in), 
			"longitude"			: double64(in), 
			"elevation"			: double64(in), 
			"hdop"				: double64(in), 
			"dataAvailable"		: int32(in), 
			"zeroValidated"		: int32(in), 
			"wptValidated"		: int32(in), 
			"lat0"				: double64(in), 
			"lon0"				: double64(in), 
			"latFuse"			: double64(in), 
			"lonFuse"			: double64(in), 
			"gpsState"			: uint32(in), 
			"xTraj"				: float32(in), 
			"xRef"				: float32(in), 
			"yTraj"				: float32(in), 
			"yRef"				: float32(in), 
			"thetaP"			: float32(in), 
			"phiP"				: float32(in), 
			"thetaI"			: float32(in), 
			"phiI"				: float32(in), 
			"thetaD"			: float32(in), 
			"phiD"				: float32(in), 
			"vdop"				: double64(in), 
			"pdop"				: double64(in), 
			"speed"				: float32(in), 
			"lastFrameTimestamp": droneTime(uint32(in)), 
			"degree"			: float32(in), 
			"degreeMag"			: float32(in), 
			"ehpe"				: float32(in), 
			"ehve"				: float32(in), 
			"c_n0"				: float32(in), 
			"nbSatellites"		: uint32(in), 
			"channels"			: x(12) { satChannel(in) }, 
			"gpsPlugged"		: int32(in), 
			"ephemerisStatus"	: uint32(in), 
			"vxTraj"			: float32(in), 
			"vyTraj"			: float32(in), 
			"firmwareStatus"	: uint32(in) 
		]
	}

	static internal Buf parseUnknown(InStream in) {
		in.readAllBuf
	}

	private static Bool		bool	(InStream in) { in.readU1 != 0 }
	private static Int		uint8	(InStream in) { in.readU1 }
	private static Int		uint16	(InStream in) { in.readU2 }
	private static Int		uint32	(InStream in) { in.readU4 }
	private static Int		int16	(InStream in) { in.readS2 }
	private static Int		int32	(InStream in) { in.readS4 }
	private static Float	float32	(InStream in) { Float.makeBits32(in.readU4) }
	private static Float	double64(InStream in) { Float.makeBits(in.readS8) }
	
	private static List x(Int num, |Int->Obj| f) {
		(0..<num).toList.map { f(it) }
	}
	
	private static Str:Int satChannel(InStream in) {
		Str:Int["sat": uint8(in), "cn0": uint8(in)]
	}

	private static Str:Int screenPoint(InStream in) {
		Str:Int["x": int32(in), "y": int32(in)]
	}

	private static Str:Float vector2x1(InStream in) {
		Str:Float["x": float32(in), "y": float32(in)]
	}

	private static Str:Float vector3x1(InStream in) {
		Str:Float["x": float32(in), "y": float32(in), "z": float32(in)]
	}

	private static Float[] matrix3x3(InStream in) {
		x(9) { Float.makeBits32(in.readU4) }
	}
	
	private static Duration droneTime(Int time) {
		// first 11 bits are seconds
		seconds := time.shiftr(21)
		// last 21 bits are microseconds
		microseconds := time.shiftl(11).shiftr(11)
		return Duration((seconds * 1sec.ticks) + (microseconds * 1000))
	}
}
