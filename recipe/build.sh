set -ex

# ---------------------------------------------------------------------------
# 1. Build a trimmed static Skia (PathOps subset) for MSDFGEN_USE_SKIA.
#
# conda-forge has no standalone skia package, so Skia is built here from
# the pinned snapshot vendored in the skia-pathops sdist -- the exact
# sources the skia-pathops feedstock already builds on these platforms.
# With every optional subsystem disabled (see build_skia_args.gni) this
# is ~530 objects and about a minute of compile time.
# ---------------------------------------------------------------------------
if [[ "${target_platform}" != "linux-ppc64le" ]]; then
    MSDFGEN_WITH_SKIA=ON
else
    # Skia has no ppc64le support; msdfgen keeps working without it
    # (geometry preprocessing unavailable, matching build number 1).
    MSDFGEN_WITH_SKIA=OFF
fi

SKIA_CMAKE_ARGS=()
if [[ "${MSDFGEN_WITH_SKIA}" == "ON" ]]; then
    SKIA_SRC="${SRC_DIR}/skia-pathops/src/cpp/skia-builder/skia"
    SKIA_BUILD="${SRC_DIR}/skia-build"

    case "${target_platform}" in
        linux-aarch64|osx-arm64) SKIA_TARGET_CPU="arm64" ;;
        *) SKIA_TARGET_CPU="x64" ;;
    esac

    SKIA_GN_ARGS="$(grep -v '^#' "${RECIPE_DIR}/build_skia_args.gni" | tr '\n' ' ')"
    SKIA_GN_ARGS+=" target_cpu=\"${SKIA_TARGET_CPU}\""
    SKIA_GN_ARGS+=" cc=\"${CC}\" cxx=\"${CXX}\" ar=\"${AR}\""
    # Avoids undefined font-manager symbols in the static lib (skia-builder
    # applies this on every non-Windows platform)
    SKIA_GN_ARGS+=" skia_enable_fontmgr_empty=true"
    if [[ "${target_platform}" == osx-* ]]; then
        SKIA_GN_ARGS+=" extra_cflags=[\"-fPIC\",\"-DSK_DISABLE_LEGACY_PNG_WRITEBUFFER\",\"-mmacosx-version-min=${MACOSX_DEPLOYMENT_TARGET}\"]"
    else
        SKIA_GN_ARGS+=" extra_cflags=[\"-fPIC\",\"-DSK_DISABLE_LEGACY_PNG_WRITEBUFFER\"]"
    fi

    # python lives in the build environment (build requirement), not the
    # host prefix that ${PYTHON} points to.
    (cd "${SKIA_SRC}" && \
        gn gen "${SKIA_BUILD}" \
            --script-executable="${BUILD_PREFIX}/bin/python3" \
            --args="${SKIA_GN_ARGS}")
    ninja -C "${SKIA_BUILD}" -j${CPU_COUNT} skia

    # msdfgen includes Skia headers as <skia/core/...>; Skia's own
    # headers reference each other as "include/..." from the source root.
    mkdir -p "${SRC_DIR}/skia-prefixed-include"
    cp -r "${SKIA_SRC}/include" "${SRC_DIR}/skia-prefixed-include/skia"

    SKIA_CMAKE_ARGS=(
        "-DCMAKE_PROJECT_INCLUDE=${RECIPE_DIR}/skia-imported-target.cmake"
        "-DSKIA_LIBRARY=${SKIA_BUILD}/libskia.a"
        "-DSKIA_INCLUDE_DIR_PREFIXED=${SRC_DIR}/skia-prefixed-include"
        "-DSKIA_INCLUDE_DIR_ROOT=${SKIA_SRC}"
    )
fi

# ---------------------------------------------------------------------------
# 2. Build msdfgen
# ---------------------------------------------------------------------------
mkdir -p build
cd build

cmake ${CMAKE_ARGS} \
    -GNinja \
    -DMSDFGEN_BUILD_STANDALONE=ON \
    -DMSDFGEN_USE_SKIA=${MSDFGEN_WITH_SKIA} \
    -DMSDFGEN_DYNAMIC_RUNTIME=ON \
    -DBUILD_SHARED_LIBS=ON \
    -DMSDFGEN_USE_VCPKG=OFF \
    -DMSDFGEN_INSTALL=ON \
    "${SKIA_CMAKE_ARGS[@]}" \
    ..

ninja -j${CPU_COUNT} -v
ninja install
