using concurrent::ActorPool
using concurrent::Actor
using concurrent::AtomicBool
using concurrent::AtomicRef
using afConcurrent::Synchronized

** The main interface to the Parrot AR Drone 2.0.
** 
** Once the drone has been disconnected, this class instance can not be re-connected. 
** Instead create a new 'Drone' instance.
const class Drone {
	private const	Log				log					:= Drone#.pod.log
	private	const	AtomicRef		navDataRef			:= AtomicRef()
	private	const	AtomicBool		crashOnExitRef		:= AtomicBool(true)
	private	const	AtomicRef		onNavDataRef		:= AtomicRef()
	private	const	AtomicRef		onStateChangeRef	:= AtomicRef()
	private	const	AtomicRef		onBatterDrainRef	:= AtomicRef()
	private	const	AtomicRef		onEmergencyRef		:= AtomicRef()
	private	const	AtomicRef		onBatteryLowRef		:= AtomicRef()
	private	const	Synchronized	eventThread

	internal const	CmdSender		cmdSender
	internal const	NavDataReader	navDataReader
	internal const	ActorPool		actorPool
	
	** The configuration as passed to the ctor.
			const	DroneConfig		config
	
	** Returns the latest Nav Data or 'null' if not connected.
	** Note that this instance always contains a culmination of all the latest nav options received.
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
	
	** Event hook that's notified when the drone sends new NavData.
	** Expect the function to be called many times a second.
	** 
	** The nav data is raw from the drone so does **not** contain a culmination of all option data.
	** Note 'Drone.navData' is updated with the new contents before the hook is called.
	** 
	** Throws 'NotImmutableErr' if the function is not immutable.
					|NavData, Drone|?		onNavData {
						get { onNavDataRef.val }
						set { onNavDataRef.val = it}
					}

	** Event hook that's called when the drone's state is changed.
	** 
	** Throws 'NotImmutableErr' if the function is not immutable.
	** 
	** Note this hook is called from a different Actor / thread to the one that sets it. 
					|CtrlState state, Drone|? onStateChange {
						get { onStateChangeRef.val }
						set { onStateChangeRef.val = it}
					}

	** Event hook that's called when the drone's battery loses a percentage of charge.
	** The function is called with the new battery percentage level (0 - 100).
	** 
	** Throws 'NotImmutableErr' if the function is not immutable.
	** 
	** Note this hook is called from a different Actor / thread to the one that sets it. 
					|Int newPercentage, Drone|? onBatteryDrain {
						get { onBatterDrainRef.val }
						set { onBatterDrainRef.val = it}
					}

	** Event hook that's called when the drone enters emergency mode.
	** When this happens, the engines are cut and the drone will not respond to commands until 
	** emergency mode is cleared.
	** 
	** Note this hook is only called when the drone is flying.
	** 
	** Throws 'NotImmutableErr' if the function is not immutable.
	** 
	** Note this hook is called from a different Actor / thread to the one that sets it. 
					|Drone|?	onEmergency {
						get { onEmergencyRef.val }
						set { onEmergencyRef.val = it}
					}

	** Event hook that's called when the drone's battery reaches a critical level.
	** 
	** Throws 'NotImmutableErr' if the function is not immutable.
	** 
	** Note this hook is called from a different Actor / thread to the one that sets it. 
					|Drone|?	onBatteryLow {
						get { onBatteryLowRef.val }
						set { onBatteryLowRef.val = it}
					}

	** Creates a 'Drone' instance, optionally passing in default configuration.
	new make(DroneConfig config := DroneConfig()) {
		this.actorPool		= ActorPool() { it.name = "Parrot Drone" }
		this.config			= config
		this.navDataReader	= NavDataReader(actorPool, config)
		this.cmdSender		= CmdSender(actorPool, config)
		this.eventThread	= Synchronized(actorPool)
		Env.cur.addShutdownHook |->| { doCrashLandOnExit }
	}

	** Sets up the socket connections to the drone. 
	** Your device must already be connected to the drone's wifi hot spot.
	** 
	** This method blocks until nav data is being received and all initiating commands have been acknowledged.
	** 
	** If 'timeout' is 'null' it defaults to 'DroneConfig.defaultTimeout'.
	This connect(Duration? timeout := null) {
		// we could re-use if we didn't stop the actor pool...?
		// but nah, we created it, we should destroy it
		if (actorPool.isStopped)
			throw Err("Can not re-use Drone() instances")

		navDataReader.addListener(#processNavData.func.bind([this]))
		
		cmdSender.connect
		navDataReader.connect

		// send me nav demo data please!
		cmdSender.send(Cmd.makeConfig("general:navdata_demo", "TRUE"))

		NavDataLoop.waitUntilReady(this, timeout ?: config.defaultTimeout)
		log.info("Connected to AR Drone 2.0")
		return this
	}
	
	** Disconnects all comms to the drone. 
	** Performs the 'crashLandOnExit' strategy should the drone still be flying.
	**  
	** This method blocks until it's finished.
	This disconnect(Duration timeout := 2sec) {
		if (actorPool.isStopped) return this
		
		doCrashLandOnExit	// our safety net!

		navDataReader.disconnect
		cmdSender.disconnect
		actorPool.stop.join(timeout)
		log.info("Disonnected from Drone")
		return this
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
		if (navData?.flags?.emergencyLanding == true)
			NavDataLoop.clearEmergencyMode(this, timeout ?: config.defaultTimeout)
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
		if (navData?.flags?.emergencyLanding == false)
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
			NavDataLoop.takeOff(this, timeout ?: config.defaultTimeout)
		else
			cmdSender.send(Cmd.makeTakeOff)
	}

	** Issues a land command. 
	** If 'block' is 'true' then this blocks the thread until the drone has landed.
	** 
	** If 'timeout' is 'null' it defaults to 'DroneConfig.defaultTimeout'.
	Void land(Bool block := true, Duration? timeout := null) {
		// let's not second guess what state the drone is in
		// if they wanna land the drone, send the gawd damn land cmd!
//		if (state != CtrlState.flying && state != CtrlState.hovering) {
//			log.warn("Can not land when state is ${state}")
//			return
//		}
		if (block)
			NavDataLoop.land(this, timeout ?: config.defaultTimeout)
		else
			cmdSender.send(Cmd.makeLand)
	}
	
	** Tell the drone to calibrate its magnetometer.
	** 
	** The drone calibrates its magnetometer by spinning around itself a few times, hence can
	** only be performed when flying.
	** 
	** This method does not block.
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
	** 
	** This method does not block.
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
	** 
	** This method does not block.
	Void animateFlight(FlightAnimation anim, Duration duration) {
		params := [anim.ordinal, duration.toSec].join(",")
		cmdSender.send(Cmd.makeConfig("control:flight_anim", params))
	}

	** Sends a config cmd to the drone.
	Void configCmd(Str key, Str val) {
		cmdSender.send(Cmd.makeConfig(key, val))
	}

	// FIXME movement cmds
	
	** If a duration is given, then by default this method will block
//	Void moveUp(Float val, Duration? duration := null, Bool? block := true) {
//	}
//	
//	Void moveDown() {
//	}
//	
//	Void moveLeft() {
//	}
//
//	Void moveRight() {
//	}
//	
//	Void moveForward() {
//	}
//
//	Void moveBackward() {
//	}
	
	Void spinClockwise(Float angularSpeed, Duration? duration := null, Bool? block := true) {
		// TODO check val 0-1
		cmd := Cmd.makeMove(0f, 0f, 0f, angularSpeed)
		
		if (duration != null) {
			future := TimedLoop(this, duration, cmd).future
			if (block) future.get
		} else
			cmdSender.send(cmd)
	}
	
	Void spinAnticlockwise() {
	}
	
	Void stop() {
		cmdSender.send(Cmd.makeHover)
	}	
	
	// ---- Private Stuff ----
	
	private Void processNavData(NavData navData) {
		if (actorPool.isStopped) return

		oldNavData	:= (NavData?) navDataRef.val
		
		// we don't need a mutex 'cos we're only ever called from the single-threaded NavDataReader actor
		newOpts := oldNavData?.options?.rw ?: NavOption:Obj[:]
		newOpts.setAll(navData.options)
		newNav := NavData {
			it.flags		= navData.flags
			it.seqNum		= navData.seqNum
			it.visionFlag	= navData.visionFlag
			it.options		= newOpts
		}
		navDataRef.val = newNav
		
		// ---- perform standard feedback ----
		
		if (navData.flags.controlCommandAck)
			cmdSender.send(Cmd.makeCtrl(5, 0))

		if (navData.flags.comWatchdogProblem)
			cmdSender.send(Cmd.makeKeepAlive)

		// ---- call event handlers ----
		
		// call handlers from a different thread so they don't block the NavDataReader
		eventThread.async |->| {
			callSafe(onNavData, [navData, this])
			
			if (navData.flags.emergencyLanding && oldNavData?.flags?.emergencyLanding != true && oldNavData?.flags?.flying == true)
				callSafe(onEmergency, [this])
	
			if (navData.flags.batteryTooLow && oldNavData?.flags?.batteryTooLow != true )
				callSafe(onBatteryLow, [this])
			
			demoData := navData.demoData
			if (demoData != null) {
				if (demoData.ctrlState != oldNavData?.demoData?.ctrlState)
					callSafe(onStateChange, [demoData.ctrlState, this])
			
				if (oldNavData?.demoData?.batteryPercentage == null || demoData.batteryPercentage < oldNavData.demoData.batteryPercentage)
					callSafe(onBatteryDrain, [demoData.batteryPercentage, this])
			}
		}
	}
	
	private Void callSafe(Func? f, Obj[]? args) {
		try f?.callList(args)
		catch (Err err)
			err.trace
	}
	
	private Void doCrashLandOnExit() {
		if (crashLandOnExit)
			if (navData?.flags?.flying == true || (state != CtrlState.landed && state != CtrlState.def)) {
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
