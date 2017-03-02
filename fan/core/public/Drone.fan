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
	private	const	AtomicRef		exitStrategyRef		:= AtomicRef(ExitStrategy.land)
	private	const	AtomicRef		onNavDataRef		:= AtomicRef()
	private	const	AtomicRef		onStateChangeRef	:= AtomicRef()
	private	const	AtomicRef		onBatterDrainRef	:= AtomicRef()
	private	const	AtomicRef		onEmergencyRef		:= AtomicRef()
	private	const	AtomicRef		onBatteryLowRef		:= AtomicRef()
	private	const	AtomicRef		onDisconnectRef		:= AtomicRef()
	private	const	AtomicRef		droneVersionRef		:= AtomicRef()
	private	const	Synchronized	eventThread
	private	const	|->|			shutdownHook

	internal const	CmdSender		cmdSender
	internal const	NavDataReader	navDataReader
	internal const	ControlReader	controlReader
	internal const	ActorPool		actorPool
	
	** The version of the drone, as reported by an FTP of 'version.txt'.
					Version?		droneVersion {
						get { droneVersionRef.val }
						private set { droneVersionRef.val = it }
					}
	
	** The network configuration as passed to the ctor.
			const	NetworkConfig		config
	
	** Returns the latest Nav Data or 'null' if not connected.
	** Note that this instance always contains a culmination of all the latest nav options received.
					NavData?		navData {
						get { navDataRef.val }
						private set { navDataRef.val = it }
					}
	
	** Returns the current flight state of the Drone.
					FlightState?	state {
						get { navData?.demoData?.flightState }
						private set { }
					}
	
	** Should this 'Drone' class instance disconnect from the drone whilst it is flying (or the VM 
	** otherwise exits) then this strategy governs what last commands should be sent to the drone 
	** before it exits.
	** 
	** (It's a useful feature I wish I'd implemented before the time my program crashed and I 
	** watched my drone sail up, up, and away, over the tree line!)
	** 
	** Defaults to 'land'.
	** 
	** Note this can not guard against a forced process kill or a 'kill -9' command. 
					ExitStrategy 	exitStrategy {
						get { exitStrategyRef.val }
						set { exitStrategyRef.val = it }
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
					|FlightState state, Drone|? onStateChange {
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

	** Event hook that's called when the drone's battery reaches a critical level ~ 20%.
	** 
	** Throws 'NotImmutableErr' if the function is not immutable.
	** 
	** Note this hook is called from a different Actor / thread to the one that sets it. 
					|Drone|?	onBatteryLow {
						get { onBatteryLowRef.val }
						set { onBatteryLowRef.val = it}
					}

	** Event hook that's called when the drone is disconnected.
	** The 'abnormal' boolean is set to 'true' if the drone is disconnected due to a communication 
	** / socket error. This may happen if the battery drains too low or the drone is switched off.
	** 
	** Throws 'NotImmutableErr' if the function is not immutable.
	** 
	** Note this hook is called from a different Actor / thread to the one that sets it. 
					|Bool abnormal, Drone|? onDisconnect {
						get { onDisconnectRef.val }
						set { onDisconnectRef.val = it}
					}

	** Creates a 'Drone' instance, optionally passing in network configuration.
	new make(NetworkConfig config := NetworkConfig()) {
		this.actorPool		= ActorPool() { it.name = "Parrot Drone" }
		this.config			= config
		this.navDataReader	= NavDataReader(this, actorPool, config)
		this.controlReader	= ControlReader(this)
		this.cmdSender		= CmdSender(this, actorPool, config)
		this.eventThread	= Synchronized(actorPool)
		this.shutdownHook	= #onShutdown.func.bind([this])
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

		// send me nav data please!
		cmdSender.send(Cmd.makeConfig("general:navdata_demo", "TRUE"))
		if (actorPool.isStopped)
			throw IOErr("Drone Connection Error")
		
		NavDataLoop.waitForAck		(this, config.configCmdAckTimeout, true)
		NavDataLoop.waitForAckClear	(this, config.configCmdAckClearTimeout, true)
		NavDataLoop.waitUntilReady	(this, timeout ?: config.actionTimeout)

		try droneVersion = BareBonesFtp().readVersion(config)
		catch (Err err)
			log.warn("Could not FTP version.txt from drone", err)

		// TODO grab some control config!

		Env.cur.addShutdownHook(shutdownHook)

		log.info("Connected to AR Drone ${droneVersion}")
		return this
	}
	
	** Disconnects all comms to the drone. 
	** Performs the 'crashLandOnExit' strategy should the drone still be flying.
	**  
	** This method blocks until it's finished.
	This disconnect(Duration timeout := 2sec) {
		doDisconnect(false, timeout)
	}
	
	
	
	// ---- Misc Commands ----
	
	** (Advanced) Sends the given Cmd to the drone.
	** 
	** This method does not block.
	@NoDoc
	Void sendCmd(Cmd cmd) {
		cmdSender.send(cmd)
	}
	
	** Sends a config cmd to the drone, and blocks until it's been acknowledged.
	** 
	** 'val' may be a Bool, Int, Float, Str, or a List of said types. 
	Void sendConfig(Str key, Obj val) {
		if (val is List)
			val = ((List) val).join(",") { encodeConfigParam(it) }
		val = encodeConfigParam(val)
		
		block := true
		NavDataLoop.waitForAckClear	(this, config.configCmdAckClearTimeout, block)
		cmdSender.send(Cmd.makeConfig(key, val))
		NavDataLoop.waitForAck		(this, config.configCmdAckTimeout, block)
		NavDataLoop.waitForAckClear	(this, config.configCmdAckClearTimeout, block)
	}

	Void setEmergencyMode() {
		// TODO
	}

	** Blocks until the emergency mode flag has been cleared.
	** 
	** If 'timeout' is 'null' it defaults to 'DroneConfig.configCmdAckTimeout'.
	Void clearEmergencyMode(Duration? timeout := null) {
		flags := navData?.flags
		if (flags?.emergencyLanding == true || flags?.userEmergencyLanding == true)
			NavDataLoop.clearEmergencyMode(this, timeout ?: config.configCmdAckTimeout)
	}

	// TODO move to DroneConfig class
//	** Sets or clears config and profiles relating to indoor / outdoor flight.
//	** See:
//	**  - 'control:outdoor'
//	**  - 'control:flight_without_shell'
//	Void setOutdoorFlight(Bool outdoors := true) {
//		sendConfig("control:outdoor", outdoors)
//		sendConfig("control:flight_without_shell", outdoors)
//	}
	
	** Sends a emergency signal which cuts off the drone's motors, causing a crash landing.
	** 
	** This method does not block.
	Void crashLand() {
		if (navData?.flags?.emergencyLanding == false)
			cmdSender.send(Cmd.makeEmergency)
	}
	
	** Sets a horizontal plane reference for the drone's internal control system.
	** 
	** Call before each flight, while making sure the drone is sitting horizontally on the ground. 
	** Not doing so will result in the drone not being unstable.
	** 
	** This method does not block.
	Void flatTrim() {
		if (state != FlightState.def && state != FlightState.init && state != FlightState.landed) {
			log.warn("Can not flat trim when state is ${state}")
			return
		}
		cmdSender.send(Cmd.makeFlatTrim)
	}

	** Tell the drone to calibrate its magnetometer.
	** 
	** The drone calibrates its magnetometer by spinning around itself a few times, hence can
	** only be performed when flying.
	** 
	** This method does not block.
	Void calibrate(Int deviceNum) {
		if (state != FlightState.flying && state != FlightState.hovering) {
			log.warn("Can not calibrate magnetometer when state is ${state}")
			return
		}
		cmdSender.send(Cmd.makeCalib(deviceNum))
	}

	** Plays one of the pre-configured LED animation sequences. Example:
	** 
	**   syntax: fantom
	**   drone.animateLeds(LedAnimation.snakeRed, 3sec)
	** 
	** If 'freqInHz' is 'null' then the default frequency of the enum is used.
	** 
	** Corresponds to the 'leds:leds_anim' config cmd.
	** 
	** This method does not block.
	Void animateLeds(LedAnimation anim, Duration duration, Float? freqInHz := null) {
		params := [anim.ordinal, (freqInHz ?: anim.defaultFrequency), duration.toSec]
		sendConfig("leds:leds_anim", params)
	}

	** Performs one of the pre-configured flight sequences.
	** 
	**   syntax: fantom
	**   drone.animateFlight(FlightAnimation.phiDance)
	** 
	** If duration is 'null' then the default duration of the enum is used.
	** 
	** Corresponds to the 'control:flight_anim' config cmd.
	Void animateFlight(FlightAnimation anim, Duration? duration := null, Bool block := true) {
		params	:= [anim.ordinal, (duration ?: anim.defaultDuration).toMillis].join(",")	
		sendConfig("control:flight_anim", params)
		if (block)
			Actor.sleep(duration ?: anim.defaultDuration)
	}
	
	
	
	// ---- Stabilising Commands ----
	
	** Repeatedly sends a take off command to the drone until it reports its state as either 'hovering' or 'flying'.
	** 
	** If 'block' is 'true' then this method blocks until a stable hover has been achieved; 
	** which usually takes ~ 6 seconds.
	** 
	** If 'timeout' is 'null' it defaults to 'DroneConfig.defaultTimeout'.
	Void takeOff(Bool block := true, Duration? timeout := null) {
		if (state == null || ![FlightState.def, FlightState.init, FlightState.landed].contains(state)) {
			log.warn("Can not take off - flight state is already ${state}")
			return
		}
		NavDataLoop.takeOff(this, block, timeout ?: config.actionTimeout)
	}

	** Repeatedly sends a land command to the drone until it reports its state as 'landed'.
	**  
	** If 'block' is 'true' then this method blocks until the drone has landed.
	** 
	** If 'timeout' is 'null' it defaults to 'DroneConfig.defaultTimeout'.
	Void land(Bool block := true, Duration? timeout := null) {
		if (state == null || [FlightState.def, FlightState.init, FlightState.landed, FlightState.transLanding].contains(state)) {
			log.warn("Can not land - flight state is already ${state}")
			return
		}
		NavDataLoop.land(this, block, timeout ?: config.actionTimeout)
	}
	
	** Repeatedly sends a hover command to the drone until it reports its state as 'hovering'.
	**  
	** If 'block' is 'true' then this method blocks until the drone hovers.
	** 
	** If 'timeout' is 'null' it defaults to 'DroneConfig.defaultTimeout'.
	Void hover(Bool block := true, Duration? timeout := null) {
		if (state == null || [FlightState.hovering].contains(state)) {
			log.warn("Can not hover - flight state is already ${state}")
			return
		}
		// the best way to prevent this from interfering with an emergency land cmd, is to set the
		// emergency flag (to kill off any existing cmds), clear it, then hover
		NavDataLoop.hover(this, block, timeout ?: config.actionTimeout)
	}
	

	
	// ---- Movement Commands ----

	** Moves the drone vertically upwards.
	** 
	** 'verticalSpeed' is a percentage of the maximum vertical speed and should be a value between -1 and 1.
	** A positive value makes the drone rise in the air, a negative value makes it go down.	
	** 
	** 'duration' is how long the drone should move for, during which the move command is resent every 'config.cmdInterval'.
	** Movement is cancelled if 'land()' is called or an emergency flag is set. 
	** 
	** Should 'block' be 'false', this method returns immediately and movement commands are sent in the background. 
	** Call the returned function to cancel movement before the 'duration' interval is reached. 
	** Calling the function after 'duration' does nothing. 
	** 
	** pre>
	** syntax: fantom
	** // move the drone
	** cancel := drone.moveUp(0.5f, 5sec, false)
	**
	** // wait a bit
	** Actor.sleep(2sec) 
	** 
	** // cancel the move
	** cancel()
	** <pre 
	** 
	** If 'duration' is 'null' then the movement command is sent just the once.
	** 
	** See config commands 'control:altitude_max', 'control:control_vz_max'.
	|->|? moveUp(Float verticalSpeed, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(0f, 0f, verticalSpeed, 0f), verticalSpeed, duration, block)
	}
	
	** Moves the drone vertically downwards.
	** 
	** 'verticalSpeed' is a percentage of the maximum vertical speed and should be a value between -1 and 1.
	** A positive value makes the drone descend in the air, a negative value makes it go up.	
	** 
	** 'duration' is how long the drone should move for, during which the move command is resent every 'config.cmdInterval'.
	** Movement is cancelled if 'land()' is called or an emergency flag is set. 
	** 
	** Should 'block' be 'false', this method returns immediately and movement commands are sent in the background. 
	** Call the returned function to cancel movement before the 'duration' interval is reached. 
	** Calling the function after 'duration' does nothing. 
	** 
	** pre>
	** syntax: fantom
	** // move the drone
	** cancel := drone.moveDown(0.5f, 5sec, false)
	**
	** // wait a bit
	** Actor.sleep(2sec) 
	** 
	** // cancel the move
	** cancel()
	** <pre 
	** 
	** If 'duration' is 'null' then the movement command is sent just the once.
	** 
	** See config commands 'control:altitude_min', 'control:control_vz_max'.
	|->|? moveDown(Float verticalSpeed, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(0f, 0f, -verticalSpeed, 0f), verticalSpeed, duration, block)
	}
	
	** Moves the drone to the left.
	** 
	** 'tilt' (aka *roll* or *phi*) is a percentage of the maximum inclination and should be a value between -1 and 1.
	** A positive value makes the drone tilt to its left, thus flying leftward. A negative value makes the drone tilt to its right.
	** 
	** 'duration' is how long the drone should move for, during which the move command is resent every 'config.cmdInterval'.
	** Movement is cancelled if 'land()' is called or an emergency flag is set. 
	** 
	** Should 'block' be 'false', this method returns immediately and movement commands are sent in the background. 
	** Call the returned function to cancel movement before the 'duration' interval is reached. 
	** Calling the function after 'duration' does nothing. 
	** 
	** pre>
	** syntax: fantom
	** // move the drone
	** cancel := drone.moveLeft(0.5f, 5sec, false)
	**
	** // wait a bit
	** Actor.sleep(2sec) 
	** 
	** // cancel the move
	** cancel()
	** <pre 
	** 
	** If 'duration' is 'null' then the movement command is sent just the once.
	** 
	** See config command 'control:euler_angle_max'.
	|->|? moveLeft(Float tilt, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(-tilt, 0f, 0f, 0f), tilt, duration, block)
	}

	** Moves the drone to the right.
	** 
	** The 'tilt' (aka *roll* or *phi*) is a percentage of the maximum inclination and should be a value between -1 and 1.
	** A positive value makes the drone tilt to its right, thus flying right. A negative value makes the drone tilt to its left.
	** 
	** 'duration' is how long the drone should move for, during which the move command is resent every 'config.cmdInterval'.
	** Movement is cancelled if 'land()' is called or an emergency flag is set. 
	** 
	** Should 'block' be 'false', this method returns immediately and movement commands are sent in the background. 
	** Call the returned function to cancel movement before the 'duration' interval is reached. 
	** Calling the function after 'duration' does nothing. 
	** 
	** pre>
	** syntax: fantom
	** // move the drone
	** cancel := drone.moveRight(0.5f, 5sec, false)
	**
	** // wait a bit
	** Actor.sleep(2sec) 
	** 
	** // cancel the move
	** cancel()
	** <pre 
	** 
	** If 'duration' is 'null' then the movement command is sent just the once.
	** 
	** See config command 'control:euler_angle_max'.
	|->|? moveRight(Float tilt, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(tilt, 0f, 0f, 0f), tilt, duration, block)		
	}
	
	** Moves the drone forward.
	** 
	** The 'tilt' (aka *pitch* or *theta*) is a percentage of the maximum inclination and should be a value between -1 and 1.
	** A positive value makes the drone drop its nose, thus flying forward. A negative value makes the drone tilt back.
	** 
	** 'duration' is how long the drone should move for, during which the move command is resent every 'config.cmdInterval'.
	** Movement is cancelled if 'land()' is called or an emergency flag is set. 
	** 
	** Should 'block' be 'false', this method returns immediately and movement commands are sent in the background. 
	** Call the returned function to cancel movement before the 'duration' interval is reached. 
	** Calling the function after 'duration' does nothing. 
	** 
	** pre>
	** syntax: fantom
	** // move the drone
	** cancel := drone.moveForward(0.5f, 5sec, false)
	**
	** // wait a bit
	** Actor.sleep(2sec) 
	** 
	** // cancel the move
	** cancel()
	** <pre 
	** 
	** If 'duration' is 'null' then the movement command is sent just the once.
	** 
	** See config command 'control:euler_angle_max'.
	|->|? moveForward(Float tilt, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(0f, -tilt, 0f, 0f), tilt, duration, block)
	}

	** Moves the drone backward.
	** 
	** The 'tilt' (aka *pitch* or *theta*) is a percentage of the maximum inclination and should be a value between -1 and 1.
	** A positive value makes the drone raise its nose, thus flying forward. A negative value makes the drone tilt forward.
	** 
	** 'duration' is how long the drone should move for, during which the move command is resent every 'config.cmdInterval'.
	** Movement is cancelled if 'land()' is called or an emergency flag is set. 
	** 
	** Should 'block' be 'false', this method returns immediately and movement commands are sent in the background. 
	** Call the returned function to cancel movement before the 'duration' interval is reached. 
	** Calling the function after 'duration' does nothing. 
	** 
	** pre>
	** syntax: fantom
	** // move the drone
	** cancel := drone.moveBackward(0.5f, 5sec, false)
	**
	** // wait a bit
	** Actor.sleep(2sec) 
	** 
	** // cancel the move
	** cancel()
	** <pre 
	** 
	** If 'duration' is 'null' then the movement command is sent just the once.
	** 
	** See config command 'control:euler_angle_max'.
	|->|? moveBackward(Float tilt, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(0f, tilt, 0f, 0f), tilt, duration, block)
	}
	
	** Spins the drone clockwise.
	** 
	** The 'angularSpeed' (aka *yaw*) is a percentage of the maximum angular speed and should be a value between -1 and 1.
	** A positive value makes the drone spin clockwise; a negative value makes it spin anti-clockwise.
	** 
	** 'duration' is how long the drone should move for, during which the move command is resent every 'config.cmdInterval'.
	** Movement is cancelled if 'land()' is called or an emergency flag is set. 
	** 
	** Should 'block' be 'false', this method returns immediately and movement commands are sent in the background. 
	** Call the returned function to cancel movement before the 'duration' interval is reached. 
	** Calling the function after 'duration' does nothing. 
	** 
	** pre>
	** syntax: fantom
	** // move the drone
	** cancel := drone.spinClockwise(0.5f, 5sec, false)
	**
	** // wait a bit
	** Actor.sleep(2sec) 
	** 
	** // cancel the move
	** cancel()
	** <pre 
	** 
	** If 'duration' is 'null' then the movement command is sent just the once.
	** 
	** See config command 'control:control_yaw'.
	|->|? spinClockwise(Float angularSpeed, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(0f, 0f, 0f, angularSpeed), angularSpeed, duration, block)
	}
	
	** Spins the drone anti-clockwise.
	** 
	** The 'angularSpeed' (aka *yaw*) is a percentage of the maximum angular speed and should be a value between -1 and 1.
	** A positive value makes the drone spin anti-clockwise; a negative value makes it spin clockwise.
	** 
	** 'duration' is how long the drone should move for, during which the move command is resent every 'config.cmdInterval'.
	** Movement is cancelled if 'land()' is called or an emergency flag is set. 
	** 
	** Should 'block' be 'false', this method returns immediately and movement commands are sent in the background. 
	** Call the returned function to cancel movement before the 'duration' interval is reached. 
	** Calling the function after 'duration' does nothing. 
	** 
	** pre>
	** syntax: fantom
	** // move the drone
	** cancel := drone.spinAntiClockwise(0.5f, 5sec, false)
	**
	** // wait a bit
	** Actor.sleep(2sec) 
	** 
	** // cancel the move
	** cancel()
	** <pre 
	** 
	** If 'duration' is 'null' then the movement command is sent just the once.
	** 
	** See config command 'control:control_yaw'.
	Void spinAntiClockwise(Float angularSpeed, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(0f, 0f, 0f, -angularSpeed), angularSpeed, duration, block)
	}
		
	
	
	// ---- Private Stuff ----
	
	internal This doDisconnect(Bool abnormal, Duration timeout := 2sec) {
		Env.cur.removeShutdownHook(shutdownHook)

		if (actorPool.isStopped) return this
		
		shutdownHook.call()

		navDataReader.disconnect
		cmdSender.disconnect

		// call handlers from a different thread so they don't block
		eventThread.async |->| {
			callSafe(onDisconnect, [abnormal, this])
		}
		
		actorPool.stop
		if (!abnormal)	// don't block internal threads
			actorPool.join(timeout)

		log.info("Disconnected from Drone")
		return this
	}
	
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
		
		// hey! I'm still here!
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
				if (demoData.flightState != oldNavData?.demoData?.flightState)
					callSafe(onStateChange, [demoData.flightState, this])
			
				if (oldNavData?.demoData?.batteryPercentage == null || demoData.batteryPercentage < oldNavData.demoData.batteryPercentage)
					callSafe(onBatteryDrain, [demoData.batteryPercentage, this])
			}
		}
	}
	
	private Void onShutdown() {
		if (navData?.flags?.flying == true || (state != null && state != FlightState.landed && state != FlightState.def)) {
			switch (exitStrategy) {
				case ExitStrategy.nothing:
					log.warn("Enforcing Exit Strategy --> Doing Nothing!")
				
				case ExitStrategy.hover:
					log.warn("Enforcing Exit Strategy --> Hovering Drone")
					hover(false)
				
				case ExitStrategy.land:
					log.warn("Enforcing Exit Strategy --> Landing Drone")
					land(false)

				case ExitStrategy.crashLand:
					log.warn("Enforcing Exit Strategy --> Crash Landing Drone")
					crashLand
			
				default:
					throw Err("WTF is a '${exitStrategy}' exit strategy ???")
			}
		}
	}

	private |->|? doMove(Cmd cmd, Float speed, Duration? duration, Bool? block) {
		if (speed < -1f || speed > 1f)
			throw ArgErr("Speed must be between -1 and 1 : ${speed}")
		
		if (duration == null) {
			cmdSender.send(cmd)
			return null
		}

		future := TimedLoop(this, duration, cmd).future
		if (block) {
			future.get
			return null 
		}
		
		return |->| { if (!future.state.isComplete) future.cancel }
	}
	
	private Str encodeConfigParam(Obj? p) {
		if (p is Bool)	return ((Bool ) p).toStr.upper
		if (p is Int)	return ((Int  ) p).toStr
		if (p is Float)	return ((Float) p).bits32.toStr
		if (p is Str)	return ((Str  ) p)
		throw ArgErr("Param should be a Bool, Int, Float, or Str - not ${p?.typeof} -> ${p}")
	}

	private Void callSafe(Func? f, Obj[]? args) {
		try f?.callList(args)
		catch (Err err)
			err.trace
	}
}

** Pre-configured LED animation sequences.
enum class LedAnimation {
	** Alternates all LEDs between red and green.
	blinkGreenRed(2f), 
	** Alternates all LEDs between green and off.
	blinkGreen(2f), 
	** Alternates all LEDs between red and off.
	blinkRed(2f), 
	** Alternates all LEDs between orange (red and green at the same time) and off.
	blinkOrange(2f), 
	** Rotates the green and red LEDs around the drone.
	snakeGreenRed(0.75f), 
	** Flashes the front LEDs orange (red and green at the same time).
	fire(9f),
	** Turns the front LEDs green and the rear LEDs red.
	standard(1f), 
	** Turns all LEDs red.
	red(1f), 
	** Turns all LEDs green.
	green(1f), 
	** Rotates the red LED around the drone.
	snakeRed(1.5f), 
	** Turns all LEDs off.
	off(1f),
	** Flashes the front LED orange and the rear LED red - right side only.
	rightMissile(6f), 
	** Flashes the front LED orange and the rear LED red - left side only.
	leftMissile(6f), 
	** Flashes the front LEDs orange and the rear LEDs red - both sides.
	doubleMissile(6f), 
	** Turns the front left LED green and the others red.
	frontLeftGreenOthersRed(1f), 
	** Turns the front right LED green and the others red.
	frontRightGreenOthersRed(1f), 
	** Turns the rear right LED green and the others red.
	rearRightGreenOthersRed(1f), 
	** Turns the rear left LED green and the others red.
	rearLeftGreenOthersRed(1f), 
	** Turns the left LEDs green and the right LEDs red.
	leftGreenRightRed(1f), 
	** Turns the left LEDs red and the right LEDs green.
	leftRedRightGreen(1f), 
	** Alternates all LEDs between standard (front LEDs green and rear LEDs red) and off.
	blinkStandard(2f);
	
	** A default frequency for the animation.
	const Float defaultFrequency
	
	private new make(Float defaultFrequency) {
		this.defaultFrequency = defaultFrequency
	}
}

** Pre-configured flight paths.
enum class FlightAnimation {
	phiM30Deg(1sec), phi30Deg(1sec), thetaM30Deg(1sec), theta30Deg(1sec), theta20degYaw200Deg(1sec), theta20degYawM200Deg(1sec), turnaround(5sec), turnaroundGodown(5sec), yawShake(2sec), yawDance(5sec), phiDance(5sec), thetaDance(5sec), vzDance(5sec), wave(5sec), phiThetaMixed(5sec), doublePhiThetaMixed(5sec), flipAhead(15ms), flipBehind(15ms), flipLeft(15ms), flipRight(15ms);

	** How long the manoeuvre should take.
	const Duration defaultDuration
	
	private new make(Duration defaultDuration) {
		this.defaultDuration = defaultDuration
	}
}

** Governs what the drone should do if the program exists whilst flying.
** Default is 'land'.
enum class ExitStrategy {
	** Do nothing, let the drone continue doing whatever it was programmed to do.
	nothing, 
	
	** Sends a 'stop()' command.
	hover, 
	
	** Sends a 'land()' command.
	land, 
	
	** Cuts the drone's engines, forcing a crash landing.
	crashLand;
}
