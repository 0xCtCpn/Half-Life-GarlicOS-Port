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

Only needed if you change the engine: run `build.bat` (requires Docker Desktop) -> binaries land in `out/`.

## If it doesn't start

Power off, put the SD in your PC, open `ROMS/PORTS/HalfLife/debug.log` and check the error.
