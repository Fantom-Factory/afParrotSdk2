using concurrent::ActorPool
using concurrent::Actor
using concurrent::AtomicBool
using concurrent::AtomicRef

** The main interface to the Parrot AR Drone 2.0.
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
	** Returns 'null' if not connected.
					NavData?		navData {
						get { navDataRef.val }
						private set { }
					}
	
	** Returns the current control (flying) state of the Drone.
					CtrlState?		state {
						get { navData?.demoData?.ctrlState }
						private set { }
					}
	
	** A flag that forces the drone to crash land on disconnect (or VM exit) should it still be 
	** flying. It sets the emergency mode which cuts off all engines.
	** 
	** Given your drone is flying autonomously, consider this a safety net to prevent it hovering 
	** in the ceiling when your program crashes! 
					Bool 			crashLandOnExit {
						get { crashOnExitRef.val }
						set { crashOnExitRef.val = it }
					}
	
	** Creates a 'Drone' instance, optionally passing in default configuration.
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
	** 
	** This method blocks until nav data is being received and all initiating commands have been acknowledged.
	** 
	** If 'timeout' is 'null' it defaults to 'DroneConfig.defaultTimeout'.
	This connect(Duration? timeout := null) {
		navDataReader.addListener(#onNavData.func.bind([this]))
		
		cmdSender.connect
		navDataReader.connect

		// send me nav demo data please!
		cmdSender.send(Cmd.makeConfig("general:navdata_demo", "TRUE"))

		DroneLoop.waitUntilReady(this, timeout ?: config.defaultTimeout)
		return this
	}
	
	** Disconnects all comms to the drone. 
	** Performs the 'crashLandOnExit' strategy should the drone still be flying.
	**  
	** This method blocks until it's finished.
	This disconnect(Duration timeout := 2sec) {
		doCrashLandOnExit	// our safety net!

		navDataReader.disconnect
		cmdSender.disconnect
		actorPool.stop.join(timeout)
		return this
	}
	
	// TODO have onNavData listener class, like fwt
	Void addNavDataListener(|NavData| f) {
		navDataReader.addListener(f)
	}
	
	Void removeNavDataListener(|NavData| f) {
		navDataReader.removeListener(f)
	}
	
	// ---- Commands ----
	
	** (Advanced) Sends the given Cmd to the drone.
	@NoDoc
	Void sendCmd(Cmd cmd) {
		cmdSender.send(cmd)
	}
	
	** Blocks until the emergency mode flag has been cleared.
	** 
	** If 'timeout' is 'null' it defaults to 'DroneConfig.defaultTimeout'.
	Void clearEmergencyMode(Duration? timeout := null) {
		if (navData?.state?.emergencyLanding == true)
			DroneLoop.clearEmergencyMode(this, timeout ?: config.defaultTimeout)
	}

	** Sets or clears config and profiles relating to indoor / outdoor flight.
	** See:
	**  - 'control:outdoor'
	**  - 'control:flight_without_shell'
	Void setOutdoorFlight(Bool outdoors := true) {
		cmdSender.send(Cmd.makeConfig("control:outdoor", outdoors.toStr.upper))
		cmdSender.send(Cmd.makeConfig("control:flight_without_shell", outdoors.toStr.upper))
	}
	
	** Sends a emergency signal which cuts off the drone's motors, causing a crash landing.
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

	** Issues a take off command. 
	** If 'block' is 'true' then this blocks the thread until a stable hover has been achieved; 
	** which usually takes ~ 6 seconds.
	** 
	** If 'timeout' is 'null' it defaults to 'DroneConfig.defaultTimeout'.
	Void takeOff(Bool block := true, Duration? timeout := null) {
		if (state != CtrlState.landed) {
			log.warn("Can not take off when state is ${state}")
			return
		}
		if (block)
			DroneLoop.takeOff(this, timeout ?: config.defaultTimeout)
		else
			cmdSender.send(Cmd.makeTakeOff)
	}

	** Issues a land command. 
	** If 'block' is 'true' then this blocks the thread until the drone has landed.
	** 
	** If 'timeout' is 'null' it defaults to 'DroneConfig.defaultTimeout'.
	Void land(Bool block := true, Duration? timeout := null) {
		if (state != CtrlState.flying && state != CtrlState.hovering) {
			log.warn("Can not land when state is ${state}")
			return
		}
		if (block)
			DroneLoop.land(this, timeout ?: config.defaultTimeout)
		else
			cmdSender.send(Cmd.makeLand)
	}
	
	** Tell the drone to calibrate its magnetometer.
	** 
	** The drone calibrates its magnetometer by spinning around itself a few times, hence can
	** only be performed when flying.
	** 
	** Does not block.
	Void calibrate(Int deviceNum) {
		if (state != CtrlState.flying && state != CtrlState.hovering) {
			log.warn("Can not calibrate magnetometer when state is ${state}")
			return
		}
		cmdSender.send(Cmd.makeCalib(deviceNum))
	}

	** Plays one of the pre-configured LED animation sequences. Example:
	** 
	**   syntax: fantom
	**   drone.animateLeds(LedAnimation.snakeRed, 2f, 3sec)
	** 
	** Corresponds to the 'leds:leds_anim' config cmd.
	Void animateLeds(LedAnimation anim, Float hz, Duration duration) {
		params := [anim.ordinal, hz.bits32, duration.toSec].join(",")
		cmdSender.send(Cmd.makeConfig("leds:leds_anim", params))
	}

	** Performs one of the pre-configured flight sequences.
	** 
	**   syntax: fantom
	**   drone.animateFlight(FlightAnimation.phiDance, 5sec)
	** 
	** Corresponds to the 'control:flight_anim' config cmd.
	Void animateFlight(FlightAnimation anim, Duration duration) {
		params := [anim.ordinal, duration.toSec].join(",")
		cmdSender.send(Cmd.makeConfig("control:flight_anim", params))
	}

	** Sends a config cmd to the drone.
	Void configCmd(Str key, Str val) {
		cmdSender.send(Cmd.makeConfig(key, val))
	}

//	['up', 'down'],
//	['left', 'right'],
//	['front', 'back'],
//	['clockwise', 'counterClockwise'],
//
//	Void stop()
	
	// ---- Private Stuff ----
	
	private Void onNavData(NavData navData) {
		oldNavData	:= (NavData?) navDataRef.val
		
		// TODO send event on state change
		if (oldNavData?.demoData?.ctrlState != navData.demoData?.ctrlState)
			log.debug("STATE: ${oldNavData?.demoData?.ctrlState} --> ${navData.demoData?.ctrlState}")
		
		// TODO send event on Battery Percent change - beware navData with NO demo data = false null alerts - update options
		if (oldNavData?.demoData?.batteryPercentage != navData.demoData?.batteryPercentage)
			log.debug("Battery now at ${navData.demoData?.batteryPercentage}%")
		
		
		navDataRef.val = navData
		
		if (navData.state.controlCommandAck)
			cmdSender.send(Cmd.makeCtrl(5, 0))

		if (navData.state.comWatchdogProblem)
			cmdSender.send(Cmd.makeKeepAlive)

		// TODO send event on Emergency landing flag
		if (navData.state.emergencyLanding && navData.state.flying)
			// only print the first time - check for change
			log.warn("   !!! EMERGENCY LANDING !!!   ")

		// TODO send event on Low Battery flag
		if (navData.state.batteryTooLow)
			log.warn("   !!! Battery Level Too Low !!!")
	}
	
	private Void doCrashLandOnExit() {
		if (crashLandOnExit)
			if (navData?.state?.flying == true || (state != CtrlState.landed && state != CtrlState.def)) {
				log.warn("Exiting Program --> Crash landing Drone")
				crashLand
			}
	}
}

** Pre-configured LED animation sequences.
enum class LedAnimation {
	blinkGreenRed, blinkGreen, blinkRed, blinkOrange, snakeGreenRed, fire, standard, red, green, snakeRed, blank, rightMissile, leftMissile, doubleMissile, frontLeftGreenOthersRed, frontRightGreenOthersRed, rearRightGreenOthersRed, rearLeftGreenOthersRed, leftGreenRightRed, leftRedRightGreen, blinkStandard;
}

** Pre-configured flight paths.
enum class FlightAnimation {
	phiM30Deg, phi30Deg, thetaM30Deg, theta30Deg, theta20degYaw200deg, theta20degYawM200deg, turnaround, turnaroundGodown, yawShake, yawDance, phiDance, thetaDance, vzDance, wave, phiThetaMixed, doublePhiThetaMixed, flipAhead, flipBehind, flipLeft, flipRight;
}
