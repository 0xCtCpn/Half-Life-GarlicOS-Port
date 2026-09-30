FROM debian:bookworm
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    gcc g++ make pkg-config git python3 curl ca-certificates \
    autoconf automake libtool file xz-utils bzip2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY toolchain.cmake /build/toolchain.cmake

# Prebuilt musl cross toolchain (no bootstrap wait)
RUN curl -sL https://musl.cc/armv7l-linux-musleabihf-cross.tgz -o musl.tgz && \
    tar xzf musl.tgz -C /opt && rm musl.tgz && \
    ls /opt/armv7l-linux-musleabihf-cross/bin/
ENV PATH=/opt/armv7l-linux-musleabihf-cross/bin:$PATH
ENV MUSL_TRIPLE=armv7l-linux-musleabihf

# SDL2 (SDL2 has no fbcon driver - Xash brings its own fbdev video vid_fbdev.c)
RUN git clone --depth 1 --branch release-2.28.5 https://github.com/libsdl-org/SDL.git SDL2
RUN cd SDL2 && ./autogen.sh 2>/dev/null || autoreconf -fi; \
    CC=${MUSL_TRIPLE}-gcc CXX=${MUSL_TRIPLE}-g++ \
    CFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=hard -O2" \
    CXXFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=hard -O2" \
    ./configure --host=${MUSL_TRIPLE} --prefix=/opt/arm-sdl2 \
      --disable-video-x11 --disable-video-wayland \
      --disable-pulseaudio --disable-esd --disable-arts \
    && make -j$(nproc) && make install

# freetype2 for ARM (Xash mainui menu requires it)
RUN (curl -sSL --retry 3 --retry-all-errors https://download.savannah.gnu.org/releases/freetype/freetype-2.13.2.tar.gz -o freetype.tar.gz || \
    curl -sSL --retry 3 --retry-all-errors https://github.com/freetype/freetype/releases/download/VER-2-13-2/freetype-2.13.2.tar.gz -o freetype.tar.gz) && \
    tar xzf freetype.tar.gz && cd freetype-2.13.2 && \
    CC=${MUSL_TRIPLE}-gcc \
    CFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=hard -O2" \
    ./configure --host=${MUSL_TRIPLE} --prefix=/opt/arm-sdl2 \
      --without-zlib --without-bzip2 --without-png --without-harfbuzz --without-brotli && \
    make -j$(nproc) && make install

# alsa-lib for ARM (fbdev engine uses SOUND_ALSA, not SDL audio)
RUN curl -sSL --retry 3 --retry-all-errors https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.12.tar.bz2 -o alsa.tar.bz2 && \
    tar xjf alsa.tar.bz2 && cd alsa-lib-1.2.12 && \
    CC=${MUSL_TRIPLE}-gcc \
    CFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=hard -O2" \
    ./configure --host=${MUSL_TRIPLE} --prefix=/opt/arm-sdl2 \
      --disable-python --disable-aload --without-debug && \
    make -j$(nproc) && make install

# Xash3D FWGS engine (WAF, not cmake). --enable-fbdev = fbdev-only,
# software-only engine: VIDEO_FBDEV + INPUT_EVDEV + SOUND_ALSA, no SDL.
# (This device: owlfb /dev/fb0, no /dev/dri, evdev present - verified in debug.log.)
# INTERP points at /tmp (SYSTEM /lib is read-only - HalfLife.sh stages it).
RUN git clone --depth 1 https://github.com/FWGS/xash3d-fwgs.git xash3d-fwgs && \
    cd xash3d-fwgs && git submodule update --init --recursive || true
RUN python3 - <<'PYEOF'
import re
def patch(path, pairs):
    s = open(path).read()
    if "#include <unistd.h>" not in s:
        s = "#include <unistd.h>\n#include <fcntl.h>\n" + s
    for frag, msg in pairs:
        rx = re.compile(frag, re.M)
        ms = rx.findall(s)
        assert len(ms) == 1, "anchor issue: " + frag
        code = '\n\t{ int mfd = open( "./mark.log", O_WRONLY|O_CREAT|O_APPEND, 0644 ); if( mfd >= 0 ) { (void)write( mfd, "%s\\n", %d ); fsync( mfd ); close( mfd ); } Con_Printf( "MARK %s\\n" ); }' % (msg, len(msg)+1, msg)
        s = rx.sub(lambda m: m.group(0) + code, s, count=1)
    open(path, "w").write(s)

patch("xash3d-fwgs/engine/client/dll_int/cl_game.c", [
    (r"^.*initailize local player and world.*$", "post-initedicts"),
    (r"CL_InitClientMove\(\);", "post-clientmove"),
    (r"dllFuncs\.pfnInit\(\);", "post-pfninit"),
    (r"CL_InitStudioAPI\(\);", "post-studioapi"),
    (r"S_InitSoundAPI\(\);", "post-soundapi"),
])

patch("xash3d-fwgs/engine/common/host.c", [
    (r"HTTP_Init\(\);", "post-http"),
    (r"SoundList_Init\(\);", "post-soundlist"),
    (r"IN_GyroCheckAvailability\(\);", "post-gyro"),
])
print("marker patch ok")
PYEOF
RUN python3 - <<'PYEOF2'
import re
def patch2(path, pairs):
    s = open(path).read()
    for frag, msg in pairs:
        rx = re.compile(frag, re.M)
        ms = rx.findall(s)
        assert len(ms) == 1, "anchor issue: " + frag
        code = '\n\t{ int mfd = open( "./mark.log", O_WRONLY|O_CREAT|O_APPEND, 0644 ); if( mfd >= 0 ) { (void)write( mfd, "%s\\n", %d ); fsync( mfd ); close( mfd ); } Con_Printf( "MARK %s\\n" ); }' % (msg, len(msg)+1, msg)
        s = rx.sub(lambda m: m.group(0) + code, s, count=1)
    open(path, "w").write(s)

patch2("xash3d-fwgs/engine/common/host.c", [
    (r"SV_Init\(\);", "pre-sv_init"),
    (r"CL_Init\(\);", "post-cl_init"),
])
patch2("xash3d-fwgs/engine/common/http/net_http_xash.c", [
    (r"HTTP_TlsInit\(\);", "post-tlsinit"),
])
print("marker patch 2 ok")
PYEOF2
# Input patch: RG35XX gamepad over evdev (no SDL here).
# - autodetect skips gamepads (wants keyboard/mouse bits) -> also open
#   devices with BTN_SOUTH or BTN_DPAD_UP
# - key table has no gamepad buttons -> map face/shoulder/start/select
# - EV_ABS ignored entirely -> translate ABS_HAT0X/Y (dpad-as-hat) to arrows
# Sticks (ABS_X/Y/RX/RY) and analog triggers stay unmapped for now.
RUN python3 - <<'PYEOF3'
import re
p = "xash3d-fwgs/engine/platform/linux/in_evdev.c"
s = open(p).read()
def once(pat, flags=0):
    rx = re.compile(pat, flags)
    ms = rx.findall(s)
    assert len(ms) == 1, "anchor issue: " + pat
    return rx

# 1. hat state, after MAX_EVDEV_DEVICES define
rx = once(r"^.*define MAX_EVDEV_DEVICES 5.*$", re.M)
s = rx.sub(lambda m: m.group(0) + "\nstatic int evdev_hat_x[MAX_EVDEV_DEVICES];\nstatic int evdev_hat_y[MAX_EVDEV_DEVICES];", s, count=1)

# 2. autodetect: open gamepads too (insert before final goto close of detector,
# preserving the mouse goto open above it)
rx = once(r"goto open;\n\t\t\}\n\t\tgoto close;")
s = rx.sub(lambda m: "goto open;\n\t\t}\n\t\t/* RG35XX-style gamepad: face buttons, optional dpad buttons */\n\t\tif( EV_HASBIT( codes, BTN_SOUTH ) || EV_HASBIT( codes, BTN_DPAD_UP ) )\n\t\t\tgoto open;\n\t\tgoto close;", s, count=1)

# 3. button map, after PLAYPAUSE line
rx = once(r"case KEY_PLAYPAUSE: return K_ENTER;")
btnmap = "\n\tcase BTN_SOUTH: return K_ENTER; /* A: menu select */\n\tcase BTN_EAST: return K_ESCAPE; /* B: menu back */\n\tcase BTN_NORTH: return K_SPACE; /* X: jump */\n\tcase BTN_WEST: return 'e'; /* Y: use */\n\tcase BTN_TL: return K_MOUSE1; /* L1: attack */\n\tcase BTN_TR: return K_MOUSE2; /* R1: attack2 */\n\tcase BTN_TL2: return 'r'; /* L2: reload */\n\tcase BTN_TR2: return 'f'; /* R2: flashlight */\n\tcase BTN_SELECT: return K_TAB; /* SELECT: scores */\n\tcase BTN_START: return K_ESCAPE; /* START: pause */\n\tcase BTN_THUMBL: return 'q'; /* L3: last weapon */\n\tcase BTN_THUMBR: return 'c'; /* R3: duck */\n\tcase BTN_DPAD_UP: return K_UPARROW;\n\tcase BTN_DPAD_DOWN: return K_DOWNARROW;\n\tcase BTN_DPAD_LEFT: return K_LEFTARROW;\n\tcase BTN_DPAD_RIGHT: return K_RIGHTARROW;"
s = rx.sub(lambda m: m.group(0) + btnmap, s, count=1)

# 4. hat-to-arrows branch, prepended before the EV_KEY branch
rx = once(r"else if \( \( ev\.type == EV_KEY")
hatblock = "\t\t\telse if( ev.type == EV_ABS )\n\t\t\t{\n\t\t\t\t/* dpad-as-hat: arrows with release tracking */\n\t\t\t\tif( ev.code == ABS_HAT0X || ev.code == ABS_HAT0Y )\n\t\t\t\t{\n\t\t\t\t\tint neg = ( ev.code == ABS_HAT0X ) ? K_LEFTARROW : K_UPARROW;\n\t\t\t\t\tint pos = ( ev.code == ABS_HAT0X ) ? K_RIGHTARROW : K_DOWNARROW;\n\t\t\t\t\tint *last = ( ev.code == ABS_HAT0X ) ? &evdev_hat_x[i] : &evdev_hat_y[i];\n\t\t\t\t\tint cur = ( ev.value < 0 ) ? -1 : ( ev.value > 0 );\n\t\t\t\t\tif( cur != *last )\n\t\t\t\t\t{\n\t\t\t\t\t\tif( *last < 0 ) Key_Event( neg, false );\n\t\t\t\t\t\telse if( *last > 0 ) Key_Event( pos, false );\n\t\t\t\t\t\tif( cur < 0 ) Key_Event( neg, true );\n\t\t\t\t\t\telse if( cur > 0 ) Key_Event( pos, true );\n\t\t\t\t\t\t*last = cur;\n\t\t\t\t\t}\n\t\t\t\t}\n\t\t\t}\n\t\t\t"
s = rx.sub(lambda m: hatblock + m.group(0), s, count=1)

open(p, "w").write(s)
print("input patch ok")
PYEOF3
# Input patch round 2: open letter-key gamepads (RG35XX original emits
# Q,W,R,T,Y,U,I,[,],ENTER,LEFTCTRL,A -- no BTN_*, no SPACE, so the stock
# keyboard/mouse/hat checks all miss it). LEFTCTRL doubles as menu-back
# (no ESC code exists on this pad). Hat presses get keydebug logging.
RUN python3 - <<'PYEOF4'
import re
p = "xash3d-fwgs/engine/platform/linux/in_evdev.c"
s = open(p).read()
def once(pat):
    rx = re.compile(pat, re.M)
    ms = rx.findall(s)
    assert len(ms) == 1, "anchor issue: " + pat
    return rx

# 1. autodetect: letter keys mean gamepad/keyboard worth opening
rx = once(r"if\( !EV_HASBIT\( codes, BTN_MOUSE \) \)")
s = rx.sub(lambda m: "if( EV_HASBIT( codes, KEY_Q ) || EV_HASBIT( codes, KEY_W ) || EV_HASBIT( codes, KEY_E ) || EV_HASBIT( codes, KEY_A ) || EV_HASBIT( codes, KEY_S ) || EV_HASBIT( codes, KEY_D ) )\n\t\t\tgoto open;\n\n\t\t" + m.group(0), s, count=1)

# 2. LEFTCTRL -> ESC alias (pad has no ESC code; CTRL useless in menu).
# Split from the shared RIGHTCTRL case so RIGHTCTRL keeps K_CTRL.
rx = once(r"case KEY_RIGHTCTRL:\n\tcase KEY_LEFTCTRL:\n\t\treturn K_CTRL;")
s = rx.sub(lambda m: "case KEY_RIGHTCTRL:\n\t\treturn K_CTRL;\n\tcase KEY_LEFTCTRL:\n\t\treturn K_ESCAPE; /* RG35XX: menu back, no ESC code on pad */", s, count=1)

# 3. hat keydebug, inside dpad-as-hat branch
rx = once(r"if\( ev\.code == ABS_HAT0X \|\| ev\.code == ABS_HAT0Y \)")
s = rx.sub(lambda m: "{ if( evdev_keydebug.value ) Con_Printf( \"hat %d val %d\\n\", ev.code, ev.value ); }\n\t\t\t\t" + m.group(0), s, count=1)

open(p, "w").write(s)
print("input patch 2 ok")
PYEOF4
RUN python3 - <<'PYEOF5'
import re
p = "xash3d-fwgs/engine/client/input/input.c"
s = open(p).read()
rx = re.compile(r"Touch_Init\(\);", re.M)
assert len(rx.findall(s)) == 1, "touch anchor"
code = "\n\t{ void Evdev_Setup( void ); void Evdev_OpenDevice( const char *path ); Con_Printf( \"MARK in_init_evdev_fixup\\n\" ); Evdev_Setup(); Evdev_OpenDevice( \"/dev/input/event0\" ); Evdev_OpenDevice( \"/dev/input/event1\" ); }"
s = rx.sub(lambda m: m.group(0) + code, s, count=1)
open(p, "w").write(s)
print("input patch 3 ok")
PYEOF5
RUN cat >> xash3d-fwgs/engine/platform/linux/vid_fbdev.c <<'PATCH_EOF'
#if XASH_VIDEO == VIDEO_FBDEV
platform_orientation_t Platform_GetDisplayOrientation( void )
{
	return ORIENTATION_LANDSCAPE;
}

void VID_Info_f( void )
{
	Con_Printf( "Video: " S_GREEN "fbdev" S_DEFAULT "\n" );
	Con_Printf( "Framebuffer: %dx%d %dbpp, %d bytes\n", fb.vinfo.xres, fb.vinfo.yres, fb.vinfo.bits_per_pixel, fb.finfo.smem_len );
}
#endif
PATCH_EOF
RUN cd xash3d-fwgs && \
    export CC=${MUSL_TRIPLE}-gcc CXX=${MUSL_TRIPLE}-g++ && \
    export CFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=hard -O2 -I/opt/arm-sdl2/include" && \
    export CXXFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=hard -O2 -I/opt/arm-sdl2/include" && \
    export LINKFLAGS="-static-libgcc -static-libstdc++ -Wl,--dynamic-linker,/tmp/ld-musl-armhf.so.1 -L/opt/arm-sdl2/lib" && \
    export PKG_CONFIG_PATH=/opt/arm-sdl2/lib/pkgconfig && \
    export PKG_CONFIG_LIBDIR=/opt/arm-sdl2/lib/pkgconfig && \
    python3 ./waf configure -T release --enable-fbdev --enable-soft --disable-werror --disable-mbedtls --prefix=/opt/xash && \
    python3 ./waf build && \
    (python3 ./waf install --destdir=/opt/xash-install || true)

# HLSDK ARM game libs (postfixed hl_armv7hf.so / client_armv7hf.so - keep names,
# Xash resolves arch postfix via library_suffix; do NOT rename to hl.so)
RUN git clone --depth 1 https://github.com/FWGS/hlsdk-portable.git hlsdk-portable && \
    cd hlsdk-portable && git submodule update --init --recursive || true
RUN cd hlsdk-portable && \
    export CC=${MUSL_TRIPLE}-gcc CXX=${MUSL_TRIPLE}-g++ && \
    export CFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=hard -O2" && \
    export CXXFLAGS="-march=armv7-a -mfpu=neon -mfloat-abi=hard -O2" && \
    export LINKFLAGS="-static-libgcc -static-libstdc++ -Wl,--dynamic-linker,/tmp/ld-musl-armhf.so.1" && \
    python3 ./waf configure -T release && \
    python3 ./waf build && \
    (python3 ./waf install --destdir=/opt/hlsdk-install || true)

CMD mkdir -p /out && \
    echo "=== xash install tree ===" && (ls -R /opt/xash-install 2>/dev/null || ls -R /build/xash3d-fwgs/build 2>/dev/null || true) && \
    echo "=== hlsdk install tree ===" && (ls -R /opt/hlsdk-install 2>/dev/null || find /build/hlsdk-portable/build -name "*.so" 2>/dev/null || true) && \
    cp /opt/xash-install/opt/xash/bin/xash3d /out/ 2>/dev/null || cp /opt/xash-install/*/xash3d /out/ 2>/dev/null || find / -name xash3d -type f -executable -exec cp {} /out/ \; 2>/dev/null || true; \
    find /opt/xash-install /build/xash3d-fwgs/build -name "*.so*" -exec cp {} /out/ \; 2>/dev/null || true; \
    find /opt/hlsdk-install /build/hlsdk-portable/build -name "*.so" -exec cp {} /out/ \; 2>/dev/null || true; \
    cp /opt/arm-sdl2/lib/libSDL2*.so* /out/ 2>/dev/null || true; \
    cp /opt/arm-sdl2/lib/libfreetype*.so* /out/ 2>/dev/null || true; \
    cp /opt/arm-sdl2/lib/libasound*.so* /out/ 2>/dev/null || true; \
    mkdir -p /out/share && cp -r /opt/arm-sdl2/share/alsa /out/share/ 2>/dev/null || true; \
    MUSLLIB=/opt/armv7l-linux-musleabihf-cross/armv7l-linux-musleabihf/lib; \
    echo "--- musl sysroot ---" && ls $MUSLLIB/ | grep -E "libc|ld-musl" || true; \
    cp $MUSLLIB/libc.so /out/ 2>/dev/null || true; \
    cp $MUSLLIB/libc.so /out/ld-musl-armhf.so.1 2>/dev/null || true; \
    ls -lh /out/ && \
    echo "--- INTERP xash3d (want /tmp/ld-musl-armhf.so.1) ---" && armv7l-linux-musleabihf-readelf -l /out/xash3d 2>/dev/null | grep -A1 INTERP || true; \
    echo "--- NEEDED xash3d ---" && armv7l-linux-musleabihf-readelf -d /out/xash3d 2>/dev/null | grep NEEDED || true; \
    echo "--- no GLIBC versions expected ---" && armv7l-linux-musleabihf-readelf -sW --dyn-syms /out/xash3d 2>/dev/null | grep -o "@GLIBC_[0-9.]*" | sort -u || true
