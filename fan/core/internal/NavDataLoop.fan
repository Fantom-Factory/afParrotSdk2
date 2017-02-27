using concurrent::ActorPool
using concurrent::Future
using afConcurrent::Synchronized

** Blocks, and optionally resends a Cmd, until certain conditions in nav data have been met. 
internal const class NavDataLoop {
	const Drone				drone
	const Func				listener
	const Future			future
	const |NavData?->Bool|	process
	const Synchronized		mutex
	const Cmd				cmd
	
	new make(Drone drone, |NavData?->Bool| process, Cmd? cmd) {
		this.drone		= drone
		this.listener	= #onNavData.func.bind([this])
		this.future		= Future()
		this.process	= process
		this.cmd		= cmd
		this.mutex		= Synchronized(drone.actorPool)
		drone.navDataReader.addListener(listener)
		
		onNavData(drone.navData)
		sendCmd
	}
	
	static Void waitUntilReady(Drone drone, Duration timeout) {
		blockAndLog(drone, timeout, |NavData? navData->Bool| {
			navData?.demoData != null && navData?.flags?.controlCommandAck == false
		}, Cmd.makeCtrl(5, 0), "Drone ready")
	}
	
	static Void clearEmergencyMode(Drone drone, Duration timeout) {
		blockAndLog(drone, timeout, |NavData? navData->Bool| {
			navData?.flags?.emergencyLanding == false
		}, Cmd.makeEmergency, "Emergency Mode cleared")
	}
	
	static Void takeOff(Drone drone, Duration timeout) {
		blockAndLog(drone, timeout, |NavData? navData->Bool| {
			navData?.demoData?.ctrlState == CtrlState.flying || navData?.demoData?.ctrlState == CtrlState.hovering
		}, Cmd.makeTakeOff, "Drone took off")
	}
	
	static Void land(Drone drone, Duration timeout) {
		blockAndLog(drone, timeout, |NavData? navData->Bool| {
			navData?.demoData?.ctrlState == CtrlState.landed
		}, Cmd.makeLand, "Drone landed")
	}
	
	private static Void blockAndLog(Drone drone, Duration timeout, |NavData?->Bool| process, Cmd? cmd, Str msg) {
		t := Timer()
		try	{
			NavDataLoop(drone, process, cmd).future.get(timeout)
			t.finish(msg)
		}
		catch (TimeoutErr err)
			// Suppress TimeoutErr if drone has since disconnected
			if ((drone.navData?.flags?.batteryTooLow == true || drone.actorPool.isStopped).not) throw err
	}
	
	private Void sendCmd() {
		if (!future.state.isComplete) {
			drone.cmdSender.send(cmd)
			mutex.asyncLater(drone.config.cmdInterval, #sendCmd.func.bind([this]))
		}
	}
	
	private Void onNavData(NavData? navData) {
		if (process(navData)) {
			drone.navDataReader.removeListener(listener)
			future.complete(null)
		}
	}
}

