using concurrent::Actor
using concurrent::ActorPool
using concurrent::AtomicRef
using concurrent::AtomicBool
using afConcurrent::Synchronized
using afConcurrent::SynchronizedState

** Utility class that attaches to the drone's 'onVideoFrame()' event.
** Example usage:
** 
**   syntax: fantom
**   VideoStreamer.toMp4File(`droneStunts.mp4`).attachToLiveStream(drone)
** 
** Note some methods start and call out to an external [FFmpeg]`https://ffmpeg.org/` process for 
** video processing. Whilst this works for the limited functionality of these methods, this class 
** is not meant to an all-encompassing FFmpeg wrapper.
** 
** For ease of use, just put 'ffmpeg' in the same directory as your program. 
const class VideoStreamer {
	// FIXME move all data to sync state to prevent race conditions
	
	private const SynchronizedState			mutex
	private const AtomicRef					pngImageRef			 := AtomicRef(null)
	private const AtomicRef					onPngImageRef		 := AtomicRef(null)
	private const AtomicRef					droneRef		 	 := AtomicRef(null)
	private const AtomicRef					oldVideoFrameHookRef := AtomicRef(null)
	private const AtomicRef					oldDisconnectHookRef := AtomicRef(null)
	private const AtomicBool				attachedRef			 := AtomicBool()
	private const AtomicBool				recordStreamRef	 	 := AtomicBool()
	private const Synchronized?				pngEventThread

	** The 'onVideoFrame()' listener for this streamer, should you wish to attach / call it yourself
	const |Buf, PaveHeader, Drone|			onVideoFrameListener := #onVideoFrame.func.bind([this])

	** The 'onDisconnect()' listener for this streamer, should you wish to attach / call it yourself
	const |Bool, Drone|						onDisconnectListener := #onDisconnect.func.bind([this])

	** The output file that the video is saved to.
	** 
	** Only available if this 'VideoSteamer' instance was initialised via [toRawFile()]`VideoStreamer.toRawFile` or 
	** [toMp4File()]`VideoStreamer.toMp4File`. 
	const File? file
	
	** Returns the latest PNG image from the video stream.
	** 
	** Only available if this 'VideoSteamer' instance was initialised via [toPngImages()]`VideoStreamer.toPngImages`. 
	Buf? pngImage() {
		pngImageRef.val
	}

	** Event hook that's called when a new PNG image becomes available.
	** 
	** Only available if this 'VideoSteamer' instance was initialised via [toPngImages()]`VideoStreamer.toPngImages`. 
	** 
	** Throws 'NotImmutableErr' if the function is not immutable.
	** Note this hook is called from a different Actor / thread to the one that sets it. 
	|Buf|? onPngImage {
		get { onPngImageRef.val }
		set { onPngImageRef.val = it?.toImmutable }
	}
	
	private new make(|This| f) { f(this) }

	** Saves raw video frames to the given file. Example:
	** 
	**   syntax: fantom
	**   VideoStreamer.toRawFile(`droneStunts.h264`).attachToLiveStream(drone)
	** 
	** Note the video consists of raw H.264 codec frames and is not readily readable by anything 
	** (with the exception of VLC, try saving the file with a '.h264' extension.)
	** 
	** To wrap the file in a more usable '.mp4' container, try the following:
	** 
	**   C:\> ffmpeg -f h264 -i droneStunts.h264 -f mp4 -codec:v copy droneStunts.mp4
	** 
	** The input URI is given a unique numerical suffix to prevent file from being overwritten.
	** Example, 'drone.h264' may become 'drone-001F.h264'. See the `file` field to acquire the
	** actual file created.
	** 
	** Available options:
	** pre>
	** actorPool : (ActorPool) the ActorPool to use for thread processing
	**             Defaults to a new instance.
	** <pre
	static VideoStreamer toRawFile(Uri outputFile, [Str:Obj]? options := null) {	
		if (outputFile.isDir)
			throw ArgErr("Output file is a directory: ${outputFile}")

		actorPool := options?.get("actorPool") ?: ActorPool()

		return VideoStreamer {
			it.file = addFileSuffix(outputFile)
			itFile := it.file
			it.mutex = SynchronizedState(actorPool) |->Obj| {
				VideoStreamerToH264File(itFile, false)
			}
		}
	}

	** Saves the video stream as the given MP4 file. Example:
	** 
	**   syntax: fantom
	**   VideoStreamer.toMp4File(`droneStunts.mp4`).attachToLiveStream(drone)
	** 
	** Note this method starts an external FFmpeg process and pipes the raw video frames to it.
	** FFmpeg then wraps the video in an MP4 container and writes the file.
	**  
	** The input URI is given a unique numerical suffix to prevent file from being overwritten.
	** Example, 'drone.mp4' may become 'drone-001F.mp4'. See the `file` field to acquire the
	** actual file created.
	** 
	** Available options:
	** pre>
	** ffmpegPath : (Uri) the location of the FFmpeg executable.
	**              Defaults to `ffmpeg.exe` on Windows, 'ffmpeg' otherwise.
	** 
	** ffmpegArgs : (Str[]) an array of arguments for FFmpeg.
	**              Defaults to "-f h264 -i - -f mp4 -codec:v copy -movflags +faststart".split
	** 
	** quiet      : (Bool) if true, then FFmpeg console output is suppressed.
	**              Defaults to false.
	** 
	** actorPool  : (ActorPool) the ActorPool to use for thread processing
	**              Defaults to a new instance.
	** <pre
	** 
	** If no 'ffmpegPath' is given then FFmpeg is assumed to be in the current directory. 
	static VideoStreamer toMp4File(Uri outputFile, [Str:Obj]? options := null) {	
		if (outputFile.isDir)
			throw ArgErr("Output file is a directory: ${outputFile}")

		actorPool	:= options?.get("actorPool")	?: ActorPool() { it.name = typeof.name }
		ffmpegPath	:= options?.get("ffmpegPath")	?: (Env.cur.os == "win32" ? `ffmpeg.exe` : `ffmpeg`)
		ffmpegArgs	:= options?.get("ffmpegArgs")	?: "-f h264 -i - -f mp4 -codec:v copy -movflags +faststart".split
		quiet		:= options?.get("quiet")		?: false
		throttle	:= options?.get("throttle")		?: 200ms	// 5 times a second should be fine for console output
		
		return VideoStreamer {
			itFile := addFileSuffix(outputFile)
			it.file = itFile
			it.mutex = SynchronizedState(actorPool) |->Obj| {
				VideoStreamerToMp4File(ffmpegPath, ffmpegArgs, itFile, actorPool, throttle, quiet)
			}
		}
	}

	** Converts the video stream into a stream of PNG images. Example:
	** 
	**   syntax: fantom
	**   vs := VideoStreamer.toPngImages.attachToLiveStream(drone)
	**   vs.onPngImage = |Bug pngBuf| {
	**       echo("Got new image of size ${pngBuf.size}")
	**   }
	** 
	** The `pngImage` field always contains the latest PNG image data.
	** 
	** Use the [onPngImage()]`onPngImage` hook to be notified of new images.
	** 
	** Note this method starts an external FFmpeg process and pipes the raw video frames to it.
	** FFmpeg converts the video to PNG images and pipes it back to the 'VideoStreamer' instance.
	**  
	** Available options:
	** pre>
	** ffmpegPath : (Uri) the location of the FFmpeg executable.
	**              Defaults to `ffmpeg.exe` on Windows, 'ffmpeg' otherwise.
	** 
	** ffmpegArgs : (Str[]) an array of arguments for FFmpeg.
	**              Defaults to "-f h264 -i - -f image2pipe -codec:v png -".split
	** 
	** frameRate  : (Int?) The frame rate FFmpeg should enforce.
	**              Defaults to null - same as video input.
	** 
	** quiet      : (Bool) if true, then FFmpeg console output is suppressed.
	** 
	** actorPool  : (ActorPool) the ActorPool to use for thread processing
	**              Defaults to a new instance.
	** <pre
	** 
	** If no 'ffmpegPath' is given then FFmpeg is assumed to be in the current directory. 
	static VideoStreamer toPngImages([Str:Obj]? options := null) {	
		actorPool	:= options?.get("actorPool")	?: ActorPool()
		ffmpegPath	:= options?.get("ffmpegPath")	?: (Env.cur.os == "win32" ? `ffmpeg.exe` : `ffmpeg`)
		ffmpegArgs	:= options?.get("ffmpegArgs")	?: "-f h264 -i - -f image2pipe -codec:v png -".split
		frameRate	:= options?.get("frameRate")
		quiet		:= options?.get("quiet")		?: false
		throttle	:= options?.get("throttle")		?: 200ms	// 5 times a second should be fine for console output

		args := (Str[]) ffmpegArgs
		if (frameRate != null) {
			args = args.rw
			args.pop
			args.push("-r")
			args.push(frameRate)
			args.push("-")
		}
		iArgs := args.toImmutable

		return VideoStreamer {
			vs := it
			it.pngEventThread = Synchronized(actorPool)
			it.mutex = SynchronizedState(actorPool) |->Obj| {
				VideoStreamerToPngEvents(ffmpegPath, iArgs, actorPool, throttle, quiet, #onNewPngImage.func.bind([vs]))
			}
		}
	}

	** Attaches this instance to the given drone and starts stream processing.
	** 
	** This methods sets new 'onVideoFrame' and 'onDisconnect' hooks on the drone, but wraps any 
	** existing hooks. Meaning any hooks that were set previously, still get called.
	This attachToLiveStream(Drone drone) {
		if (droneRef.val != null)
			throw Err("Already attached to ${droneRef.val}")
		droneRef.val = drone

		recordStreamRef.val = false
		oldVideoFrameHookRef.val = drone.onVideoFrame
		drone.onVideoFrame = |Buf payload, PaveHeader pave, Drone dron| {
			onVideoFrameListener(payload, pave, dron)
			((Func?) oldVideoFrameHookRef.val)?.call(payload, pave, dron)
		}
		
		oldDisconnectHookRef.val = drone.onDisconnect
		drone.onDisconnect = |Bool abnormal, Drone dron| {
			onDisconnectListener(abnormal, dron)
			((Func?) oldDisconnectHookRef.val)?.call(abnormal, dron)
		}

		// fire it up! Sync so we can receive any ctor errors
		mutex.sync |->| { }

		attachedRef.val = true
		return this
	}
	
	** Attaches this instance to the given drone and starts stream processing.
	** 
	** This methods sets new 'onRecordFrame' and 'onDisconnect' hooks on the drone, but wraps any 
	** existing hooks. Meaning any hooks that were set previously, still get called.
	** 
	** Ensure you call 'Drone.startRecording()' before calling this.
	@NoDoc
	This attachToRecordStream(Drone drone) {
		if (droneRef.val != null)
			throw Err("Already attached to ${droneRef.val}")
		droneRef.val = drone

		recordStreamRef.val = true
		oldVideoFrameHookRef.val = drone.onRecordFrame
		drone.onRecordFrame = |Buf payload, PaveHeader pave, Drone dron| {
			onVideoFrameListener(payload, pave, dron)
			((Func?) oldVideoFrameHookRef.val)?.call(payload, pave, dron)
		}
		
		oldDisconnectHookRef.val = drone.onDisconnect
		drone.onDisconnect = |Bool abnormal, Drone dron| {
			onDisconnectListener(abnormal, dron)
			((Func?) oldDisconnectHookRef.val)?.call(abnormal, dron)
		}

		// fire it up! Sync so we can receive any ctor errors
		mutex.sync |->| { }

		attachedRef.val = true
		return this
	}
	
	** Reverts the 'onVideoFrame' and 'onDisconnect' hooks to what they were before 'attachTo()' 
	** was called.
	** Closes files and halts stream processing.
	Void detach() {
		onDisconnect(false)
	}
	
	private Void onVideoFrame(Buf payload, PaveHeader pave) {
		if (!mutex.lock.actor.pool.isStopped)
			mutex.withState |VideoStreamerImpl state| {
				state.onVideoFrame(payload, pave)
			}
	}
	
	private Void onDisconnect(Bool abnormal) {
		if (attachedRef.val.not) return
		
		if (!mutex.lock.actor.pool.isStopped)
			mutex.getState |VideoStreamerImpl state| {
				state.onDisconnect(abnormal)
			}

		// revert the drone hooks
		drone := (Drone) droneRef.val
		if (recordStreamRef.val)
			drone.onRecordFrame = oldVideoFrameHookRef.val
		else
			drone.onVideoFrame = oldVideoFrameHookRef.val
		drone.onDisconnect = oldDisconnectHookRef.val

		// only stop *our* ActorPools
		if (mutex.lock.actor.pool.name == typeof.name)
			mutex.lock.actor.pool.stop
	}
	
	private Void onNewPngImage(Buf buf) {
		pngEventThread.async |->| {
			callSafe(onPngImage, [buf])
		}
	}
	
	private File addFileSuffix(Uri fileLocation) {
		origFile := fileLocation.toFile.normalize
		index	 := 0
		file	 := null as File
		while (file == null || file.exists) {
			file = origFile.parent + (`${origFile.basename}-${index.toHex(4).upper}.${origFile.ext}`)
			index++
		}
		return file
	}
	
	private Void callSafe(Func? f, Obj[]? args) {
		try f?.callList(args)
		catch (Err err)
			err.trace
	}
}

internal mixin VideoStreamerImpl {
	abstract Void onVideoFrame(Buf payload, PaveHeader pave)
	abstract Void onDisconnect(Bool abnormal)
}

internal class VideoStreamerToH264File : VideoStreamerImpl {
	private static const Log log := VideoStreamer#.pod.log
	OutStream	out

	new make(File file, Bool append) {
		this.out = file.out(append)
		log.info("Streaming video to ${file.normalize.osPath}")
	}
	
	override Void onVideoFrame(Buf payload, PaveHeader pave) {
		out.writeBuf(payload).flush
	}

	override Void onDisconnect(Bool abnormal) {
		out.flush.close
	}
}

internal class VideoStreamerToMp4File : VideoStreamerImpl {
	private static const Log log := VideoStreamer#.pod.log
	Process2	ffmpegProcess

	new make(Uri ffmpegPath, Str[] ffmpegArgs, File output, ActorPool actorPool, Duration throttle, Bool quiet) {
		ffmpegFile := ffmpegPath.toFile.normalize
		if (!ffmpegFile.exists)
			throw IOErr("${ffmpegFile.osPath} does not exist")

		// kick off an ffmpeg process
		ffmpegArgs = ffmpegArgs.rw
		ffmpegArgs.insert(0, ffmpegFile.osPath)
		ffmpegArgs.add(output.normalize.osPath)
		ffmpegProcess = Process2(ffmpegArgs) {
			it.actorPool = actorPool
			it.mergeErr = false
			it.env.clear
		}.run

		ffmpegProcess.pipeFromStdOut(quiet ? null : Env.cur.out, throttle)
		ffmpegProcess.pipeFromStdErr(quiet ? null : Env.cur.err, throttle)
		
		log.info("Streaming video to ${output.normalize.osPath}")		
	}
	
	override Void onVideoFrame(Buf payload, PaveHeader pave) {
		if (ffmpegProcess.isRunning)
			ffmpegProcess.stdIn.writeBuf(payload).flush
	}

	override Void onDisconnect(Bool abnormal) {
		ffmpegProcess.kill
	}
}

internal class VideoStreamerToPngEvents : VideoStreamerImpl {
	private static const Log log := VideoStreamer#.pod.log
	Process2 	ffmpegProcess
	|Buf|	 	onNewPngImage

	new make(Uri ffmpegPath, Str[] ffmpegArgs, ActorPool actorPool, Duration throttle, Bool quiet, |Buf| onNewPngImage) {
		this.onNewPngImage = onNewPngImage
		
		ffmpegFile := ffmpegPath.toFile.normalize
		if (!ffmpegFile.exists)
			throw IOErr("${ffmpegFile.osPath} does not exist")

		// kick off an ffmpeg process
		ffmpegArgs = ffmpegArgs.rw
		ffmpegArgs.insert(0, ffmpegFile.osPath)
		ffmpegProcess = Process2(ffmpegArgs) {
			it.actorPool = actorPool
			it.mergeErr = false
			it.env.clear
		}.run
		
		ffmpegProcess.pipeFromStdErr(quiet ? null : Env.cur.err, throttle)

		// kick off a thread to read data from the ffmpeg output
		pngReaderThread	:= Synchronized(actorPool)
		processRef		:= Unsafe(ffmpegProcess)
		pngReaderThread.async |->| {
			process		:= (Process2) processRef.val
			inStream	:= process.stdOut
			
			while (process.isAlive) {
				pngBuf := readPng(inStream)
				if (pngBuf != null) {
					onNewPngImage(pngBuf.toImmutable)
					pngBuf.clear.trim
					pngBuf = null
				}
			}
		}
		return this
	}
	
	override Void onVideoFrame(Buf payload, PaveHeader pave) {
		ffmpegProcess.stdIn.writeBuf(payload).flush
	}

	override Void onDisconnect(Bool abnormal) {
		ffmpegProcess.kill
	}
	
	
	static Void main(Str[] args) {
		in := `file:/C:/Projects/Fantom-Factory/FormBean/doc/icon.png`.toFile.in
		out := readPng(in)
		`icon.png-bad`.toFile.out.writeBuf(out).close
		in.close
	}
	
	** Luckily, the PNG format is easy to read and easy to find the end of and image.
	static Buf? readPng(InStream in) {
		pngMagicNum := 0x89_50_4E_47_0D_0A_1A_0A
		try {
			pngBuf := Buf() { endian = Endian.big }
			bufMagicNum := in.readS8
			pngBuf.writeI8(bufMagicNum)
			if (bufMagicNum != pngMagicNum)
				log.warn("Invalid PNG Magic Num: 0x${bufMagicNum}")
			pngEnd := false
			while (!pngEnd) {
				chunkSize	:= in.readU4
				chunkType	:= in.readChars(4)
				pngBuf.writeI4(chunkSize)
				pngBuf.writeChars(chunkType)
				in.readBufFully(pngBuf, chunkSize + 4).seek(pngBuf.size)	// 4 bytes = CRC
				pngEnd 		= (chunkType == "IEND")							// 0x "49 45 4e 44"
			}
			return pngBuf.flip

		} catch (IOErr ioe) {
			// meh - we usually get 'Unexpected end of stream' when then FFMPEG is killed
		} catch (Err err) {
			log.err("VideoStreamerToPngEvents - ${err.typeof} - ${err.msg}")
		}
		return null
	}
}
