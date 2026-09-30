# Half-Life (Xash3D FWGS) - GarlicOS RG35XX Port
Target: RG35XX `Actions ATM7039S` / `Cortex-A9` / `256MB` / `garlic.img` (SYSTEM SDL1.2 only, we bundle SDL2)

Engine: FWGS Xash3D FWGS (open source) + hlsdk-portable - runs Half-Life WON/Steam data without box86.
Build system: WAF (`./waf configure -T release --enable-soft`), NOT cmake.
Toolchain: musl-cross `armv7l-linux-musleabihf` on `debian:bookworm` host.
Why musl: device libc is Ubuntu EGLIBC 2.15 (banner in `garlic.img`); ELF audit
showed glibc builds need GLIBC_2.16..2.34 incl. symbols missing from 2.15
entirely - no glibc toolchain can target it. musl `libc.so` + `ld-musl` ship
in `out/`; `HalfLife.sh` copies the loader to `/tmp` (SYSTEM `/lib` read-only,
INTERP is `/tmp/ld-musl-armhf.so.1`). Game libs keep their arch-postfixed names
(`hl_armv7hf.so`, `client_armv7hf.so`) - Xash resolves them, do NOT rename.
Renderer: `ref_soft` (software, no GL) for PowerVR SGX544MP which has no usable GL driver on Garlic kernel 3.x.

Video status: fbdev-only engine build (`--enable-fbdev` = VIDEO_FBDEV + INPUT_EVDEV
+ SOUND_ALSA, no SDL at all). Matches the device (owlfb `/dev/fb0`, no `/dev/dri`,
evdev nodes - all verified in `debug.log` probe). Upstream gap patched in
`Dockerfile:61-76` (`VID_Info_f` + `Platform_GetDisplayOrientation` only existed
in SDL backends). SDL2 is built in the image but NOT shipped - nothing links it.

RAM: ~80-100MB - fits 256MB (close limit, close other apps). Needs HL data:
- `valve/` folder from Half-Life (GOG/Steam WON): `valve/models/` `valve/maps/` `valve/halflife.wad` etc.
- Put `valve/` next to binary.
- IMPORTANT: overwrite `valve/dlls/hl.so` + `valve/cl_dlls/client.so` with the ARM
  `.so` files from `out/` (hlsdk-portable build). The x86 `.so`/`.dll` shipped
  with Steam will NOT load on ARM (verified: bundled `hl.so`/`client.so` are `e_machine=0x3` x86).

Layout on SD `ROMS` (FAT32):
```
ROMS/PORTS/
  HalfLife.sh          # launcher at PORTS root (device convention, like Diablo.sh)
  HalfLife/            # game dir (progdir)
    xash3d             # engine launcher, musl ARM
    libxash.so         # engine
    libref_soft.so     # software renderer (the one that matters, -ref soft)
    libref_gl.so       # (unused, no GL on device)
    libmenu.so filesystem_stdio.so
    libasound.so.2 libfreetype.so.6   # bundled deps (ALSA sound, menu fonts)
    libc.so ld-musl-armhf.so.1        # musl runtime (NOT optional)
    # NOTE: no libSDL2 - fbdev build links none of it
    valve/             # your data + ARM game libs below
      dlls/hl_armv7hf.so
      cl_dlls/client_armv7hf.so
```

Controls: evdev direct (`/dev/input/event*`, no SDL layer). RG35XX mapping TBD on first run - check `debug.log` + `valve/config.cfg`. Edit `valve/config.cfg` for tuning.

Build: `Port_HalfLife\build.bat` (Docker) -> `out/` (`xash3d` + `libxash.so` + `libref_soft.so` + `hl_armv7hf.so`/`client_armv7hf.so` + `libasound` + `libfreetype` + musl `libc.so`/`ld-musl`; no SDL)

Install (No ADB - SD reader only):
EITHER download the SD-ready zip from Releases (recommended, no Docker needed):
1. Backup `ROMS` (`README.txt:3`)
2. Extract the release zip into SD `ROMS/PORTS/` -> `HalfLife.sh` + `HalfLife/`
3. Copy the CONTENTS of your `valve/` folder (lowercase, from Half-Life WON/Steam)
   into `ROMS/PORTS/HalfLife/valve/` - ARM libs (`hl_armv7hf.so`,
   `client_armv7hf.so`) are already pre-placed there; x86 `.so`/`.dll` sit
   alongside with no clash
OR build from source with `build.bat`, then:
2. Copy `out/*` + your `valve/` folder (lowercase) to SD `ROMS/PORTS/HalfLife/` (create it),
   and `HalfLife.sh` to SD `ROMS/PORTS/` next to the other launchers (device
   convention: `.sh` at PORTS root, game files in subfolder)
3. Copy `hl_armv7hf.so` into `valve/dlls/` + `client_armv7hf.so` into `valve/cl_dlls/` (KEEP names; x86 `.so`/`.dll` stay, ARM ones sit alongside)
4. Safely eject, boot -> `PORTS` -> `HalfLife`
5. No `chmod +x` needed - `HalfLife.sh:4` sets `LD_LIBRARY_PATH` + `sync` (no forced
   video driver; SDL probes, see "Video status" above)

Debug (No ADB - log on SD):
If black screen returns to menu: power off, SD in PC, open `ROMS/PORTS/HalfLife/debug.log`
- `missing valve/` -> wrong case/location, must be `valve/` next to `xash3d`
- `libasound.so.2: cannot open` -> forgot the ALSA `.so` next to binary (fbdev sound needs it)
- `error while loading shared libraries: ld-musl` -> `.sh` failed to stage
  loader to `/tmp` (check `debug.log` probe section, `/tmp` must be writable)
- `ref_soft` is forced - `ref_gles1` will fail on Garlic/PowerVR
Do NOT use `MISC/enableADB` (`README.txt:16` - corrupts FAT).
