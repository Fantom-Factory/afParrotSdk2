using concurrent::ActorPool
using concurrent::Future
using afConcurrent::Synchronized

** Blocks, and optionally resends a Cmd, until certain conditions in nav data have been met. 
internal const class NavDataLoop {
	const Drone				drone
	const Func				listener
	const Future			future
	const |NavData?->Bool|	process
	const Synchronized		thread
	const Cmd?				cmd
	const Func				sendCmdFunc	:= #sendCmd.func.bind([this])	// cache the func, no need to make a new one each time
	const Bool				completeOnEmergency
	
	new make(Drone drone, |NavData?->Bool| process, Cmd? cmd, Bool completeOnEmergency) {
		this.drone		= drone
		this.listener	= #onNavData.func.bind([this])
		this.future		= Future()
		this.process	= process
		this.cmd		= cmd
		this.thread		= Synchronized(drone.actorPool)
		this.completeOnEmergency = completeOnEmergency
		drone.navDataReader.addListener(listener)
		
		// there are 2 loops here; 1 called by onNavData, the other is an interval loop calling sendCmd
		onNavData(drone.navData)
		sendCmd
	}
	
	
	
	// ---- Stabilising Commands ----
	
	static Void takeOff(Drone drone, Bool block, Duration timeout) {
		blockAndLog(drone, timeout, |NavData? navData->Bool| {
			state := navData?.demoData?.flightState
			// stop taking off if we start landing -> landing takes precedence!
			return state == FlightState.flying || state == FlightState.hovering || state == FlightState.transLanding
		}, Cmd.makeTakeOff, "Drone took off", block, true, "Timed out waiting for drone to take off")
	}
	
	static Void land(Drone drone, Bool block, Duration timeout) {
		blockAndLog(drone, timeout, |NavData? navData->Bool| {
			navData?.demoData?.flightState == FlightState.landed
		}, Cmd.makeLand, "Drone landed", block, true, "Timed out waiting for drone to land")
	}
	
	static Void hover(Drone drone, Bool block, Duration timeout) {
		blockAndLog(drone, timeout, |NavData? navData->Bool| {
			navData?.demoData?.flightState == FlightState.hovering
		}, Cmd.makeHover, "Drone hovering", block, true, "Timed out waiting for drone to hover")
	}
	
	
	
	// ---- Misc Commands ----
	
	static Void waitUntilReady(Drone drone, Duration timeout) {
		blockAndLog(drone, timeout, |NavData? navData->Bool| {
			flags := navData?.flags
			return navData?.demoData != null && flags?.controlCommandAck == false && flags?.emergencyLanding == false && flags?.userEmergencyLanding == false
		}, null, "Drone ready", true, false, "Timed out waiting for initial demo data")
	}
	
	static Void clearEmergencyMode(Drone drone, Duration timeout) {
		blockAndLog(drone, timeout, |NavData? navData->Bool| {
			navData?.flags?.emergencyLanding == false
		}, Cmd.makeEmergency, "Emergency Mode cleared", true, false, "Timed out waiting for emergency flag to clear")
	}
	
	static Void waitForAck(Drone drone, Duration timeout, Bool block) {
		blockAndLog(drone, timeout, |NavData? navData->Bool| {
			navData?.flags?.controlCommandAck == true
		}, null, "", block, false, "Timed out waiting for a Config Cmd Ack")
	}
	
	static Void waitForAckClear(Drone drone, Duration timeout, Bool block) {
		blockAndLog(drone, timeout, |NavData? navData->Bool| {
			navData?.flags?.controlCommandAck == false
		}, Cmd.makeCtrl(5, 0), "", block, false, "Timed out waiting for Config Cmd Ack flag to clear")
	}
	
	
	
	// ---- Private Stuff ----
	
	private static Void blockAndLog(Drone drone, Duration timeout, |NavData?->Bool| process, Cmd? cmd, Str msg, Bool block, Bool completeOnEmergency, Str timeoutErrMsg) {
		Timer.time(msg) |->| {
			future := null as Future
			try {
				future = NavDataLoop(drone, process, cmd, completeOnEmergency).future
				if (block)
					future.get(timeout)
			}
			catch (TimeoutErr err) {
				// complete the future to prevent the sendCmd() from sending stuff  
				future.completeErr(err)
				
				// Suppress TimeoutErr if drone has since disconnected
				if (drone.navData?.flags?.batteryTooLow == true || drone.actorPool.isStopped)
					return
				throw TimeoutErr(timeoutErrMsg)
			}
		}
	}
	
	private Void onNavData(NavData? navData) {
		if (process(navData) || (completeOnEmergency && drone.navData?.flags?.emergencyLanding == true)) {
			drone.navDataReader.removeListener(listener)
			future.complete(null)
		}
	}
	
	private Void sendCmd() {
		if (future.state.isComplete || drone.actorPool.isStopped)
			return
		if (cmd != null)
			drone.cmdSender.send(cmd)
		thread.asyncLater(drone.config.cmdInterval, sendCmdFunc)
	}
}

