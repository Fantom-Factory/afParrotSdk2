using inet

internal class BareBonesFtp {
	private static const	Log	log	:= Drone#.pod.log

	Version readVersion(DroneConfig config) {
//		log.debug("FTP --- Opening TCP connection on ${config.droneIpAddr}::${config.ftpPort}")
		ctrlSock := TcpSocket().connect(config.droneIpAddr, config.ftpPort, config.tcpConnectTimeout) { it.options.receiveTimeout = config.tcpReceiveTimeout }
		line	 := null as Str
		readLine := |Int expectedStatus| {
			line = ctrlSock.in.readLine
//			log.debug("FTP <-- ${line}")
			if (!line.startsWith(expectedStatus.toStr))
				throw IOErr("Bad FTP Status - $line")
		}
		sendCmd  := |Str cmd| {
//			log.debug("FTP --> ${cmd}")
			ctrlSock.out.print("${cmd}\r\n").flush
		}
		
		readLine(220)		// 220 Operation successful

		sendCmd("PWD /")
		readLine(257)		// 257 "/"

		sendCmd("TYPE A")
		readLine(200)		// 220 Operation successful

		sendCmd("PASV")
		readLine(227)		// 227 PASV ok (192,168,1,1,172,139)
		
		// Fuck yeah! A line of magic!
		dataPort := (Int) line[12..<-1].split(',')[4..-1].reduce(0) |Int p, b, i| { p + ((i == 0 ? 256 : 1) * b.toStr.toInt) }
//		log.debug("FTP --- Opening TCP connection on ${config.droneIpAddr}::${dataPort}")
		dataSock := TcpSocket().connect(config.droneIpAddr, dataPort, config.tcpConnectTimeout) { it.options.receiveTimeout = config.tcpReceiveTimeout }

		sendCmd("RETR version.txt")
		readLine(150)		// 150 Opening BINARY connection for version.txt (6 bytes)		
		readLine(226)		// 226 Operation successful
		
		versionTxt := dataSock.in.readAllStr.trim
//		log.debug("FTP --- version.txt = ${versionTxt}")
		
		sendCmd("QUIT")
		readLine(221)		// 221 Operation successful

		ctrlSock.close
		dataSock.close

		return Version(versionTxt)
	}
	
	
	static Void main(Str[] args) {
		log.level = LogLevel.debug
		BareBonesFtp().readVersion(DroneConfig())
	}
}
