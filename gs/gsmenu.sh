#!/bin/bash
set -o pipefail
source /etc/gs.conf
# Configuration
REMOTE_IP="10.5.0.10"
SSH_PASS="12345"
CACHE_DIR="/tmp/gsmenu_cache"
CACHE_TTL=10 # seconds
MAJESTIC_YAML="/etc/majestic.yaml"
WFB_YAML="/etc/wfb.yaml"
PRESET_DIR="/etc/presets"

# SSH command setup
SSH="timeout -k 1 11 sshpass -p $SSH_PASS ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ControlMaster=auto -o ControlPath=/run/ssh_control:%h:%p:%r -o ControlPersist=15s -o ServerAliveInterval=3 -o ServerAliveCountMax=2 root@$REMOTE_IP"
SCP="timeout -k 1 11 sshpass -p $SSH_PASS scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ControlMaster=auto -o ControlPath=/run/ssh_control:%h:%p:%r -o ControlPersist=15s -o ServerAliveInterval=3 -o ServerAliveCountMax=2"

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

# Function to refresh cached files
refresh_cache() {
    local current_time=$(date +%s)
    local last_refresh=$((current_time - CACHE_TTL))

    # Check if we need to refresh
    if [[ ! -f "$CACHE_DIR/last_refresh" ]] || [[ $(cat "$CACHE_DIR/last_refresh") -lt $last_refresh ]]; then
        # Copy the YAML configuration files
        $SSH "cat $MAJESTIC_YAML" > "$CACHE_DIR/majestic.yaml" 2>/dev/null
        $SSH "cat $WFB_YAML" > "$CACHE_DIR/wfb.yaml" 2>/dev/null

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
        echo -e "1500\n1600\n1700\n1800\n1900\n2000\n2100\n2200\n2300\n2400\n2500\n2600\n2700\n2800\n2900\n3000\n3100\n3200\n3300\n3400\n3500\n3600\n3700\n3800\n3900\n4000"
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
        echo -e "1\n20\n25\n30\n35\n40\n45\n50\n55\n58"
        ;;
    "values air wfbng air_channel")
        iw list | grep MHz | grep -v disabled | grep \* | tr -d '[]' | awk '{print $4 " (" $2 " " $3 ")"}' | grep '^[1-9]' | sort -n |  uniq
        ;;
    "values air wfbng width")
        echo -e "20\n40"
        ;;
    "values air camera size")
        echo -e "1280x720\n1456x816\n1920x1080\n1440x1080\n1920x1440\n2104x1184\n2208x1248\n2240x1264\n2312x1304\n2436x1828\n2512x1416\n2560x1440\n2560x1920\n2720x1528\n2944x1656\n3200x1800\n3840x2160"
        ;;
    "values air camera fps")
        echo -e "60\n90\n120"
        ;;
    "values air camera bitrate")
        echo -e "1024\n2048\n3072\n4096\n5120\n6144\n7168\n8192\n9216\n10240\n11264\n12288\n13312\n14336\n15360\n16384\n17408\n18432\n19456\n20480\n21504\n22528\n23552\n24576\n25600\n26624\n27648\n28672\n29692\n30720"
        ;;
    "values air camera codec")
        echo -e "h264\nh265"
        ;;
    "values air camera rc_mode")
        echo -e "vbr\navbr\ncbr"
        ;;
    "values air camera antiflicker")
        echo -e "disabled\n50\n60"
        ;;
    "values air camera sensor_file")
        echo -e "/etc/sensors/imx307.bin\n/etc/sensors/imx335.bin\n/etc/sensors/imx335_fpv.bin\n/etc/sensors/imx415_fpv.bin\n/etc/sensors/imx415_fpv.bin\n/etc/sensors/imx415_milos10.bin\n/etc/sensors/imx415_milos15.bin\n/etc/sensors/imx335_milos12tweak.bin\n/etc/sensors/imx335_greg15.bin\n/etc/sensors/imx335_spike5.bin\n/etc/sensors/gregspike05.bin"
        ;;
    "values air telemetry serial")
        echo -e "ttyS0\nttyS1\nttyS2"
        ;;
    "values air telemetry router")
        echo -e "mavfwd\nmsposd"
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
        get_majestic_value '.isp.sensorConfig'
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
        $SSH "cli -s .isp.sensorConfig $5 && killall -1 majestic"
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
        $SSH wifibroadcast cli -g .telemetry.serial
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
        $SSH wifibroadcast cli -s .telemetry.serial $5
        $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
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
        then -o 127.0.0.1:"$port_tx" -z "$size"
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
        systemctl restart wifibroadcast.service
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

    "values gs wfbng gs_channel")
        iw list | grep MHz | grep -v disabled | grep \* | tr -d '[]' | awk '{print $4 " (" $2 " " $3 ")"}' | grep '^[1-9]' | sort -n |  uniq
        ;;
    "values gs wfbng bandwidth")
        echo -e "20\n40"
        ;;
    "values gs system resolution")
        drm_info -j /dev/dri/card0 2>/dev/null | jq -r '."/dev/dri/card0".connectors[1].modes[] | select(.name | contains("i") | not) | .name + "@" + (.vrefresh|tostring)' | sort | uniq
        ;;
    "values gs system rec_fps")
        echo -e "60\n90\n120"
        ;;

    "get gs system gs_rendering")
        [ "$osd_type" = "msposd_gs" ] && echo 1 || echo 0
        ;;
    "get gs system resolution")
        drm_info -j /dev/dri/card0 2>/dev/null | jq -r '."/dev/dri/card0".crtcs[0].mode| .name + "@" + (.vrefresh|tostring)'
        ;;
    "get gs system rec_fps")
        echo -n $rec_fps
        ;;
    "set gs system gs_rendering"*)
        if [ "$5" = "off" ]
        then
            sed -i "s/^osd_type=.*/osd_type='msposd_air'/" "$(readlink -f /etc/gs.conf)"
            killall -q msposd
        else
            sed -i "s/^osd_type=.*/osd_type='msposd_gs'/" "$(readlink -f /etc/gs.conf)"
            if [ -e /dev/shm/msposd ]; then
                if [ "$msposd_gs_record" == "yes" ]; then
                    msposd --master 0.0.0.0:$msposd_gs_port --osd -r $msposd_gs_fps --ahi $msposd_gs_ahi --subtitle $rec_dir &
                else
                    msposd --master 0.0.0.0:$msposd_gs_port --osd -r $msposd_gs_fps --ahi $msposd_gs_ahi &
                fi
            else
                systemctl restart stream
	        fi
        fi
        ;;
    "set gs system resolution"*)
        sed -i "s/^screen_mode=.*/screen_mode='$5'/" "$(readlink -f /etc/gs.conf)"
        ;;
    "set gs system rec_fps"*)
        sed -i "s/^rec_fps=.*/rec_fps='$5'/" "$(readlink -f /etc/gs.conf)"
        ;;
    "set gs system rec_enabled"*)
        if [ "$5" = "off" ]
        then
            : #noop
        else
            : #noop
        fi
        ;;
    "get gs wifi hotspot")
        nmcli connection show --active | grep -q "hotspot" && echo 1 || echo 0
        ;;
    "get gs wifi wlan")
        connection=$(nmcli -t connection show --active | grep wifi0 | cut -d : -f1)
        [ -z "${connection}" ] && echo 0 || echo 1
        ;;
    "get gs wifi ssid")
        if [ -d /sys/class/net/wifi0 ]; then
            nmcli -t connection show --active | grep wifi0 | cut -d : -f1
        else
            echo -n ""
        fi
        ;;
    "get gs wifi password")
        if [ -d /sys/class/net/wifi0 ]; then
            connection=$(nmcli -t connection show --active | grep wifi0 | cut -d : -f1)
            nmcli -t connection show $connection --show-secrets | grep 802-11-wireless-security.psk: | cut -d : -f2
        else
                echo -n ""
        fi
        ;;

    "get gs wifi IP")
        WIFI_DEV=$(nmcli -t connection show --active | grep wifi0 | cut -d : -f4)
        ip -4 addr show "$WIFI_DEV" | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
        ;;

    "set gs wifi wlan"*)
        [ ! -d /sys/class/net/wifi0 ] && exit 0 # we have no wifi
        if [ "$5" = "on" ]
        then
            # Check if connection already exists
            if nmcli connection show | grep -q "$6"; then
                echo "$6 connection exists. Starting it..."
                nmcli con up "$6"
            else
                echo "Creating new "$6" connection..."
                nmcli device wifi connect "$6" password "$7"
                echo "Starting Wlan..."
                nmcli con up "$6"
            fi
        else
            nmcli con down "$6"
        fi
        ;;
    "set gs wifi hotspot"*)
        [ ! -d /sys/class/net/wifi0 ] && exit 0 # we have no wifi
        if [ "$5" = "on" ]
        then
            # Check if connection already exists
            if nmcli connection show | grep -q "hotspot"; then
                echo "Hotspot connection exists. Starting it..."
                nmcli con up hotspot
            # else
            #     echo "Creating new Hotspot connection..."
            #     nmcli con add type wifi ifname wifi0 con-name Hotspot autoconnect no ssid "OpenIPC GS"
            #     nmcli con modify Hotspot 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
            #     nmcli con modify Hotspot wifi-sec.key-mgmt wpa-psk
            #     nmcli con modify Hotspot wifi-sec.psk "openipcgs"
            #     nmcli con modify Hotspot ipv4.addresses 192.168.4.1/24
            #     echo "Starting Hotspot..."
            #     nmcli con up Hotspot
            fi
        else
            nmcli con down hotspot
        fi
        ;;

    "get gs wfbng adaptivelink")
        [ "$alink_enable" == "yes" ] && echo 1 || echo 0
        ;;
    "get gs wfbng gs_channel")
        channel=$wfb_channel
        iw list | grep "\[$channel\]" | tr -d '[]' | awk '{print $4 " (" $2 " " $3 ")"}' | sort -n | uniq
        ;;
    "get gs wfbng bandwidth")
        echo -n $wfb_bandwidth
        ;;

    "set gs wfbng adaptivelink"*)
        if [ "$5" = "on" ]
        then
            sed -i "s/^alink_enable=.*/alink_enable='yes'/" "$(readlink -f /etc/gs.conf)"
            systemd-run --unit=alink /usr/local/bin/alink --config /etc/alink.conf
        else
            sed -i "s/^alink_enable=.*/alink_enable='no'/" "$(readlink -f /etc/gs.conf)"
            systemctl stop alink.service
        fi
        ;;
    "set gs wfbng gs_channel"*)
        channel=$(echo $5 | awk '{print $1}')
        if [ "$GSMENU_VTX_DETECTED" -eq "1" ]; then
            $SSH wifibroadcast cli -s .wireless.channel $channel
            $SSH "(wifibroadcast stop ;wifibroadcast stop; sleep 1;  wifibroadcast start) >/dev/null 2>&1 &"
        fi
        sed -i "s/^wfb_channel=.*/wfb_channel='$channel'/" "$(readlink -f /etc/gs.conf)"
        /gs/wfb.sh
        ;;
    "set gs wfbng bandwidth"*)
        sed -i "s/^wfb_bandwidth=.*/wfb_bandwidth='$5'/" "$(readlink -f /etc/gs.conf)"
        /gs/wfb.sh
        ;;
    "get gs main Channel")
        gsmenu.sh get gs wfbng gs_channel
        ;;
    "get gs main HDMI-OUT")
        gsmenu.sh get gs system resolution
        ;;
    "get gs main Version")
        grep PRETTY_NAME= /etc/os-release | cut -d \" -f2
        ;;
    "get gs main Disk")
        read -r size avail pcent <<< $(df -h / | awk 'NR==2 {print $2, $4, $5}')
        echo -e "\n   Size: $size\n   Available: $avail\n   Pct: $pcent\c"
        ;;
    "get gs main WFB_NICS")
        grep ^WFB_NICS /etc/default/wifibroadcast | cut -d \" -f 2
        ;;
    "search channel")
        echo "Not implmented"
        echo "Not implmented" >&2
        exit 1
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
