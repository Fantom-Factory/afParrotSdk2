using concurrent::ActorPool
using concurrent::Actor
using concurrent::AtomicBool
using concurrent::AtomicRef

const class Drone {
	private const	Log				log				:= Drone#.pod.log
	private	const	AtomicRef		navDataRef		:= AtomicRef(null)
	private	const	AtomicBool		crashOnExitRef	:= AtomicBool(true)

	internal const	CmdSender		cmdSender
	internal const	NavDataReader	navDataReader
	internal const	ActorPool		actorPool
	
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
	
	** Forces the drone to crash land on disconnect (or VM exit) should it still be flying.
	** It sets emergency mode which cuts off all engines.
	** 
	** Given your drone is flying autonomously, consider this a safety net to prevent it hovering 
	** in the ceiling when your program crashes! 
					Bool 			crashLandOnExit {
						get { crashOnExitRef.val }
						set { crashOnExitRef.val = it }
					}
	
	new make(DroneConfig config := DroneConfig()) {
		this.actorPool		= ActorPool() { it.name = "Parrot Drone" }
		this.config			= config
		this.navDataReader	= NavDataReader(actorPool, config)
		this.cmdSender		= CmdSender(actorPool, config)
		navDataRef			:= navDataRef
		Env.cur.addShutdownHook |->| { doCrashLandOnExit }
	}

	** Sets up the socket connections to the drone. 
	** Your device must already be connected to the drone's wifi hot spot.
	This connect() {
		navDataReader.addListener |navData| {
			oldNavData	:= (NavData?) navDataRef.val
			if (oldNavData?.demoData?.ctrlState != navData.demoData?.ctrlState)
				log.debug("STATE: ${oldNavData?.demoData?.ctrlState} --> ${navData.demoData?.ctrlState}")
			
			navDataRef.val = navData
			
			if (navData.state.controlCommandAck) {
				echo("contrl ack")
				cmdSender.send(Cmd.makeCtrl(5, 0))
			}

			if (navData.state.comWatchdogProblem)
				cmdSender.send(Cmd.makeKeepAlive)
		}
		
		cmdSender.connect
		navDataReader.connect

		// send me nav demo data please!
		cmdSender.send(Cmd.makeConfig("general:navdata_demo", "TRUE"))
		return this
	}
	
	This disconnect() {
		doCrashLandOnExit	// our safety net!

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
		if (state != CtrlState.landed) {
			log.warn("Can not take off when state is ${state}")
			return
		}
		if (block)
			DroneLoop.takeOff(this, timeout ?: config.loopTimeout)
		else
			cmdSender.send(Cmd.makeTakeOff)
	}

	Void land(Bool block := true, Duration? timeout := null) {
		if (state != CtrlState.flying && state != CtrlState.hovering) {
			log.warn("Can not land when state is ${state}")
			return
		}
		if (block)
			DroneLoop.land(this, timeout ?: config.loopTimeout)
		else
			cmdSender.send(Cmd.makeLand)
	}
	
	// ---- Private Stuff ----
	
	Void doCrashLandOnExit() {
		if (crashLandOnExit)
			if (navData?.state?.flying == true || (state != CtrlState.landed || state != CtrlState.def)) {
				log.warn("Exiting Program --> Crash landing Drone")
				crashLand
			}
	}
}
