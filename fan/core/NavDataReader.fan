using concurrent::Actor
using concurrent::ActorPool
using afConcurrent::Synchronized
using afConcurrent::SynchronizedList
using inet::IpAddr
using inet::UdpSocket
using inet::UdpPacket

// TODO simplify and use SyncState
internal const class NavDataReader {
	private const ActorPool			actorPool
	private const DroneConfig		config
	private const Synchronized		mutex
	private const SynchronizedList	listeners
	
	private NavDataReaderImpl reader {
		get { Actor.locals[NavDataReaderImpl#.qname] }
		set { Actor.locals[NavDataReaderImpl#.qname] = it}
	}
	
	new make(ActorPool actorPool, DroneConfig config) {
		this.listeners	= SynchronizedList(actorPool) {
			it.valType	= |NavData|#
		}
		this.mutex		= Synchronized(actorPool)
		this.config		= config
		this.actorPool	= actorPool
	}
	
	Void addListener(|NavData| f) {
		listeners.add(f)
	}
	
	Void removeListener(|NavData| f) {
		listeners.remove(f)
	}
	
	Void connect() {
		// synchronized so we know we've connected -   so we can throw err if already connected?
		mutex.synchronized |->| {
			reader = NavDataReaderImpl(config.droneIpAddr, config.navDataPort, config.udpReceiveTimeout)
			reader.connect
			if (reader.connected && !actorPool.isStopped)
				mutex.async |->| { read }
		}
	}
	
	private Void read() {
		mutex.async |->| {
			navData := reader.receive
			if (navData != null) {
				listeners.each { 
					try ((|NavData|) it).call(navData)
					catch (Err err)	err.trace
				}
			}
			if (reader.connected && !actorPool.isStopped)
				mutex.async |->| { read }
		}
	}
	
	Void disconnect() {
		mutex.synchronized |->| {
			reader.disconnect
		}
	}
}

internal class NavDataReaderImpl {
	Log			log	:= Drone#.pod.log
	UdpSocket	socket
	Bool		connected
	Int			lastSeqNum
	
	new make(Str ipAddr, Int port, Duration receiveTimeout) {
		socket = UdpSocket().connect(IpAddr(ipAddr), port) {
			it.options.receiveTimeout = receiveTimeout
		}
	}
	
	Void connect() {
		if (connected)
			disconnect

		// send any old data to the nav port to prompt the drone to start sending stuff back
		triggerPacket := UdpPacket(null, null, Buf(4).write(1).write(0).write(0).write(0).flip)
		socket.send(triggerPacket)
		connected = true
	}
	
	NavData? receive() {
		try {
			packet := null as UdpPacket
			try	packet	= socket.receive
			catch (IOErr err) {
				if (err.msg.contains("SocketTimeoutException")) {
					log.warn("Drone not connected (SocketTimeoutException) - check your Wifi settings")
					return null
				}
				throw err
			}

			navData	:= NavData(packet.data.flip.with {
				it.endian = Endian.little
			})
			
			if (navData.seqNum < lastSeqNum && navData.seqNum != 1) {
				log.warn("Nav data out of sequence; expected > $lastSeqNum got $navData.seqNum")
				return null
			}

			lastSeqNum = navData.seqNum
			return navData
			
		} catch (Err err) {
			err.trace
			// err? should we disconnect, throw an event or something?
			return null
		}
	}
	
	Void disconnect() {
		socket.disconnect
		connected = false
	}
}