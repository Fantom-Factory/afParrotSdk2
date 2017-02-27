using concurrent::ActorPool
using concurrent::Future
using afConcurrent::Synchronized

** Repeatedly resends a Cmd until a timeout is reached. 
internal const class TimedLoop {
	const Drone				drone
	const Synchronized		mutex
	const Cmd				cmd
	const Duration			duration
	const Duration			startTime
	const Future			future
	
	new make(Drone drone, Duration duration, Cmd? cmd) {
		this.drone		= drone
		this.duration	= duration
		this.cmd		= cmd
		this.mutex		= Synchronized(drone.actorPool)
		this.startTime	= Duration.now
		this.future		= Future()
		
		sendCmd
	}
	
	private static Future startLoop(Drone drone, Duration duration, Cmd? cmd) {
		TimedLoop(drone, duration, cmd).future
	}
	
	private Void sendCmd() {
		// abandon manoeuvre if an emergency occurs!
		if ((Duration.now - startTime) >= duration || drone.navData?.flags?.emergencyLanding == true) {
			future.complete(null)
		} else {
			drone.cmdSender.send(cmd)
			if (!drone.actorPool.isStopped)
				mutex.asyncLater(drone.config.cmdInterval, #sendCmd.func.bind([this]))
		}
	}
}
