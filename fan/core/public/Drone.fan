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
		navDataReader.addListener(#onNavData.func.bind([this]))
		
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
	
	// TODO have onNavData listener class, like fwt
	Void addNavDataListener(|NavData| f) {
		navDataReader.addListener(f)
	}
	
	Void removeNavDataListener(|NavData| f) {
		navDataReader.removeListener(f)
	}
	
	// ---- Commands ----
	
	** Blocks until nav data is being received and all initiating commands have been acknowledged.
	Void waitUntilReady(Duration? timeout := null) {
		DroneLoop.waitUntilReady(this, timeout ?: config.defaultTimeout)
	}
	
	Void clearEmergencyMode(Duration? timeout := null) {
		if (navData?.state?.emergencyLanding == true)
			DroneLoop.clearEmergencyMode(this, timeout ?: config.defaultTimeout)
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
			DroneLoop.takeOff(this, timeout ?: config.defaultTimeout)
		else
			cmdSender.send(Cmd.makeTakeOff)
	}

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
	** This command MUST be sent when the AR.Drone is flying.
	** When receiving this command, the drone will automatically calibrate its magnetometer by
	** spinning around itself for a few time.
	** 
	** Does not block
		// TODO better fandocs
	Void calibrate(Int deviceNum) {
		if (state != CtrlState.flying && state != CtrlState.hovering) {
			log.warn("Can not calibrate magnetometer when state is ${state}")
			return
		}
		cmdSender.send(Cmd.makeCalib(deviceNum))
	}

	Void animateLeds(LedAnimation anim := LedAnimation.redSnake, Float hz := 2f, Duration duration := 3sec) {
		params := [anim.ordinal, hz.bits32, duration.toSec].join(",")
		cmdSender.send(Cmd.makeConfig("leds:leds_anim", params))
	}

//	Void config(Str key, Str val, |->| callback)
//	
//Client.prototype.animate = function(animation, duration) {
//  // @TODO Figure out if we can get a ACK for this, so we don't need to
//  // repeat it blindly like this
//  var self = this;
//  this._repeat(10, function() {
//    self._udpControl.animate(animation, duration);
//  });
//};
//
//Client.prototype.animateLeds = function(animation, hz, duration) {
//	
//	['up', 'down'],
//	['left', 'right'],
//	['front', 'back'],
//	['clockwise', 'counterClockwise'],
//
//	Void stop()
	
	// ---- Private Stuff ----
	
	Void onNavData(NavData navData) {
		oldNavData	:= (NavData?) navDataRef.val
		
		// TODO send event on state change
		if (oldNavData?.demoData?.ctrlState != navData.demoData?.ctrlState)
			log.debug("STATE: ${oldNavData?.demoData?.ctrlState} --> ${navData.demoData?.ctrlState}")
		
		// TODO send event on Battery Percent change
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
	
	Void doCrashLandOnExit() {
		if (crashLandOnExit)
			if (navData?.state?.flying == true || (state != CtrlState.landed || state != CtrlState.def)) {
				log.warn("Exiting Program --> Crash landing Drone")
				crashLand
			}
	}
}

enum class LedAnimation {
	blinkGreenRed, blinkGreen, blinkRed, blinkOrange, snakeGreenRed, fire, standard, red, green, redSnake, blank, rightMissile, leftMissile, doubleMissile, frontLeftGreenOthersRed, frontRightGreenOthersRed, rearRightGreenOthersRed, rearLeftGreenOthersRed, leftGreenRightRed, leftRedRightGreen, blinkStandard;
}

enum class FlightAnimation {
	phiM30Deg, phi30Deg, thetaM30Deg, theta30Deg, theta20degYaw200deg, theta20degYawM200deg, turnaround, turnaroundGodown, yawShake, yawDance, phiDance, thetaDance, vzDance, wave, phiThetaMixed, doublePhiThetaMixed, flipAhead, flipBehind, flipLeft, flipRight;
}
