# Half-Life - GarlicOS (RG35XX) Port

Half-Life on the Anbernic RG35XX running GarlicOS, using the open-source Xash3D FWGS engine (software renderer). No PC build needed - just download, copy your game data, play.

You need: RG35XX with GarlicOS, the release zip below, and your own Half-Life `valve/` data (Steam/GOG).

## Install

1. Download the latest zip from Releases and extract it into SD `ROMS/PORTS/`
2. Copy the CONTENTS of your `valve/` folder into `ROMS/PORTS/HalfLife/valve/`
3. Safely eject, boot, go to PORTS -> HalfLife

## SD folder structure

```
ROMS/PORTS/
  HalfLife.sh          # launcher
  HalfLife/            # engine + libs (from the zip)
    xash3d
    libxash.so
    libref_soft.so     # software renderer (used, no GL on this device)
    libmenu.so filesystem_stdio.so
    libasound.so.2 libfreetype.so.6
    libc.so ld-musl-armhf.so.1
    share/             # audio config data
    valve/             # YOUR game data goes here (not included, copyrighted)
      dlls/hl_armv7hf.so          # pre-included ARM game lib
      cl_dlls/client_armv7hf.so   # pre-included ARM game lib
```

## Build from source (optional)

Only needed if you change the engine or want fresh binaries. The build runs in Docker, so nothing is installed on your PC besides Docker Desktop.

Prerequisites:

* Windows PC with Docker Desktop installed, rebooted, and running (whale icon green)
* ~10GB free disk (first build downloads the toolchain and sources, takes 10-20 min)

Steps:

1. Open this folder (`Port_HalfLife/`) and double-click `build.bat`
2. Wait for it to finish - success ends with `=== Built ===` plus a listing of `out/`
3. Fresh binaries land in `out/`: `xash3d`, `libxash.so`, `libref_soft.so`, `hl_armv7hf.so` / `client_armv7hf.so`, ALSA/freetype libs, musl `libc.so` / `ld-musl-armhf.so.1`, `share/alsa/`

What the build does (`Dockerfile`):

* Starts from `debian:bookworm`, installs compilers and build tools
* Fetches a prebuilt musl cross toolchain (`armv7l-linux-musleabihf`) - musl is required because the device libc (EGLIBC 2.15) is too old for glibc builds
* Cross-compiles SDL2, freetype, and alsa-lib for ARM
* Builds the Xash3D FWGS engine with `./waf configure -T release --enable-fbdev --enable-soft` (framebuffer + software renderer, no GL) and the `hlsdk-portable` ARM game libs
* Prints checks at the end: loader path (want `/tmp/ld-musl-armhf.so.1`), needed libs, and no `GLIBC_*` version deps

To install your own build: copy `out/*` + `HalfLife.sh` + your `valve/` to SD `ROMS/PORTS/HalfLife/` (see Install above), then copy `hl_armv7hf.so` into `valve/dlls/` and `client_armv7hf.so` into `valve/cl_dlls/`.

If the build fails: make sure Docker Desktop is running first, then re-run `build.bat`. A stale half-finished image can be cleared with `docker rmi xash-garlic`.

## If it doesn't start

Power off, put the SD in your PC, open `ROMS/PORTS/HalfLife/debug.log` and check the error.

## Credits

Thanks to:

* FWGS team — [xash3d-fwgs](https://github.com/FWGS/xash3d-fwgs) engine and [hlsdk-portable](https://github.com/FWGS/hlsdk-portable) ARM game libs
* libsdl, freetype, and ALSA upstreams for the bundled dependencies
* The GarlicOS developers for the firmware

## Licensing

The port files in this repo (launcher, build scripts, docs) are MIT licensed, see `LICENSE`. The engine, game libs, and bundled dependencies stay under their upstream licenses. Half-Life game data (`valve/`) belongs to Valve and is not included.
