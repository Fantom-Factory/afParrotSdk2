//using afParrotSdk2
using fwt::Canvas
using fwt::Desktop
using fwt::Window
using gfx::Graphics
using gfx::Image
using gfx::Size

** Use the Drone like a web cam.
class VideoExample {
	CamCanvas canvas := CamCanvas()

	Void main() {
		thisRef	 := Unsafe(this)
		drone	 := Drone().connect
		streamer := VideoStreamer.toPngImages.attachToLiveStream(drone)
		streamer.onPngImage = |Buf pngBuf| {
			Desktop.callAsync |->| {
				thisRef.val->canvas->onPngImage(pngBuf)
			}
		}

		Window() {
			it.title = "AR Drone Cam"
			it.size	 = Size(640, 360)
			it.add(canvas)
		}.open

		drone.disconnect
	}
}

class CamCanvas : Canvas {
	Image? pngImage
	
	Void onPngImage(Buf pngBuf) {
		// you get a MASSIVE memory leak if you don't call this!
		pngImage?.dispose
		
		// note this creates is an in-memory file, not a real file
		pngImage = Image(pngBuf.toFile(`droneCam.png`))
		this.repaint
	}

	override Void onPaint(Graphics g) {
		if (pngImage != null)
			g.drawImage(pngImage, 0, 0)
	}
}
