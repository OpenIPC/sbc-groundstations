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
from smbus2 import SMBus, i2c_msg
from pathlib import Path
# import socket

# ==========================================================
# system
# ==========================================================
gs_conf = dotenv_values("/etc/gs.conf")
oled_refresh_interval = int(gs_conf['oled_refresh_interval'])
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

# ==========================================================
# ina226
# ==========================================================
# I2C bus number
I2C_DEVICE = oled_port

# INA226 I2C device address
INA226_ADDR = int(gs_conf['ina226_i2c_address'], 16)
# Global flag, ina226 available or not
ina226_available = False

# Register addresses
REG_CONFIG    = 0x00
REG_SHUNTV    = 0x01  # Shunt voltage
REG_BUSV      = 0x02  # Bus voltage
REG_POWER     = 0x03  # Power
REG_CURRENT   = 0x04  # Current
REG_CALIB     = 0x05  # Calibration register

# Configuration parameters
SHUNT_RESISTOR = 0.1    # Shunt resistor value (unit: Ω)
CURRENT_LSB    = 0.001  # Current resolution (unit: A)

# Initialize I2C bus
bus = SMBus(I2C_DEVICE)

def detect_ina226():
    """Check whether INA226 exists on the I2C bus"""
    global ina226_available
    if gs_conf['ina226_kernel_driver'] == 'no':
        try:
            msg = i2c_msg.write(INA226_ADDR, [])
            bus.i2c_rdwr(msg)
            ina226_available = True
            print("INA226 detected on I2C bus.")
            return True
        except Exception:
            ina226_available = False
            print("INA226 not detected, skip power monitoring.")
            return False
    elif gs_conf['ina226_kernel_driver'] == 'yes':
        hwmon_path = None
        for name_file in Path("/sys/class/hwmon").glob("hwmon*/name"):
            try:
                if name_file.read_text().strip() == "ina226":
                    hwmon_path = name_file.parent
                    break
            except Exception:
                continue
        if hwmon_path:
            ina226_available = hwmon_path
            print(f"INA226 kernel device detected {hwmon_path}.")
            return True
        else:
            ina226_available = False
            print("INA226 kernel device not detected, skip power monitoring.")
            return False

def init_ina226():
    global ina226_available
    if not ina226_available:
        return
    elif ina226_available is True:
        try:
            # Calculate calibration value: CAL = 0.00512 / (CURRENT_LSB * SHUNT_RESISTOR)
            cal_value = int(0.00512 / (CURRENT_LSB * SHUNT_RESISTOR))

            # Configure register: continuous mode, sampling rate, etc.
            # 0x4127 = average 16 samples, conversion time 1ms
            config = 0x4127
            bus.write_i2c_block_data(INA226_ADDR, REG_CONFIG, [(config >> 8) & 0xFF, config & 0xFF])
            bus.write_i2c_block_data(INA226_ADDR, REG_CALIB, [(cal_value >> 8) & 0xFF, cal_value & 0xFF])
        except Exception as e:
            print("INA226 init failed:", e)
            ina226_available = False
    else:
            print("INA226 is already inited by kernel driver.")

def read_sensor():
    if not ina226_available:
        return 0.0, 0.0, 0.0
    elif ina226_available is True:
        try:
            # Read bus voltage (unit: V)
            bus_voltage_raw = bus.read_i2c_block_data(INA226_ADDR, REG_BUSV, 2)
            bus_voltage = (bus_voltage_raw[0] << 8 | bus_voltage_raw[1]) * 0.00125  # LSB=1.25mV

            # Read current (unit: A)
            current_raw = bus.read_i2c_block_data(INA226_ADDR, REG_CURRENT, 2)
            current = (current_raw[0] << 8 | current_raw[1]) * CURRENT_LSB

            # Read power (unit: W)
            power_raw = bus.read_i2c_block_data(INA226_ADDR, REG_POWER, 2)
            power = (power_raw[0] << 8 | power_raw[1]) * CURRENT_LSB * 25  # LSB=25*CURRENT_LSB

            return bus_voltage, current, power
        except Exception as e:
            print("INA226 read error:", e)
            return 0.0, 0.0, 0.0
    else:
        hwmon_path = ina226_available
        def read_value(file_path):
            try:
                with open(file_path, "r") as f:
                    return int(f.read().strip())
            except Exception as e:
                print(f"Error reading {file_path}: {e}")
                return 0.0

        in1_input   = read_value(os.path.join(hwmon_path, "in1_input"))
        curr1_input = read_value(os.path.join(hwmon_path, "curr1_input"))
        power1_input = read_value(os.path.join(hwmon_path, "power1_input"))
        return in1_input/1000, curr1_input/1000, power1_input/1000000

# ==========================================================
# display
# ==========================================================
def display_system_info(device, delay):
    if detect_ina226():
        init_ina226()
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
                if ina226_available:
                    voltage, current, power = read_sensor()
                    draw.text((0, 30), f"DC:{voltage:.1f}V|{current:.1f}A|{power:.1f}W", font=font_medium, fill=255)
                else:
                    draw.text((0, 30), get_root_disk(), font=font_medium, fill=255)
                draw.text((0, 40), get_wifi_info(), font=font_large, fill=255)
                draw.text((0, 52), get_rec_disk(), font=font_large, fill=255)

            time.sleep(delay)

# ==========================================================
# main function
# ==========================================================
if __name__ == "__main__":
    try:
        display_system_info(device, oled_refresh_interval)
    except KeyboardInterrupt:
        device.clear()
