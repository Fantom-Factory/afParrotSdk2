using concurrent::ActorPool
using concurrent::Actor
using concurrent::AtomicBool

class Drone {

	private ActorPool		actorPool
	private NavDataReader	navDataReader
	private CmdSender		cmdSender
	private AtomicBool		connectedRef	:= AtomicBool(false)
	
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
		connectedRef	:= connectedRef
		navDataReader.addListener |navData| {
			if (navData.state.controlCommandAck && connectedRef.val) {
				echo("contrl ack")
				cmdSender.send(Cmd.makeCtrl(5, 0))
			}

			if (navData.state.comWatchdogProblem && connectedRef.val)
				cmdSender.send(Cmd.makeKeepAlive)

//			if (navData.state.controlCommandAck)
//				cmdSender.ack
//			else
//				cmdSender.ackReset
		}
		
		cmdSender.connect
		navDataReader.connect

		// send me nav demo data please!
		cmdSender.send(Cmd.makeConfig("general:navdata_demo", "TRUE"))
		
		connectedRef.val = true
		return this
	}
	
	This disconnect() {
		// do this first so our listener knows when NOT to send cmds
		connectedRef.val = false
		navDataReader.disconnect
		cmdSender.disconnect
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
