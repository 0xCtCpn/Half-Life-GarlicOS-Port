# Half-Life - GarlicOS (RG35XX) Port

Half-Life on the Anbernic RG35XX running GarlicOS, using the open-source Xash3D FWGS engine

You need: RG35XX with GarlicOS 1.4.9, the release zip, and your own Half-Life `valve/` data from Steam

## Install

1. Download the latest zip from Releases and extract it into SD `ROMS/PORTS/`
2. Copy the CONTENTS of your `valve/` folder into `ROMS/PORTS/HalfLife/valve/`
3. Safely eject, boot, go to PORTS -> HalfLife

## SD folder structure

```
ROMS/PORTS/
  HalfLife.sh          
  HalfLife/            
    xash3d
    libxash.so
    libref_soft.so     
    libmenu.so filesystem_stdio.so
    libasound.so.2 libfreetype.so.6
    libc.so ld-musl-armhf.so.1
    share/             
    valve/             # YOUR game data goes here
      dlls/hl_armv7hf.so
      cl_dlls/client_armv7hf.so
```

## Build from source

Only needed if you change the engine or want fresh binaries

Prerequisites:

* Windows PC with Docker Desktop installed
* ~10GB free disk

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

To install your own build: copy `out/*` + `HalfLife.sh` + your `valve/` to SD `ROMS/PORTS/HalfLife/`, then copy `hl_armv7hf.so` into `valve/dlls/` and `client_armv7hf.so` into `valve/cl_dlls/`.

If the build fails: make sure Docker Desktop is running first, then re-run `build.bat`. A stale half-finished image can be cleared with `docker rmi xash-garlic`.

## Debugging

If crashing open `ROMS/PORTS/HalfLife/debug.log` and check/submit the error.

## Credits

Thanks to:

* FWGS team — [xash3d-fwgs](https://github.com/FWGS/xash3d-fwgs) engine and [hlsdk-portable](https://github.com/FWGS/hlsdk-portable) ARM game libs
* libsdl, freetype, and ALSA upstreams for the bundled dependencies
* [Black-Seraph](https://www.patreon.com/blackseraph/posts/garlicos-for-76561333) for GarlicOS