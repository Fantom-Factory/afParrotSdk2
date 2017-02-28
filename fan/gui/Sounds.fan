
internal class Sounds : SoundClips {
	
	SoundClip	beep() 		{ load("beep.wav") }

	SoundClip	takingOff() { load("takingOff.wav")	}
	SoundClip	takeOff() 	{ load("takeOff.wav") }		// TODO rename / resample flying
	SoundClip	landing() 	{ load("landing.wav") }
	SoundClip	landed() 	{ load("landed.wav") }

	
	SoundClip load(Str name) {
		loadSoundClip(`fan://${typeof.pod}/res/${name}`)
	}
	
	SoundClip[] preloadSounds() {
		typeof.methods.findAll |method| {
			(method.returns == SoundClip#) && (method.isPublic) && (!method.isStatic) && (method.params.size == 0)
		}.map |Method method->SoundClip| {
			method.callOn(this, null)
		}
	}
}
