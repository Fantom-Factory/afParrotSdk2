//using afParrotSdk2
using concurrent

class SimpleExample {
	Void main() {
		Drone#.pod.log.level = LogLevel.debug

		drone := Drone().connect
		drone.clearEmergency

		drone.config.session("afSquawk")
		drone.config.session.videoCamera = VideoCamera.horizontal
		drone.config.session.videoResolution = VideoResolution._720p
		
		streamer := VideoStreamer.toMp4File(`vid.mp4`).attachTo(drone)
		Actor.sleep(5sec)

		
		drone.takeOff
//		drone.animateFlight(FlightAnimation.vzDance)
		drone.animateFlight(FlightAnimation.flipBackward)		
		Actor.sleep(2sec)
		drone.land
		
		Actor.sleep(2sec)
		streamer.detach

		Actor.sleep(2sec)
		drone.disconnect
	}
}
