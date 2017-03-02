using [java] fanx.interop::Interop
using [java] fanx.interop::ByteArray
using [java] purejavahidapi::HidDevice
using [java] purejavahidapi::HidDeviceInfo
using [java] purejavahidapi::PureJavaHidApi
using [java] purejavahidapi::InputReportListener
using concurrent

class GameController {
	
	static Void main(Str[] args) {
		
		gamePadInfo := null as HidDeviceInfo
		devList := (HidDeviceInfo[]) Interop.toFan(PureJavaHidApi.enumerateDevices)
		devList.each |info| {
			echo("$info.getVendorId   $info.getProductId   $info.getManufacturerString   $info.getProductString   $info.getPath")
			if (info.getVendorId == 3727 && info.getProductId == 12557)
				gamePadInfo = info
		}

		oldDat := Buf()
		PureJavaHidApi.openDevice(gamePadInfo).setInputReportListener |HidDevice? source, Int id, ByteArray? data, Int len| {
			for (i := 0; i < data.size; ++i) {
				d:=data.get(i)
				Env.cur.out.print(d.and(0xFF).toHex(2)).print(" ")
			}
			Env.cur.out.printLine
			
		}
		
		Actor.sleep(20sec)
		
	}
	
}
