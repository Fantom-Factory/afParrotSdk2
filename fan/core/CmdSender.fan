using afConcurrent
using concurrent
using inet::IpAddr
using inet::UdpSocket
using inet::UdpPacket

// TODO simplify and use SyncState
const class CmdSender {
	private const ActorPool			actorPool
	private const DroneConfig		config
	private const Synchronized		mutex
	private const SynchronizedList	listeners
	
	private CmdSenderImpl sender {
		get { Actor.locals[CmdSenderImpl#.qname] }
		set { Actor.locals[CmdSenderImpl#.qname] = it}
	}
	
	new make(ActorPool actorPool, DroneConfig config) {
		this.listeners	= SynchronizedList(actorPool) {
			it.valType	= |NavData|#
		}
		this.mutex		= Synchronized(actorPool)
		this.config		= config
		this.actorPool	= actorPool
	}
	
	Void connect() {
		// synchronized so we know we've connected -   so we can throw err if already connected?
		mutex.synchronized |->| {
			sender = CmdSenderImpl(config.droneIpAddr, config.controlPort)
			sender.connect

//			if (sender.connected && !actorPool.isStopped)
//				commsWatchdog
		}
	}
	
//	private Void commsWatchdog() {
//		mutex.asyncLater(30ms) |->| {
//			send(Cmd.makeKeepAlive)
//			if (sender.connected && !actorPool.isStopped)
//				mutex.async |->| { commsWatchdog }
//		}
//	}
	
	Void send(Cmd cmd) {
		mutex.async |->| {
			sender.send(cmd)
		}
	}
	
	Void disconnect() {
		mutex.synchronized |->| {
			sender.disconnect
		}
	}	
}

class CmdSenderImpl {
	Log			log	:= Drone#.pod.log
	UdpSocket	socket
	Bool		connected
	Int			lastSeq
	
	new make(Str ipAddr, Int port) {
		socket = UdpSocket().connect(IpAddr(ipAddr), port)
	}
	
	Void connect() {
		if (connected)
			disconnect
		connected = true
	}
	
	Void send(Cmd cmd) {
		if (connected) {
			socket.send(UdpPacket() { data = cmd.cmdStr(++lastSeq).toBuf.seek(0) })
			echo("  Sent: ${cmd.cmdStr(lastSeq)}")
		}
	}
	
	Void disconnect() {
		socket.disconnect
		connected = false
	}
}