#!/bin/sh
set -o pipefail

# Configuration
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
PRESET_DIR="/etc/presets"

# SSH command setup
SSH="timeout -k 1 11 sshpass -p $SSH_PASS ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ControlMaster=auto -o ControlPath=/run/ssh_control:%h:%p:%r -o ControlPersist=15s -o ServerAliveInterval=3 -o ServerAliveCountMax=2 root@$REMOTE_IP"
SCP="timeout -k 1 11 sshpass -p $SSH_PASS scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ControlMaster=auto -o ControlPath=/run/ssh_control:%h:%p:%r -o ControlPersist=15s -o ServerAliveInterval=3 -o ServerAliveCountMax=2"

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

# Function to refresh cached files
refresh_cache() {
    local current_time=$(date +%s)
    local last_refresh=$((current_time - CACHE_TTL))
    
    # Check if we need to refresh
    if [[ ! -f "$CACHE_DIR/last_refresh" ]] || [[ $(cat "$CACHE_DIR/last_refresh") -lt $last_refresh ]]; then
        # Copy the YAML configuration files
        files="$MAJESTIC_YAML $WFB_YAML $ALINK_CONF $TXPROFILES_CONF $AALINK_CONF"
        $SSH "tar cf - $files" 2>/dev/null | tar xf - --strip-components 1 -C /tmp/gsmenu_cache/ 2>/dev/null
        # Update refresh timestamp
        echo "$current_time" > "$CACHE_DIR/last_refresh"
    fi
}

# Function to get value from majestic.yaml using yaml-cli
get_majestic_value() {
    local key="$1"
    yaml-cli -i "$CACHE_DIR/majestic.yaml" -g "$key" 2>/dev/null
}

# Function to get value from wfb.yaml using yaml-cli
get_wfb_value() {
    local key="$1"
    yaml-cli -i "$CACHE_DIR/wfb.yaml" -g "$key" 2>/dev/null
}

# Function to get value from alink.conf
get_alink_value() {
    local key="$1"
    grep $key= "$CACHE_DIR/alink.conf" | cut -d "=" -f 2 2>/dev/null
}

# Function to get value from alink.conf
get_aalink_value() {
    local key="$1"
    grep ^$key= "$CACHE_DIR/aalink.conf" | cut -d "=" -f 2 2>/dev/null
}

# Refresh cache for get
case "$@" in
  "get air"*)
    [ "$3" != "presets" ] && refresh_cache
    ;;
esac

case "$@" in
    "values air presets preset")
        if [ -d $PRESET_DIR ]; then
            for dir in $PRESET_DIR/presets/*; do
                echo $(basename $dir)
            done
        fi
    ;;
    "values air wfbng mcs_index")
        echo -n 0 10
        ;;
    "values air wfbng fec_k")
        echo -n 0 15
        ;;
    "values air wfbng fec_n")
        echo -n 0 15
        ;;
    "values air wfbng mlink")
        echo -n -e "1500\n1600\n1700\n1800\n1900\n2000\n2100\n2200\n2300\n2400\n2500\n2600\n2700\n2800\n2900\n3000\n3100\n3200\n3300\n3400\n3500\n3600\n3700\n3800\n3900\n4000"
        ;;
    "values air camera contrast")
        echo -n 0 100
        ;;
    "values air camera hue")
        echo -n 0 100
        ;;
    "values air camera saturation")
        echo -n 0 100
        ;;
    "values air camera luminace")
        echo -n 0 100
        ;;
    "values air camera gopsize")
        echo -n 0 10
        ;;
    "values air camera rec_split")
        echo -n 0 60
        ;;
    "values air camera rec_maxusage")
        echo -n 0 100
        ;;
    "values air camera exposure")
        echo -n 5 50
        ;;
    "values air camera noiselevel")
        echo -n 0 1
        ;;
    "values air telemetry osd_fps")
        echo -n 0 60
        ;;
    "values air wfbng power")
        echo -n -e "1\n20\n25\n30\n35\n40\n45\n50\n55\n58"
        ;;
    "values air wfbng air_channel")
        iw list | grep MHz | grep -v disabled | grep -v "radar detection" | grep \* | tr -d '[]' | awk '{print $4 " (" $2 " " $3 ")"}' | grep '^[1-9]' | sort -n |  uniq  | head -c -1
        ;;
    "values air wfbng width")
        echo -n -e "20\n40"
        ;;
    "values air alink power_level_0_to_4")
        echo -n -e "0\n1\n2\n3\n4"
        ;;
    "values air alink fallback_ms")
        echo -n  1 2000
        ;;
    "values air alink hold_fallback_mode_s")
        echo -n  1 10
        ;;
    "values air alink min_between_changes_ms")
        echo -n 1 10000
        ;;
    "values air alink hold_modes_down_s")
        echo -n 1 10
        ;;
    "values air alink hysteresis_percent")
        echo -n 0 100
        ;;
    "values air alink hysteresis_percent_down")
        echo -n 0 100
        ;;
    "values air alink exp_smoothing_factor")
        echo -n 0 1.6
        ;;
    "values air alink exp_smoothing_factor_down")
        echo -n 0 1.6
        ;;
    "values air alink check_xtx_period_ms")
        echo -n 1 5000
        ;;
    "values air alink request_keyframe_interval_ms")
        echo -n 1 5000
        ;;
    "values air alink osd_level")
        echo -n -e "0\n1\n2\n3\n4\n5\n6"
        ;;
    "values air alink multiply_font_size_by")
        echo -n 0 1.5
        ;;
    "values air aalink channel")
        echo -n -e "36\n40\n44\n48\n52\n56\n60\n64\n100\n104\n108\n112\n116\n120\n124\n128\n132\n136\n140\n144\n149\n153\n157\n161\n165\n36_40\n44_48\n52_56\n60_64\n100_104\n108_112\n116_120\n124_128\n132_136\n140_144\n149_153\n157_161\n36_48\n52_64\n100_112\n116_128\n132_144\n149_161"
        ;;
    "values air aalink SCALE_TX_POWER")
        echo -n 0.2 1.2
        ;;
    "values air aalink THRESH_SHIFT")
        echo -n -50 50
        ;;
    "values air aalink OSD_SCALE")
        echo -n 0.2 2
        ;;
    "values air aalink THROUGHPUT_PCT")
        echo -n 0 100
        ;;
    "values air aalink HIGH_TEMP")
        echo -n 70 100
        ;;
    "values air aalink MCS_SOURCE")
        echo -n -e "lowest\ndownlink"
        ;;
    "values air camera size")
        echo -n -e "1280x720\n1456x816\n1920x1080\n1440x1080\n1920x1440\n2104x1184\n2208x1248\n2240x1264\n2312x1304\n2436x1828\n2512x1416\n2560x1440\n2560x1920\n2720x1528\n2944x1656\n3200x1800\n3840x2160"
        ;;
    "values air camera video_mode")
        echo -ne "16:9 720p 30\n16:9 720p 30 50HzAC\n16:9 1080p 30\n16:9 1080p 30 50HzAC\n16:9 1440p 30\n16:9 1440p 30 50HzAC\n16:9 4k 2160p 30\n16:9 4k 2160p 30 50HzAC\n16:9 540p 60\n16:9 540p 60 50HzAC\n16:9 720p 60\n16:9 720p 60 50HzAC\n16:9 1080p 60\n16:9 1080p 60 50HzAC\n16:9 1440p 60\n16:9 1440p 60 50HzAC\n16:9 1688p 60\n16:9 1688p 60 50HzAC\n16:9 540p 90\n16:9 540p 90 50HzAC\n16:9 720p 90\n16:9 720p 90 50HzAC\n16:9 1080p 90\n16:9 1080p 90 50HzAC\n16:9 540p 120\n16:9 720p 120\n16:9 816p 120\n4:3 720p 30\n4:3 720p 30 50HzAC\n4:3 960p 30\n4:3 960p 30 50HzAC\n4:3 1080p 30\n4:3 1080p 30 50HzAC\n4:3 1440p 30\n4:3 1440p 30 50HzAC\n4:3 2160p 30\n4:3 2160p 30 50HzAC\n4:3 720p 60\n4:3 720p 60 50HzAC\n4:3 960p 60\n4:3 960p 60 50HzAC\n4:3 1080p 60\n4:3 1080p 60 50HzAC\n4:3 1440p 60\n4:3 1440p 60 50HzAC\n4:3 1688p 60\n4:3 1688p 60 50HzAC\n4:3 720p 90\n4:3 720p 90 50HzAC\n4:3 960p 90\n4:3 960p 90 50HzAC\n4:3 1080p 90\n4:3 1080p 90 50HzAC\n4:3 540p 120\n4:3 720p 120\n4:3 816p 120"
        ;;
    "values air camera fps")
        echo -n -e "60\n90\n120"
        ;;
    "values air camera bitrate")
        echo -n -e "1024\n2048\n3072\n4096\n5120\n6144\n7168\n8192\n9216\n10240\n11264\n12288\n13312\n14336\n15360\n16384\n17408\n18432\n19456\n20480\n21504\n22528\n23552\n24576\n25600\n26624\n27648\n28672\n29692\n30720"
        ;;
    "values air camera codec")
        echo -n -e "h264\nh265"
        ;;
    "values air camera rc_mode")
        echo -n -e "vbr\navbr\ncbr"
        ;;
    "values air camera antiflicker")
        echo -n -e "disabled\n50\n60"
        ;;
    "values air camera sensor_file")
        echo -n -e "imx307\nimx335\nimx335_fpv\nimx415_fpv\nimx415_fpv\nimx415_milos10\nimx415_milos15\nimx335_milos12tweak\nimx335_greg15\nimx335_spike5\ngregspike05"
        ;;
    "values air telemetry serial")
        echo -n -e "ttyS0\nttyS1\nttyS2\nttyS3"
        ;;
    "values air telemetry router")
        echo -n -e "mavfwd\nmsposd"
        ;;

    "get air presets info"*)
        if [ "$5" == "" ] ; then
            echo ""
        else
            echo "Name: $(yaml-cli -i $PRESET_DIR/presets/$5/preset-config.yaml -g .name)"
            echo "Author: $(yaml-cli -i $PRESET_DIR/presets/$5/preset-config.yaml -g .author)"
            echo "Description: $(yaml-cli -i $PRESET_DIR/presets/$5/preset-config.yaml -g .description)"
            echo "Category: $(yaml-cli -i $PRESET_DIR/presets/$5/preset-config.yaml -g .category)"
            echo "Sensor: $(yaml-cli -i $PRESET_DIR/presets/$5/preset-config.yaml -g .sensor)"
            echo "Status: $(yaml-cli -i $PRESET_DIR/presets/$5/preset-config.yaml -g .status)"
            echo "Tags: $(yaml-cli -i $PRESET_DIR/presets/$5/preset-config.yaml -g .tags)"
        fi
    ;;
    "get air presets update")
        mkdir -p $PRESET_DIR
        if [ -d "$PRESET_DIR/.git" ]; then
            # If it's already a git repo, force reset and pull
            cd $PRESET_DIR
            git fetch --all
            git reset --hard origin/master
            git pull origin master --force
        else
            # If not a git repo yet, clone fresh
            git clone https://github.com/OpenIPC/fpv-presets.git $PRESET_DIR
        fi
    ;;
    "get air camera mirror")
        [ "$(get_majestic_value '.image.mirror')" = "true" ] && echo 1 || echo 0
        ;;
    "get air camera flip")
        [ "$(get_majestic_value '.image.flip')" = "true" ] && echo 1 || echo 0
        ;;
    "get air camera contrast")
        get_majestic_value '.image.contrast'
        ;;
    "get air camera hue")
        get_majestic_value '.image.hue'
        ;;
    "get air camera saturation")
        get_majestic_value '.image.saturation'
        ;;
    "get air camera luminace")
        get_majestic_value '.image.luminance'
        ;;
    "get air camera size")
        get_majestic_value '.video0.size'
        ;;
    "get air camera video_mode")
        echo get_current_video_mode | nc -w 11 $REMOTE_IP 12355
        ;;
    "get air camera fps")
        get_majestic_value '.video0.fps'
        ;;
    "get air camera bitrate")
        get_majestic_value '.video0.bitrate'
        ;;
    "get air camera codec")
        get_majestic_value '.video0.codec'
        ;;
    "get air camera gopsize")
        get_majestic_value '.video0.gopSize'
        ;;
    "get air camera rc_mode")
        get_majestic_value '.video0.rcMode'
        ;;
    "get air camera rec_enable")
        [ "$(get_majestic_value '.records.enabled')" = "true" ] && echo 1 || echo 0
        ;;
    "get air camera rec_split")
        get_majestic_value '.records.split'
        ;;
    "get air camera rec_maxusage")
        get_majestic_value '.records.maxUsage'
        ;;
    "get air camera exposure")
        get_majestic_value '.isp.exposure'
        ;;
    "get air camera antiflicker")
        get_majestic_value '.isp.antiFlicker'
        ;;
    "get air camera sensor_file")
        basename -s .bin $(basename $(get_majestic_value '.isp.sensorConfig'))
        ;;
    "get air camera fpv_enable")
        get_majestic_value '.fpv.enabled' | grep -q true && echo 1 || echo 0
        ;;
    "get air camera noiselevel")
        get_majestic_value '.fpv.noiseLevel'
        ;;

    "set air presets "*)
        PRESET="$PRESET_DIR/presets/$4/preset-config.yaml"

        # Create a temporary script file
        REMOTE_SCRIPT=$(mktemp)
        echo "#!/bin/sh" > "$REMOTE_SCRIPT"
        echo "# Auto-generated configuration script" >> "$REMOTE_SCRIPT"
        echo "echo 'Applying configuration...'" >> "$REMOTE_SCRIPT"

        # Process config files
        FILES=$(yq e '.files | keys | .[]' "$PRESET")

        for FILE in $FILES; do
            # Generate CLI commands for each key-value pair
            while IFS= read -r LINE; do
                KEY="${LINE%% *}"    # Get everything before first space
                VALUE="${LINE#* }"   # Get everything after first space
                
                # Escape single quotes in values for bash
                VALUE=${VALUE//\'/\'\\\'\'}
                
                echo "echo \"Setting $KEY to $VALUE in $FILE\"" >> "$REMOTE_SCRIPT"
                echo "cli -i '/etc/$FILE' -s '$KEY' '$VALUE'" >> "$REMOTE_SCRIPT"
            done < <(yq e ".files[\"$FILE\"] | to_entries | .[] | \".\" + .key + \" \" + .value" "$PRESET")
        done

        # Add additional file copies
        yq e '.additional_files // [] | .[]' "$PRESET" | while read -r ADDITIONAL_FILE; do
            LOCAL_FILE="$PRESET_DIR/presets/$4/$ADDITIONAL_FILE"
            if [ -f "$LOCAL_FILE" ]; then
                # Transfer the file first
                $SCP "$LOCAL_FILE" "root@$REMOTE_IP:/etc/"
                echo "echo 'Copied additional file: $ADDITIONAL_FILE'"
            else
                echo "echo 'Warning: Additional file not found: $ADDITIONAL_FILE'"
            fi
        done

        # Add service restart commands
        echo "echo 'Restarting services...'" >> "$REMOTE_SCRIPT"
        echo "(wifibroadcast stop; wifibroadcast stop; sleep 1; wifibroadcast start) >/dev/null 2>&1 &" >> "$REMOTE_SCRIPT"
        echo "killall -1 majestic" >> "$REMOTE_SCRIPT"
        echo "echo 'Configuration applied successfully'" >> "$REMOTE_SCRIPT"

        # Transfer and execute the script
        $SCP "$REMOTE_SCRIPT" "root@$REMOTE_IP:/tmp/apply_config.sh"
        $SSH "sh /tmp/apply_config.sh"

        # Cleanup
        rm "$REMOTE_SCRIPT"
    ;;
    "set air camera mirror"*)
        if [ "$5" = "on" ]
        then 
            $SSH 'cli -s .image.mirror true && killall -1 majestic'
        else
            $SSH 'cli -s .image.mirror false && killall -1 majestic'
        fi
        ;;
    "set air camera flip"*)
        if [ "$5" = "on" ]
        then 
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
        if [ "$5" = "on" ]
        then 
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
        if [ "$5" = "on" ]
        then     
            $SSH 'cli -s .fpv.enabled true && killall -1 majestic'
        else
            $SSH 'cli -s .fpv.enabled false && killall -1 majestic'
        fi
        ;;
    "set air camera noiselevel"*)
        $SSH "cli -s .fpv.noiseLevel $5 && killall -1 majestic"
        ;;

    "get air telemetry serial")
        if [ $AIR_FIRMWARE_TYPE = "wfb" ]
        then
            $SSH wifibroadcast cli -g .telemetry.serial
        elif [ $AIR_FIRMWARE_TYPE = "apfpv" ]
        then
            tty=$($SSH "fw_printenv -n msposd_tty")
            if [ ! -z $tty ]
            then
                basename "$tty"
            else
                echo ttyS2
            fi
        fi
        ;;
    "get air telemetry router")
        $SSH wifibroadcast cli -g .telemetry.router
        ;;
    "get air telemetry osd_fps")
        $SSH wifibroadcast cli -g .telemetry.osd_fps
        ;;
    "get air telemetry gs_rendering")
        $SSH 'grep "\-z \"\$size\"" /usr/bin/wifibroadcast' | grep -q size && echo 0 || echo 1
        ;;

    "set air telemetry serial"*)
        if [ "$5" = "ttyS0" ]
        then
          $SSH "sed -i 's/^console::respawn:\/sbin\/getty -L console 0 vt100/#console::respawn:\/sbin\/getty -L console 0 vt100/' /etc/inittab ; kill -HUP 1"
        else
          $SSH "sed -i 's/^#console::respawn:\/sbin\/getty -L console 0 vt100/console::respawn:\/sbin\/getty -L console 0 vt100/' /etc/inittab ; kill -HUP 1"
        fi
        if [ $AIR_FIRMWARE_TYPE = "wfb" ]
        then
            $SSH wifibroadcast cli -s .telemetry.serial $5
            $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        elif [ $AIR_FIRMWARE_TYPE = "apfpv" ]
        then
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
        if [ "$5" = "on" ]
        then
            $SSH 'sed -i "s/-o 127\.0\.0\.1:\"\$port_tx\" -z \"\$size\"/-o 10\.5\.0\.1:\"\$port_tx\"/" /usr/bin/wifibroadcast'
            $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        else
            $SSH 'sed -i "s/-o 10\.5\.0\.1:\"\$port_tx\"/-o 127\.0\.0\.1:\"\$port_tx\" -z \"\$size\"/" /usr/bin/wifibroadcast'
            $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        fi
        ;;

    "get air wfbng power")
        get_wfb_value '.wireless.txpower'
        ;;
    "get air wfbng air_channel")
        channel=$(get_wfb_value '.wireless.channel' | tr -d '\n')
        iw list | grep "\[$channel\]" | tr -d '[]' | awk '{print $4 " (" $2 " " $3 ")"}' | sort -n | uniq | tr -d '\n'
        ;;
    "get air wfbng width")
        get_wfb_value '.wireless.width'
        ;;
    "get air wfbng mcs_index")
        get_wfb_value '.broadcast.mcs_index'
        ;;
    "get air wfbng stbc")
        get_wfb_value '.broadcast.stbc'
        ;;
    "get air wfbng ldpc")
        get_wfb_value '.broadcast.ldpc'
        ;;
    "get air wfbng fec_k")
        get_wfb_value '.broadcast.fec_k'
        ;;
    "get air wfbng fec_n")
        get_wfb_value '.broadcast.fec_n'
        ;;
    "get air wfbng mlink")
        get_wfb_value '.wireless.mlink'
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
        if [ "$5" = "on" ]
        then 
            $SSH wifibroadcast cli -s .broadcast.stbc 1
        else
            $SSH wifibroadcast cli -s .broadcast.stbc 0
        fi
        $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        ;;
    "set air wfbng ldpc"*)
        if [ "$5" = "on" ]
        then 
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
        if [ "$5" = "on" ]
        then
            $SSH 'sed -i "/alink_drone &/d" /etc/rc.local && sed -i -e "\$i alink_drone &" /etc/rc.local && cli -s .video0.qpDelta -12 && killall -1 majestic && (nohup alink_drone >/dev/null 2>&1 &)'
        else
            $SSH 'killall -q -9 alink_drone;  sed -i "/alink_drone &/d" /etc/rc.local  ; cli -d .video0.qpDelta && killall -1 majestic'
        fi
        ;;

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
            if [ $($0 get gs apfpv $IFACE) = 1 ]
            then
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
            if [ $($0 get gs apfpv $IFACE) = 1 ]
            then
                ifdown $IFACE
                sleep 1
                ifup $IFACE
            fi
            INDEX=$((INDEX + 1))
        done
        ;;

    "set gs apfpv wlx"*)
        if [ $5 = "on" ]
        then
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
    "get air alink"*)
        get_alink_value $4
        ;;

    "get air aalink channel")
        $SSH "fw_printenv -n wlanchan || echo 157"
        ;;

    "get air aalink"*)
        get_aalink_value $4
        ;;

    "set air aalink channel"*)
        echo "set_ap_channel $5" | nc -w 11 $REMOTE_IP 12355
        ;;

    "set air alink"*)
        if [ "$5" = "off" ]
        then
            $SSH 'sed -i "s/'$4'=.*/'$4'=0/" /etc/alink.conf; killall -9 alink_drone ; alink_drone &'
        elif [ "$5" = "on" ]
        then
            $SSH 'sed -i "s/'$4'=.*/'$4'=1/" /etc/alink.conf; killall -9 alink_drone ; alink_drone &'
        elif [ "$4" = "txprofiles" ]
        then
            $SCP $CACHE_DIR/txprofiles.conf root@$REMOTE_IP:$TXPROFILES_CONF
            $SSH 'killall -9 alink_drone ; alink_drone &'
        else
            $SSH 'sed -i "s/'$4'=.*/'$4'='$5'/" /etc/alink.conf; killall -9 alink_drone ; alink_drone &'
        fi
        ;;

    "set air aalink"*)
            $SSH 'sed -i "s/'$4'=.*/'$4'='$5'/" /etc/aalink.conf; kill -SIGHUP $(pidof aalink)'
        ;;

    "values gs wfbng gs_channel")
        iw list | grep MHz | grep -v disabled | grep -v "radar detection" | grep \* | tr -d '[]' | awk '{print $4 " (" $2 " " $3 ")"}' | grep '^[1-9]' | sort -n |  uniq | head -c -1
        ;;
    "values gs wfbng bandwidth")
        echo -n -e "20\n40"
        ;;
    "values gs wfbng txpower")
        echo -n -e "1\n100"
        ;;
    "values gs system rx_codec")
        echo -n -e "h264\nh265"
        ;;
    "values gs system video_scale")
        echo -n 0.5 1.0
        ;;
    "values gs system rx_mode")
        echo -n -e "wfb\napfpv"
        ;;
    "values gs system connector")
        echo -n -e "HDMI"
        ;;
    "values gs system resolution")
        drm_info -j /dev/dri/card0 2>/dev/null | jq -r '."/dev/dri/card0".connectors[1].modes[] | select(.name | contains("i") | not) | .name + "@" + (.vrefresh|tostring)' | sort | uniq | head -c -1
        ;;
    "values gs system rec_fps")
        echo -n -e "60\n90\n120"
        ;;
    "get gs system rx_codec")
        . /etc/default/pixelpilot
        echo $PIXELPILOT_CODEC
    ;;
    "get gs system rx_mode")
        . /etc/default/wifibroadcast
        if [ x$WIFIBROADCAST_ENABLED = x"false" ]
        then
           echo "apfpv"
        else
            echo "wfb"
        fi
    ;;
    "get gs system gs_rendering")
        . /etc/default/msposd
        [ x$MSPOSD_ENABLED = x"false" ] && echo 0 || echo 1
        ;;
    "get gs system resolution")
        drm_info -j /dev/dri/card0 2>/dev/null | jq -r '."/dev/dri/card0".crtcs[0].mode| .name + "@" + (.vrefresh|tostring)'
        ;;
    "get gs system rec_fps")
        . /etc/default/pixelpilot
        echo $PIXELPILOT_DVR_FRAMERATE
        ;;
    "set gs system rx_codec"*)
        sed -i "s/^PIXELPILOT_CODEC=.*/PIXELPILOT_CODEC=\"$5\"/" /etc/default/pixelpilot
    ;;
    "set gs system rx_mode"*)
            EXCLUDE_IFACE="wlan0"
            SSID="${6:-OpenIPC}"
            PASSWORD="${7:-12345678}"
            if [ "$5" = "apfpv" ]
            then
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
                #ToDO: increase power of gs ln -s /usr/local/bin/gsmenu.sh /etc/NetworkManager/dispatcher.d/
                #ACTION=="change", SUBSYSTEM=="net", KERNEL=="wlx*", ENV{OPERSTATE}=="up", RUN+="/path/to/your/script.sh"
        elif [ "$5" = "wfb" ]
        then
            # ToDo: decrease power rm /etc/NetworkManager/dispatcher.d/gsmenu.sh
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
        if [ "$5" = "off" ]
        then
            /etc/init.d/S98msposd stop
            sed -i 's/MSPOSD_ENABLED.*/MSPOSD_ENABLED=false/' /etc/default/msposd
        else
            sed -i 's/MSPOSD_ENABLED.*/MSPOSD_ENABLED=true/' /etc/default/msposd
            /etc/init.d/S98msposd start
        fi
        ;;
    "set gs system resolution"*)
        sed -i "s/^PIXELPILOT_SCREEN_MODE=.*/PIXELPILOT_SCREEN_MODE=\"$5\"/" /etc/default/pixelpilot
        ;;
    "set gs system rec_fps"*)
        sed -i "s/^PIXELPILOT_DVR_FRAMERATE=.*/PIXELPILOT_DVR_FRAMERATE=$5/" /etc/default/pixelpilot
        ;;
    "set gs system rec_enabled"*)
        if [ "$5" = "off" ]
        then
            : #noop
        else
            : #noop
        fi
        ;;
    "get gs system video_scale")
        . /etc/default/pixelpilot
        echo $PIXELPILOT_VIDEO_SCALE
        ;;
    "set gs system video_scale"*)
        sed -i "s/^PIXELPILOT_VIDEO_SCALE=.*/PIXELPILOT_VIDEO_SCALE=$5/" /etc/default/pixelpilot
        ;;
    "get gs wifi hotspot")
        # Check if hotspot config exists AND wlan0 is up with an IP
        if [ -f /etc/wpa_supplicant.hotspot.conf ] && ip addr show wlan0 2>/dev/null | grep -q "inet "; then
            echo 1
        else
            echo 0
        fi
        ;;
    "get gs wifi wlan")
        # Check if wlan0 config exists AND wlan0 is up with an IP (and not hotspot mode)
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
            [ ! -d /sys/class/net/wlan0 ] && exit 0 # we have no wifi
            if [ "$5" = "on" ]
            then
                if [ -f /etc/wpa_supplicant.hotspot.conf ] # stop hotspot first
                then
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
        [ ! -d /sys/class/net/wlan0 ] && exit 0 # we have no wifi
        if [ "$5" = "on" ]
        then
            if [ -f /etc/network/interfaces.d/wlan0 ] # stop station first
            then
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

    "get gs wfbng adaptivelink")
        . /etc/default/adaptive-link
        if [ x$ADAPTIVE_LINK_ENABLED = x"false" ]
        then
           echo "0"
        else
            echo "1"
        fi
        ;;
    "get gs wfbng gs_channel")
        channel=$(grep wifi_channel /etc/wifibroadcast.cfg | cut -d ' ' -f 3)
        iw list | grep "\[$channel\]" | tr -d '[]' | awk '{print $4 " (" $2 " " $3 ")"}' | sort -n | uniq | head -c -1
        ;;
    "get gs wfbng bandwidth")
        grep ^bandwidth /etc/wifibroadcast.cfg | cut -d ' ' -f 3
        ;;
    "get gs wfbng txpower")
        wifi_txpower=$(grep ^wifi_txpower /etc/wifibroadcast.cfg)
        [ -z "$wifi_txpower" ] && echo "50" && exit 0
        read first_card first_card_power < <(
            echo "$wifi_txpower" | cut -d = -f 2 | jq -r '"\(to_entries[0].key) \(to_entries[0].value)"'
        )
        first_card_type=$(udevadm info /sys/class/net/${first_card} | grep -E 'ID_USB_DRIVER=(rtl88xxau_wfb|rtl88x2eu|rtl88x2cu)'| cut -d = -f2)
        case "$first_card_type" in
        "rtl88xxau_wfb")
            min_phy_txpower=-1000
            max_phy_txpower=-3000
            ;;

        "rtl88x2eu"|"rtl88x2cu")
            min_phy_txpower=1000
            max_phy_txpower=2900
            ;;
        esac
        range=$((max_phy_txpower - min_phy_txpower))
        position=$((first_card_power - min_phy_txpower))
        percentage=$(( (position * 100) / range ))
        echo $percentage
        ;;

    "set gs wfbng adaptivelink"*)
        if [ "$5" = "on" ]
        then
            sed -i 's/ADAPTIVE_LINK_ENABLED.*/ADAPTIVE_LINK_ENABLED=true/' /etc/default/adaptive-link
            /etc/init.d/S98adaptive-link start
        else
            /etc/init.d/S98adaptive-link stop
            sed -i 's/ADAPTIVE_LINK_ENABLED.*/ADAPTIVE_LINK_ENABLED=false/' /etc/default/adaptive-link
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
            "rtl88xxau_wfb")
                min_phy_txpower=-1000
                max_phy_txpower=-3000
                ;;

            "rtl88x2eu"|"rtl88x2cu")
                min_phy_txpower=1000
                max_phy_txpower=2900
                ;;
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
    "get gs main Channel")
        gsmenu.sh get gs wfbng gs_channel
        ;;
    "get gs main HDMI-OUT")
        gsmenu.sh get gs system resolution
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
    "search channel")
        echo "Not implmented"
        echo "Not implmented" >&2
        exit 1
        ;;

    "button air actions Reboot")
        $SSH 'reboot &'
    ;;

    "button gs actions Reboot")
        reboot
    ;;

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
