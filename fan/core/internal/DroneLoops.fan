using concurrent::ActorPool
using concurrent::Future
using afConcurrent::Synchronized

** Blocks, and optionally resends a Cmd, until certain conditions in nav data have been met. 
internal const class DroneLoop {
	const NavDataReader 	reader
	const CmdSender			sender
	const Func				listener
	const Future			future
	const |NavData->Bool|	process
	const Synchronized		mutex
	const Cmd				cmd
	
	new make(Drone drone, |NavData?->Bool| process, Cmd? cmd) {
		this.reader		= drone.navDataReader
		this.sender		= drone.cmdSender
		this.listener	= #onNavData.func.bind([this])
		this.future		= Future()
		this.process	= process
		this.cmd		= cmd
		this.mutex		= Synchronized(drone.actorPool)
		reader.addListener(listener)
		
		if (process(drone.navData))
			future.complete(null)

		sendCmd
	}
	
	static Void waitUntilReady(Drone drone, Duration timeout) {
		blockAndLog(drone, timeout, |NavData? navData->Bool| {
			navData?.demoData != null && navData?.state?.controlCommandAck == false
		}, Cmd.makeCtrl(5, 0), "Drone ready")
	}
	
	static Void clearEmergencyMode(Drone drone, Duration timeout) {
		blockAndLog(drone, timeout, |NavData? navData->Bool| {
			navData?.state?.emergencyLanding == false
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
		DroneLoop(drone, process, cmd).future.get(timeout)
		t.finish(msg)
	}
	
	private Void sendCmd() {
		if (!future.state.isComplete) {
			sender.send(cmd)
			mutex.asyncLater(30ms, #sendCmd.func.bind([this]))
		}
	}
	
	private Void onNavData(NavData navData) {
		if (process(navData)) {
			reader.removeListener(listener)
			future.complete(null)
		}
	}
}

