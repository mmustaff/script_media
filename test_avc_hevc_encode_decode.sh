#!/usr/bin/env bash
# =============================================================================
# Codec Sanity Test Script
# Tests AVC (H.264) and HEVC (H.265) Encode + Decode using:
#   - Intel Media SDK sample_encode / sample_decode
#   - GStreamer VA plugin  (GST-VA)
#   - GStreamer QSV plugin (GST-VPL, based on Intel oneVPL)
#
# Usage: ./codec_sanity_test.sh [--keep-files]
#   --keep-files : Do not remove working directory on exit
# =============================================================================

set -uo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
WIDTH=1280
HEIGHT=720
FRAMERATE=30
DURATION=2          # seconds
BITRATE=4000        # kbps
WORKDIR="${TMPDIR:-/tmp}/codec_sanity_$$"
LOGDIR="${WORKDIR}/logs"
PASS=0
FAIL=0
SKIP=0
KEEP_FILES=0

for arg in "$@"; do
    [[ "$arg" == "--keep-files" ]] && KEEP_FILES=1
done

# Colours
RED='\033[0;31m'
GRN='\033[0;32m'
YEL='\033[1;33m'
CYN='\033[0;36m'
BLD='\033[1m'
RST='\033[0m'

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
log()     { echo -e "${CYN}[INFO]${RST}  $*"; }
pass()    { echo -e "${GRN}[PASS]${RST}  $*"; ((PASS++)); }
fail()    { echo -e "${RED}[FAIL]${RST}  $*"; ((FAIL++)); }
skip()    { echo -e "${YEL}[SKIP]${RST}  $*"; ((SKIP++)); }
section() {
    echo -e "\n${BLD}${CYN}══════════════════════════════════════${RST}"
    echo -e "${BLD}${CYN}  $*${RST}"
    echo -e "${BLD}${CYN}══════════════════════════════════════${RST}"
}

# encode_test <label> <logfile_base> <expected_output> <cmd...>
#   Runs <cmd...>, checks that <expected_output> is a non-empty file.
encode_test() {
    local label="$1"
    local logbase="$2"
    local outfile="$3"
    shift 3
    local logfile="${LOGDIR}/${logbase}.log"

    if "$@" >"${logfile}" 2>&1; then
        if [[ -f "${outfile}" && -s "${outfile}" ]]; then
            pass "${label}"
        else
            fail "${label} — output file missing/empty: ${outfile}  (log: ${logfile})"
        fi
    else
        fail "${label} — command returned non-zero  (log: ${logfile})"
    fi
}

# decode_test <label> <logfile_base> <expected_output> <expected_frames> <cmd...>
#   Runs <cmd...>, validates output size against expected frame count (±10%).
decode_test() {
    local label="$1"
    local logbase="$2"
    local outfile="$3"
    local expected_frames="$4"
    shift 4
    local logfile="${LOGDIR}/${logbase}.log"

    local frame_bytes=$(( WIDTH * HEIGHT * 3 / 2 ))
    local expected_bytes=$(( expected_frames * frame_bytes ))
    local lo=$(( expected_bytes * 90 / 100 ))
    local hi=$(( expected_bytes * 110 / 100 ))

    if "$@" >"${logfile}" 2>&1; then
        if [[ -f "${outfile}" && -s "${outfile}" ]]; then
            local actual
            actual=$(stat -c%s "${outfile}")
            if (( actual >= lo && actual <= hi )); then
                local nframes=$(( actual / frame_bytes ))
                pass "${label}  [${nframes} frames]"
            else
                fail "${label} — unexpected output size ${actual} B (expected ~${expected_bytes} B)  (log: ${logfile})"
            fi
        else
            fail "${label} — output file missing/empty: ${outfile}  (log: ${logfile})"
        fi
    else
        fail "${label} — command returned non-zero  (log: ${logfile})"
    fi
}

# cleanup on exit
cleanup() {
    if (( KEEP_FILES == 0 )); then
        rm -rf "${WORKDIR}"
    else
        log "Working files retained at: ${WORKDIR}"
    fi
}
trap cleanup EXIT

# -----------------------------------------------------------------------------
# Pre-flight checks
# -----------------------------------------------------------------------------
section "Pre-flight checks"

MISSING=0
for tool in ffmpeg sample_encode sample_decode gst-launch-1.0 vainfo; do
    if command -v "$tool" &>/dev/null; then
        log "Found: $tool"
    else
        echo -e "${RED}[ERROR]${RST} Required tool not found: $tool"
        MISSING=$(( MISSING + 1 ))
    fi
done

for plugin in vah264enc vah265enc vah264dec vah265dec \
              qsvh264enc qsvh265enc qsvh264dec qsvh265dec; do
    if gst-inspect-1.0 "$plugin" &>/dev/null 2>&1; then
        log "Found GStreamer plugin: $plugin"
    else
        echo -e "${YEL}[WARN]${RST}  Missing GStreamer plugin: $plugin"
        MISSING=$(( MISSING + 1 ))
    fi
done

if (( MISSING > 0 )); then
    echo -e "${RED}[ERROR]${RST} $MISSING tool(s)/plugin(s) missing. Aborting."
    exit 1
fi

log "Checking VA-API hardware..."
if ! vainfo &>/dev/null 2>&1; then
    echo -e "${RED}[ERROR]${RST} VA-API hardware not accessible. Aborting."
    exit 1
fi
DRIVER_VER=$(vainfo 2>/dev/null | grep 'Driver version' | sed 's/.*Driver version: //')
log "VA-API OK  (${DRIVER_VER})"

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------
section "Setup"
mkdir -p "${WORKDIR}/raw" "${WORKDIR}/encoded" "${WORKDIR}/decoded" "${LOGDIR}"
log "Working directory: ${WORKDIR}"

TOTAL_FRAMES=$(( FRAMERATE * DURATION ))
RAW_YUV="${WORKDIR}/raw/test_${WIDTH}x${HEIGHT}.yuv"

log "Generating ${DURATION}s test pattern (${WIDTH}x${HEIGHT} @ ${FRAMERATE}fps)..."
if ! ffmpeg -y -f lavfi \
        -i "testsrc=duration=${DURATION}:size=${WIDTH}x${HEIGHT}:rate=${FRAMERATE}" \
        -pix_fmt yuv420p "${RAW_YUV}" \
        >"${LOGDIR}/ffmpeg_gen.log" 2>&1; then
    echo -e "${RED}[ERROR]${RST} Failed to generate test YUV. See ${LOGDIR}/ffmpeg_gen.log"
    exit 1
fi
log "Raw YUV: ${RAW_YUV}  ($(du -sh "${RAW_YUV}" | cut -f1))"

# -----------------------------------------------------------------------------
# 1. sample_encode / sample_decode
# -----------------------------------------------------------------------------
section "sample_encode / sample_decode (Intel Media SDK / oneVPL)"

AVC_BS="${WORKDIR}/encoded/sample_avc.h264"
HEVC_BS="${WORKDIR}/encoded/sample_hevc.h265"

encode_test \
    "sample_encode  AVC  (H.264)  Encode" \
    "sample_encode_avc" \
    "${AVC_BS}" \
    sample_encode h264 \
        -i "${RAW_YUV}" -o "${AVC_BS}" \
        -w "${WIDTH}" -h "${HEIGHT}" \
        -b "${BITRATE}" -f "${FRAMERATE}"

encode_test \
    "sample_encode  HEVC (H.265)  Encode" \
    "sample_encode_hevc" \
    "${HEVC_BS}" \
    sample_encode h265 \
        -i "${RAW_YUV}" -o "${HEVC_BS}" \
        -w "${WIDTH}" -h "${HEIGHT}" \
        -b "${BITRATE}" -f "${FRAMERATE}"

decode_test \
    "sample_decode  AVC  (H.264)  Decode" \
    "sample_decode_avc" \
    "${WORKDIR}/decoded/sample_avc_out.yuv" \
    "${TOTAL_FRAMES}" \
    sample_decode h264 \
        -i "${AVC_BS}" \
        -o "${WORKDIR}/decoded/sample_avc_out.yuv"

decode_test \
    "sample_decode  HEVC (H.265)  Decode" \
    "sample_decode_hevc" \
    "${WORKDIR}/decoded/sample_hevc_out.yuv" \
    "${TOTAL_FRAMES}" \
    sample_decode h265 \
        -i "${HEVC_BS}" \
        -o "${WORKDIR}/decoded/sample_hevc_out.yuv"

# -----------------------------------------------------------------------------
# 2. GST-VA plugin (VA-API GStreamer)
# -----------------------------------------------------------------------------
section "GST-VA plugin (vah264enc/dec, vah265enc/dec)"

AVC_BS="${WORKDIR}/encoded/gstva_avc.h264"
HEVC_BS="${WORKDIR}/encoded/gstva_hevc.h265"

encode_test \
    "GST-VA         AVC  (H.264)  Encode" \
    "gstva_encode_avc" \
    "${AVC_BS}" \
    gst-launch-1.0 -q \
        filesrc location="${RAW_YUV}" \
        ! rawvideoparse width="${WIDTH}" height="${HEIGHT}" \
            format=i420 framerate="${FRAMERATE}/1" \
        ! videoconvert \
        ! "video/x-raw,format=NV12" \
        ! vah264enc \
        ! filesink location="${AVC_BS}"

encode_test \
    "GST-VA         HEVC (H.265)  Encode" \
    "gstva_encode_hevc" \
    "${HEVC_BS}" \
    gst-launch-1.0 -q \
        filesrc location="${RAW_YUV}" \
        ! rawvideoparse width="${WIDTH}" height="${HEIGHT}" \
            format=i420 framerate="${FRAMERATE}/1" \
        ! videoconvert \
        ! "video/x-raw,format=NV12" \
        ! vah265enc \
        ! filesink location="${HEVC_BS}"

decode_test \
    "GST-VA         AVC  (H.264)  Decode" \
    "gstva_decode_avc" \
    "${WORKDIR}/decoded/gstva_avc_out.yuv" \
    "${TOTAL_FRAMES}" \
    gst-launch-1.0 -q \
        filesrc location="${AVC_BS}" \
        ! h264parse \
        ! vah264dec \
        ! filesink location="${WORKDIR}/decoded/gstva_avc_out.yuv"

decode_test \
    "GST-VA         HEVC (H.265)  Decode" \
    "gstva_decode_hevc" \
    "${WORKDIR}/decoded/gstva_hevc_out.yuv" \
    "${TOTAL_FRAMES}" \
    gst-launch-1.0 -q \
        filesrc location="${HEVC_BS}" \
        ! h265parse \
        ! vah265dec \
        ! filesink location="${WORKDIR}/decoded/gstva_hevc_out.yuv"

# -----------------------------------------------------------------------------
# 3. GST-VPL plugin (Intel oneVPL / QSV GStreamer)
# -----------------------------------------------------------------------------
section "GST-VPL plugin (qsvh264enc/dec, qsvh265enc/dec)"

AVC_BS="${WORKDIR}/encoded/gstvpl_avc.h264"
HEVC_BS="${WORKDIR}/encoded/gstvpl_hevc.h265"

# byte-stream output so the file can be parsed back cleanly by h264parse/h265parse
encode_test \
    "GST-VPL        AVC  (H.264)  Encode" \
    "gstvpl_encode_avc" \
    "${AVC_BS}" \
    gst-launch-1.0 -q \
        filesrc location="${RAW_YUV}" \
        ! rawvideoparse width="${WIDTH}" height="${HEIGHT}" \
            format=i420 framerate="${FRAMERATE}/1" \
        ! videoconvert \
        ! "video/x-raw,format=NV12" \
        ! qsvh264enc \
        ! "video/x-h264,stream-format=byte-stream" \
        ! filesink location="${AVC_BS}"

encode_test \
    "GST-VPL        HEVC (H.265)  Encode" \
    "gstvpl_encode_hevc" \
    "${HEVC_BS}" \
    gst-launch-1.0 -q \
        filesrc location="${RAW_YUV}" \
        ! rawvideoparse width="${WIDTH}" height="${HEIGHT}" \
            format=i420 framerate="${FRAMERATE}/1" \
        ! videoconvert \
        ! "video/x-raw,format=NV12" \
        ! qsvh265enc \
        ! "video/x-h265,stream-format=byte-stream" \
        ! filesink location="${HEVC_BS}"

decode_test \
    "GST-VPL        AVC  (H.264)  Decode" \
    "gstvpl_decode_avc" \
    "${WORKDIR}/decoded/gstvpl_avc_out.yuv" \
    "${TOTAL_FRAMES}" \
    gst-launch-1.0 -q \
        filesrc location="${AVC_BS}" \
        ! h264parse \
        ! qsvh264dec \
        ! filesink location="${WORKDIR}/decoded/gstvpl_avc_out.yuv"

decode_test \
    "GST-VPL        HEVC (H.265)  Decode" \
    "gstvpl_decode_hevc" \
    "${WORKDIR}/decoded/gstvpl_hevc_out.yuv" \
    "${TOTAL_FRAMES}" \
    gst-launch-1.0 -q \
        filesrc location="${HEVC_BS}" \
        ! h265parse \
        ! qsvh265dec \
        ! filesink location="${WORKDIR}/decoded/gstvpl_hevc_out.yuv"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
section "Test Summary"
TOTAL=$(( PASS + FAIL + SKIP ))
printf "  Total   : %d\n" "${TOTAL}"
echo -e "  ${GRN}Passed  : ${PASS}${RST}"
if (( FAIL > 0 )); then
    echo -e "  ${RED}Failed  : ${FAIL}${RST}"
else
    printf "  Failed  : %d\n" "${FAIL}"
fi
if (( SKIP > 0 )); then
    echo -e "  ${YEL}Skipped : ${SKIP}${RST}"
fi
echo ""

if (( FAIL == 0 )); then
    echo -e "${GRN}${BLD}All ${PASS} tests PASSED.${RST}"
    exit 0
else
    echo -e "${RED}${BLD}${FAIL} of ${TOTAL} test(s) FAILED.  Logs: ${LOGDIR}${RST}"
    exit 1
fi
