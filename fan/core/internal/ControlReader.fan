using concurrent::Actor
using concurrent::ActorPool
using afConcurrent::SynchronizedList
using afConcurrent::SynchronizedState
using inet::IpAddr
using inet::TcpSocket

using inet::UdpSocket
using inet::UdpPacket

internal const class ControlReader {
	private const Log				log		:= Drone#.pod.log
	private const Drone				drone
	
	new make(Drone drone) {
		this.drone	= drone
	}
	
	static Void read2() {
		config := DroneConfig()

		sock := UdpSocket {
			it.options.receiveTimeout = config.udpReceiveTimeout
		}.connect(IpAddr(config.droneIpAddr), config.cmdPort)
		sock.send(UdpPacket() { data = Cmd.makeCtrl(4, 0).cmdStr(1).toBuf.seek(0) })
//		sock.send(UdpPacket() { data = Cmd.makeCtrl(4, 0).cmdStr(2).toBuf.seek(0) })
//		sock.disconnect
		
		Actor.sleep(30ms)
		
		socket := TcpSocket {
			it.options.receiveTimeout = config.udpReceiveTimeout
		}.connect(IpAddr(config.droneIpAddr), config.controlPort, config.defaultTimeout)
		echo("connected")
		
		buf := Buf() 
		socket.in.readBuf(buf, 100)
		echo("BUG $buf.size $buf.flip.toBase64")
		
		socket.close
	}
	
	Str? read() {
		// ~ 7secs
		Timer.time("Read config") |->| {
			drone.sendCmd(Cmd.makeCtrl(4, 0))
			echo("READING")
			config := drone.config
			socket := TcpSocket {
				it.options.receiveTimeout = config.udpReceiveTimeout
			}.connect(IpAddr(config.droneIpAddr), config.controlPort, config.defaultTimeout)
			echo("connected")
				
//			echo("sendCmd")
//			Actor.sleep(1sec)
//			drone.sendCmd(Cmd.makeCtrl(5, 0))
//			Actor.sleep(1sec)
			
			props := null as Str
			try	{
//				props	= socket.in.readAllStr
				buf := Buf() 
//				drone.doDisconnect(true)
				socket.in.readBuf(buf, 100)
				echo("BUG $buf.size")
				props = buf.flip.readAllStr
			}
			catch (IOErr err) {
				if (err.msg.contains("SocketTimeoutException")) {
					log.warn("Drone not connected (SocketTimeoutException on Control read) - check your Wifi settings")
					drone.doDisconnect(true)
					return null
				}
				throw err
			}
	
			echo("READ [${props}]")
			
			socket.close
			return props
		}
	}
}
