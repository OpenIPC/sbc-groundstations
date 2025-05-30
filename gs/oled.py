#!/bin/python3

import time
import psutil
import glob
import os
import subprocess
import re
from luma.core.interface.serial import i2c
from luma.oled.device import ssd1306
from luma.core.render import canvas
from PIL import ImageFont
from dotenv import dotenv_values
# import socket

gs_conf = dotenv_values("/etc/gs.conf")
oled_port = int(gs_conf['oled_i2c_port'])
oled_address = gs_conf['oled_i2c_address']
# init oled screen
serial = i2c(port=oled_port, address=oled_address)
device = ssd1306(serial, rotate=0)
# device = ssd1306(serial, width=128, height=64)
# print(device.width, device.height)

# Define font sizes
font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 8)
font_medium = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 10)
font_large = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 12)
# font = ImageFont.load_default()

def get_wifi_info():
    channel, frequency, width = "", "", ""
    matches = glob.glob('/sys/class/net/wl*')
    if matches:
        interface = os.path.basename(matches[0])
        try:
            # run iw command
            result = subprocess.run(['iw', interface, 'info'], capture_output=True, text=True, check=True)
            output = result.stdout

            # get channel, freq and bandwidth
            match = re.search(r'channel\s+(\d+)\s+\((\d+)\s+MHz\),\s+width:\s+([\d]+),?', output)
            if match:
                channel = match.group(1)
                frequency = match.group(2)
                width = match.group(3).strip()
            else:
                print("No matching information found.")
        except subprocess.CalledProcessError as e:
            print(f"Command execution failed: {e}")
    else:
        print("No wifi card found.")
    return f"CH:{channel}/{frequency}/{width}MHz"

def get_ip_addresses():
    ip_list = []
    for iface, addrs in psutil.net_if_addrs().items():
        for addr in addrs:
            if addr.family == 2:
                ip_list.append((iface, addr.address))
    return ip_list

def get_cpu():
    cpu_usage = psutil.cpu_percent(interval=1)
    try:
        with open("/sys/class/thermal/thermal_zone0/temp", "r") as f:
            temp = round(int(f.read()) / 1000, 1)
    except:
        temp = "N/A"

    return f"CPU:{cpu_usage}% {temp}°C"

def get_mem():
    mem = psutil.virtual_memory()
    mem_str="Mem:{}/{}M {}%".format(
        int(mem.used/(1024*1024)),
        int(mem.total/(1024*1024)),
        mem.percent)
    return mem_str

def get_root_disk():
    disk = psutil.disk_usage('/')
    disk_str="Disk:{}/{}G {}%".format(
        int(disk.used/(1024*1024*1024)),
        int(disk.total/(1024*1024*1024)),
        disk.percent)
    return disk_str

def get_rec_disk():
    disk = psutil.disk_usage('/Videos')
    disk_str="REC:{}/{}G {}%".format(
        int(disk.used/(1024*1024*1024)),
        int(disk.total/(1024*1024*1024)),
        disk.percent)
    return disk_str

def display_system_info(device, delay=2):
    while True:
        ip_entries = get_ip_addresses()
        if not ip_entries:
            ip_entries = [("None", "No IP")]
        for iface, ip in ip_entries:
            with canvas(device) as draw:
                # Display all white
                # draw.rectangle(device.bounding_box, outline="white", fill="white")
                draw.text((0, 0),  f"{iface}:{ip}", font=font_medium, fill=255)
                draw.text((0, 10), get_cpu(), font=font_medium, fill=255)
                draw.text((0, 20), get_mem(), font=font_medium, fill=255)
                draw.text((0, 30), get_root_disk(), font=font_medium, fill=255)
                draw.text((0, 40), get_wifi_info(), font=font_large, fill=255)
                draw.text((0, 52), get_rec_disk(), font=font_large, fill=255)
            time.sleep(delay)

if __name__ == "__main__":
    try:
        display_system_info(device)
    except KeyboardInterrupt:
        device.clear()
