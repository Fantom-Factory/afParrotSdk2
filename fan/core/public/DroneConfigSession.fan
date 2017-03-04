
** Drone config in the Session category.
** These setting are be saved for the current flight session, regardless of application / user.
const class DroneConfigSession {
	private const Drone drone
	
	** Creates a wrapper around the given drone.
	new make(Drone drone) {
		this.drone = drone
	}

//CONTROL:flying_mode
//CAT_SESSION | Read/Write
//Description :
//Since 1.5.1 firmware, the AR.Drone has two different flight modes. The first is the legacy FreeFlight mode, where the
//user controls the drone, an a new semi-autonomous mode, called "HOVER_ON_TOP_OF_ROUNDEL", where the
//drones will hover on top of a ground tag. This new flying mode was developped for 2011 CES autonomous demon-
//stration. Since 2.0 and 1.10 firmwares, a third mode, called "HOVER_ON_TOP_OF_ORIENTED_ROUDNEL", was
//added. This mode is the same as the previous one, except that the AR.Drone will always face the same direction.
//For all modes, progressive commands are possible.
//
//Note : Oriented Black&White Roundel detection must be activated with the DETECT:detect_type setting if you want
//to use the "HOVER_ON_TOP_OF_(ORIENTED_)ROUNDEL" mode.
//Note : Enum with modes can be found in the ardrone_api.h file.
//	
//CONTROL:hovering_range
//CAT_SESSION | Read/Write
//Description :
//This setting is used when CONTROL:flying_mode is set to "HOVER_ON_TOP_OF_(ORIENTED_)ROUNDEL". It
//givestheAR.Dronethemaximumdistance(inmillimeters)allowedbetweentheAR.Droneandtheorientedroundel.
//	
//VIDEO:codec_fps
//CAT_SESSION | Read/Write
//Description :
//Current FPS of the live video codec. Maximum value is 30. Note : Only effective on AR.Drone 2.0 .
//
//VIDEO:video_codec
//CAT_SESSION | Default : Read only | Multiconfig : Read/Write
//Description :
//Current video codec of the AR.Drone . Values differs for AR.Drone 1.0 and AR.Drone 2.0 .
//Note : On AR.Drone 2.0 , this key controls the start/stop of the record stream.
//Possible codec values for AR.Drone 2.0 are :
//• MP4_360P_CODEC : Live stream with MPEG4.2 soft encoder. No record stream.
//• H264_360P_CODEC : Live stream with H264 hardware encoder configured in 360p mode. No record stream.
//• MP4_360P_H264_720P_CODEC : Live stream with MPEG4.2 soft encoder. Record stream with H264 hard-
//ware encoder in 720p mode.
//• H264_720P_CODEC : Live stream with H264 hardware encoder configured in 720p mode. No record stream.
//• MP4_360P_H264_360P_CODEC : Live stream with MPEG4.2 soft encoder. Record stream with H264 hard-
//ware encoder in 360p mode.
//Possible codec values for AR.Drone 1.0 are :
//• UVLC_CODEC : MJPEG-like codec.
//• P264_CODEC : H264-like codec.
//Note : Other codec values can lead to unexpected behaviour. Note : Enum with codec values can be found in the
//VLIB/video_codec.h file of the ARDroneLIB .
//	
//VIDEO:max_bitrate
//CAT_SESSION | Default : Read only | Multiconfig : Read/Write
//Description :
//AR.Drone 2.0 only.
//Maximum bitrate that the device can decode. This is set as the upper bound for drone bitrate values.
//Typical values for Apple iOS Device are :
//• iPhone 4S : 4000 kbps
//• iPhone 4 : 1500 kbps
//• iPhone 3GS : 500 kbps
//Note : When using the bitrate control mode in "VBC_MANUAL", this maximum bitrate is ignored. Note : When
//using the bitrate control mode in "VBC_MODE_DISABLED", the bitrate is fixed to this maximum bitrate.
//	
//VIDEO:videol_channel
//CAT_SESSION | Read/Write
//Description :
//The video channel that will be sent to the controller.
//Current implementation supports 4 different channels :
//- ZAP_CHANNEL_HORI
//- ZAP_CHANNEL_VERT
//- ZAP_CHANNEL_LARGE_HORI_SMALL_VERT (AR.Drone 1.0 only)
//- ZAP_CHANNEL_LARGE_VERT_SMALL_HORI (AR.Drone 1.0 only)
//
//DETECT:detect_type
//CAT_SESSION | Read/Write
//Description :
//Select the active tag detection.
//Possible values are (see ardrone_api.h) :
//• CAD_TYPE_NONE : No detections.
//• CAD_TYPE_MULTIPLE_DETECTION_MODE : See following note.
//• CAD_TYPE_ORIENTED_COCARDE_BW : Black&White oriented roundel detected on bottom facing cam-
//era.
//• CAD_TYPE_VISION_V2 : Standard tag detection (for both AR.Drone 2.0 and AR.Drone 1.0 ).
//
//Any other values are either deprecated or in development.
//Note : It is advised to enable the multiple detection mode, and then configure the detection needed using the
//following keys.
//Note : The multiple detection mode allow the selection of different detections on each camera. Note that you should
//NEVER enable two similar detection on both cameras, as this will cause failures in the algorithms.
//Note : The Black&White oriented roundel can be downloaded on Parrot website
//
//DETECT:detections_select_h
//CAT_SESSION | Read/Write
//Description :
//Bitfields to select detections that should be enabled on horizontal camera.
//Possible tags values are (see ardrone_api.h) :
//• TAG_TYPE_NONE : No tag to detect.
//• TAG_TYPE_SHELL_TAG_V2 : Standard hulls (both indoor and outdoor) tags, for both AR.Drone 2.0 and
//AR.Drone 1.0 .
//• TAG_TYPE_BLACK_ROUNDEL : Black&While oriented roundel.
//All other value are either deprecated or in development.
//Note : You should NEVER enable one detection on two different cameras.
//	
//DETECT:detections_select_v_hsync
//CAT_SESSION | Read/Write
//Description :
//Bitfileds to select the detections that should be enabled on vertical camera.
//Detection enables in the hsync mode will run synchronously with the horizontal camera pipeline, a 30fps instead
//of 60. This can be useful to reduce the CPU load when you don’t need a 60Hz detection.
//Note : You should use either v_hsync or v detections, but not both at the same time. This can cause unexpected
//behaviours.
//Note : Notes from DETECT:detections_select_h also applies.
//
//DETECT:detections_select_v
//CAT_SESSION | Read/Write
//Description :
//Bitfileds to select the detections that should be active on vertical camera.
//These detections will be run at 60Hz. If you don’t need that speed, using detections_select_v_hsync instead will
//reduce the CPU load.
//Note : See the DETECT:detections_select_h and DETECT:detections_select_v_hsync for further details.
//
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
//GPS:latitude
//CAT_SESSION | Read/Write
//Description :
//GPS Latitude sent by the controlling device.
//This data is used for media tagging and userbox recording.
//Note : value is a double precision floating point number, sent as a the binary equivalent 64bit integer on AT com-
//mand
//AT command example : AT*CONFIG=605,"gps:latitude","4631107791820423168"
//API use example :
//double gpsLatitude = 42.0;
//ARDRONE_TOOL_CONFIGURATION_ADDEVENT (latitude, &gpsLatitude, myCallback);
//
//GPS:longitude
//CAT_SESSION | Read/Write
//Description :
//GPS Longitude sent by the controlling device.
//This data is used for media tagging and userbox recording.
//Note : value is a double precision floating point number, sent as a the binary equivalent 64bit integer on AT com-
//mand
//AT command example : AT*CONFIG=605,"gps:longitude","4631107791820423168"
//API use example :
//double gpsLongitude = 42.0;
//ARDRONE_TOOL_CONFIGURATION_ADDEVENT (longitude, &gpsLongitude, myCallback);
//
//GPS:altitude
//CAT_SESSION | Read/Write
//Description :
//GPS Altitude sent by the controlling device.
//This data is used for media tagging and userbox recording.
//Note : value is a double precision floating point number, sent as a the binary equivalent 64bit integer on AT com-
//mand


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
