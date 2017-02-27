using concurrent::Actor
using concurrent::ActorPool
using afConcurrent::SynchronizedList
using afConcurrent::SynchronizedState
using inet::IpAddr
using inet::UdpSocket
using inet::UdpPacket

internal const class NavDataReader {
	private const ActorPool			actorPool
	private const DroneConfig		config
	private const SynchronizedState	mutex
	private const SynchronizedList	listeners
	
	new make(Drone drone, ActorPool actorPool, DroneConfig config) {
		this.mutex		= SynchronizedState(actorPool) |->Obj?| {
			NavDataReaderImpl(drone, config.droneIpAddr, config.navDataPort, config.udpReceiveTimeout)
		}
		this.listeners	= SynchronizedList(actorPool) {
			it.valType	= |NavData|#
		}
		this.config		= config
		this.actorPool	= actorPool
	}
	
	** Only internal listeners should be added here.
	Void addListener(|NavData| f) {
		listeners.add(f)
	}
	
	Void removeListener(|NavData| f) {
		listeners.remove(f)
	}
	
	Void connect() {
		// call synchronized so we know when we've connected
		mutex.getState |NavDataReaderImpl reader| {
			reader.connect
			if (reader.connected && !actorPool.isStopped)
				readNavData
		}
	}
	
	private Void readNavData() {
		mutex.withState |NavDataReaderImpl reader| {
			navData := reader.receive
			if (navData != null) {
				listeners.each {
					try ((|NavData|) it).call(navData)
					catch (Err err)	err.trace
				}
			}
			if (reader.connected && !actorPool.isStopped)
				readNavData
		}
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
	
	new make(Drone drone, Str ipAddr, Int port, Duration receiveTimeout) {
		this.drone  = drone
		this.socket = UdpSocket().connect(IpAddr(ipAddr), port) {
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
					log.warn("Drone not connected (SocketTimeoutException on navData read) - check your Wifi settings")
					drone.doDisconnect(true)
					return null
				}
				throw err
			}

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