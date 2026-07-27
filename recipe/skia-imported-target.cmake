# Injected via -DCMAKE_PROJECT_INCLUDE. msdfgen's CMakeLists uses an
# existing `skia` target when one is defined (`if(NOT TARGET skia)`), so
# the static Skia built by build.sh/build.bat can be provided without
# patching msdfgen. SKIA_LIBRARY / SKIA_INCLUDE_DIR_* are passed on the
# cmake command line.
if(MSDFGEN_USE_SKIA AND NOT TARGET skia)
    add_library(skia STATIC IMPORTED)
    set_target_properties(skia PROPERTIES
        IMPORTED_LOCATION "${SKIA_LIBRARY}"
        # msdfgen includes <skia/core/...> (SKIA_INCLUDE_DIR_PREFIXED
        # holds a `skia/` copy of Skia's include tree); Skia's public
        # headers include each other as "include/core/..." relative to
        # the Skia source root (SKIA_INCLUDE_DIR_ROOT).
        INTERFACE_INCLUDE_DIRECTORIES "${SKIA_INCLUDE_DIR_PREFIXED};${SKIA_INCLUDE_DIR_ROOT}"
    )
endif()
