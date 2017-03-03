using [java] fanx.interop::Interop
using [java] javax.sound.sampled::AudioSystem
using [java] javax.sound.sampled::AudioFormat
using [java] javax.sound.sampled::Clip
using [java] javax.sound.sampled::DataLine$Info as Info
using [java] javax.sound.sampled::FloatControl
using [java] javax.sound.sampled::FloatControl$Type as FType

internal class SoundClips {
	private const Log		log			:= typeof.pod.log
	private Str:SoundClip	soundClips	:= Str:SoundClip[:]

	Void stopAll() {
		soundClips.each |soundClip| {
			soundClip.stop
		}
	}
	
	SoundClip loadSoundClip(Uri soundUrl) {
		soundClips.getOrAdd(soundUrl.toStr) |->SoundClip| {
			return Env.cur.runtime == "js"
				? typeof.pod.type("SoundClipJs"  ).make([soundUrl])
				: typeof.pod.type("SoundClipJava").make([soundUrl])
		}
	}
}

internal mixin SoundClip {
	abstract Float volume
	abstract Bool loaded()
	abstract Void play()
	abstract Void stop()
}

internal class SoundClipJava : SoundClip {
	private Uri		soundUri
	private Clip	clip
	
	new make(Uri soundUri) {
		soundFile			:= soundUri.get as File
		soundStream 		:= Interop.toJava(soundFile.in)
	    audioInputStream	:= AudioSystem.getAudioInputStream(soundStream)
   	 	audioFormat			:= audioInputStream.getFormat
    	dataLineInfo		:= Info(Clip#->toClass, audioFormat)
        clip 				:= AudioSystem.getLine(dataLineInfo) as Clip
        clip.open(audioInputStream)
		
		this.clip		= clip
		this.soundUri	= soundUri
	}
	
	// see http://stackoverflow.com/questions/40514910/set-volume-of-java-clip/40698149#40698149
	override Float volume {
		get {
			gainControl	:= (FloatControl) clip.getControl(FType.MASTER_GAIN)
			return 10f.pow(gainControl.getValue / 20f)
		}
		set {
			if (it < 0f || it > 1f)
				throw ArgErr("Invalid volume: $it")
			gainControl	:= (FloatControl) clip.getControl(FType.MASTER_GAIN)
			gainControl.setValue(20f * it.log10)
		}
	}
	
	override Bool loaded() { true }
	
	override Void play() {
		stop
		clip.setFramePosition(0)
		clip.start
	}
	
	override Void stop() {
		if (clip.isRunning) {
			clip.stop
			clip.flush
		}
	}
	
	override Str toStr() {
		soundUri.name
	}
}
