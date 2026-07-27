@echo on
setlocal enabledelayedexpansion

:: -------------------------------------------------------------------------
:: 1. Build a trimmed static Skia (PathOps subset) for MSDFGEN_USE_SKIA,
::    from the pinned snapshot vendored in the skia-pathops sdist (the
::    same sources the skia-pathops feedstock builds on win-64).
:: -------------------------------------------------------------------------
set "SKIA_SRC=%SRC_DIR%\skia-pathops\src\cpp\skia-builder\skia"
set "SKIA_BUILD=%SRC_DIR%\skia-build"

:: Assemble the gn args from the shared file, then append win specifics.
set "SKIA_GN_ARGS="
for /f "usebackq eol=# delims=" %%a in ("%RECIPE_DIR%\build_skia_args.gni") do (
    set "SKIA_GN_ARGS=!SKIA_GN_ARGS! %%a"
)
set "SKIA_GN_ARGS=!SKIA_GN_ARGS! target_cpu=\"x64\""
:: msdfgen is built with the dynamic CRT (MSDFGEN_DYNAMIC_RUNTIME=ON);
:: Skia's official build defaults to the static CRT, so align them.
set "SKIA_GN_ARGS=!SKIA_GN_ARGS! extra_cflags=[\"/MD\",\"-DSK_DISABLE_LEGACY_PNG_WRITEBUFFER\"]"

cd /d "%SKIA_SRC%"
gn gen "%SKIA_BUILD%" --script-executable="%PYTHON%" --args="!SKIA_GN_ARGS!"
if errorlevel 1 exit 1
ninja -C "%SKIA_BUILD%" -j%CPU_COUNT% skia
if errorlevel 1 exit 1
cd /d "%SRC_DIR%"

:: msdfgen includes Skia headers as <skia/core/...>; Skia's own headers
:: reference each other as "include/..." from the source root.
mkdir "%SRC_DIR%\skia-prefixed-include"
xcopy /e /i /q "%SKIA_SRC%\include" "%SRC_DIR%\skia-prefixed-include\skia"
if errorlevel 1 exit 1

:: -------------------------------------------------------------------------
:: 2. Build msdfgen
:: -------------------------------------------------------------------------
if not exist build mkdir build
cd build

cmake %CMAKE_ARGS% ^
    -G Ninja ^
    -DMSDFGEN_BUILD_STANDALONE=ON ^
    -DMSDFGEN_USE_SKIA=ON ^
    -DMSDFGEN_DYNAMIC_RUNTIME=ON ^
    -DBUILD_SHARED_LIBS=ON ^
    -DMSDFGEN_USE_VCPKG=OFF ^
    -DMSDFGEN_INSTALL=ON ^
    -DCMAKE_PROJECT_INCLUDE=%RECIPE_DIR%\skia-imported-target.cmake ^
    -DSKIA_LIBRARY=%SKIA_BUILD%\skia.lib ^
    -DSKIA_INCLUDE_DIR_PREFIXED=%SRC_DIR%\skia-prefixed-include ^
    -DSKIA_INCLUDE_DIR_ROOT=%SKIA_SRC% ^
    ..
if errorlevel 1 exit 1

ninja -j%CPU_COUNT% -v
if errorlevel 1 exit 1
ninja install
if errorlevel 1 exit 1
