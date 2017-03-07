using afConcurrent::SynchronizedState
using concurrent::ActorPool
using inet::IpAddr
using inet::UdpSocket
using inet::UdpPacket

internal const class CmdSender {
	private const ActorPool			actorPool
	private const SynchronizedState	mutex
	
	new make(Drone drone, ActorPool actorPool) {
		this.mutex		= SynchronizedState(actorPool) |->Obj| {
			CmdSenderImpl(drone)
		}
		this.actorPool	= actorPool
	}
	
	Void connect() {
		// call synchronized so we know we've connected
		if (!actorPool.isStopped)
			mutex.getState |CmdSenderImpl sender| {
				sender.connect
			}
	}
	
	Void send(Cmd cmd, Cmd? cmd2 := null) {
		if (!actorPool.isStopped)
			mutex.withState |CmdSenderImpl sender| {
				sender.send(cmd, cmd2)
			}
	}
	
	Void disconnect() {
		if (!actorPool.isStopped)
			mutex.getState |CmdSenderImpl sender| {
				sender.disconnect
			}
	}	
}

internal class CmdSenderImpl {
	Log			log	:= Drone#.pod.log
	Drone		drone
	UdpSocket	socket
	Bool		connected
	Int			lastSeq
	
	new make(Drone drone) {
		this.drone = drone
		this.socket = UdpSocket().connect(drone.networkConfig.droneIpAddr, drone.networkConfig.cmdPort) {
			it.options.receiveTimeout = drone.networkConfig.udpReceiveTimeout
		}
	}
	
	Void connect() {
		if (connected)
			disconnect
		connected = true
	}
	
	Void send(Cmd cmd, Cmd? cmd2) {
		if (connected) {
			try	{
				cmdStr := cmd.cmdStr(++lastSeq)
				if (cmd2 != null)
					cmdStr += cmd2.cmdStr(++lastSeq)				
				socket.send(UdpPacket() { data = cmdStr.toBuf.seek(0) })
				if (log.isDebug)
//					if (cmd.id != "COMWDG")
					if (cmd.id != "COMWDG" && cmd.id != "REF" && cmd.id != "PCMD" && cmd.id != "CTRL")
						log.debug("--> " + cmdStr.trim.replace("\r", "  "))
			} catch (IOErr ioe) {
				if (ioe.msg.contains("java.net.SocketException")) {
					log.warn("Drone not connected (could not send cmd) - check the drone's power")
					drone._doDisconnect(true)
					return
				}
				throw ioe
			}
		}
	}
	
	Void disconnect() {
		socket.disconnect
		connected = false
	}
}