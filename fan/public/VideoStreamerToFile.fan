using concurrent::ActorPool
using afConcurrent::SynchronizedState

** Raw H.264 files can be converted (wrapped up in) to .mp4 files with the following ffmeg command:  
const class VideoStreamerToFile {
	private const SynchronizedState mutex

	** The file that the video is saved to.
	const File file
	
	** The hook used to capture video frame events
	const |Buf, PaveHeader, Drone| onVideoFrameListener := #onVideoFrame.func.bind([this])
	
	** The hook used to capture disconnect events
	const |Bool, Drone| onDisconnectListener := #onDisconnect.func.bind([this])

//	VideoStreamer toFile(Uri fileLocation, Bool append := false) {		
//	}

	new make(Uri fileLocation, Bool append := false) {
		if (fileLocation.isDir)
			throw ArgErr("File location is a directory: ${fileLocation}")
		
		file = append ? fileLocation : addFileSuffix(fileLocation)
		mutex = SynchronizedState(ActorPool()) |->Obj| {
			VideoStreamerToFileImpl(file, append)
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
		
		return this
	}
	
	Void close() {
		onDisconnect(false)
	}
	
	private Void onVideoFrame(Buf payload, PaveHeader pave) {
		mutex.withState |VideoStreamerToFileImpl state| {
			state.onVideoFrame(payload, pave)
		}
	}
	
	private Void onDisconnect(Bool abnormal) {
		mutex.withState |VideoStreamerToFileImpl state| {
			state.onDisconnect(abnormal)
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
}

internal class VideoStreamerToFileImpl {
	OutStream	out

	new make(File file, Bool append) {
		this.out = file.out(append)
	}
	
	Void onVideoFrame(Buf payload, PaveHeader pave) {
		out.writeBuf(payload).flush
	}

	Void onDisconnect(Bool abnormal) {
		out.flush.close
	}
}
