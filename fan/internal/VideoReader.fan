using concurrent::Actor
using concurrent::ActorPool
using afConcurrent::SynchronizedList
using afConcurrent::SynchronizedState
using inet::TcpSocket

internal const class VideoReader {
	private const Log				log		:= Drone#.pod.log
	
	private const ActorPool			actorPool
	private const SynchronizedList	listeners
	private const SynchronizedState	mutex
	
	new make(Drone drone, ActorPool actorPool) {
		this.actorPool	= actorPool
		this.listeners	= SynchronizedList(actorPool) { it.valType = |Buf, PaveHeader|# }
		this.mutex		= SynchronizedState(actorPool) |->Obj?| {
			VideoReaderImpl(drone)
		}
	}
	
	** Only internal listeners should be added here.
	Void addListener(|Buf, PaveHeader| f) {
		listeners.add(f)
	}
	
	Void removeListener(|Buf, PaveHeader| f) {
		listeners.remove(f)
	}
	
	Void connect() {
		// call synchronized so we know when we've connected
		mutex.withState |VideoReaderImpl reader| {
			reader.connect
			
			if (reader.isConnected && !actorPool.isStopped)
				readVidData
		}
	}
	
	Bool isConnected() {
		mutex.getState |VideoReaderImpl reader| {
			reader.isConnected
		}
	}

	Void disconnect() {
		mutex.getState |VideoReaderImpl reader| {
			reader.disconnect
		}
	}

	private Void readVidData() {
		mutex.withState |VideoReaderImpl reader| {
			doReadVidData(reader)
			if (reader.isConnected && !actorPool.isStopped)
				readVidData
		}
	}

	private PaveHeader? doReadVidData(VideoReaderImpl reader) {
		pave := reader.receive
		if (pave != null) {
			// call internal listeners
			listeners.each {
				try ((|Buf, PaveHeader|) it).call(pave.payload, pave)
				catch (Err err)	err.trace
			}
		}
		return pave
	}
}

	
internal class VideoReaderImpl {
	const Log			log		:= Drone#.pod.log
	const Drone			drone
	const NetworkConfig	config
		  TcpSocket?	socket
	
	new make(Drone drone) {
		this.drone	= drone
		this.config = drone.networkConfig
	}

	Void connect() {
		if (isConnected)
			disconnect
		
		this.socket	= TcpSocket {
			it.options.receiveTimeout = config.tcpReceiveTimeout
		}.connect(config.droneIpAddr, config.videoPort, config.actionTimeout)
	}

	Bool isConnected() {
		socket != null && socket.isConnected
	}

	Void disconnect() {
		socket?.close
		socket = null
	}
	
	PaveHeader? receive() {
		in := socket.in { endian = Endian.little }
		
		try
			// TODO may need to wait until we have all the header data -> readBufFully()
			return PaveHeader {
				signature			= in.readChars(4)
				version				= uint8(in)
				videoCodec			= uint8(in)
				headerSize			= uint16(in)
				payloadSize			= uint32(in)
				encodedStreamWidth	= uint16(in)
				encodedStreamHeight	= uint16(in)
				displayWidth 		= uint16(in)
				displayHeight		= uint16(in)
				frameNumber			= uint32(in)
				timestamp			= 1ms * uint32(in)
				totalChunks			= uint8(in)
				chunkIndex			= uint8(in)
				frameType			= uint8(in)
				control				= uint8(in)
				streamBytePosition	= uint32(in) + (uint32(in).shiftl(32))
				streamId			= uint16(in)
				totalSlices			= uint8(in)
				sliceIndex			= uint8(in)
				header1Size			= uint8(in)
				header2Size			= uint8(in)
				in.skip(2)
				advertisedSize		= uint32(in)
				in.skip(12)
			
				if (signature != "PaVE")
					// meh - lets carry on regardless
					log.warn("Invalid PaVE signature: ${signature}")
				
				// stupid kludge for https://projects.ardrone.org/issues/show/159
				in.skip(headerSize - 64)
				
				payload = in.readBufFully(null, payloadSize)
			}

		catch (Err err) {
			// log err as this could mess up our position in the stream
			// TODO maybe auto-disconnect / re-connect to re-establish stream position?
			log.err("Could not decode Video data - $err.msg")
			return null
		}
	}

	private static Bool		bool	(InStream in) { in.readU1 != 0 }
	private static Int		uint8	(InStream in) { in.readU1 }
	private static Int		uint16	(InStream in) { in.readU2 }
	private static Int		uint32	(InStream in) { in.readU4 }
	private static Int		int16	(InStream in) { in.readS2 }
	private static Int		int32	(InStream in) { in.readS4 }
	private static Int		int64	(InStream in) { in.readS8 }
	private static Float	float32	(InStream in) { Float.makeBits32(in.readU4) }
	private static Float	double64(InStream in) { Float.makeBits(in.readS8) }
}

** Parrot Video Encapsulation (PaVE) headers for video frame data.
** Passed to the [drone.onVideoFrame()]`Drone.onVideoFrame` event hook. 
const class PaveHeader {
	** "PaVE" - used to identify the start of frame
	const Str signature
	
	** Version code
	const Int version
	
	** Codec of the following frame
	const Int videoCodec

	** Size of the parrot_video_encapsulation_t
	const Int headerSize

	** Amount of data following this PaVE
	const Int payloadSize
	
	** Example: 640
	const Int encodedStreamWidth

	** Example: 368
	const Int encodedStreamHeight
	
	** Example: 640
	const Int displayWidth

	** Example: 360
	const Int displayHeight

	** Frame position inside the current stream
	const Int frameNumber
	
	** In milliseconds
	const Duration timestamp

	** Number of UDP packets containing the current decodable payload - currently unused
	const Int totalChunks

	** Position of the packet - first chunk is #0 - currenty unused
	const Int chunkIndex

	** I-frame, P-frame - parrot_video_encapsulation_frametypes_t
	const Int frameType

	** Special commands like end-of-stream or advertised frames
	const Int control

	** Byte position of the current payload in the encoded stream
	const Int streamBytePosition

	** This ID indentifies packets that should be recorded together
	const Int streamId

	** Number of slices composing the current frame
	const Int totalSlices

	** Position of the current slice in the frame
	const Int sliceIndex

	** H.264 only : size of SPS inside payload - no SPS present if value is zero
	const Int header1Size

	** H.264 only : size of PPS inside payload - no PPS present if value is zero
	const Int header2Size

	** Size of frames announced as advertised frames
	const Int advertisedSize	
	
	** The raw video frame data 
	const Buf payload
	
	@NoDoc
	new make(|This| f) { f(this) }
}