#!/bin/sh
progdir=$(dirname "$0")/HalfLife
cd $progdir
HOME=$progdir
export LD_LIBRARY_PATH="$PWD:$LD_LIBRARY_PATH"
export SDL_FBDEV=/dev/fb0
# ALSA data files ship in ./share/alsa (compiled prefix doesn't exist on device)
export ALSA_CONFIG_PATH="$PWD/share/alsa/alsa.conf"
export ALSA_CONFIG_DIR="$PWD/share/alsa"
# musl loader: SYSTEM /lib is read-only and INTERP points at /tmp (see Dockerfile).
# Stage it on every launch (/tmp is tmpfs, gone after reboot).
cp -f ./ld-musl-armhf.so.1 /tmp/ld-musl-armhf.so.1 2>/dev/null
# NOTE: SDL2 has NO fbcon driver (fbcon was SDL1.2-only). Do NOT export
# SDL_VIDEODRIVER=fbcon - let SDL probe. This script logs what the device
# actually exposes so the video backend is chosen with evidence.
{
  echo "=== HalfLife launcher v4 (fbdev, nointro, markers) ==="
  echo "=== device video probe ==="
  echo "--- /proc/fb ---"
  cat /proc/fb 2>&1
  echo "--- /dev/fb* ---"
  ls -lh /dev/fb* 2>&1
  echo "--- /dev/dri ---"
  ls -R /dev/dri 2>&1
  echo "--- /dev/input ---"
  ls /dev/input/event* 2>&1
  echo "--- /proc/bus/input/devices ---"
  cat /proc/bus/input/devices 2>&1
  echo "--- /dev/snd ---"
  ls -R /dev/snd 2>&1
  echo "--- musl loader staged ---"
  ls -lh /tmp/ld-musl-armhf.so.1 2>&1
  echo "=== shipped files ==="
  ls -lh ./xash3d 2>&1
  ls -lh ./lib*.so* 2>&1
  echo "=== valve game libs (must be ARM, not x86) ==="
  ls -lh ./valve/dlls/ ./valve/cl_dlls/ 2>&1
} > ./debug.log 2>&1
# fresh breadcrumb file for this run (engine appends fsync'd markers)
rm -f ./mark.log
if [ ! -d "./valve" ]; then
  echo "missing valve/ - copy from Half-Life WON/Steam" >> ./debug.log
  echo "missing valve/ - check ROMS/PORTS/HalfLife/debug.log on PC" >> ./debug.log
  sleep 3
  sync
  exit 1
fi
# 640x480 native RG35XX, 16bpp for speed on 256MB - log to SD for no-ADB debug
# NOTE: valve/dlls/hl_armv7hf.so + valve/cl_dlls/client_armv7hf.so are the ARM
# files from out/ (hlsdk-portable build). The x86 .so shipped with Steam will not load.
# +vid_info / +echo run after init: if MARKER_ALIVE is in debug.log the engine
# reached the main loop (anything earlier = hang during init).
./xash3d -game valve -width 640 -height 480 -bpp 16 -ref soft -dev 3 -nointro +evdev_keydebug 1 +vid_info +echo MARKER_ALIVE $@ >> ./debug.log 2>&1
RET=$?
echo "exit code $RET" >> ./debug.log
sync
exit $RET
