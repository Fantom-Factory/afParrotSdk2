using concurrent::Actor
using concurrent::ActorPool
using afConcurrent::SynchronizedList
using afConcurrent::SynchronizedState
using inet::IpAddr
using inet::UdpSocket
using inet::UdpPacket

internal const class ControlReader {
	private const ActorPool			actorPool
	private const DroneConfig		config
	private const SynchronizedState	mutex
	private const SynchronizedList	listeners
	
	new make(Drone drone, ActorPool actorPool, DroneConfig config) {
		this.mutex		= SynchronizedState(actorPool) |->Obj?| {
			ControlReaderImpl(drone, config.droneIpAddr, config.controlPort, config.udpReceiveTimeout)
		}
		this.listeners	= SynchronizedList(actorPool) {
			it.valType	= |Str|#
		}
		this.config		= config
		this.actorPool	= actorPool
	}
	
	** Only internal listeners should be added here.
	Void addListener(|Str| f) {
		listeners.add(f)
	}
	
	Void removeListener(|Str| f) {
		listeners.remove(f)
	}
	
	Void connect() {
		// call synchronized so we know when we've connected
		mutex.getState |ControlReaderImpl reader| {
			reader.connect
//			if (reader.connected && !actorPool.isStopped)
//				readControlData
		}
	}
	
	Void readControlData() {
		mutex.withState |ControlReaderImpl reader| {
			navData := reader.receive
//			if (navData != null) {
//				listeners.each {
//					try ((|Str|) it).call(navData)
//					catch (Err err)	err.trace
//				}
//			}
//			if (reader.connected && !actorPool.isStopped)
//				readControlData
		}
	}
	
	Void disconnect() {
		mutex.getState |ControlReaderImpl reader| {
			reader.disconnect
		}
	}
}

internal class ControlReaderImpl {
	Log				log		:= Drone#.pod.log
	Drone			drone
	UdpSocket?		socket
	Bool			connected
	Int				lastSeqNum
	NavDataParser	parser	:= NavDataParser()
	
	new make(Drone drone, Str ipAddr, Int port, Duration receiveTimeout) {
		this.drone  = drone
		this.socket = UdpSocket().connect(IpAddr(ipAddr), port) {
			it.options.receiveTimeout = receiveTimeout
		}
	}
	
	Void connect() {
		if (connected)
			disconnect
		connected = true
	}
	
	Str? receive() {
		packet := null as UdpPacket
		try	packet	= socket.receive
		catch (IOErr err) {
			if (err.msg.contains("SocketTimeoutException")) {
				log.warn("Drone not connected (SocketTimeoutException on control read) - check your Wifi settings")
				drone.doDisconnect(true)
				return null
			}
			throw err
		}

		data := packet.data.flip.readAllStr
		
		echo(data)
		
		return data
		
//		try {
//			navData	:= parser.parse(packet.data.flip.with {
//				it.endian = Endian.little
//			})
//			
//			if (navData.seqNum < lastSeqNum && navData.seqNum != 1) {
//				log.warn("Nav data out of sequence; expected > $lastSeqNum got $navData.seqNum")
//				return null
//			}
//
//			lastSeqNum = navData.seqNum
//			return navData
//			
//		} catch (Err err) {
//			err.trace
//			// err? should we disconnect, throw an event or something?
//			return null
//		}
	}
	
	Void disconnect() {
		socket.disconnect
		connected = false
	}
}