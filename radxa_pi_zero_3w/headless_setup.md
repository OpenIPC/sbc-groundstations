<h1>Headless Mode -- connection of wifi, setup of autoconnect to your home wifi </h1>

Our system is going to have two wireless adapters; one for receiving video and our onboard wifi. Step 1 is to segregate and name our wireless cards via udev rules.

<br>

This changes all wifi cards connect to be wlan0

`sudo nano /etc/udev/rules.d/98-custom-wifi.rules`

    SUBSYSTEM=="net", KERNEL=="wlan*", ACTION=="add", NAME="wlan0"

<br>

This changes the raxda zero 3w internal wifi to wlan1 *note -- we're relying on the OUI of the MAC address on the internal wifi adapter, which *should* be the same for all zero 3w boards.

`sudo nano /etc/udev/rules.d/99-custom-wifi.rules`

    SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="98:03:cf:*:*:*", NAME="wlan1"

<br>

Reboot the system for our changes to take effect.

***

<h3>Setup of autoconnect on boot</h3>

We're going to rely on NetworkManager.<br>
Enter the following, replacing your_SSID and your_password as needed.


`nmcli connection add ifname wlan1 type wifi ssid Your_SSID`   <---- enter your network name here

`nmcli connection edit wifi-wlan1`

	nmcli> goto wifi
	nmcli 802-11-wireless> set mode infrastructure
	nmcli 802-11-wireless> back
	nmcli> goto wifi-sec
	nmcli 802-11-wireless-security> set key-mgmt wpa-psk
	nmcli 802-11-wireless-security> set psk Your_Password  <---- enter your password here
	nmcli 802-11-wireless-security> save
	nmcli 802-11-wireless-security> quit

 ***

<h3>If your image does not come with NetworkManager</h3>

If your image does not ship with NetworkManager, you will need to make an initial manual connection via wpa_supplicant to download and install NetworkManager and then follow the steps above for autoconnection on boot. Wpa_supplicant will not persisist after a reboot.

If this is your first boot, you will need to set the root password.

`sudo passwd root`

then as su:

`wpa_passphrase your_SSID your_password > /etc/wpa_supplicant.conf`

`wpa_supplicant -B -i wlan1 -c /etc/wpa_supplicant.conf`

`dhclient wlan1`


your_SSID is the name of your wifi network<br> 
your_password is the network's wifi password<br>

exit su with `exit`


We should now have connection to the internet. Try pinging a website: `ping www.google.com`

If that works, run:

`sudo apt install --no-install-recommends network-manager`

Reboot and then follow the steps above for NetworkManager.

***

Your Radxa pi zero 3w is now headless, ready for an ssh connection on your home wifi network on bootup.
