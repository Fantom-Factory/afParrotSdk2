using concurrent::ActorPool
using concurrent::Future
using afConcurrent::Synchronized

** Repeatedly resends a Cmd until a timeout is reached. 
internal const class TimedLoop {
	const DroneConfig		config
	const CmdSender			sender
	const Synchronized		mutex
	const Cmd				cmd
	const Duration			duration
	const Duration			startTime
	const Future			future
	
	new make(Drone drone, Duration duration, Cmd? cmd) {
		this.config		= drone.config
		this.sender		= drone.cmdSender
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
		// FIXME abandon if emergengy!
		if ((Duration.now - startTime) < duration) {
			sender.send(cmd)
			mutex.asyncLater(config.cmdInterval, #sendCmd.func.bind([this]))
		} else 
			future.complete(null)
	}
}

