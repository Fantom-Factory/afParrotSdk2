using concurrent::AtomicRef

** Drone config in the Session category.
** Session config relates to the current flight and encapsulates user and application data. 
** That is, should the session be changed / reset, the user and application config changes also.
** 
** Create a new session by means of:
** 
**   syntax: fantom
**   drone.config.session("My Session Name")
**
** Future code may then access the same session by **not** passing a session name:
**    
**   syntax: fantom
**   drone.config.session.hoveringRange = 1000
** 
const class DroneSessionConfig {
	private const Log			log		:= Drone#.pod.log
	internal const DroneConfig	_config
	
	** Internal because we need to keep track of the multi-config IDs 
	** Creates a wrapper around the given drone.
	internal new make(DroneConfig config, Bool reReadConfig := true) {
		this._config = config
		if (reReadConfig)
			config.drone.configRefresh
	}
	
	** The wrapped drone instance
	Drone drone() {
		_config.drone
	}
	
	// ---- Identity ----
	
	** The current session ID.
	**  
	** Corresponds to the 'CUSTOM:profile_id' configuration key.
	Str id {
		get { getConfig("CUSTOM:session_id") }
		private set { }
	}
	
	** The current session name.
	** 
	** Corresponds to the 'CUSTOM:profile_desc' configuration key.
	Str name {
		get { getConfig("CUSTOM:session_desc") }
		private set { }
	}
	
	** Deletes this session data from the drone.
	Void deleteMe() {
		id := id
		if (id == "00000000") {
			log.warn("Will not delete default data!")	// don't know what might happen if we try this!?
			return
		}
		_config._delSess("-${id}")
	}

	** Deletes **ALL** session data from the drone.
	** Use with caution.
	Void deleteAll() {
		log.warn("Deleting ALL session data!")
		_config._delSess("-all")
	}

	
	
	// ---- Config ----

	** Gets or makes user config.
	DroneUserConfig user(Str? userName := null) {
		_config._userConfig(userName, true)
	}

	** Gets or makes application config.
	** If 'null' is passed, this just returns the current config.
	DroneAppConfig app(Str? appicationName := null) {
		_config._appConfig(appicationName, true)
	}	


	
	// ---- Other Cmds ----

	** Set to 'true' to enable roundel detection and activate a semi-autonomous hover on top of an 
	** [oriented roundel]`https://bitbucket.org/AlienFactory/afparrotsdk2/downloads/orientedRoundel.png`. 
	** 
	**   0 = FREE_FLIGHT                // Normal mode, commands are enabled
	**   1 = HOVER_ON_ROUNDEL           // Commands are disabled, drone hovers on a roundel
	**   2 = HOVER_ON_ORIENTED_ROUNDEL  // Commands are disabled, drone hovers on an oriented roundel
	** 
	** Hover modes **MUST** be activated by the 'detect_type' configuration.
	** 
	** Note 'HOVER_ON_ROUNDEL' was developed for the 2011 CES autonomous demonstration.
	** 
	** Corresponds to the 'CONTROL:flying_mode' configuration key.
	Bool hoverOnRoundel {
		get { getConfig("CONTROL:flying_mode").toInt == 2 }
		set {
			if (it == true) {
				detectRoundel = VideoCamera.vertical
				setConfig("CONTROL:flying_mode", 2.toStr)
			} else
				setConfig("CONTROL:flying_mode", 0.toStr)
		}		
	}

	** The maximum distance (in millimetres) the drone should hover. 
	** Used when 'flyingMode' is set to 'HOVER_ON_(ORIENTED_)ROUNDEL'
	** 
	** Corresponds to the 'CONTROL:hovering_range' configuration key.
	Int hoverMaxHeight {
		get { getConfig("CONTROL:hovering_range").toInt }
		set { setConfig("CONTROL:hovering_range", it.toStr) }		
	}

	** Sets the frames per second (fps) of the live video codec.
	** Values should be between 15 and 30. 
	** 
	** Corresponds to the 'VIDEO:codec_fps' configuration key.
	Int videoFps {
		get { getConfig("VIDEO:codec_fps").toInt }
		set { setConfig("VIDEO:codec_fps", it.toStr) }		
	}


	** Selects which video camera on the drone to stream data back from.
	** 
	** Corresponds to the 'VIDEO:video_channel' configuration key.
	VideoCamera videoCamera {
		get { VideoCamera.vals[getConfig("VIDEO:video_channel", false)?.toInt ?: 0] }
		set { setConfig("VIDEO:video_channel", it.ordinal.toStr) }		
	}

	** Selects the resolution of the video that's streamed back.
	** 
	** Corresponds to the 'VIDEO:video_codec' configuration key.
	VideoResolution videoResolution {
//		TODO add recordStart(videoResolution) and recordStop() functions
		get {
			// H264_360P_CODEC          = 0x81  // Live stream with 360p H264 hardware encoder. No record stream.
			// H264_720P_CODEC          = 0x83  // Live stream with 720p H264 hardware encoder. No record stream.
			//
			// MP4_360P_CODEC           = 0x80  // Live stream with MPEG4.2 soft encoder. No record stream.
			// MP4_360P_H264_360P_CODEC = 0x82  // Live stream with MPEG4.2 soft encoder. Record stream with 360p H264 hardware encoder.
			// MP4_360P_H264_720P_CODEC = 0x88  // Live stream with MPEG4.2 soft encoder. Record stream with 720p H264 hardware encoder.
			//
			// NULL_CODEC               = 0,
			// UVLC_CODEC               = 0x20  // codec_type value is used for START_CODE
			// P264_CODEC               = 0x40
			// MP4_360P_SLRS_CODEC      = 0x84
			// H264_360P_SLRS_CODEC     = 0x85
			// H264_720P_SLRS_CODEC     = 0x86
			// H264_AUTO_RESIZE_CODEC   = 0x87  // resolution is automatically adjusted according to bitrate
			liveCodec := getConfig("VIDEO:video_codec", false)?.toInt ?: 0x81
			return VideoResolution.vals.find { it.liveCodec == liveCodec }
		}
		set { setConfig("VIDEO:video_codec", it.liveCodec.toStr) }		
	}

	** Maximum bitrate (kilobits per second) the device can decode. This is set as the upper bound for drone bitrate values.
	** 
	** Typical values for Apple iOS Device are:
	**  - iPhone 4S  : 4000 kbps
	**  - iPhone 4   : 1500 kbps
	**  - iPhone 3GS :  500 kbps
	** 
	** When using the bitrate control mode in 'VBC_MANUAL', this maximum bitrate is ignored.
	** 
	** When using the bitrate control mode in 'VBC_MODE_DISABLED', the bitrate is fixed to this maximum bitrate.
	**  
	** Corresponds to the 'VIDEO:max_bitrate' configuration key.
	Int videoMaxBitrate {
		get { getConfig("VIDEO:max_bitrate").toInt }
		set { setConfig("VIDEO:max_bitrate", it.toStr) }
	}

	** Enables roundel detection on the given camera.
	**  
	** TODO:  play with vision tags
	** 
	** Corresponds to the configuration keys:
	**   - 'DETECT:detect_type'
	**   - 'DETECT:detections_select_v'
	**   - 'DETECT:detections_select_h'
	VideoCamera? detectRoundel {
		get {
			//  3 = CAD_TYPE_NONE : No detections
			// 10 = CAD_TYPE_MULTIPLE_DETECTION_MODE : See following note
			// 12 = CAD_TYPE_ORIENTED_COCARDE_BW : Black & White oriented roundel detected on bottom facing camera
			// 13 = CAD_TYPE_VISION_V2 : Standard tag detection
			type := getConfig("DETECT:detect_type").toInt
			if (type == 12)
				return VideoCamera.vertical
			if (type == 13) {
				// 0 = TAG_TYPE_NONE : No tag to detect
				// 3 = TAG_TYPE_ORIENTED_ROUNDEL 
				// 6 = TAG_TYPE_SHELL_TAG_V2 : Standard hulls (both indoor and outdoor) tags
				// 8 = TAG_TYPE_BLACK_ROUNDEL : Black&While oriented roundel
				vert := getConfig("DETECT:detections_select_v").toInt
				if (vert == 8)
					return VideoCamera.vertical

				hori := getConfig("DETECT:detections_select_h").toInt
				if (hori == 8)
					return VideoCamera.horizontal
			}
			return null
		}
		set {
			type := getConfig("DETECT:detect_type").toInt
			if (type != 10)
				setConfig("DETECT:detect_type", 10.toStr)
			
			if (it == null) {	// NPE if null used in switch 
				setConfig("DETECT:detections_select_v", 0.toStr)
				setConfig("DETECT:detections_select_h", 0.toStr)
				return
			}

			switch (it) {
				case VideoCamera.vertical:
					setConfig("DETECT:detections_select_v", 8.toStr)
					setConfig("DETECT:detections_select_h", 0.toStr)
				
				case VideoCamera.horizontal:
					setConfig("DETECT:detections_select_v", 0.toStr)
					setConfig("DETECT:detections_select_h", 8.toStr)
			}
		}
	}

	** Detection defaults to 60 fps, but may be reduced to 30 fps to reduce the CPU load when you don’t need a 60Hz detection.
	** 
	** Corresponds to the 'DETECT:detections_select_v_hsync' configuration key.
	Int detectVertFps {	// TODO convert detectVertFps to Bool and rename 
		get { getConfig("DETECT:detections_select_v_hsync").toInt }
		set { setConfig("DETECT:detections_select_v_hsync", it.toStr) }		
	}

	** The GPS position used for media tagging and userbox recording.
	** 
	** When setting values, all unknown values are ignored. 
	** To change, pass in a map with just the values you wish to update.
	** 
	** Corresponds to the configuration keys:
	**   - 'GPS:longitude'
	**   - 'GPS:latitude'
	**   - 'GPS:altitude'
	Str:Float gpsPosition {
		get {
			[
				"longitude"	: getConfig("GPS:longitude").toFloat,
				"latitude"	: getConfig("GPS:latitude").toFloat,
				"altitude"	: getConfig("GPS:altitude").toFloat
			]
		}
		set {
			setConfig("GPS:longitude"	, it["longitude"]?.toStr)
			setConfig("GPS:latitude"	, it["latitude"	]?.toStr)
			setConfig("GPS:altitude"	, it["altitude"	]?.toStr)
		}
	}

	// FIXME userbox config commands
//USERBOX:userbox_cmd
//CAT_SESSION | Read/Write
//Description :
//The USERBOX:userbox_cmd provide a feature to save navigation data from drone during a time period and to take
//pictures. When the USERBOX:userbox_cmd is sent with parameter USERBOX_CMD_START, the AR.Drone create
//directory /data/video/boxes/tmp_flight_YYYYMMDD_hhmmss in AR.Drone flash memory and save a binary file
//containingnavigationdataandnamed/data/video/boxes/tmp_flight_YYYYMMDD_hhmmss/userbox_<timestamp>.
//<timestamp> represent the time since the AR.Drone booted.
//When the USERBOX:userbox_cmd is sent with parameter USERBOX_CMD_STOP, the AR.Drone finish saving of
///data/video/boxes/tmp_flight_YYYYMMDD_hhmmss/userbox_<timestamp>. and rename directory from
///data/video/boxes/tmp_flight_YYYYMMDD_hhmmss to /data/video/boxes/flight_YYYYMMDD_hhmmss.
//When the USERBOX:userbox_cmd is sent with parameter USERBOX_CMD_CANCEL, the AR.Drone stop the user-
//box like sending USERBOX_CMD_STOP and delete file
///data/video/boxes/tmp_flight_YYYYMMDD_hhmmss/userbox_<timestamp>.
//When the USERBOX:userbox_cmd is sent with parameter USERBOX_CMD_SCREENSHOT, the AR.Drone takes pic-
//ture of frontal camera and saves it as JPEG image named
///data/video/boxes/tmp_flight_YYYYMMDD_hhmmss/picture_YYMMDD_hhmmss.jpg.
//Note : If the userbox is started, the picture is saved in userbox directory. Note : After stopping userbox or taking
//picture, you MUST call academy_download_resume function to download flight directory by ftp protocol.
//Typical values are :
//• USERBOX_CMD_STOP : Command to stop userbox. This command takes no parameters.
//• USERBOX_CMD_CANCEL : Command to cancel userbox. If the userbox is started, stop the userbox and
//delete its content.
//• USERBOX_CMD_START : Command to start userbox. This command takes the current date as string pa-
//rameter with format YYYYMMDD_hhmmss
//• USERBOX_CMD_SCREENSHOT : Command to take a picture from AR.Drone . This command takes 3
//parameters.
//– 1 - delay : This value is an unsigned integer representing the delay (in seconds) between each screen-
//shot.
//– 1 - number of burst : This value is an unsigned integer representing the number of screenshot to take.
//– 1 - current date : This value is the current date as string parameter with format YYYYMMDD_hhmmss.
//Note : The file /data/video/boxes/tmp_flight_YYYYMMDD_hhmmss/userbox_<timestamp> will be used for future
//feature. (AR.Drone Academy ).
//	

	** Dumps all fields to debug string.
	Str dump(Bool dumpToStdOut := true) {
		fields := typeof.fields.findAll { it.isPublic && it.parent == this.typeof }
		names  := (Str[]) fields.map { it.name.toDisplayName }
		width  := names.max |p1, p2| { p1.size <=> p2.size }.size
		values := fields.map |field, i| { names[i].padr(width, '.') + "..." + field.get(this).toStr }
		dump   := values.join("\n")
		
		dump = "SESSION CONFIG\n==============\n" + dump + "\n\n"
		dump += user.dump(false)
		dump += app.dump(false)

		if (dumpToStdOut)
			echo(dump)
		return dump
	}
	
	@NoDoc
	override Str toStr() { dump	}

	private Str? getConfig(Str key, Bool checked := true) {
		_config.drone.configMap[key] ?: (checked ? throw UnknownKeyErr(key) : null)
	}
	
	private Void setConfig(Str key, Str? val) {
		if (val != null) {	// for GPS position
			_config.sendMultiConfig(key, val)
			_config.drone._updateConfig(key, val)
		}
	}
}

** The video cameras on the AR Drone. 
enum class VideoCamera {
	** The forward facing horizontal camera.
	horizontal,

	** The botton facing vertical camera.
	vertical;
}

** A selection of video resolutions. 
enum class VideoResolution {
	** 640 x 360
	_360p(0x81, 0x82),

	** 1280 x 720
	_720p(0x83, 0x88);
	
	internal const Int liveCodec
	internal const Int recordCodec
	
	private new make(Int liveCodec, Int recordCodec) {
		this.liveCodec	 = liveCodec
		this.recordCodec = recordCodec
	}
}
