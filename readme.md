#Parrot Drone SDK 2 v0.0.6
---

[![Written in: Fantom](http://img.shields.io/badge/written%20in-Fantom-lightgray.svg)](http://fantom-lang.org/)
[![pod: v0.0.6](http://img.shields.io/badge/pod-v0.0.6-yellow.svg)](http://www.fantomfactory.org/pods/afParrotSdk2)
![Licence: ISC](http://img.shields.io/badge/licence-ISC-blue.svg)

## Overview

The Parrot Drone SDK 2 is a pure [Fantom](http://fantom-lang.org/) implementation of the Parrot SDK 2.0 that lets you pilot your [AR Drone](https://www.parrot.com/uk/drones/parrot-ardrone-20-elite-%C3%A9dition) quadcopter remotely via Fantom programs.

It's an intuitive and simple API that'll have you flying your drone in minutes!

![Parrot AR Drone](http://eggbox.fantomfactory.org/pods/afParrotSdk2/doc/arDrone.png)

The Fantom SDK features:

- Blocking & non-blocking drone movement methods
- Feedback events with telemetry, flight, and drone data
- Video stream processing
- FFmpeg integration for video conversion
- Pre-programmed flight stunts and LED patterns
- Read and write drone configuration
- Full decoding of all navigation option data
- Exit strategy to guard against run-away drones when your program crashes!

For more information on the AR Drone, see the AR Drone Developer Guide in the official [Parrot SDK 2.0](http://developer.parrot.com/docs/SDK2/) (for C).

## Install

Install `Parrot Drone SDK 2` with the Fantom Pod Manager ( [FPM](http://eggbox.fantomfactory.org/pods/afFpm) ):

    C:\> fpm install afParrotSdk2

Or install `Parrot Drone SDK 2` with [fanr](http://fantom.org/doc/docFanr/Tool.html#install):

    C:\> fanr install -r http://eggbox.fantomfactory.org/fanr/ afParrotSdk2

To use in a [Fantom](http://fantom-lang.org/) project, add a dependency to `build.fan`:

    depends = ["sys 1.0", ..., "afParrotSdk2 0.0"]

## Documentation

Full API & fandocs are available on the [Eggbox](http://eggbox.fantomfactory.org/pods/afParrotSdk2/) - the Fantom Pod Repository.

## Quick Start

1. Create a text file called `Example.fan`

        using afParrotSdk2
        
        class Example {
            Void main() {
                drone := Drone().connect
        
                // handle feedback events
                drone.onEmergency = |->| {
                    echo("!!! EMERGENCY LANDING !!!")
                }
        
                // control the drone
                drone.takeOff
                drone.spinClockwise(0.5f, 3sec)
                drone.moveForward  (1.0f, 2sec)
                drone.animateFlight(FlightAnimation.flipBackward)
                drone.land
        
                drone.disconnect
            }
        }


2. Turn on your A.R. Drone and connect to its Wifi hotspot.
3. Run `Example.fan` as a Fantom script from the command line:

        C:\> fan Example.fan
        
        [info] [afParrotSdk2] Connected to AR Drone 2.4.8
        [info] [afParrotSdk2] Drone ready in 0.574ms
        [info] [afParrotSdk2] Drone took off in 5.23sec
        [info] [afParrotSdk2] Drone landed in 0.82sec
        [info] [afParrotSdk2] Disconnected from Drone



## Drone Communication

The Fantom SDK communications to the AR Drone over standard open wifi.

When you turn your AR Drone on, it creates a wifi hotspot that your computer must connect to. Once connected, the Fantom SDK communicates with the drone via UDP and TCP sockets.

Note that while there is no real concept of being *connected* to a drone, the `drone.connect()` method blocks until nav data is being received and all initiating commands have been acknowledged. That way we're certain the drone is in a known state and ready to receive commands.

## Take Off and Land

Taking off and landing is as simple as calling the corresponding methods:

```
drone.takeOff()
drone.hover()
drone.land()
```

All methods block until the drone has performed the task in hand. Note that taking off usually takes some 5 seconds before a stable hover is reached.

If all the red lights are on, it usually indicates that the drone is in an emergency state and it won't take off until the emergency is cleared:

```
drone.clearEmergencyFlag()
```

Whilst on the ground in a flat horizontal position, it's a good idea to tell the drone to calibrate its sensors for a wobble free flight:

```
drone.flatTrim()
```

Which makes for a complete and simple flight program of:

```
drone := Drone().connect
drone.clearEmergencyFlag
drone.flatTrim

drone.takeOff
drone.hover(3sec)
drone.land
drone.disconnect
```

## Movement

Basic movement is achieved with the following methods:

```
drone.moveUp()
drone.moveDown()
drone.moveLeft()
drone.moveRight()
drone.spinClockwise()
drone.spinAntiClockwise()
```

All take a value between 0 and 1 which determine how *fast* the drone moves. The methods also take an optional `Duration` telling it how long to move for, and by default they block until finished. See the move methods for details.

There are couple of *fun* commands which perform one of the drone's preprogrammed stunts:

    drone.animateFlight()
    drone.animateLeds()

See [FlightAnimation](http://eggbox.fantomfactory.org/pods/afParrotSdk2/api/FlightAnimation) and [LedAnimation](http://eggbox.fantomfactory.org/pods/afParrotSdk2/api/LedAnimation) for details.

## Exit Strategy

During the course of developing for your drone, your program will crash, bomb out, and otherwise exit unexpectedly; as do all programs under development. When this happens you don't want your drone to keep flying away, up and over the tree line or into the sea.

To guard against this, the Fantom SDK has an exit strategy, which is a JVM shutdown hook that transmits one last command before it exits.

See [ExitStrategy](http://eggbox.fantomfactory.org/pods/afParrotSdk2/api/ExitStrategy) for details.

## Events

The drone constantly sends data back to the Fantom SDK, which decodes it and fires events to keep you updated. The main event is:

    drone.onNavData()

[NavData](http://eggbox.fantomfactory.org/pods/afParrotSdk2/api/NavData) contains all the basic telemetry data such as speeds and orientation. The Fantom SDK also has other events for handling common cases:

```
drone.onBatteryDrain()
drone.onBatteryLow()
drone.onDisconnect()
drone.onEmergency()
drone.onStateChange()
```

## Configuration

Use the [DroneConfig](http://eggbox.fantomfactory.org/pods/afParrotSdk2/api/DroneConfig) helper class to read and write common drone config. Example:

    drone.config.totalFlightTime

The drone further splits configuration up into session, user, and application categories, each of which may be named.

    drone.config.session("My Session").hoveringRange = 1000

Once named, you may access the category directly:

    drone.config.session.hoveringRange = 2000

User and application categories are encapsulated by a session, so when the session changes, the user and application config is reset. Because of this, the Fantom SDK wraps these categories in the session category:

    drone.config.session.app("My App").navDataOptions = NavOption.demo.flag

All config settings are stored on the drone's internal flash drive and are persisted between reboots, so it is advisable to use named categories whenever possible so the drone may always be reset back to a *known good* profile.

The drone SDK calls the categorised config mechanism `Multi-Config`.

### Raw Config Data

Raw drone configuration may be inspected with:

    drone.configMap()

Reading config from the drone takes a number of milliseconds, so the config is cached. Pass in `true` to force a re-read of fresh config from the drone.

New raw config may be set by sending configuration commands. Do so with:

    drone.sendConfig()

## Nav Options

The drone is capable of pouring out bucket loads of data for your consumption. General purpose data is known as `demo` and is available in the [NavOptionDemo](http://eggbox.fantomfactory.org/pods/afParrotSdk2/api/NavOptionDemo) class:

    demoData := drone.navData.demoData

All other data is made available via *options*. To receive options you must first set which option packets you want the drone to send via application config:

    drone.config.session.app("My App").navDataOptions = NavOption.demo.flag + NavOption.windSpeed.flag

Once option data is received, the latest is always available via [NavData](http://eggbox.fantomfactory.org/pods/afParrotSdk2/api/NavData):

    windSpeed := drone.navData.getOption(NavOption.windSpeed)

Note that nav options are lazily decoded and kept in their raw compressed format until requested, thus making the mechanism extremely efficient.

Note that unfortunately, the nav option data is not documented in the Drone SDK so the best this Fantom SDK can do is decode it into maps of data with semi-descriptive string keys. Manually inspect the data returned from `NavData.getOption()` for details.

### Demo Mode vs Full Mode

By default the Fantom SDK puts the drone into *demo* mode whereby the drone sends out packets of option data ~15 times a second. But the drone may also be put into *full* mode where it sends data ~200 times a second.

Switching to full mode resets the drone to sending out *ALL* option data, but this may be further configured with `navDataOptions`:

    drone.config.hiResNavData = true
    drone.config.session.app("My App").navDataOptions = NavOption.demo.flag + NavOption.windSpeed.flag

## Video Streaming

Setting a listener on `Drone.onVideoFrame()` will instruct the drone to start streaming data over TCP on port 5555. The frames are decoded and sent to the event hook.

Note the frames are raw H.264 codec frames and may not immediately usable in their current format. Instead it is better to use the [VideoStreamer](http://eggbox.fantomfactory.org/pods/afParrotSdk2/api/VideoStreamer) utility class to either convert the video to a `.mp4` file, or create a stream of PNG images.

```
vs := VideoStreamer.toPngImages.attachToLiveStream(drone)
vs.onPngImage = |Bug pngBuf| {
    echo("Got new image of size ${pngBuf.size}")
}
```

Note that `VideoStreamer` requires [FFmpeg](https://ffmpeg.org/) so you should download (or compile) a version for your hardware. Installation isn't required, just place the `ffmpeg` executable in the current working directory.

Note that PNG images are streamed at the same frame rate as the video, is not juttery, and is fine for piping / drawing to an FWT canvas.

## Roundel Detection

The AR Drone supports detecting certain machine-parsable images with its cameras. Only the cameras aren't that good so there's a limited range of luminance which provide acceptable results. Spotlights and reflections are also a serious problem. Due to this the Fantom SDK opted not to support the various detection options and instead focus on more positive and reliable attributes of the drone.

That said, the *Black & White Oriented Roundel* (downloadable from the [downloads section](https://bitbucket.org/AlienFactory/afparrotsdk2/downloads/)) is usually detected without problems. To active detection, set [DroneSessionConfig.detectRoundel](http://eggbox.fantomfactory.org/pods/afParrotSdk2/api/DroneSessionConfig.detectRoundel) to the either the front or the ground camera, and enable the `visionDetect` NavData option:

```
drone.config.session.app.navDataOptions = NavOption.demo.flag + NavOption.visionDetect.flag
drone.config.session.detectRoundel = VideoCamera.horizontal
```

The following can then be used to extract the roundel detection data:

```
data := (Str:Obj) drone.navData[NavOption.visionDetect]
if (data["nbDetected"] > 0) {
    // ... roundel detected ...
    x := ((Int[])   data["xc"])[0]                // 0 - 1000
    y := ((Int[])   data["yc"])[0]                // 0 - 1000
    w := ((Int[])   data["width"])[0]             // 0 - 1000
    h := ((Int[])   data["height"])[0]            // 0 - 1000
    d := ((Int[])   data["dist"])[0]              // distance in cm
    a := ((Float[]) data["orientationAngle"])[0]  // angle in degrees
}
```

Note the `x`, `y`, `width`, and `height` co-ordinates are between 0 - 1000 regardless of the video resolution or the camera source. `(0, 0)` is the top-left hand corner.

Detecting other tags and markers is still possible with the Fantom SDK, you just need to use the lower level configuration methods - such as:

```
drone.config.sendMultiConfig("DETECT:detect_type", 3)
drone.config.sendMultiConfig("DETECT:detections_select_h", <flags>)
```

where `flags` may be a combination of upto 4 of:

`Shell=1 | Roundel=2 | BlackRoundel=4 | Stripe=8 | Cap=16 | ShellV2=32 | TowerSide=64 | OrientedRoundel=128`

The *Roundel* (looks like a bull's eye) is available from the [downloads section](https://bitbucket.org/AlienFactory/afparrotsdk2/downloads/) but I don't know what the other markers look like.

## References & Resources

Websites that have proved valuable in creating the Fantom SDK:

- [AR Drone SDK Forum (Official)](http://forum.developer.parrot.com/c/drone-sdk/ardrone)
- [AR Drone Community Forum (Official)](https://community.parrot.com/t5/AR-Drone-2-0/bd-p/ARDrone_EN)
- [AR Drone on StackOverflow](http://stackoverflow.com/questions/tagged/ar.drone)
- [AR Drone Arduino Communication](https://gist.github.com/maxogden/4152815)
- [AR Drone Spare Parts Page](https://www.parrot.com/us/catalog/spareparts?f%5B0%5D=im_field_product_category%3A5)

List of useful SDKs:

- [Parrot SDK 2.0 for C (Official)](http://developer.parrot.com/docs/SDK2/ARDrone_SDK_2_0_1.zip)
- [Parrot SDK 2.0 for C#](https://github.com/Ruslan-B/AR.Drone)
- [Parrot SDK 2.0 for Java](https://github.com/codeminders/javadrone)
- [Parrot SDK 2.0 for node.js](https://github.com/felixge/node-ar-drone)
- [Parrot SDK 2.0 for Python](http://www.playsheep.de/drone/)

The developer guide PDF has been uploaded to BitBucket, should the official SDK ever disappear:

- [AR Drone Developer Guide 2.0.1](https://bitbucket.org/AlienFactory/afparrotsdk2/downloads/ARDrone_Developer_Guide_2_0_1.pdf) (PDF - 5 MB)

Have fun!

