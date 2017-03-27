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
	** Setting this also sets the 'detectRoundel' config to 'vertical'.
	** 
	** Note 'HOVER_ON_ROUNDEL' was developed for the 2011 CES autonomous demonstration.
	** 
	** Corresponds to the 'CONTROL:flying_mode' configuration key.
	Bool hoverOnRoundel {
		// 0 = FREE_FLIGHT                // Normal mode, commands are enabled
		// 1 = HOVER_ON_ROUNDEL           // Commands are disabled, drone hovers on a roundel
		// 2 = HOVER_ON_ORIENTED_ROUNDEL  // Commands are disabled, drone hovers on an oriented roundel
		get { getConfig("CONTROL:flying_mode").toInt == 2 }
		set {
			if (it == true) {
				detectRoundel = VideoCamera.vertical
				setConfig("CONTROL:flying_mode", 2)
			} else
				setConfig("CONTROL:flying_mode", 0)
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
	** It is generally not advised to change this whilst video is already streaming.
	** 
	** Corresponds to the 'VIDEO:video_codec' configuration key.
	VideoResolution videoResolution {
		get {
			// H264_360P_CODEC          = 0x81  // Live stream with 360p H264 hardware encoder. No record stream.
			// H264_720P_CODEC          = 0x83  // Live stream with 720p H264 hardware encoder. No record stream.
			//
			// MP4_360P_CODEC           = 0x80  // Live stream with MPEG4.2 soft encoder. No record stream.
			// MP4_360P_H264_360P_CODEC = 0x82  // Live stream with MPEG4.2 soft encoder. Record stream with 360p H264 hardware encoder.
			// MP4_360P_H264_720P_CODEC = 0x88  // Live stream with MPEG4.2 soft encoder. Record stream with 720p H264 hardware encoder.
			liveCodec := getConfig("VIDEO:video_codec", false)?.toInt
			return (liveCodec == VideoResolution._720p.liveCodec) ? VideoResolution._720p : VideoResolution._360p
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

	** Enables black & white oriented roundel detection on the given camera.
	** To receive detection data, enable 'NavOption.visionDetect' in 
	** [DroneAppConfig.navDataOptions()]`DroneAppConfig.navDataOptions` and inspect the 
	** 'visionDetect' data in 'NavData'
	** 
	** Set to 'null' to disable detection.
	**  
	** Corresponds to the configuration keys:
	**   - 'DETECT:detect_type'
	**   - 'DETECT:detections_select_v'
	**   - 'DETECT:detections_select_h'
	VideoCamera? detectRoundel {
		get {
			//  3 = CAD_TYPE_NONE                : No detections
			//  5 = CAD_TYPE_ORIENTED_COCARDE    : Detects an oriented roundel under the drone
			//  8 = CAD_TYPE_H_ORIENTED_COCARDE  : Detects an oriented roundel in front of the drone
			// 10 = CAD_TYPE_MULTIPLE_DETECTION_MODE : See following note
			// 12 = CAD_TYPE_ORIENTED_COCARDE_BW : Black & White oriented roundel detected on bottom facing camera
			type := getConfig("DETECT:detect_type").toInt
			if (type == 12)
				return VideoCamera.vertical
			if (type == 3) {
				// Shell=1 | Roundel=2 | BlackRoundel=4 | Stripe=8 | Cap=16 | ShellV2=32 | TowerSide=64 | OrientedRoundel=128
				vert := getConfig("DETECT:detections_select_v").toInt
				if (vert == 128)
					return VideoCamera.vertical

				// Shell=1 | Roundel=2 | BlackRoundel=4 | Stripe=8 | Cap=16 | ShellV2=32 | TowerSide=64 | OrientedRoundel=128
				hori := getConfig("DETECT:detections_select_h").toInt
				if (hori == 128)
					return VideoCamera.horizontal
			}
			return null
		}
		set {
			type := getConfig("DETECT:detect_type").toInt
			if (type != 3)
				setConfig("DETECT:detect_type", 3)
			
			if (it == null) {	// NPE if null used in switch 
				setConfig("DETECT:detections_select_v", 0)
				setConfig("DETECT:detections_select_h", 0)
				return
			}

			switch (it) {
				case VideoCamera.vertical:
					setConfig("DETECT:detections_select_v", 128)
					setConfig("DETECT:detections_select_h", 0)
				
				case VideoCamera.horizontal:
					setConfig("DETECT:detections_select_v", 0)
					setConfig("DETECT:detections_select_h", 128)
			}
		}
	}

	** Detection, by default, runs at 60 frames per section (fps) but by setting this to 'true'
	** it is reduced to 30 fps, removing unnecessary CPU load when not needed. 
	** 
	** Corresponds to the 'DETECT:detections_select_v_hsync' configuration key.
	Bool detectRoundelLoRes {
		get { getConfig("DETECT:detections_select_v_hsync").toInt == 30 }
		set { setConfig("DETECT:detections_select_v_hsync", it ? 30 : 60) }
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

	** Starts saving navigation data to flash memory.
	** 
	** Creates the binary file '/data/video/boxes/tmp_flight_<dateTime>/userbox_<timestamp>' in flash memory 
	** containing navigation data where '<timestamp>' is the time since the drone booted.
	** 
	** Corresponds to the 'USERBOX:userbox_cmd' configuration key.
	Void userboxStart() {
		setConfig("USERBOX:userbox_cmd", [1, DateTime.now.toLocale("YYYYMMDD_hhmmss")])
	}
	
	** Stops saving navigation data to flash memory.
	** 
	** Renames the directory containing the binary files to '/data/video/boxes/flight_<dateTime>/'.
	**
	** Corresponds to the 'USERBOX:userbox_cmd' configuration key.
	Void userboxStop() {
		setConfig("USERBOX:userbox_cmd", [0])		
	}
	
	** Stops saving navigation data to flash memory and deletes the temporary files.
	** 
	** Corresponds to the 'USERBOX:userbox_cmd' configuration key.
	Void userboxCancel() {
		setConfig("USERBOX:userbox_cmd", [3])		
	}
	
	** Takes photographs with the forward facing front camera and saves it as JPEG images named
	** '/data/video/boxes/tmp_flight_<dateTime>/picture_<dateTime>.jpg'.
	** 
	** Note 'delayBetweenPhotos' must be in seconds.
	** 
	** Corresponds to the 'USERBOX:userbox_cmd' configuration key.
	Void takePhoto(Int numberOfPhotos := 1, Duration delayBetweenPhotos := 1sec) {
		setConfig("USERBOX:userbox_cmd", [2, delayBetweenPhotos.toSec, numberOfPhotos, DateTime.now.toLocale("YYYYMMDD_hhmmss")])		
	}
	
	
	** Dumps all fields to debug string.
	Str dump(Bool dumpToStdOut := true) {
		fields := typeof.fields.findAll { it.isPublic && it.parent == this.typeof }
		names  := (Str[]) fields.map { it.name.toDisplayName }
		width  := names.max |p1, p2| { p1.size <=> p2.size }.size
		values := fields.map |field, i| { names[i].padr(width, '.') + "...${field.get(this)}" }
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
	
	private Void setConfig(Str key, Obj? val) {
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
