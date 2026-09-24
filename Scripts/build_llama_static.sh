#!/bin/zsh
# Builds the embedded llama.cpp inference engine as one static arm64 macOS archive, with Metal
# and BLAS enabled and every app, tool, example, server, test and OpenSSL option off.
#
# Input:  none; LOCAL_ASSISTANT_SOURCE names the project when the script runs from the offline
#         kit rather than beside LocalAssistant.xcodeproj. Requires CMake.
# Reads:  Vendor/llama.cpp, the prepared pinned checkout
# Writes: Vendor/llama.cpp/build-localassistant-macos/Release/libllama-localassistant.a
# Run by: Scripts/prepare_offline_bundle.sh and Scripts/build_offline.sh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
if [[ -d "${SCRIPT_DIR}/../LocalAssistant.xcodeproj" ]]; then
  PROJECT_DIR="${SCRIPT_DIR}/.."
elif [[ -n "${LOCAL_ASSISTANT_SOURCE:-}" ]]; then
  PROJECT_DIR="${LOCAL_ASSISTANT_SOURCE}"
else
  print -u2 "Set LOCAL_ASSISTANT_SOURCE to the transferred source directory."
  exit 1
fi

SOURCE_DIR="${PROJECT_DIR}/Vendor/llama.cpp"
BUILD_DIR="${SOURCE_DIR}/build-localassistant-macos"
OUTPUT_DIR="${BUILD_DIR}/Release"
OUTPUT_LIBRARY="${OUTPUT_DIR}/libllama-localassistant.a"

if ! command -v cmake >/dev/null 2>&1; then
  print -u2 "CMake is required to build the embedded llama.cpp libraries."
  exit 1
fi

cmake -S "${SOURCE_DIR}" -B "${BUILD_DIR}" -G Xcode \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_C_FLAGS="-Wno-shorten-64-to-32" \
  -DCMAKE_CXX_FLAGS="-Wno-shorten-64-to-32" \
  -DBUILD_SHARED_LIBS=OFF \
  -DLLAMA_BUILD_APP=OFF \
  -DLLAMA_BUILD_COMMON=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_TOOLS=OFF \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_SERVER=OFF \
  -DLLAMA_BUILD_MTMD=OFF \
  -DGGML_METAL=ON \
  -DGGML_METAL_EMBED_LIBRARY=ON \
  -DGGML_BLAS_DEFAULT=ON \
  -DGGML_NATIVE=OFF \
  -DGGML_OPENMP=OFF \
  -DGGML_CCACHE=OFF \
  -DLLAMA_OPENSSL=OFF

cmake --build "${BUILD_DIR}" --config Release -j 8 -- -quiet

/bin/mkdir -p "${OUTPUT_DIR}"
/usr/bin/xcrun libtool -static -o "${OUTPUT_LIBRARY}" \
  "${BUILD_DIR}/src/Release/libllama.a" \
  "${BUILD_DIR}/ggml/src/Release/libggml.a" \
  "${BUILD_DIR}/ggml/src/Release/libggml-base.a" \
  "${BUILD_DIR}/ggml/src/Release/libggml-cpu.a" \
  "${BUILD_DIR}/ggml/src/ggml-metal/Release/libggml-metal.a" \
  "${BUILD_DIR}/ggml/src/ggml-blas/Release/libggml-blas.a"

print "Embedded llama.cpp library prepared at: ${OUTPUT_LIBRARY}"
