
class DroneConfig {
	private const	Log				log					:= Drone#.pod.log

	private const Drone drone
	
	new make(Drone drone) {
		this.drone = drone
	}
	
	** Sets or clears config and profiles relating to indoor / outdoor flight.
	** See:
	**  - 'control:outdoor'
	**  - 'control:flight_without_shell'
	Void setOutdoorFlight(Bool outdoors := true) {
		drone.sendConfig("control:outdoor", outdoors)
		drone.sendConfig("control:flight_without_shell", outdoors)
	}

	** Tell the drone to calibrate its magnetometer.
	** 
	** The drone calibrates its magnetometer by spinning around itself a few times, hence can
	** only be performed when flying.
	** 
	** This method does not block.
	Void calibrate(Int deviceNum) {
		if (drone.state != FlightState.flying && drone.state != FlightState.hovering) {
			log.warn("Can not calibrate magnetometer when state is ${drone.state}")
			return
		}
		drone.sendCmd(Cmd.makeCalib(deviceNum))
	}
}
