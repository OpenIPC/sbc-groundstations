Main Features
-------------

* __Centralize configuration file in fat32 partition.__ Use a single configuration file to configure almost everything you need. The configuration file path is `/config/gs.conf` and linked to `/etc/gs.conf`. The partition mount to /config is fat32 format, configuration file can be accessed and edited directly on Windows PC. See configuration part for detial.
* __Default wfb key file in fat32 partition.__ `/config/gs.key` and linked to `/etc/gs.key`.
* __Button support.__ There are 8 buttons in plan, they are `up, down, left, right, center and quick 1, 2, 3` buttons. Currently only the quick buttons are used, `quick 1` button start / stop video record, `quick 2` button switch USB OTG mode between host and device, `quick 3` button switch WiFi mode between station and hotspot (Only for 3W).
* __LED support.__ Currently support `video record LED (Red)` and `power LED (Green)`. The green and red LED turn on after the SBC is powered on. Red LED turn off after the system is startup completed. The red LED will blink when video record is turn on. The green LED will blink when OTG mode is switched to device.
* __Multiple types of network support.__ Support `WiFi`, `Ethernet` and `USB Net`, See Network Configuration for details.
* __Optional video player.__ Support pixelpilot, fpvue, gstreamer as Video player. Gstreamer not support OSD.
* __Multiple USB OTG gadget functions.__ Support `adbd` and `CDC NCM`, `CDC ACM` and `MASS` supported in plan. Use a data cable to connect the computer and the SBC OTG port, adb device and an additional NCM network card will appear on the computer. NCM  can auto get ip address with DHCP.
* __Temperature monitoring and active cooling.__ Support monitoring `RK3566` and `RTL8812EU` temperature and automatically adjust PWM fan speed according to temperature.
* __Multiple WiFi card drivers.__ Currently supports `RTL8812AU, RTL8812EU, RTL8812BU, RTL8812CU, RTL8814AU, RTL8731BU`.
* __USB WiFi card hot plug.__ Support multiple USB WiFi cards with Hotplugging.
* __Two wifibroadcast working modes.__ `standalone` mode is the native mode with the best compatibility, but hot-plugging USB WiFi card will briefly interrupted the stream. `aggregator` mode will run wfb_rx aggregator on boot, and run wfb_rx forwarder for each USB WiFi card, hot-plugging USB WiFi card will not interrupt the stram and can receive streams from other external devices through the network like an openwrt router, but may add a little delay (<1ms?)
* __Share config and videos with smb.__ Anonymous access with root permissions is enabled by default, which allows you to easily modify configurations, obtain and delete record files. Enter \\192.168.x.x (SBC IP address) in the Windows Explorer address bar to access.
* __Auto extend root partition and rootfs.__ The root partition and rootfs will automatically `expand to the size specified in gs.conf->rootfs_reserved_space` on initial startup.
* __exfat partition for video recordings.__ Automatically create an `exfat partition` using all remaining space during initial startup. The partition will be `mounted to /home/radxa/Videos` for storing video recordings, can get the record files through smb or insert the TF card into the computer.
* __Sequentially increasing video file names.__ SBC has incorrect time without Internet, The gstreamer record video files name sequentially starting from 1000.mkv, Finally video files will be like this: `1000.mkv, 1001.mkv, etc.` PixelPilot record file name use template since this [commit](https://github.com/OpenIPC/PixelPilot_rk/commit/eab6c59e203c22c468a4ce99ff8461ec00d56fc3), Finally video files will be like record_%Y-%m-%d_%H-%M-%S.mp4.
* __send stream over USB tethering and Ethernet__ Video and telemetry stream can send to other device over USB tethering or Ethernet, witch can be played with Android QGroundControl,PixelPilot etc. Notice: share stream using multicast by default, not working with windows QGroundControl.
* __Version in /etc/gs-release__
* __Auto build with github action.__


Files and Services
------------------
* __build files:__ script files for build images
* __workflows files:__ Auto build images using github action
* __gs files:__
  1. Configuration file `/config/gs.conf`
  2. wfb key file `/config/gs.key`
  3. script files `/home/radxa/gs/[button.sh, fan.sh, gs.sh, stream.sh, wfb.sh]`
  4. udev rule files `/etc/udev/rules.d/[98-gadget.rules, 99-wfb.rules]`
* __Services:__
  1. `gs`.service
  2. `stream`.service (temporary unit)
  3. `button`.service (temporary unit)
  4. `fan`.service (temporary unit)
  5. unnamed temporary services started for each USB WiFi card in wfb aggregator mode
```bash
GS Directory Tree
/
├── boot
│   └── dtbo
│       ├── rk3566-dwc3-otg-role-switch.dtbo
│       └── rk3566-hdmi-max-resolution-4k.dtbo
├── config
│   ├── gs.conf
│   └── gs.key
├── etc
│   ├── gs.conf -> /config/gs.conf
│   ├── gs.key -> /config/gs.key
│   ├── gs-release
│   ├── network
│   │   └── interfaces.d
│   │       └── radxa0
│   ├── NetworkManager
│   │   ├── conf.d
│   │   │   └── 00-gs-unmanaged.conf
│   │   └── system-connections
│   │       ├── hotspot.nmconnection
│   │       └── wlan0.nmconnection
│   ├── samba
│   │   └── smb.conf
│   ├── systemd
│   │   ├── network
│   │   │   ├── br0.netdev
│   │   │   ├── br0.network
│   │   │   ├── dummy0.netdev
│   │   │   ├── dummy0.network
│   │   │   ├── eth0.network
│   │   │   └── usb0.network
│   │   └── system
│   │       ├── gs-init.service
│   │       ├── gs.service
│   │       └── multi-user.target.wants
│   │           ├── gs-ini.service -> /etc/systemd/system/gs-ini.service
│   │           └── gs.service -> /etc/systemd/system/gs.service
│   └── udev
│       └── rules.d
│           ├── 98-gadget.rules
│           └── 99-wfb.rules
└── home
    └── radxa
        ├── gs
        │   ├── button.sh
        │   ├── fan.sh
        │   ├── gs-init.service
        │   ├── gs-init.sh
        │   ├── gs.sh
        │   ├── rk3566-dwc3-otg-role-switch.dts
        │   ├── rk3566-hdmi-max-resolution-4k.dts
        │   ├── stream.sh
        │   └── wfb.sh
        └── Videos

```


Hardware
--------
__Designed for and tested on Radxa Zero 3W/3E only.__
* __Buttons:__ All buttons must connect to 3.3V.
* __LEDs:__
  1. GPIO work in `Push-Pull` mode. `GPIO->Resistor->LED->GND`
  2. GPIO work in `Open-Drain` mode.
  ```
  3V3->Resistor--->LED->GND
                │  
               GPIO
  ```


DEBUG
-----

1. ssh over hotspot, ethernet or usb net
2. serial console
3. keyboard
4. adb


Configuration [ gs.conf for details ]
-------------------------------------

### 1. Button Configuration

### 2. LED Configuration

### 3. Network Configuration
1. __WiFi:__ `wlan0`
    * `station mode:` Default connect to an open WiFi named `OpenIPC` if not configured.
    * `hotspot mode:` Default SSID is `SBC-GS` with password `12345678`, IP is `192.168.4.1/24`
2. __Ethernet:__ `eth0` Default `DHCP client` with static IP `192.168.1.20/24, 10.0.36.254/24`
3. __USB Net:__ `radxa0` Default `DHCP server` with static IP `192.168.2.20/24`
4. __USB tethering:__ `usb0` Default slave of br0.
5. __Bridge:__ `br0` Default `DHCP client` with static IP `192.168.3.20/24`

### 4. Video Configuration

### 5. Record Configuration

### 6. System Configuration

### 7. Cooling Configuration

### 8. Wifibroadcast Configuration


TODO
----
* Check remaining space before recording
* Automatically select the video storage location according to the priority of external storage > TF card > emmc
* [wfb-ng](https://github.com/svpcom/wfb-ng) cluster mode support
* [Adaptive-Link](https://github.com/sickgreg/OpenIPC-Adaptive-Link) support
* [improver](https://github.com/OpenIPC/improver) support
* Change the built-in LED to a normal GPIO LED
* USB WiFi tx power Configuration
* Screenshots
* Record video playback
* Unify variable names


Known issues
------------

1. When WiFi is set to station mode, it will enter hotspot mode when it is turned on for the first time after initialization. [ maybe not bad :) ]

