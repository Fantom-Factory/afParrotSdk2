using concurrent::Actor
using concurrent::ActorPool
using concurrent::AtomicRef
using afConcurrent::SynchronizedList
using afConcurrent::SynchronizedState
using inet::TcpSocket

internal const class VideoReader {
	private const Log				log		:= Drone#.pod.log
	
	private const Drone				drone
	private const ActorPool			actorPool
	private const AtomicRef			frameListenerRef	:= AtomicRef()
	private const AtomicRef			errorListenerRef	:= AtomicRef()
	private const SynchronizedState	mutex
	private const Int				port
	
	new make(Drone drone, ActorPool actorPool, Int port) {
		this.drone		= drone
		this.actorPool	= actorPool
		this.port		= port
		this.mutex		= SynchronizedState(actorPool) |->Obj?| {
			VideoReaderImpl(drone.networkConfig, port)
		}
	}
	
	** Only internal listeners should be added here.
	Void setFrameListener(|Buf, PaveHeader| f) {
		frameListenerRef.val = f
	}
	
	Void setErrorListener(|Err| f) {
		errorListenerRef.val = f
	}
	
	Void connect() {
		mutex.getState |VideoReaderImpl reader| {
//		mutex.withState |VideoReaderImpl reader| {
			reader.connect
			
			if (reader.isConnected && !actorPool.isStopped)
				readVidData
		}
	}
	
	Bool isConnected() {
		mutex.getState |VideoReaderImpl reader->Bool| {
			reader.isConnected
		}
	}

	Void disconnect() {
		if (!mutex.lock.actor.pool.isStopped)
			try mutex.getState |VideoReaderImpl reader| {
				reader.disconnect
			}
			catch { /* meh */ }

		frameListenerRef.val = null
		errorListenerRef.val = null
	}

	private Void readVidData() {
		mutex.withState |VideoReaderImpl reader| {
			doReadVidData(reader)
			if (reader.isConnected && !actorPool.isStopped)
				readVidData
		}
	}

	private Void doReadVidData(VideoReaderImpl reader) {
		pave := null as PaveHeader
		
		try	pave = reader.receive
		catch (IOErr err)
			// drone.isConnected is set to false *before* we stop the ActorPool
			if (drone.isConnected)
				((|Err|?) errorListenerRef.val)?.call(err)

		catch (Err err)
			((|Err|?) errorListenerRef.val)?.call(err)
		
		// call internal listeners
		if (pave != null)
			((|Buf, PaveHeader|?) frameListenerRef.val)?.call(pave.payload, pave)

		pave = null
	}
}

	
internal class VideoReaderImpl {
	const Log			log		:= Drone#.pod.log
	const Int			port
	const NetworkConfig	config
		  TcpSocket?	socket
	
	new make(NetworkConfig config, Int port) {
		this.config = config
		this.port	= port
	}

	Void connect() {
		if (isConnected)
			disconnect
		
		this.socket	= TcpSocket {
			it.options.receiveTimeout = config.tcpReceiveTimeout
		}.connect(config.droneIpAddr, port, config.actionTimeout)
	}

	Bool isConnected() {
		socket != null && socket.isConnected
	}

	Void disconnect() {
		socket?.close
		socket = null
	}
	
	PaveHeader? receive() {
		if (socket == null)	return null
		in := socket.in { endian = Endian.little }
		
		// may need to wait until we have all the header data -> readBufFully() ??
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