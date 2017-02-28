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
	private	const	Synchronized	eventThread
	private	const	|->|			shutdownHook

	internal const	CmdSender		cmdSender
	internal const	NavDataReader	navDataReader
	internal const	ControlReader	controlReader
	internal const	ActorPool		actorPool
	
	** The configuration as passed to the ctor.
			const	DroneConfig		config
	
	** Returns the latest Nav Data or 'null' if not connected.
	** Note that this instance always contains a culmination of all the latest nav options received.
					NavData?		navData {
						get { navDataRef.val }
						private set { }
					}
	
	** Returns the current flight state of the Drone.
					FlightState?		state {
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

	** Creates a 'Drone' instance, optionally passing in default configuration.
	new make(DroneConfig config := DroneConfig()) {
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

		NavDataLoop.waitUntilReady(this, timeout ?: config.defaultTimeout)

		Env.cur.addShutdownHook(shutdownHook)

		if (!actorPool.isStopped)
			log.info("Connected to AR Drone 2.0")
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
	@NoDoc
	Void sendCmd(Cmd cmd) {
		cmdSender.send(cmd)
	}
	
	** Sends a config cmd to the drone.
	** 
	** 'val' may be a Bool, Int, Float, Str, or a List of said types. 
	Void sendConfig(Str key, Obj val) {
		if (val is List)
			val = ((List) val).join(",") { encodeConfigParam(it) }
		val = encodeConfigParam(val)
		cmdSender.send(Cmd.makeConfig(key, val))
		// FIXME block + wait for ack to clear, send, wait for ack, send ack ack, wait for clear
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
		sendConfig("control:outdoor", outdoors)
		sendConfig("control:flight_without_shell", outdoors)
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
		params := [anim.ordinal, (duration ?: anim.defaultDuration).toSec]
		sendConfig("control:flight_anim", params)
		if (block)
			Actor.sleep(duration ?: anim.defaultDuration)
	}
	
	
	// ---- Equilibrium Commands ----
	
	** Issues a take off command. 
	** 
	** If 'block' is 'true' then it blocks the thread until a stable hover has been achieved; 
	** which usually takes ~ 6 seconds.
	** 
	** If 'timeout' is 'null' it defaults to 'DroneConfig.defaultTimeout'.
	Void takeOff(Bool block := true, Duration? timeout := null) {
		if (state != FlightState.landed) {
			log.warn("Can not take off when state is ${state}")
			return
		}
		// Don't takeoff if already taking off --> need an internal state: none, landing, takingOff
		// FIXME cancel / ignore all other move commands when taking off
		if (block)
			NavDataLoop.takeOff(this, timeout ?: config.defaultTimeout)
		else
			// FIXME still repeat until takeoff
			cmdSender.send(Cmd.makeTakeOff)
	}

	** Repeatedly sends a land cmd to the drone until it reports its state as 'landed'.
	**  
	** If 'block' is 'true' then it blocks the thread until the drone has landed.
	** 
	** If 'timeout' is 'null' it defaults to 'DroneConfig.defaultTimeout'.
	Void land(Bool block := true, Duration? timeout := null) {
		// let's not second guess what state the drone is in
		// if they wanna land the drone, send the gawd damn land cmd!
//		if (state != CtrlState.flying && state != CtrlState.hovering) {
//			log.warn("Can not land when state is ${state}")
//			return
//		}

		// Don't land if already landing --> need an internal state: none, landing, takingOff
		echo("Landing")
		
		// FIXME cancel / ignore all other move commands when landing
		
		if (block)
			NavDataLoop.land(this, timeout ?: config.defaultTimeout)
		else
			// FIXME still repeat until landed
			cmdSender.send(Cmd.makeLand)
	}
	
	Void hover(Bool block := true, Duration? timeout := null) {
		cmdSender.send(Cmd.makeHover)
		// TODO block until hover state???
		// TODO cancel / ignore all other move commands when landing -> except LAND!
	}
	

	
	// ---- Movement Commands ----

	** The 'verticalSpeed' is a percentage of the maximum vertical speed.
	** A positive value makes the drone rise in the air, a negative value makes it go down.	
	|->|? moveUp(Float verticalSpeed, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(0f, 0f, verticalSpeed, 0f), verticalSpeed, duration, block)
	}
	
	|->|? moveDown(Float verticalSpeed, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(0f, 0f, -verticalSpeed, 0f), verticalSpeed, duration, block)
	}
	
	** The 'tilt' (aka *roll* or *phi*) is a percentage of the maximum inclination.
	** A positive value makes the drone tilt to its left, thus flying leftward. A negative value makes the drone tilt to its right.
	|->|? moveLeft(Float tilt, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(-tilt, 0f, 0f, 0f), tilt, duration, block)
	}

	** The 'tilt' (aka *roll* or *phi*) is a percentage of the maximum inclination.
	** A positive value makes the drone tilt to its right, thus flying right. A negative value makes the drone tilt to its left.
	|->|? moveRight(Float tilt, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(tilt, 0f, 0f, 0f), tilt, duration, block)		
	}
	
	** The 'tilt' (aka *pitch* or *theta*) is a percentage of the maximum inclination.
	** A negative value drops its nose, thus flying forward. A positive value raises the nose, thus flying backward.
	|->|? moveForward(Float tilt, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(0f, -tilt, 0f, 0f), tilt, duration, block)
	}

	** The 'tilt' (aka *pitch* or *theta*) is a percentage of the maximum inclination.
	|->|? moveBackward(Float tilt, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(0f, tilt, 0f, 0f), tilt, duration, block)
	}
	
	** The 'angularSpeed' (aka *yaw*) is a percentage of the maximum angular speed.
	** A positive value makes the drone spin clockwise; a negative value makes it spin anti-clockwise.
	** 
	**  -1 to 1
	** 
	** If 'duration' is given then this method will block and send move cmd to the drone every 
	** 'config.cmdInterval'.
	** 
	** Alternatively, if 'block' is false then the method returns immediately, returning a func that, 
	** when called, cancels any future cmd sends.
	|->|? spinClockwise(Float angularSpeed, Duration? duration := null, Bool? block := true) {
		doMove(Cmd.makeMove(0f, 0f, 0f, angularSpeed), angularSpeed, duration, block)
	}
	
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
		
		// send me nav data please!
		if (!navData.flags.navDataDemo)
			cmdSender.send(Cmd.makeConfig("general:navdata_demo", "TRUE"))

		// hey! I'm still here!
		if (navData.flags.comWatchdogProblem)
			cmdSender.send(Cmd.makeKeepAlive)

		// okay, so I don't actually understand why I'm doing this! But everything works better when I do!
		if (navData.flags.controlCommandAck)
			cmdSender.send(Cmd.makeCtrl(5, 0))

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
		
		return |->| { future.cancel }
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
	blinkGreenRed(2f), blinkGreen(2f), blinkRed(2f), blinkOrange(2f), snakeGreenRed(0.75f), fire(9f), standard(1f), red(1f), green(1f), snakeRed(1.5f), off(1f), rightMissile(6f), leftMissile(6f), doubleMissile(6f), frontLeftGreenOthersRed(1f), frontRightGreenOthersRed(1f), rearRightGreenOthersRed(1f), rearLeftGreenOthersRed(1f), leftGreenRightRed(1f), leftRedRightGreen(1f), blinkStandard(2f);
	
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

** Governs what the drone should do if the program exists whilst it's flying.
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
