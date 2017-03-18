using concurrent::Actor
using concurrent::ActorPool
using concurrent::AtomicRef
using afConcurrent::Synchronized
using afConcurrent::SynchronizedState

** Utility class that attaches to a drone's 'onVideoFrame()' event.
** 
** Raw H.264 files can be converted (wrapped up in) to .mp4 files with the following ffmeg command:  
const class VideoStreamer {
	private const SynchronizedState			mutex
	private const |Buf, PaveHeader, Drone|	onVideoFrameListener := #onVideoFrame.func.bind([this])
	private const |Bool, Drone|				onDisconnectListener := #onDisconnect.func.bind([this])
	private const AtomicRef					pngImageRef			 := AtomicRef(null)
	private const AtomicRef					onPngImageRef		 := AtomicRef(null)
	private const Synchronized?				pngEventThread

	** The file that the video is saved to.
	const File? file
	
	** Returns the latest PNG image from the video stream.
	** Only available if FFMPEG is used for image encoding. See [toPngImages()]`toPngImages`. 
	Buf? pngImage() {
		pngImageRef.val
	}

	** Event hook that's called when a new PNG image becomes available.
	** 
	** Throws 'NotImmutableErr' if the function is not immutable.
	** Note this hook is called from a different Actor / thread to the one that sets it. 
	|Buf|? onPngImage {
		get { onPngImageRef.val }
		set { onPngImageRef.val = it?.toImmutable }
	}
	
	private new make(|This| f) { f(this) }

	static VideoStreamer toRawFile(Uri outputFile, Bool append := false, [Str:Obj]? options := null) {	
		if (outputFile.isDir)
			throw ArgErr("Output file is a directory: ${outputFile}")

		actorPool := options?.get("actorPool") ?: ActorPool()
		
		return VideoStreamer {
			it.file = append ? outputFile.toFile : addFileSuffix(outputFile)
			itFile := it.file
			it.mutex = SynchronizedState(actorPool) |->Obj| {
				VideoStreamerToH264File(itFile, append)
			}
		}
	}

	static VideoStreamer toMp4File(Uri outputFile, [Str:Obj]? options := null) {	
		if (outputFile.isDir)
			throw ArgErr("Output file is a directory: ${outputFile}")

		actorPool	:= options?.get("actorPool")	?: ActorPool()
		ffmpegPath	:= options?.get("ffmpegPath")	?: (Env.cur.os == "win32" ? `ffmpeg.exe` : `ffmpeg`)
		ffmpegArgs	:= options?.get("ffmpegArgs")	?: "-f h264 -i - -codec:v copy".split
		throttle	:= options?.get("throttle")		?: 50ms

		return VideoStreamer {
			itFile := addFileSuffix(outputFile)
			it.file = itFile
			it.mutex = SynchronizedState(actorPool) |->Obj| {
				VideoStreamerToMp4File(ffmpegPath, ffmpegArgs, itFile, actorPool, throttle)
			}
		}
	}

	static VideoStreamer toPngImages([Str:Obj]? options := null) {	
		actorPool	:= options?.get("actorPool")	?: ActorPool()
		ffmpegPath	:= options?.get("ffmpegPath")	?: (Env.cur.os == "win32" ? `ffmpeg.exe` : `ffmpeg`)
		ffmpegArgs	:= options?.get("ffmpegArgs")	?: "-f h264 -i - -f image2pipe -codec:v png -".split
		frameRate	:= options?.get("frameRate")
		throttle	:= options?.get("throttle")		?: 200ms	// 5 times a second should be fine for console output

		args := (Str[]) ffmpegArgs
		if (frameRate != null) {
			args = args.rw
			args.pop
			args.push("-r")
			args.push(frameRate)
			args.push("-")
		}

		return VideoStreamer {
			vs := it
			it.pngEventThread = Synchronized(actorPool)
			it.mutex = SynchronizedState(actorPool) |->Obj| {
				VideoStreamerToPngEvents(ffmpegPath, args, actorPool, throttle, #onNewPngImage.func.bind([vs]))
			}
		}
	}

	This attachTo(Drone drone) {
		oldVideoFrameHook := drone.onVideoFrame
		drone.onVideoFrame = |Buf payload, PaveHeader pave, Drone dron| {
			onVideoFrameListener(payload, pave, dron)
			oldVideoFrameHook?.call(payload, pave, dron)
		}
		
		oldDisconnectHook := drone.onDisconnect
		drone.onDisconnect = |Bool abnormal, Drone dron| {
			onDisconnectListener(abnormal, dron)
			oldDisconnectHook?.call(abnormal, dron)
		}

		// fire it up!
		mutex.sync |->| { }

		return this
	}
	
	Void close() {
		onDisconnect(false)
	}
	
	private Void onVideoFrame(Buf payload, PaveHeader pave) {
		if (!mutex.lock.actor.pool.isStopped)
			mutex.withState |VideoStreamerImpl state| {
				state.onVideoFrame(payload, pave)
			}
	}
	
	private Void onDisconnect(Bool abnormal) {
		if (!mutex.lock.actor.pool.isStopped)
			mutex.withState |VideoStreamerImpl state| {
				state.onDisconnect(abnormal)
			}
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
	OutStream	out

	new make(File file, Bool append) {
		this.out = file.out(append)
	}
	
	override Void onVideoFrame(Buf payload, PaveHeader pave) {
		out.writeBuf(payload).flush
	}

	override Void onDisconnect(Bool abnormal) {
		out.flush.close
	}
}

internal class VideoStreamerToMp4File : VideoStreamerImpl {
	Process2 ffmpegProcess

	new make(Uri ffmpegPath, Str[] ffmpegArgs, File output, ActorPool actorPool, Duration throttle) {
		// kick off an ffmpeg process
		ffmpegArgs = ffmpegArgs.rw
		ffmpegArgs.insert(0, ffmpegPath.toFile.normalize.osPath)
		ffmpegArgs.add(output.normalize.osPath)
		ffmpegProcess = Process2(ffmpegArgs) {
			it.actorPool = actorPool
			it.mergeErr = false
			it.env.clear
		}.run
		ffmpegProcess.pipeFromStdOut(Env.cur.out, throttle)
		ffmpegProcess.pipeFromStdErr(Env.cur.err, throttle)
	}
	
	override Void onVideoFrame(Buf payload, PaveHeader pave) {
		ffmpegProcess.stdIn.writeBuf(payload).flush
	}

	override Void onDisconnect(Bool abnormal) {
		ffmpegProcess.kill
	}
}

internal class VideoStreamerToPngEvents : VideoStreamerImpl {
	static const Log	log			:= Drone#.pod.log
	Process2 			ffmpegProcess
	|Buf|	 			onNewPngImage

	new make(Uri ffmpegPath, Str[] ffmpegArgs, ActorPool actorPool, Duration throttle, |Buf| onNewPngImage) {
		this.onNewPngImage = onNewPngImage

		// kick off an ffmpeg process
		ffmpegArgs = ffmpegArgs.rw
		ffmpegArgs.insert(0, ffmpegPath.toFile.normalize.osPath)
		ffmpegProcess = Process2(ffmpegArgs) {
			it.actorPool = actorPool
			it.mergeErr = false
			it.env.clear
		}.run
		ffmpegProcess.pipeFromStdErr(Env.cur.err, throttle)

		// kick off a thread to read data from the ffmpeg output
		pngReaderThread	:= Synchronized(actorPool)
		processRef		:= Unsafe(ffmpegProcess)
		pngReaderThread.async |->| {
			process		:= (Process2) processRef.val
			inStream	:= process.stdOut
			
			while (process.isAlive) {
				pngBuf := readPng(inStream)
				if (pngBuf != null)
					onNewPngImage(pngBuf.toImmutable)
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
