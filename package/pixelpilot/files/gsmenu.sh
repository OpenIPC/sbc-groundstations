#!/bin/sh
set -o pipefail

# ══════════════════════════════════════════════════════════════════════════════
# Configuration
# ══════════════════════════════════════════════════════════════════════════════

REMOTE_IP="${REMOTE_IP:-10.5.0.10}"
AIR_FIRMWARE_TYPE="${AIR_FIRMWARE_TYPE:-wfb}"
SSH_PASS="12345"
CACHE_DIR="/tmp/gsmenu_cache"
CACHE_TTL=10 # seconds
MAJESTIC_YAML="/etc/majestic.yaml"
WFB_YAML="/etc/wfb.yaml"
ALINK_CONF="/etc/alink.conf"
AALINK_CONF="/etc/aalink.conf"
TXPROFILES_CONF="/etc/txprofiles.conf"

# ══════════════════════════════════════════════════════════════════════════════
# SSH / SCP setup
# ══════════════════════════════════════════════════════════════════════════════

SSH="timeout -k 1 11 sshpass -p $SSH_PASS ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ControlMaster=auto -o ControlPath=/run/ssh_control:%h:%p:%r -o ControlPersist=15s -o ServerAliveInterval=3 -o ServerAliveCountMax=2 root@$REMOTE_IP"
SCP="timeout -k 1 11 sshpass -p $SSH_PASS scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ControlMaster=auto -o ControlPath=/run/ssh_control:%h:%p:%r -o ControlPersist=15s -o ServerAliveInterval=3 -o ServerAliveCountMax=2"

# ══════════════════════════════════════════════════════════════════════════════
# Helper functions
# ══════════════════════════════════════════════════════════════════════════════

mkdir -p "$CACHE_DIR"

# Emit the record separator followed by allowed values (for dropdowns/sliders).
# Called after the current value has been printed.
#   emit_values "1\n20\n25\n30"        – static list / range
#   emit_values_cmd <command> [args]   – dynamic values from a command
emit_values()     { printf '\x1e'"$1"; }
emit_values_cmd() { printf '\x1e'; "$@"; }

# Refresh cached config files from the air unit (10s TTL)
refresh_cache() {
    local current_time=$(date +%s)
    local last_refresh=$((current_time - CACHE_TTL))

    if [[ ! -f "$CACHE_DIR/last_refresh" ]] || [[ $(cat "$CACHE_DIR/last_refresh") -lt $last_refresh ]]; then
        files="$MAJESTIC_YAML $WFB_YAML $ALINK_CONF $TXPROFILES_CONF $AALINK_CONF"
        $SSH "tar cf - $files" 2>/dev/null | tar xf - --strip-components 1 -C /tmp/gsmenu_cache/ 2>/dev/null
        $SSH "find /etc/sensors/ -type f -name \"*\$(ipcinfo -s)*.bin\"" | sed 's/^\/etc\/sensors\///' | sed 's/\.bin$//' > /tmp/gsmenu_cache/sensor.txt
        echo "$current_time" > "$CACHE_DIR/last_refresh"
    fi
}

get_majestic_value() {
    local key="$1"
    yaml-cli -i "$CACHE_DIR/majestic.yaml" -g "$key" 2>/dev/null
}

get_wfb_value() {
    local key="$1"
    yaml-cli -i "$CACHE_DIR/wfb.yaml" -g "$key" 2>/dev/null
}

get_alink_value() {
    local key="$1"
    grep $key= "$CACHE_DIR/alink.conf" | cut -d "=" -f 2 2>/dev/null
}

get_aalink_value() {
    local key="$1"
    grep ^$key= "$CACHE_DIR/aalink.conf" | cut -d "=" -f 2 2>/dev/null
}

# Helper: list available wifi channels (used by air and gs)
list_wifi_channels() {
    iw list | grep MHz | grep -v disabled | grep -v "radar detection" | grep \* | tr -d '[]' | awk '{print $4 " (" $2 " " $3 ")"}' | grep '^[1-9]' | sort -n | uniq | head -c -1
}

send_cmd() {
    echo "$1" | nc -w 11 $REMOTE_IP 12355
}


# ══════════════════════════════════════════════════════════════════════════════
# Cache refresh (only for air get commands)
# ══════════════════════════════════════════════════════════════════════════════

case "$@" in
  "get air"*)
    refresh_cache
    ;;
esac

# ══════════════════════════════════════════════════════════════════════════════
# Main command dispatch
# ══════════════════════════════════════════════════════════════════════════════

case "$@" in

# ── Air: WFB-NG ─────────────────────────────────────────────────────────────

    "get air wfbng power")
        get_wfb_value '.wireless.txpower'
        emit_values "1\n20\n25\n30\n35\n40\n45\n50\n55\n58"
        ;;
    "get air wfbng air_channel")
        channel=$(get_wfb_value '.wireless.channel' | tr -d '\n')
        iw list | grep "\[$channel\]" | tr -d '[]' | awk '{print $4 " (" $2 " " $3 ")"}' | sort -n | uniq | tr -d '\n'
        emit_values_cmd list_wifi_channels
        ;;
    "get air wfbng width")
        get_wfb_value '.wireless.width'
        emit_values "20\n40"
        ;;
    "get air wfbng mcs_index")
        get_wfb_value '.broadcast.mcs_index'
        emit_values "0 10"
        ;;
    "get air wfbng stbc")
        get_wfb_value '.broadcast.stbc'
        ;;
    "get air wfbng ldpc")
        get_wfb_value '.broadcast.ldpc'
        ;;
    "get air wfbng fec_k")
        get_wfb_value '.broadcast.fec_k'
        emit_values "0 15"
        ;;
    "get air wfbng fec_n")
        get_wfb_value '.broadcast.fec_n'
        emit_values "0 15"
        ;;
    "get air wfbng mlink")
        get_wfb_value '.wireless.mlink'
        emit_values "1500\n1600\n1700\n1800\n1900\n2000\n2100\n2200\n2300\n2400\n2500\n2600\n2700\n2800\n2900\n3000\n3100\n3200\n3300\n3400\n3500\n3600\n3700\n3800\n3900\n4000"
        ;;
    "get air wfbng adaptivelink")
        $SSH grep ^alink_drone /etc/rc.local | grep -q 'alink_drone' && echo 1 || echo 0
        ;;

    "set air wfbng power"*)
        $SSH wifibroadcast cli -s .wireless.txpower $5
        $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        ;;
    "set air wfbng air_channel"*)
        channel=$(echo $5 | awk '{print $1}')
        $SSH wifibroadcast cli -s .wireless.channel $channel
        $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        sed -i "s/^wifi_channel =.*/wifi_channel = $channel/" /etc/wifibroadcast.cfg
        /etc/init.d/S98wifibroadcast restart
        ;;
    "set air wfbng width"*)
        $SSH wifibroadcast cli -s .wireless.width $5
        $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        ;;
    "set air wfbng mcs_index"*)
        $SSH wifibroadcast cli -s .broadcast.mcs_index $5
        $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        ;;
    "set air wfbng stbc"*)
        if [ "$5" = "on" ]; then
            $SSH wifibroadcast cli -s .broadcast.stbc 1
        else
            $SSH wifibroadcast cli -s .broadcast.stbc 0
        fi
        $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        ;;
    "set air wfbng ldpc"*)
        if [ "$5" = "on" ]; then
            $SSH wifibroadcast cli -s .broadcast.ldpc 1
        else
            $SSH wifibroadcast cli -s .broadcast.ldpc 0
        fi
        $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        ;;
    "set air wfbng fec_k"*)
        $SSH wifibroadcast cli -s .broadcast.fec_k $5
        $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        ;;
    "set air wfbng fec_n"*)
        $SSH wifibroadcast cli -s .broadcast.fec_n $5
        $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        ;;
    "set air wfbng mlink"*)
        $SSH wifibroadcast cli -s .wireless.mlink $5
        $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        ;;
    "set air wfbng adaptivelink"*)
        if [ "$5" = "on" ]; then
            $SSH 'sed -i "/alink_drone &/d" /etc/rc.local && sed -i -e "\$i alink_drone &" /etc/rc.local && cli -s .video0.qpDelta -12 && killall -1 majestic && (nohup alink_drone >/dev/null 2>&1 &)'
        else
            $SSH 'killall -q -9 alink_drone;  sed -i "/alink_drone &/d" /etc/rc.local  ; cli -d .video0.qpDelta && killall -1 majestic'
        fi
        ;;

# ── Air: Camera ──────────────────────────────────────────────────────────────

    "get air camera mirror")
        [ "$(get_majestic_value '.image.mirror')" = "true" ] && echo 1 || echo 0
        ;;
    "get air camera flip")
        [ "$(get_majestic_value '.image.flip')" = "true" ] && echo 1 || echo 0
        ;;
    "get air camera contrast")
        get_majestic_value '.image.contrast'
        emit_values "0 100"
        ;;
    "get air camera hue")
        get_majestic_value '.image.hue'
        emit_values "0 100"
        ;;
    "get air camera saturation")
        get_majestic_value '.image.saturation'
        emit_values "0 100"
        ;;
    "get air camera luminace")
        get_majestic_value '.image.luminance'
        emit_values "0 100"
        ;;
    "get air camera size")
        get_majestic_value '.video0.size'
        emit_values "1280x720\n1456x816\n1920x1080\n1440x1080\n1920x1440\n2104x1184\n2208x1248\n2240x1264\n2312x1304\n2436x1828\n2512x1416\n2560x1440\n2560x1920\n2720x1528\n2944x1656\n3200x1800\n3840x2160"
        ;;
    "get air camera video_mode")
        send_cmd get_current_video_mode
        emit_values_cmd send_cmd get_all_video_modes
        ;;
    "get air camera fps")
        get_majestic_value '.video0.fps'
        emit_values "60\n90\n120"
        ;;
    "get air camera bitrate")
        get_majestic_value '.video0.bitrate'
        emit_values "1000\n2000\n3000\n4000\n5000\n6000\n7000\n8000\n9000\n10000\n11000\n12000\n13000\n14000\n15000\n16000\n17000\n18000\n19000\n20000\n21000\n22000\n23000\n24000\n25000\n26000\n27000\n28000\n29000\n30000"
        ;;
    "get air camera codec")
        get_majestic_value '.video0.codec'
        emit_values "h264\nh265"
        ;;
    "get air camera gopsize")
        get_majestic_value '.video0.gopSize'
        emit_values "0 10"
        ;;
    "get air camera rc_mode")
        get_majestic_value '.video0.rcMode'
        emit_values "vbr\navbr\ncbr"
        ;;
    "get air camera rec_enable")
        [ "$(get_majestic_value '.records.enabled')" = "true" ] && echo 1 || echo 0
        ;;
    "get air camera rec_split")
        get_majestic_value '.records.split'
        emit_values "0 60"
        ;;
    "get air camera rec_maxusage")
        get_majestic_value '.records.maxUsage'
        emit_values "0 100"
        ;;
    "get air camera exposure")
        get_majestic_value '.isp.exposure'
        emit_values "5 50"
        ;;
    "get air camera antiflicker")
        get_majestic_value '.isp.antiFlicker'
        emit_values "disabled\n50\n60"
        ;;
    "get air camera sensor_file")
        basename -s .bin $(basename $(get_majestic_value '.isp.sensorConfig'))
        emit_values "$(cat /tmp/gsmenu_cache/sensor.txt)"
        ;;
    "get air camera fpv_enable")
        get_majestic_value '.fpv.enabled' | grep -q true && echo 1 || echo 0
        ;;
    "get air camera noiselevel")
        get_majestic_value '.fpv.noiseLevel'
        emit_values "0 1"
        ;;

    "set air camera mirror"*)
        if [ "$5" = "on" ]; then
            $SSH 'cli -s .image.mirror true && killall -1 majestic'
        else
            $SSH 'cli -s .image.mirror false && killall -1 majestic'
        fi
        ;;
    "set air camera flip"*)
        if [ "$5" = "on" ]; then
            $SSH 'cli -s .image.flip true && killall -1 majestic'
        else
            $SSH 'cli -s .image.flip false && killall -1 majestic'
        fi
        ;;
    "set air camera contrast"*)
        $SSH "cli -s .image.contrast $5 && killall -1 majestic"
        ;;
    "set air camera hue"*)
        $SSH "cli -s .image.hue $5 && killall -1 majestic"
        ;;
    "set air camera saturation"*)
        $SSH "cli -s .image.saturation $5 && killall -1 majestic"
        ;;
    "set air camera luminace"*)
        $SSH "cli -s .image.luminance $5 && killall -1 majestic"
        ;;
    "set air camera size"*)
        $SSH "cli -s .video0.size $5 && killall -1 majestic"
        ;;
    "set air camera video_mode"*)
        echo set_simple_video_mode "$5" | nc -w 11 $REMOTE_IP 12355
        ;;
    "set air camera fps"*)
        $SSH "cli -s .video0.fps $5 && killall -1 majestic"
        ;;
    "set air camera bitrate"*)
        $SSH "cli -s .video0.bitrate $5 && killall -1 majestic"
        ;;
    "set air camera codec"*)
        $SSH "cli -s .video0.codec $5 && killall -1 majestic"
        ;;
    "set air camera gopsize"*)
        $SSH "cli -s .video0.gopSize $5 && killall -1 majestic"
        ;;
    "set air camera rc_mode"*)
        $SSH "cli -s .video0.rcMode $5 && killall -1 majestic"
        ;;
    "set air camera rec_enable"*)
        if [ "$5" = "on" ]; then
            $SSH 'cli -s .records.enable true && killall -1 majestic'
        else
            $SSH 'cli -s .records.enable false && killall -1 majestic'
        fi
        ;;
    "set air camera rec_split"*)
        $SSH "cli -s .records.split $5 && killall -1 majestic"
        ;;
    "set air camera rec_maxusage"*)
        $SSH "cli -s .records.maxUsage $5 && killall -1 majestic"
        ;;
    "set air camera exposure"*)
        $SSH "cli -s .isp.exposure $5 && killall -1 majestic"
        ;;
    "set air camera antiflicker"*)
        $SSH "cli -s .isp.antiFlicker $5 && killall -1 majestic"
        ;;
    "set air camera sensor_file"*)
        $SSH "cli -s .isp.sensorConfig /etc/sensors/${5}.bin && killall -1 majestic"
        ;;
    "set air camera fpv_enable"*)
        if [ "$5" = "on" ]; then
            $SSH 'cli -s .fpv.enabled true && killall -1 majestic'
        else
            $SSH 'cli -s .fpv.enabled false && killall -1 majestic'
        fi
        ;;
    "set air camera noiselevel"*)
        $SSH "cli -s .fpv.noiseLevel $5 && killall -1 majestic"
        ;;

# ── Air: Telemetry ───────────────────────────────────────────────────────────

    "get air telemetry serial")
        if [ $AIR_FIRMWARE_TYPE = "wfb" ]; then
            $SSH wifibroadcast cli -g .telemetry.serial
        elif [ $AIR_FIRMWARE_TYPE = "apfpv" ]; then
            tty=$($SSH "fw_printenv -n msposd_tty")
            if [ ! -z $tty ]; then
                basename "$tty"
            else
                echo ttyS2
            fi
        fi
        emit_values "ttyS0\nttyS1\nttyS2\nttyS3"
        ;;
    "get air telemetry router")
        $SSH wifibroadcast cli -g .telemetry.router
        emit_values "mavfwd\nmsposd"
        ;;
    "get air telemetry osd_fps")
        $SSH wifibroadcast cli -g .telemetry.osd_fps
        emit_values "0 60"
        ;;
    "get air telemetry gs_rendering")
        $SSH 'grep "\-z \"\$size\"" /usr/bin/wifibroadcast' | grep -q size && echo 0 || echo 1
        ;;

    "set air telemetry serial"*)
        if [ "$5" = "ttyS0" ]; then
          $SSH "sed -i 's/^console::respawn:\/sbin\/getty -L console 0 vt100/#console::respawn:\/sbin\/getty -L console 0 vt100/' /etc/inittab ; kill -HUP 1"
        else
          $SSH "sed -i 's/^#console::respawn:\/sbin\/getty -L console 0 vt100/console::respawn:\/sbin\/getty -L console 0 vt100/' /etc/inittab ; kill -HUP 1"
        fi
        if [ $AIR_FIRMWARE_TYPE = "wfb" ]; then
            $SSH wifibroadcast cli -s .telemetry.serial $5
            $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        elif [ $AIR_FIRMWARE_TYPE = "apfpv" ]; then
            $SSH "fw_setenv msposd_tty /dev/$5; /etc/init.d/S99msposd stop ; /etc/init.d/S99msposd stop ; sleep 1; /etc/init.d/S99msposd start"
        fi
        ;;
    "set air telemetry router"*)
        $SSH wifibroadcast cli -s .telemetry.router $5
        $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        ;;
    "set air telemetry osd_fps"*)
        $SSH wifibroadcast cli -s .telemetry.osd_fps $5
        $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        ;;
    "set air telemetry gs_rendering"*)
        if [ "$5" = "on" ]; then
            $SSH 'sed -i "s/-o 127\.0\.0\.1:\"\$port_tx\" -z \"\$size\"/-o 10\.5\.0\.1:\"\$port_tx\"/" /usr/bin/wifibroadcast'
            $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        else
            $SSH 'sed -i "s/-o 10\.5\.0\.1:\"\$port_tx\"/-o 127\.0\.0\.1:\"\$port_tx\" -z \"\$size\"/" /usr/bin/wifibroadcast'
            $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        fi
        ;;

# ── Air: Alink ───────────────────────────────────────────────────────────────

    "get air alink power_level_0_to_4")
        get_alink_value power_level_0_to_4
        emit_values "0\n1\n2\n3\n4"
        ;;
    "get air alink fallback_ms")
        get_alink_value fallback_ms
        emit_values "1 2000"
        ;;
    "get air alink hold_fallback_mode_s")
        get_alink_value hold_fallback_mode_s
        emit_values "1 10"
        ;;
    "get air alink min_between_changes_ms")
        get_alink_value min_between_changes_ms
        emit_values "1 10000"
        ;;
    "get air alink hold_modes_down_s")
        get_alink_value hold_modes_down_s
        emit_values "1 10"
        ;;
    "get air alink hysteresis_percent")
        get_alink_value hysteresis_percent
        emit_values "0 100"
        ;;
    "get air alink hysteresis_percent_down")
        get_alink_value hysteresis_percent_down
        emit_values "0 100"
        ;;
    "get air alink exp_smoothing_factor")
        get_alink_value exp_smoothing_factor
        emit_values "0 1.6"
        ;;
    "get air alink exp_smoothing_factor_down")
        get_alink_value exp_smoothing_factor_down
        emit_values "0 1.6"
        ;;
    "get air alink check_xtx_period_ms")
        get_alink_value check_xtx_period_ms
        emit_values "1 5000"
        ;;
    "get air alink request_keyframe_interval_ms")
        get_alink_value request_keyframe_interval_ms
        emit_values "1 5000"
        ;;
    "get air alink osd_level")
        get_alink_value osd_level
        emit_values "0\n1\n2\n3\n4\n5\n6"
        ;;
    "get air alink multiply_font_size_by")
        get_alink_value multiply_font_size_by
        emit_values "0 1.5"
        ;;
    "get air alink"*)
        get_alink_value $4
        ;;

    "set air alink"*)
        if [ "$5" = "off" ]; then
            $SSH 'sed -i "s/'$4'=.*/'$4'=0/" /etc/alink.conf; killall -9 alink_drone ; alink_drone &'
        elif [ "$5" = "on" ]; then
            $SSH 'sed -i "s/'$4'=.*/'$4'=1/" /etc/alink.conf; killall -9 alink_drone ; alink_drone &'
        elif [ "$4" = "txprofiles" ]; then
            $SCP $CACHE_DIR/txprofiles.conf root@$REMOTE_IP:$TXPROFILES_CONF
            $SSH 'killall -9 alink_drone ; alink_drone &'
        else
            $SSH 'sed -i "s/'$4'=.*/'$4'='$5'/" /etc/alink.conf; killall -9 alink_drone ; alink_drone &'
        fi
        ;;

# ── Air: Aalink ──────────────────────────────────────────────────────────────

    "get air aalink SHOW_SIGNAL_BARS")
        [ "$(get_aalink_value 'SHOW_SIGNAL_BARS')" = "true" ] && echo 1 || echo 0
        ;;
    "get air aalink channel")
        send_cmd get_current_ap_channel
        emit_values_cmd send_cmd get_all_ap_channels
        ;;
    "get air aalink SCALE_TX_POWER")
        get_aalink_value SCALE_TX_POWER
        emit_values "0.2 1.2"
        ;;
    "get air aalink THRESH_SHIFT")
        get_aalink_value THRESH_SHIFT
        emit_values "-50 50"
        ;;
    "get air aalink OSD_SCALE")
        get_aalink_value OSD_SCALE
        emit_values "0.2 2"
        ;;
    "get air aalink OSD_LEVEL")
        get_aalink_value OSD_LEVEL
        emit_values "0\n1\n2\n3"
        ;;
    "get air aalink THROUGHPUT_PCT")
        get_aalink_value THROUGHPUT_PCT
        emit_values "0 100"
        ;;
    "get air aalink HIGH_TEMP")
        get_aalink_value HIGH_TEMP
        emit_values "70 100"
        ;;
    "get air aalink MCS_SOURCE")
        get_aalink_value MCS_SOURCE
        emit_values "lowest\ndownlink"
        ;;
    "get air aalink"*)
        get_aalink_value $4
        ;;

    "set air aalink channel"*)
        echo "set_ap_channel $5" | nc -w 11 $REMOTE_IP 12355
        ;;
    "set air aalink SHOW_SIGNAL_BARS"*)
        case "$5" in
        on|true|1|yes)  val=true  ;;
        *)              val=false ;;
        esac
        $SSH "sed -i 's/^SHOW_SIGNAL_BARS=.*/SHOW_SIGNAL_BARS=$val/' /etc/aalink.conf && kill -SIGHUP \$(pidof aalink)"
        ;;
    "set air aalink"*)
        $SSH 'sed -i "s/^'$4'=.*/'$4'='$5'/" /etc/aalink.conf; kill -SIGHUP $(pidof aalink)'
        ;;

# ── GS: WFB-NG ──────────────────────────────────────────────────────────────

    "get gs wfbng gs_channel")
        channel=$(grep wifi_channel /etc/wifibroadcast.cfg | cut -d ' ' -f 3)
        iw list | grep "\[$channel\]" | tr -d '[]' | awk '{print $4 " (" $2 " " $3 ")"}' | sort -n | uniq | head -c -1
        emit_values_cmd list_wifi_channels
        ;;
    "get gs wfbng bandwidth")
        grep ^bandwidth /etc/wifibroadcast.cfg | cut -d ' ' -f 3
        emit_values "20\n40"
        ;;
    "get gs wfbng txpower")
        wifi_txpower=$(grep ^wifi_txpower /etc/wifibroadcast.cfg)
        if [ -z "$wifi_txpower" ]; then
            echo "50"
        else
            read first_card first_card_power < <(
                echo "$wifi_txpower" | cut -d = -f 2 | jq -r '"\(to_entries[0].key) \(to_entries[0].value)"'
            )
            first_card_type=$(udevadm info /sys/class/net/${first_card} | grep -E 'ID_USB_DRIVER=(rtl88xxau_wfb|rtl88x2eu|rtl88x2cu)'| cut -d = -f2)
            case "$first_card_type" in
            "rtl88xxau_wfb") min_phy_txpower=-1000; max_phy_txpower=-3000 ;;
            "rtl88x2eu"|"rtl88x2cu") min_phy_txpower=1000; max_phy_txpower=2900 ;;
            esac
            range=$((max_phy_txpower - min_phy_txpower))
            position=$((first_card_power - min_phy_txpower))
            percentage=$(( (position * 100) / range ))
            echo $percentage
        fi
        emit_values "1\n100"
        ;;
    "get gs wfbng adaptivelink")
        . /etc/default/adaptive-link
        if [ x$ADAPTIVE_LINK_ENABLED = x"false" ]; then
           echo "0"
        else
            echo "1"
        fi
        ;;

    "set gs wfbng gs_channel"*)
        channel=$(echo $5 | awk '{print $1}')
        if [ "$GSMENU_VTX_DETECTED" -eq "1" ]; then
            $SSH wifibroadcast cli -s .wireless.channel $channel
            $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        fi
        sed -i "s/^wifi_channel =.*/wifi_channel = $channel/" /etc/wifibroadcast.cfg
        /etc/init.d/S98wifibroadcast restart
        ;;
    "set gs wfbng bandwidth"*)
        sed -i "s/^bandwidth = .*/bandwidth = $5/" /etc/wifibroadcast.cfg
        /etc/init.d/S98wifibroadcast restart
        ;;
    "set gs wfbng txpower"*)
        .  /etc/default/wifibroadcast
        wifi_txpower=""
        for nic in $WFB_NICS
        do
            card_type=$(udevadm info /sys/class/net/${nic} | grep -E 'ID_USB_DRIVER=(rtl88xxau_wfb|rtl88x2eu|rtl88x2cu)'| cut -d = -f2)
            case "$card_type" in
            "rtl88xxau_wfb") min_phy_txpower=-1000; max_phy_txpower=-3000 ;;
            "rtl88x2eu"|"rtl88x2cu") min_phy_txpower=1000; max_phy_txpower=2900 ;;
            esac
            range=$((max_phy_txpower - min_phy_txpower))
            percentage=$5
            power_value=$(( min_phy_txpower + (percentage * range) / 100 ))
            [ ! -z "$wifi_txpower" ] && wifi_txpower=$wifi_txpower,
            wifi_txpower=$wifi_txpower" \"$nic\": $power_value"
        done
        if ! grep -A 20 "\[common\]" /etc/wifibroadcast.cfg | grep -q "^wifi_txpower = "; then
            sed -i "/^\[common\]/a\wifi_txpower = {$wifi_txpower}" /etc/wifibroadcast.cfg
        else
            sed -i "s/^wifi_txpower = .*/wifi_txpower = {$wifi_txpower}/" /etc/wifibroadcast.cfg
        fi
        /etc/init.d/S98wifibroadcast restart
        ;;
    "set gs wfbng adaptivelink"*)
        if [ "$5" = "on" ]; then
            sed -i 's/ADAPTIVE_LINK_ENABLED.*/ADAPTIVE_LINK_ENABLED=true/' /etc/default/adaptive-link
            /etc/init.d/S98adaptive-link start
        else
            /etc/init.d/S98adaptive-link stop
            sed -i 's/ADAPTIVE_LINK_ENABLED.*/ADAPTIVE_LINK_ENABLED=false/' /etc/default/adaptive-link
        fi
        ;;

# ── GS: System ──────────────────────────────────────────────────────────────

    "get gs system rx_codec")
        . /etc/default/pixelpilot
        echo $PIXELPILOT_CODEC
        emit_values "h264\nh265"
        ;;
    "get gs system rx_mode")
        . /etc/default/wifibroadcast
        if [ x$WIFIBROADCAST_ENABLED = x"false" ]; then
           echo "apfpv"
        else
            echo "wfb"
        fi
        emit_values "wfb\napfpv"
        ;;
    "get gs system gs_rendering")
        . /etc/default/msposd
        [ x$MSPOSD_ENABLED = x"false" ] && echo 0 || echo 1
        ;;
    "get gs system connector")
        echo HDMI
        emit_values "HDMI"
        ;;
    "get gs system resolution")
        drm_info -j /dev/dri/card0 2>/dev/null | jq -r '."/dev/dri/card0".crtcs[0].mode| .name + "@" + (.vrefresh|tostring)'
        printf '\x1e'
        drm_info -j /dev/dri/card0 2>/dev/null | jq -r '."/dev/dri/card0".connectors[1].modes[] | select(.name | contains("i") | not) | .name + "@" + (.vrefresh|tostring)' | sort | uniq | head -c -1
        ;;
    "get gs system video_scale")
        . /etc/default/pixelpilot
        echo $PIXELPILOT_VIDEO_SCALE
        emit_values "0.5 1.0"
        ;;
    "get gs system rec_fps")
        . /etc/default/pixelpilot
        echo $PIXELPILOT_DVR_FRAMERATE
        emit_values "60\n90\n120"
        ;;
    "get gs system dvr_mode")
        . /etc/default/pixelpilot
        echo $PIXELPILOT_DVR_MODE
        emit_values "raw\nreencode\nboth"
        ;;
    "get gs system dvr_max_size")
        . /etc/default/pixelpilot
        echo $(( $PIXELPILOT_DVR_MAX_SIZE / 100 ))
        emit_values "1 40"
        ;;
    "get gs system dvr_reenc_codec")
        . /etc/default/pixelpilot
        echo $PIXELPILOT_DVR_CODEC
        emit_values "h264\nh265"
        ;;
    "get gs system dvr_reenc_resolution")
        . /etc/default/pixelpilot
        echo $PIXELPILOT_DVR_RESOLUTION
        emit_values "720p\n1080p"
        ;;
    "get gs system dvr_reenc_fps")
        . /etc/default/pixelpilot
        echo $PIXELPILOT_DVR_FPS
        emit_values "30\n60"
        ;;
    "get gs system dvr_reenc_bitrate")
        . /etc/default/pixelpilot
        echo $PIXELPILOT_DVR_BITRATE
        emit_values "5000\n10000\n15000\n20000\n25000\n30000\n35000\n40000\n45000\n50000"
        ;;

    "set gs system rx_codec"*)
        sed -i "s/^PIXELPILOT_CODEC=.*/PIXELPILOT_CODEC=\"$5\"/" /etc/default/pixelpilot
        ;;
    "set gs system gs_live_colortrans"*)
        if [ "$5" = "on" ]
        then
            sed -i "s/^PIXELPILOT_LIVE_COLORTRANS=.*/PIXELPILOT_LIVE_COLORTRANS=\"--live-colortrans\"/" /etc/default/pixelpilot
        else
            sed -i "s/^PIXELPILOT_LIVE_COLORTRANS=.*/PIXELPILOT_LIVE_COLORTRANS=\"\"/" /etc/default/pixelpilot
        fi
        ;;
    "set gs system rx_mode"*)
        EXCLUDE_IFACE="wlan0"
        SSID="${6:-OpenIPC}"
        PASSWORD="${7:-12345678}"
        if [ "$5" = "apfpv" ]; then
            /etc/init.d/S98adaptive-link stop
            /etc/init.d/S98wifibroadcast stop
            sed -i 's/WIFIBROADCAST_ENABLED.*/WIFIBROADCAST_ENABLED=false/' /etc/default/wifibroadcast
            sed -i 's/ADAPTIVE_LINK_ENABLED.*/ADAPTIVE_LINK_ENABLED=false/' /etc/default/adaptive-link
            rmmod 8812eu
            rmmod 88XXau_wfb
            modprobe 8812eu
            modprobe 88XXau_wfb
            cat <<EOF > /etc/wpa_supplicant.apfpv.conf
network={
    ssid="$SSID"
    psk="$PASSWORD"
}

EOF
            WIFI_IFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep '^wlx' | grep -v "^$EXCLUDE_IFACE$")
            INDEX=0
            for IFACE in $WIFI_IFACES; do
cat <<EOF > /etc/network/interfaces.d/$IFACE
$( [ $INDEX -eq 0 ] && echo "auto $IFACE" || echo "#auto $IFACE")
iface $IFACE inet dhcp
  wpa-conf /etc/wpa_supplicant.apfpv.conf
  udhcpc_opts -s /etc/udhcpc/udhcpc.apfpv.script

EOF
            [ $INDEX -eq 0 ] && ifup $IFACE
            INDEX=$((INDEX + 1))
            done
        elif [ "$5" = "wfb" ]; then
            WIFI_IFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^wlx' | grep -v "^$EXCLUDE_IFACE$")
            INDEX=0
            for IFACE in $WIFI_IFACES; do
                ifdown $IFACE
                rm /etc/network/interfaces.d/$IFACE
            done
            rmmod 8812eu
            rmmod 88XXau_wfb
            modprobe 8812eu
            modprobe 88XXau_wfb
            sed -i 's/WIFIBROADCAST_ENABLED.*/WIFIBROADCAST_ENABLED=true/' /etc/default/wifibroadcast
            sed -i 's/ADAPTIVE_LINK_ENABLED.*/ADAPTIVE_LINK_ENABLED=true/' /etc/default/adaptive-link
            /etc/init.d/S98adaptive-link start
            /etc/init.d/S98wifibroadcast start
        fi
        ;;
    "set gs system gs_rendering"*)
        if [ "$5" = "off" ]; then
            /etc/init.d/S98msposd stop
            sed -i 's/MSPOSD_ENABLED.*/MSPOSD_ENABLED=false/' /etc/default/msposd
        else
            sed -i 's/MSPOSD_ENABLED.*/MSPOSD_ENABLED=true/' /etc/default/msposd
            /etc/init.d/S98msposd start
        fi
        ;;
    "set gs system gs_live_colortrans"*)
        if [ "$5" = "on" ]; then
            sed -i "s/^PIXELPILOT_LIVE_COLORTRANS=.*/PIXELPILOT_LIVE_COLORTRANS=\"--live-colortrans\"/" /etc/default/pixelpilot
        else
            sed -i "s/^PIXELPILOT_LIVE_COLORTRANS=.*/PIXELPILOT_LIVE_COLORTRANS=\"\"/" /etc/default/pixelpilot
        fi
        ;;
    "set gs system resolution"*)
        sed -i "s/^PIXELPILOT_SCREEN_MODE=.*/PIXELPILOT_SCREEN_MODE=\"$5\"/" /etc/default/pixelpilot
        ;;
    "set gs system video_scale"*)
        sed -i "s/^PIXELPILOT_VIDEO_SCALE=.*/PIXELPILOT_VIDEO_SCALE=$5/" /etc/default/pixelpilot
        ;;
    "set gs system rec_fps"*)
        sed -i "s/^PIXELPILOT_DVR_FRAMERATE=.*/PIXELPILOT_DVR_FRAMERATE=$5/" /etc/default/pixelpilot
        ;;
    "set gs system rec_enabled"*)
        if [ "$5" = "off" ]; then
            : #noop
        else
            : #noop
        fi
        ;;
    "set gs system dvr_mode"*)
        sed -i "s/^PIXELPILOT_DVR_MODE=.*/PIXELPILOT_DVR_MODE=\"$5\"/" /etc/default/pixelpilot
        ;;
    "set gs system dvr_max_size"*)
        sed -i "s/^PIXELPILOT_DVR_MAX_SIZE=.*/PIXELPILOT_DVR_MAX_SIZE=\"$(( $5 * 100 ))\"/" /etc/default/pixelpilot
        ;;
    "set gs system dvr_reenc_resolution"*)
        sed -i "s/^PIXELPILOT_DVR_RESOLUTION=.*/PIXELPILOT_DVR_RESOLUTION=\"$5\"/" /etc/default/pixelpilot
        ;;
    "set gs system dvr_reenc_codec"*)
        sed -i "s/^PIXELPILOT_DVR_CODEC=.*/PIXELPILOT_DVR_CODEC=\"$5\"/" /etc/default/pixelpilot
        ;;
    "set gs system dvr_reenc_fps"*)
        sed -i "s/^PIXELPILOT_DVR_FPS=.*/PIXELPILOT_DVR_FPS=\"$5\"/" /etc/default/pixelpilot
        ;;
    "set gs system dvr_reenc_bitrate"*)
        sed -i "s/^PIXELPILOT_DVR_BITRATE=.*/PIXELPILOT_DVR_BITRATE=\"$5\"/" /etc/default/pixelpilot
        ;;
    "set gs system dvr_osd"*)
        if [ "$5" = "on" ]; then
            sed -i "s/^PIXELPILOT_DVR_OSD=.*/PIXELPILOT_DVR_OSD=\"--dvr-osd\"/" /etc/default/pixelpilot
        else
            sed -i "s/^PIXELPILOT_DVR_OSD=.*/PIXELPILOT_DVR_OSD=\"\"/" /etc/default/pixelpilot
        fi
        ;;

# ── GS: APFPV ───────────────────────────────────────────────────────────────

    "get gs apfpv ssid")
        grep ssid /etc/wpa_supplicant.apfpv.conf  | cut -d \" -f 2
        ;;
    "get gs apfpv password")
        grep psk /etc/wpa_supplicant.apfpv.conf  | cut -d \" -f 2
        ;;
    "get gs apfpv wlx"*)
        grep -q "^auto $4" /etc/network/interfaces.d/$4 && echo 1 || echo 0
        ;;
    "get gs apfpv status wlx"*)
        iw dev $5 link | grep -q "Not connected." && echo Disconnected || echo Connected
        ;;

    "set gs apfpv ssid"*)
        if [ "$GSMENU_VTX_DETECTED" -eq "1" ]; then
            $SSH 'fw_setenv wlanssid "'$5'"'
            $SSH '(hostapd_cli -i wlan0 set ssid "'$5'"; hostapd_cli -i wlan0 reload)  >/dev/null 2>&1 &'
        fi
        sed -i "s/ssid=.*/ssid=\""$5"\"/" /etc/wpa_supplicant.apfpv.conf
        WIFI_IFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep '^wlx')
        INDEX=0
        for IFACE in $WIFI_IFACES; do
            if [ $($0 get gs apfpv $IFACE) = 1 ]; then
                ifdown $IFACE
                sleep 1
                ifup $IFACE
            fi
            INDEX=$((INDEX + 1))
        done
        ;;
    "set gs apfpv password"*)
        if [ "$GSMENU_VTX_DETECTED" -eq "1" ]; then
            $SSH 'fw_setenv wlanpass "'$5'"'
            $SSH '(hostapd_cli -i wlan0 set wpa_passphrase "'$5'"; hostapd_cli -i wlan0 reload)  >/dev/null 2>&1 &'
        fi
        sed -i "s/psk=.*/psk=\""$5"\"/" /etc/wpa_supplicant.apfpv.conf
        WIFI_IFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep '^wlx')
        INDEX=0
        for IFACE in $WIFI_IFACES; do
            if [ $($0 get gs apfpv $IFACE) = 1 ]; then
                ifdown $IFACE
                sleep 1
                ifup $IFACE
            fi
            INDEX=$((INDEX + 1))
        done
        ;;
    "set gs apfpv wlx"*)
        if [ $5 = "on" ]; then
            sed -i "s/^#auto/auto/" /etc/network/interfaces.d/$4
            ifup $4
        else
            sed -i "s/^auto/#auto/" /etc/network/interfaces.d/$4
            ifdown $4
            DRV_PATH=$(readlink -f /sys/class/net/$4/device/driver 2>/dev/null || true)
            DEV_PATH=$(readlink -f /sys/class/net/$4/device 2>/dev/null || true)
            DRV_NAME=$(basename "$DRV_PATH")
            DEV_NAME=$(basename "$DEV_PATH")
            echo -n "$DEV_NAME" > /sys/bus/usb/drivers/$DRV_NAME/unbind >/dev/null
            sleep 1
            echo -n "$DEV_NAME" > /sys/bus/usb/drivers/$DRV_NAME/bind >/dev/null
            sleep 1
        fi
        ;;
    "set gs apfpv reset")
        for CONN in /etc/network/interfaces.d/wlx*; do
            ifdown $(basename $CONN)
            rm $CONN
        done
        ;;

# ── GS: WiFi ────────────────────────────────────────────────────────────────

    "get gs wifi hotspot")
        if [ -f /etc/wpa_supplicant.hotspot.conf ] && ip addr show wlan0 2>/dev/null | grep -q "inet "; then
            echo 1
        else
            echo 0
        fi
        ;;
    "get gs wifi wlan")
        if [ -f /etc/network/interfaces.d/wlan0 ] && \
        [ ! -f /etc/wpa_supplicant.hotspot.conf ] && \
        ip addr show wlan0 2>/dev/null | grep -q "inet "; then
            echo 1
        else
            echo 0
        fi
        ;;
    "get gs wifi ssid")
        if [ -f /etc/wpa_supplicant.conf ]; then
            grep ssid /etc/wpa_supplicant.conf | cut -d = -f 2 | cut -d \" -f 2
        else
            echo -n ""
        fi
        ;;
    "get gs wifi password")
        if [ -f /etc/wpa_supplicant.conf ]; then
            grep psk /etc/wpa_supplicant.conf | cut -d = -f 2 | cut -d \" -f 2
        else
            echo -n ""
        fi
        ;;
    "get gs wifi IP")
        ip -4 addr show | grep "inet " | awk '{print $2}'
        ;;

    "set gs wifi wlan"*)
        [ ! -d /sys/class/net/wlan0 ] && exit 0
        if [ "$5" = "on" ]; then
            if [ -f /etc/wpa_supplicant.hotspot.conf ]; then
                ifdown wlan0
                rm /etc/network/interfaces.d/wlan0
                rm /etc/wpa_supplicant.hotspot.conf
            fi
            cat <<EOF > /etc/wpa_supplicant.conf
network={
    ssid="$6"
    psk="$7"
}
EOF
            cat <<EOF > /etc/network/interfaces.d/wlan0
auto wlan0
iface wlan0 inet dhcp
wpa-conf /etc/wpa_supplicant.conf
EOF
            ifup wlan0
        else
            ifdown wlan0
            rm -f /etc/network/interfaces.d/wlan0
        fi
        ;;
    "set gs wifi hotspot"*)
        [ ! -d /sys/class/net/wlan0 ] && exit 0
        if [ "$5" = "on" ]; then
            if [ -f /etc/network/interfaces.d/wlan0 ]; then
                ifdown wlan0
                rm /etc/network/interfaces.d/wlan0
            fi
            cat <<EOF > /etc/wpa_supplicant.hotspot.conf
network={
    mode=2
    frequency=2412
    ssid="OpenIPC GS"
    psk="12345678"
}
EOF
            cat <<EOF > /etc/network/interfaces.d/wlan0
iface wlan0 inet static
    address 192.168.4.1
    netmask 255.255.255.0
    post-up udhcpd -S
    pre-down killall -q udhcpd
wpa-conf /etc/wpa_supplicant.hotspot.conf
EOF
            ifup wlan0
        else
            ifdown wlan0
            rm /etc/network/interfaces.d/wlan0
            rm /etc/wpa_supplicant.hotspot.conf
        fi
        ;;

# ── GS: Main page (info labels) ─────────────────────────────────────────────

    "get gs main Channel")
        gsmenu.sh get gs wfbng gs_channel | head -1
        ;;
    "get gs main HDMI-OUT")
        gsmenu.sh get gs system resolution | head -1
        ;;
    "get gs main Version")
        . /etc/os-release
        echo $PRETTY_NAME $VERSION
        ;;
    "get gs main Disk")
        df -h /media/dvr | awk 'NR==2 {print $2, $4, $5}' | while read -r size avail pcent
        do
            echo -e "\n   Size: $size\n   Available: $avail\n   Pct: $pcent\c"
            exit 0
        done
        ;;
    "get gs main WFB_NICS")
        . /etc/default/wifibroadcast
        echo $WFB_NICS
        ;;

# ── Buttons / Actions ───────────────────────────────────────────────────────

    "button air actions Reboot")
        $SSH 'reboot &'
        ;;
    "button gs actions Reboot")
        reboot
        ;;
    "search channel")
        echo "Not implmented"
        echo "Not implmented" >&2
        exit 1
        ;;

# ── Unknown command ──────────────────────────────────────────────────────────

    *)
        echo "Unknown $@"
        exit 1
        ;;
esac

case $? in
    0) ;;
    1) exit 0 ;;
    *) exit $? ;;
esac
