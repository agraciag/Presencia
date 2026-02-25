#!/usr/bin/env bash
# Presencia - Audio setup and diagnostics
# Configures PulseAudio output and provides diagnostics.
#
# Usage:
#   presencia-audio.sh setup   # Configure default audio
#   presencia-audio.sh test    # Play test sound
#   presencia-audio.sh status  # Show audio devices and levels
set -euo pipefail

CONFIG="/opt/presencia/presencia.conf"
if [[ -f "$CONFIG" ]]; then
    source "$CONFIG"
fi

ACTION="${1:-status}"

case "$ACTION" in
    setup)
        echo "── Audio Setup ──"

        # Set HDMI as default output if available
        HDMI_SINK="$(pactl list short sinks 2>/dev/null | grep -i hdmi | head -1 | awk '{print $2}')"
        if [[ -n "$HDMI_SINK" ]]; then
            pactl set-default-sink "$HDMI_SINK"
            echo "Default sink set to HDMI: ${HDMI_SINK}"
        elif [[ -n "${AUDIO_DEVICE:-}" ]]; then
            pactl set-default-sink "$AUDIO_DEVICE"
            echo "Default sink set to: ${AUDIO_DEVICE}"
        else
            echo "Using system default audio output."
        fi

        # Set volume to 80%
        pactl set-sink-volume @DEFAULT_SINK@ 80%
        pactl set-sink-mute @DEFAULT_SINK@ 0
        echo "Volume set to 80%, unmuted."

        # Ensure mic is active
        pactl set-source-mute @DEFAULT_SOURCE@ 0
        pactl set-source-volume @DEFAULT_SOURCE@ 100%
        echo "Microphone unmuted, volume 100%."
        ;;

    test)
        echo "Playing test sound..."
        if command -v speaker-test &>/dev/null; then
            speaker-test -t wav -c 2 -l 1 2>/dev/null || echo "speaker-test failed"
        elif command -v paplay &>/dev/null; then
            paplay /usr/share/sounds/freedesktop/stereo/bell.oga 2>/dev/null || echo "paplay failed"
        else
            echo "No audio test tool available."
        fi
        ;;

    status)
        echo "── Audio Status ──"
        echo ""
        echo "=== Sinks (output) ==="
        pactl list short sinks 2>/dev/null || echo "PulseAudio not available"
        echo ""
        echo "=== Sources (input) ==="
        pactl list short sources 2>/dev/null || echo "PulseAudio not available"
        echo ""
        echo "=== Default Sink ==="
        pactl get-default-sink 2>/dev/null || echo "Unknown"
        echo ""
        echo "=== Default Source ==="
        pactl get-default-source 2>/dev/null || echo "Unknown"
        echo ""
        echo "=== ALSA Devices ==="
        aplay -l 2>/dev/null || echo "ALSA not available"
        ;;

    *)
        echo "Usage: $0 {setup|test|status}"
        exit 1
        ;;
esac
