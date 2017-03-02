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
		config := NetworkConfig()

		socket := TcpSocket {
			it.options.receiveTimeout = config.udpReceiveTimeout
		}.connect(config.droneIpAddr, config.controlPort, config.actionTimeout)
		echo("connected")

//		Actor.sleep(300ms)

		sock := UdpSocket {
			it.options.receiveTimeout = config.udpReceiveTimeout
		}.connect(config.droneIpAddr, config.cmdPort)
		sock.send(UdpPacket() { data = Cmd.makeCtrl(5, 0).cmdStr(1).toBuf.seek(0) })
		sock.send(UdpPacket() { data = Cmd.makeCtrl(4, 0).cmdStr(2).toBuf.seek(0) })
		sock.disconnect
		
//		Actor.sleep(300ms)
		
		
//		socket.out.writeBuf(Cmd.makeCtrl(4, 0).cmdStr(1).toBuf.seek(0)).flush
		
		buf := Buf() 
		socket.in.readBuf(buf, 100)
//		socket.in.readBufFully(buf, 100)
//		echo("BUG $buf.size $buf.flip.toBase64")
		echo("BUG $buf.size $buf.flip.readAllStr")
		
		w:= socket.in.readNullTerminatedStr
		echo(w)
		
//		line := "" as Str
//		while (line != null) {
//			line = socket.in.readLine
//			echo(line)
//		}
		echo("DONE")
		socket.close
	}
	
	static Void main(Str[] args) {
		read2
	}
	
	Str? read() {
		// ~ 7secs
		Timer.time("Read config") |->| {
			drone.sendCmd(Cmd.makeCtrl(4, 0))
			echo("READING")
			config := drone.networkConfig
			socket := TcpSocket {
				it.options.receiveTimeout = config.udpReceiveTimeout
			}.connect(config.droneIpAddr, config.controlPort, config.actionTimeout)
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
					drone._doDisconnect(true)
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
