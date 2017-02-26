using concurrent::ActorPool
using concurrent::Actor

class Drone {

	private ActorPool		actorPool
	private NavDataReader	navDataReader
	private CmdSender		cmdSender
	
	const	DroneConfig		config
	
	
	
	new make(DroneConfig config := DroneConfig()) {
		this.actorPool		= ActorPool() { it.name = "Parrot Drone" }
		this.config			= config
		this.navDataReader	= NavDataReader(actorPool, config)
		this.cmdSender		= CmdSender(actorPool, config)
	}

	This connect() {
		cmdSender		:= cmdSender
		navDataReader	:= navDataReader

		// note - config cmds block?
		navDataReader.addListener |navData| {
			if (navData.state.controlCommandAck) {
				echo("contrl ack")
				cmdSender.send(Cmd.makeCtrl(5, 0))
			}

			if (navData.state.comWatchdogProblem) {
				echo("comms watch prov")
				cmdSender.send(Cmd.makeKeepAlive)
				
			}

//			if (navData.state.controlCommandAck)
//				cmdSender.ack
//			else
//				cmdSender.ackReset
		}
		
		cmdSender.connect
//		cmdSender.send(Cmd.makeCtrl(5, 0))
		navDataReader.connect

		cmdSender.send(Cmd.makeConfig("general:navdata_demo", "TRUE"))
		
		return this
	}
	
	This disconnect() {
		navDataReader.disconnect
		cmdSender.disconnect
		
//		Actor.sleep(50ms)
		actorPool.stop.join(1sec)
		return this
	}
	
	Void addNavDataListener(|NavData| f) {
		navDataReader.addListener(f)
	}
	
	Void removeNavDataListener(|NavData| f) {
		navDataReader.removeListener(f)
	}
	
	// ---- Commands ----
	
	Void flatTrim() {
		// TODO check flying state
		cmdSender.send(Cmd.makeFlatTrim)
	}

	Void takeOff() {
		cmdSender.send(Cmd.makeTakeOff)
	}

	Void land() {
		cmdSender.send(Cmd.makeLand)
	}
}
