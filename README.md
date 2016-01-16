## Resin Arduino Programmer

## How to use it:

Push this repository to your resin application.
```
git push resin master
```
Connect your Arduino to the resin device via usb. Check the logs to see if your Arduino is flashed with the new image. To make changes to the Arduino all you have to do is edit your code, in this case `/src/blink/blink.ino`, repush to resin.io and it will automatically reflash the Arduino.

The basic workflow is this:
 * Build your Arduino script(`sample.ino` on resin.io builders)
 * When the code lands on the device check if there is a difference between the new Arduino code and previously pushed code (which is stored in `/data` to persist through resin updates)
 * If there is a difference raise a flag to signal the uploading the built image to the Arduino.

Let's have a look at some code. Of course the basis for all resin projects is a Dockerfile so lets start there.

First, we need to install some native dependencies.
```
# Dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    arduino \
    g++ \
    gcc \
    usbutils \
    make
```

Next, we build our Ardiuno image using `[this handy make file](http://ed.am/dev/make/arduino-mk)`. It allows you to pass build configurations via environment variables. As you can see we are building for the `leonardo` board and uploading via `/dev/ttyACM0`. Full documentation on the make file can be found [here](http://ed.am/dev/make/arduino-mk).

```
# Dockerfile
# build the Arduino image
WORKDIR /app

ENV ARDUINODIR /usr/share/arduino
ENV BOARD leonardo
ENV SERIALDEV /dev/arduino

RUN cd blink && make
```

Now once the container hits the device, we'll need to run a script to compare the code in `blink.ino` against the previous version. We declare our entry point like so:

```
# run start.sh when the container starts
CMD ["bash","start.sh"]
```

Here we have a flag `PROGRAMMER` which indicates whether there is an update for our Arduino. If the flag is raised, we run `make upload` which uploads the image via serial cable `/dev/ttyACM0`. We then store our new `blink.ino` in `/data`. This is important because resin treats `/data` as a docker volume, in that its contents survive container updates. This is of course crucial to making the comparison between new and old code.

```bash
# start.sh
diff /app/blink/blink.ino /data/blink.ino || PROGRAMMER=1
if [ "${PROGRAMMER:-}" == "1" ]; then
  echo $PROGRAMMER
  pushd /app/blink
  make upload && cp blink.ino /data/
  popd
fi
```

So if a difference is detected we'll use our `Makefile`'s `upload` function to transfer the image via the usb-serial connection. You can view the write progress from the resin logs.

** *Note: I've stripped out some of the logs to make it more concise.* **

```
12.01.16 13:04:58 [+0000] Connecting to programmer: .
12.01.16 13:04:58 [+0000] Programmer supports the following devices:
12.01.16 13:04:58 [+0000] Device code: 0x44
12.01.16 13:04:59 [+0000] avrdude: AVR device initialized and ready to accept instructions
12.01.16 13:04:59 [+0000] Reading | | 0% 0.00s Reading | ################################################## | 100% 0.01s
12.01.16 13:04:59 [+0000] avrdude: Device signature = 0x1e9587
12.01.16 13:04:59 [+0000] avrdude: reading input file "blink.hex"
12.01.16 13:04:59 [+0000] avrdude: writing flash (4756 bytes):
12.01.16 13:04:59 [+0000] Writing || ################################################## | 100% 0.59s
12.01.16 13:04:59 [+0000] avrdude: 4756 bytes of flash written
12.01.16 13:04:59 [+0000] avrdude done. Thank you.
```

And there you have it: updating an Arduino using resin.io.

## Troubleshooting
* If the flashing fails, check to see if the `ENV SERIALDEV` is correct for the device path for your Arduino. You can do this by running `ls /dev/tty*`, removing the Arduino and running it again and then comparing the output.
