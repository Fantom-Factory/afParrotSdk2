using concurrent::AtomicRef

** Creates a 'NavData' instance from the contents of a UDP payload. 
internal class NavDataParser {
	private const Log		log	:= Drone#.pod.log

	// It appears there are 2 header numbers
	// see https://github.com/felixge/node-ar-drone/blob/master/lib/navdata/parseNavdata.js#L592
	private static const Int navDataHeader1	:= 0x55667788
	private static const Int navDataHeader2	:= 0x55667789
	
	NavData parse(Buf navDataBuf) {
		in := navDataBuf.in
		in.endian = Endian.little
		
		header := in.readS4
		if (header != navDataHeader1 && header != navDataHeader2)
			throw Err("Nav Data Magic Number [${header}] does not equal 0x${navDataHeader1.toHex.upper}")
		
		flags		:= NavDataFlags(in.readU4)
		seqNum		:= in.readU4
		visionFlag	:= in.readU4
		options		:= NavOption:LazyNavOptData[:]
		
		while (in.avail > 0) {
			optionId  := in.readU2
			optionLen := in.readU2

			if (optionId == 0xFFFF) {
				chkSum	 := in.readU4
				navDataBuf.size = navDataBuf.pos - 8
				navDataBuf.trim
				chkSumIn := navDataBuf.flip.in
				myChkSum := 0
				while (chkSumIn.avail > 0) { myChkSum += chkSumIn.read }
			
				if (chkSum != myChkSum)
					throw IOErr("Invalid NavData checksum; expected 0x${chkSum} got 0x${myChkSum}")
				continue
			}
			
			if (optionId > NavOption.unknown2.flag) {
				log.warn("Unknown NavOption value: ${optionId}")
				in.skip(optionLen - 4)
				continue
			}

			navOption	:= (NavOption) NavOption.vals[optionId]
			rawOpt 		:= in.readBufFully(null, optionLen - 4) { it.endian = Endian.little }
			options[navOption] = LazyNavOptData(rawOpt, navOption.parseMethod)
		}
		
		return NavData {
			it.flags		= flags
			it.seqNum		= seqNum
			it.visionFlag	= visionFlag
			it._lazyOpts	= options
		}
	}
}

internal const class LazyNavOptData {
	private const Buf		optRaw
	private const Method	parseMethod
	private const AtomicRef	optRef	:= AtomicRef(null)

	new make(Buf optRaw, Method parseMethod) {
		this.optRaw = optRaw.toImmutable
		this.parseMethod = parseMethod
	}
	
	Obj get() {
		if (optRef.val == null)
			optRef.val  = parseMethod.call(optRaw.in { endian = Endian.little }).toImmutable
		return optRef.val
	}
}
