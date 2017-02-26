using afConcurrent::SynchronizedState
using concurrent::ActorPool
using inet::IpAddr
using inet::UdpSocket
using inet::UdpPacket

const class CmdSender {
	private const ActorPool			actorPool
	private const DroneConfig		config
	private const SynchronizedState	mutex
	
	new make(ActorPool actorPool, DroneConfig config) {
		this.mutex		= SynchronizedState(actorPool) |->Obj| {
			CmdSenderImpl(config.droneIpAddr, config.controlPort)
		}
		this.config		= config
		this.actorPool	= actorPool
	}
	
	Void connect() {
		// call synchronized so we know we've connected
		if (!actorPool.isStopped)
			mutex.getState |CmdSenderImpl sender| {
				sender.connect
			}
	}
	
	Void send(Cmd cmd) {
		if (!actorPool.isStopped)
			mutex.withState |CmdSenderImpl sender| {
				sender.send(cmd)
			}
	}
	
	Void disconnect() {
		if (!actorPool.isStopped)
			mutex.getState |CmdSenderImpl sender| {
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
			if (cmd.id != "COMWDG" && cmd.id != "REF")
				log.debug("--> ${cmd.cmdStr(lastSeq).trim}")
		}
	}
	
	Void disconnect() {
		socket.disconnect
		connected = false
	}
}