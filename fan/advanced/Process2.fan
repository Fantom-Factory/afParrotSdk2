using [java] fanx.interop::Interop
using [java] java.lang::IllegalThreadStateException	as JIllegalThreadStateException
using [java] java.lang::Process						as JProcess
using [java] java.lang::ProcessBuilder				as JProcessBuilder
using [java] java.util::Map$Entry					as JEntry
using [java] java.util.concurrent::TimeUnit			as JTimeUnit
using concurrent::Actor
using concurrent::ActorPool
using afConcurrent::Synchronized

** Process manages spawning external OS processes.
** Goes one better than the standard 'sys::Process' as this constantly stream keyboard input to the new process.
@NoDoc
class Process2 {
	private JProcess?	_jProc
	private OutStream?	_stdIn
	private InStream?	_stdOut
	private InStream?	_stdErr

	** The 'ActorPool' used to control the pipe threads.
	** Leave as 'null' to create a default 'ActorPool'.
	ActorPool?	actorPool {
		set { checkRun; &actorPool = it }		
	}

	** Command argument list used to launch process.
	** The first item is the executable itself, then rest are the parameters.
	Str[] command {
		set { checkRun; &command = it }
	}

	** Working directory of process.
	File? dir {
		set { checkRun; &dir = it }
	}

	** If true, then stderr is redirected to the output stream configured via the 'out' field, and the 'err'
	** field is ignored.  The default is 'true'.
	Bool mergeErr := true {
		set { checkRun; &mergeErr = it }		
	}
	
	** Environment variables to pass to new process as a mutable map of string key/value pairs.
	** This map is initialised with the current process environment.
	Str:Str env {
		set { checkRun; &env = it }		
	}
	
	** Construct a Process instanced used to launch an external OS process with the specified command arguments.
	** The first item in the 'cmd' list is the executable itself, then rest are the parameters.
	new make(Str[] cmd := Str[,], File? dir := null) {
		this.command = cmd
		this.dir	 = dir
		
		&env = Str:Str[:]
		itr := JProcessBuilder((Str[]) Str#.emptyList).environment.entrySet.iterator
		while (itr.hasNext) {
			entry := (JEntry) itr.next
			&env[entry.getKey] = entry.getValue
		}
	}

	** Spawn this process.
	** See `join` to wait until the process has finished and get the exit code.
	** Return this.
	This run() {
		checkRun

		builder := JProcessBuilder(command)
		
		envMap	:= builder.environment
		env.each |v, k| {
			envMap.put(k, v)
		}

		if (dir != null)
			builder.directory(Interop.toJava(dir))
		
		builder.redirectErrorStream(mergeErr)
		
		_jProc 	= builder.start
		_stdIn	= Interop.toFan(_jProc.getOutputStream, 0)
		_stdOut	= Interop.toFan(_jProc.getInputStream,  0)
		_stdErr	= Interop.toFan(_jProc.getErrorStream,  0)
		
		return this
	}

	** The stream that gets piped to StdIn.
	** May only be called once the process has started.
	OutStream stdIn() {
		checkNotRun._stdIn		
	}

	** The stream that reads from StdOut.
	** May only be called once the process has started.
	InStream stdOut() {
		checkNotRun._stdOut		
	}

	** The stream that reads from StdErr. Returns 'null' if 'mergeErr' is 'true'.
	** May only be called once the process has started.
	InStream? stdErr() {
		mergeErr ? null : checkNotRun._stdErr		
	}

	** Wait for this process to exit and return the exit code.
	** This method may only be called once after 'run'.
	Int join(Duration? timeout := null) {
		if (_jProc == null) throw Err("Process not running")
		try return timeout == null
			? _jProc.waitFor
			: _jProc.waitFor(timeout.toMillis, JTimeUnit.MILLISECONDS)
		finally {
			actorPool.stop
			_stdIn	= null
			_stdOut	= null
			_stdErr	= null
			_jProc	= null
		}
	}

	** Kill this process.  Returns this.
	This kill() {
		if (_jProc == null) throw Err("Process not running")
		try {
			_jProc.destroy
			return this
		}
		finally {
			actorPool.stop
			_stdIn	= null
			_stdOut	= null
			_stdErr	= null
			_jProc	= null
		}
	}
	
	Bool isAlive() {
		// hacky to use exception for flow control, but there
		// doesn't seem to be any other way to check state
		try {
			return _jProc == null ? false : _jProc.exitValue
		} catch (Err err) {
			if (Interop.toJava(err) is JIllegalThreadStateException)
				return true
		}
		return false
	}
	
	** Launches a new thread that constantly streams the given 'InStream' to stdIn.
	** The thread terminates once the process has finished.
	Void pipeToStdIn(InStream in, Duration throttle := 20ms) {
		PipeInToOut(getActorPool, this, in, stdIn, throttle).pipe
	}
	
	** Launches a new thread that constantly streams stdOut to the given 'OutStream'.
	** The thread terminates once the process has finished.
	Void pipeFromStdOut(OutStream out, Duration throttle := 20ms) {
		PipeInToOut(getActorPool, this, stdOut, out, throttle).pipe
	}
	
	** Launches a new thread that constantly streams stdOut to the given 'OutStream'.
	** The thread terminates once the process has finished.
	** 
	** Does nothing if 'mergeErr' is 'true'.
	Void pipeFromStdErr(OutStream err, Duration throttle := 20ms) {
		if (!mergeErr)
			PipeInToOut(getActorPool, this, stdErr, err, throttle).pipe
	}
	
	private ActorPool getActorPool() {
		if (&actorPool == null)
			&actorPool = ActorPool() { it.name = "Process: ${command.first}" }
		return &actorPool
	}
	
	private This checkRun() {
		if (_jProc != null) throw Err.make("Process already run")
		return this
	}

	private This checkNotRun() {
		if (_jProc == null) throw Err.make("Process has not been created")
		return this
	}
}

internal const class PipeInToOut {
	private const Synchronized		thread
	private const Unsafe			inStreamRef
	private const Unsafe			outStreamRef
	private const Unsafe			processRef
	private const Duration			throttle
	
	new make(ActorPool actorPool, Process2 process, InStream? inStream, OutStream? outStream, Duration throttle) {
		this.thread			= Synchronized(actorPool)
		this.outStreamRef	= Unsafe(outStream)
		this.inStreamRef	= Unsafe(inStream)
		this.processRef		= Unsafe(process)
		this.throttle		= throttle
	}

	This pipe() {
		thread.async |->| {
			inStream	:= (InStream? )	inStreamRef .val
			outStream	:= (OutStream?)	outStreamRef.val
			process		:= (Process2)	processRef.val
			
			if (inStream != null)
				while (process.isAlive) {

					// read & write bytes
					while (inStream.avail > 0) {
						ch := inStream.read
						if (ch != null)
							outStream?.write(ch)
					}
					outStream?.flush

					// lets not hammer the thread waiting for key inputs!
					Actor.sleep(throttle)
				}
		}
		return this
	}
}
