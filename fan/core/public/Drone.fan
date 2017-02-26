using concurrent::ActorPool
using concurrent::Actor
using concurrent::AtomicBool
using concurrent::AtomicRef

class Drone {
	private Log				log				:= Drone#.pod.log
	private AtomicBool		connectedRef	:= AtomicBool(false)
	private	AtomicRef		navDataRef		:= AtomicRef(null)

	internal CmdSender		cmdSender
	internal NavDataReader	navDataReader
	internal ActorPool		actorPool
	
	** The configuration as passed to the ctor.
	const	DroneConfig		config
	
	** Returns a copy of the latest Nav Data.
	** 'null' if not connected.
			NavData?		navData {
				get { navDataRef.val }
				private set { }
			}
	
	** The current control (flying) state of the Drone.
			CtrlState?		state {
				get { navData?.demoData?.ctrlState }
				private set { }
			}
	
	new make(DroneConfig config := DroneConfig()) {
		this.actorPool		= ActorPool() { it.name = "Parrot Drone" }
		this.config			= config
		this.navDataReader	= NavDataReader(actorPool, config)
		this.cmdSender		= CmdSender(actorPool, config)
	}

	** Sets up the socket connections to the drone. 
	** Your device must already be connected to the drone's wifi hot spot.
	This connect() {
		cmdSender		:= cmdSender
		navDataReader	:= navDataReader
		connectedRef	:= connectedRef
		navDataRef		:= navDataRef
		navDataReader.addListener |navData| {
			oldNavData	:= (NavData?) navDataRef.val
			if (oldNavData?.demoData?.ctrlState != navData.demoData?.ctrlState)
				echo("STATE: ${oldNavData?.demoData?.ctrlState} --> ${navData.demoData?.ctrlState}")
			
			navDataRef.val = navData
			
			if (navData.state.controlCommandAck && connectedRef.val) {
				echo("contrl ack")
				cmdSender.send(Cmd.makeCtrl(5, 0))
			}

			if (navData.state.comWatchdogProblem && connectedRef.val)
				cmdSender.send(Cmd.makeKeepAlive)
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
	
	** Blocks until nav data is being received and all initiating commands have been acknowledged.
	Void waitUntilReady(Duration? timeout := null) {
		DroneLoop.waitUntilReady(this, timeout ?: config.loopTimeout)
	}
	
	Void clearEmergencyMode(Duration? timeout := null) {
		if (navData?.state?.emergencyLanding == true)
			DroneLoop.clearEmergencyMode(this, timeout ?: config.loopTimeout)
	}

	Void crashLand() {
		if (navData?.state?.emergencyLanding == false)
			cmdSender.send(Cmd.makeEmergency)
	}
	
	** Sets a horizontal plane reference for the drone's internal control system.
	** 
	** Call before each flight, while making sure the drone is sitting horizontally on the ground. 
	** Not doing so will result in the drone not being unstable.
	Void flatTrim() {
		if (state != CtrlState.def && state != CtrlState.init && state != CtrlState.landed) {
			log.warn("Can not Flat Trim when flying - ${state}")
			return
		}
		cmdSender.send(Cmd.makeFlatTrim)
	}

	Void takeOff(Bool block := true, Duration? timeout := null) {
//		if (state != CtrlState.landed) {
//			log.warn("Can not take off when state is ${state}")
//			return
//		}
		if (block)
			DroneLoop.takeOff(this, timeout ?: config.loopTimeout)
		else
			cmdSender.send(Cmd.makeTakeOff)
	}

	Void land(Bool block := true, Duration? timeout := null) {
//		if (state != CtrlState.flying && state != CtrlState.hovering) {
//			log.warn("Can not land when state is ${state}")
//			return
//		}
		if (block)
			DroneLoop.land(this, timeout ?: config.loopTimeout)
		else
			cmdSender.send(Cmd.makeLand)
	}
}
