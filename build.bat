@echo off
REM Build Half-Life Xash3D for GarlicOS RG35XX - requires Docker Desktop
REM Toolchain: musl-cross armv7l (device libc is EGLIBC 2.15 - glibc builds cannot
REM link there, verified by ELF audit 2026-09-28). Loader staged to /tmp by .sh.
copy /Y toolchain.cmake . >nul 2>&1
docker build -t xash-garlic .
if errorlevel 1 (
  echo Build failed - check docker log above
  exit /b 1
)
if not exist out mkdir out
docker run --rm -v "%cd%/out:/out" xash-garlic
echo.
echo === Built ===
dir out
echo.
echo Next (SD reader only, NO ADB):
echo 1. Copy out\* + valve\ to SD: ROMS/PORTS/HalfLife/
echo    Copy HalfLife.sh to SD: ROMS/PORTS/ (next to the other .sh launchers)
echo 2. Copy your valve\ folder from Half-Life WON/Steam into the same folder
echo    IMPORTANT: copy out\hl_armv7hf.so to valve\dlls\ + out\client_armv7hf.so
echo    to valve\cl_dlls\ (KEEP those names, do not rename). The x86 .so files
echo    shipped with Steam will NOT load on ARM - the ARM ones sit alongside.
echo 3. Safely eject, boot -^> PORTS -^> HalfLife
echo 4. If black screen: power off, open ROMS/PORTS/HalfLife/debug.log on PC
