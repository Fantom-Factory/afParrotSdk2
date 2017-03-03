using inet::TcpSocket

internal const class ControlReader {
	private const Log				log		:= Drone#.pod.log
	private const Drone				drone
	
	new make(Drone drone) {
		this.drone	= drone
	}
	
	Str:Str read() {
		config := drone.networkConfig

		socket := TcpSocket {
			it.options.receiveTimeout = config.tcpReceiveTimeout
		}.connect(config.droneIpAddr, config.controlPort, config.actionTimeout)
		
//		NavDataLoop.waitForAckClear	(drone, config.configCmdAckClearTimeout, true)
//		cmdSender.send(Cmd.makeConfig(key, val))
//		NavDataLoop.waitForAck		(this, networkConfig.configCmdAckTimeout, block)
//		NavDataLoop.waitForAckClear	(this, networkConfig.configCmdAckClearTimeout, block)

		try {
			drone.sendCmd(Cmd.makeCtrl(4, 0))
			
			// config is usually ~ 4.5 KB
			configStr := socket.in.readNullTerminatedStr(1024 * 8)

			echo("################### $configStr.in.readProps")
			return Str:Str[:] { caseInsensitive=true }.addAll(configStr.in.readProps)
		} finally			
			socket.close
	}
}
