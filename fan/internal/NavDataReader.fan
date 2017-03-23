using concurrent::Actor
using concurrent::ActorPool
using afConcurrent::SynchronizedList
using afConcurrent::SynchronizedState
using inet::IpAddr
using inet::UdpSocket
using inet::UdpPacket

internal const class NavDataReader {
	private const ActorPool			actorPool
	private const SynchronizedList	listeners
	private const SynchronizedState	mutex
	
	new make(Drone drone, ActorPool actorPool) {
		this.actorPool	= actorPool
		this.listeners	= SynchronizedList(actorPool) { it.valType = |NavData|# }
		this.mutex		= SynchronizedState(actorPool) |->Obj?| {
			NavDataReaderImpl(drone)
		}
	}
	
	** Only internal listeners should be added here.
	Void addListener(|NavData| f) {
		listeners.add(f)
	}
	
	Void removeListener(|NavData| f) {
		listeners.remove(f)
	}
	
	NavData? connect() {
		// call synchronized so we know when we've connected
		mutex.getState |NavDataReaderImpl reader->NavData?| {
			reader.connect
			
			// check we have data coming through before we enter the loop
			navData := doReadNavData(reader)
			if (reader.connected && !actorPool.isStopped)
				readNavData
			
			return navData
		}
	}
	
	private Void readNavData() {
		mutex.withState |NavDataReaderImpl reader| {
			doReadNavData(reader)
			if (reader.connected && !actorPool.isStopped)
				readNavData
		}
	}

	private NavData? doReadNavData(NavDataReaderImpl reader) {
		navData := reader.receive
		if (navData != null) {
			// call internal listeners
			listeners.each {
				try ((|NavData|) it).call(navData)
				catch (Err err)	err.trace
			}
		}
		return navData
	}
	
	Void disconnect() {
		mutex.getState |NavDataReaderImpl reader| {
			reader.disconnect
		}
	}
}

internal class NavDataReaderImpl {
	Log				log		:= Drone#.pod.log
	Drone			drone
	UdpSocket		socket
	Bool			connected
	Int				lastSeqNum
	NavDataParser	parser	:= NavDataParser()
	UdpPacket		packet	:= UdpPacket(null, null, Buf(2560))
	
	new make(Drone drone) {
		this.drone  = drone
		this.socket = UdpSocket().connect(drone.networkConfig.droneIpAddr, drone.networkConfig.navDataPort) {
			it.options.receiveTimeout = drone.networkConfig.udpReceiveTimeout
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
		packet.data.flip.flip	// double flip to set size to zero
		packet.data.capacity = 2560
		try	socket.receive(packet)
		catch (IOErr err) {
			if (err.msg.contains("SocketTimeoutException")) {
				log.warn("Drone not connected (SocketTimeoutException on NavData read) - check your Wifi settings")
				drone._doDisconnect(true)
				return null
			}
			throw err
		}

		try {
			navData	:= parser.parse(packet.data.flip.with {
				it.endian = Endian.little
			})
			
			if (navData.seqNum < lastSeqNum && navData.seqNum != 1) {
				log.warn("Nav data out of sequence; expected > $lastSeqNum got $navData.seqNum")
				return null
			}

			lastSeqNum = navData.seqNum
			return navData
			
		} catch (Err err) {
			err.trace	// data parsing error - log it so we can fix it
			return null
		}
	}
	
	Void disconnect() {
		socket.disconnect
		connected = false
	}
}
