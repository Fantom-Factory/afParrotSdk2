using concurrent::ActorPool
using concurrent::Future
using afConcurrent::Synchronized

** Repeatedly resends a Cmd until a timeout is reached. 
internal const class TimedLoop {
	const Drone				drone
	const Synchronized		mutex
	const Cmd?				cmd
	const Duration			duration
	const Duration			startTime
	const Future			future
	const Func				sendCmdFunc	:= #sendCmd.func.bind([this])	// cache the func, no need to make a new one each time
	
	new make(Drone drone, Duration duration, Cmd? cmd) {
		this.drone		= drone
		this.duration	= duration
		this.cmd		= cmd
		this.mutex		= Synchronized(drone.actorPool)
		this.startTime	= Duration.now
		this.future		= Future()
		
		sendCmd
	}
	
	private Void sendCmd() {
		// check if the user cancelled us
		if (future.state.isComplete) return

		// time's up = job done!
		if ((Duration.now - startTime) >= duration) {
			future.complete(null)
			return
		}
		// abandon manoeuvre if an emergency occurs!
		flags := drone.navData?.flags
		if (flags?.emergencyLanding == true || flags?.userEmergencyLanding == true || drone.state == FlightState.transLanding) {
			future.complete(null)
			return
		}
		
		if (cmd != null)
			drone.cmdSender.send(cmd)
		if (!drone.actorPool.isStopped)
			mutex.asyncLater(drone.config.cmdInterval, sendCmdFunc)
	}
}
