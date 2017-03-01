
using concurrent::Actor
using concurrent::ActorPool
using afConcurrent::SynchronizedList
using afConcurrent::SynchronizedState
using inet::IpAddr
using inet::TcpSocket

internal const class VideoReader {
	private const Log				log		:= Drone#.pod.log
	
	Void? read() {
		config := DroneConfig()
		socket := TcpSocket {
			it.options.receiveTimeout = config.udpReceiveTimeout
		}.connect(IpAddr(config.droneIpAddr), config.videoPort, config.actionTimeout)
		echo("connected")
			
		buf := Buf() 
		socket.in.readBuf(buf, 100)
		echo("BUG $buf.size $buf.flip.toBase64")
		
		socket.close
	}
}
