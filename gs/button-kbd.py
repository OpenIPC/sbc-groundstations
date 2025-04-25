#!/bin/python3

import os
import sys
import time
import subprocess
from evdev import InputDevice, categorize, ecodes

# Only connect keyboard after gs service is started will use kbd as buttons
if not os.path.lexists("/run/systemd/units/invocation:gs.service"):
    print("gs service is not started, use keyboard as normal")
    sys.exit(1)

# Do not use keyboard as button when RubyFpv is running
if os.path.lexists("/run/systemd/units/invocation:rubyfpv.service"):
    print("RubyFpv is running, use keyboard as normal")
    sys.exit(1)

# Check number of command line arguments
if len(sys.argv) != 2:
    print("Usage: python script.py /path/to/kbd_device")
    sys.exit(1)

# Get keyboard device path from the parameters
kbd_device_path = sys.argv[1]
try:
    kbd_device = InputDevice(kbd_device_path)
except FileNotFoundError:
    print(f"Device not found: {kbd_device_path}")
    sys.exit(1)

# Long press time threshold
LONG_PRESS_THRESHOLD = 1.0
# Record the timestamp of the key pressed
key_press_time = {}
# button script location
button_script="/gs/button.sh"
# Buttons mapped to keys
BTN_Q1 = ecodes.KEY_1
BTN_Q2 = ecodes.KEY_2
BTN_Q3 = ecodes.KEY_3
BTN_CU = ecodes.KEY_UP
BTN_CD = ecodes.KEY_DOWN
BTN_CL = ecodes.KEY_LEFT
BTN_CR = ecodes.KEY_RIGHT
KEY_QUIT = ecodes.KEY_Q
KEY_SHUTDOWN = ecodes.KEY_S
KEY_REBOOT = ecodes.KEY_R

get_button_conf_command = "grep '^BTN.*press=' /etc/gs.conf"
try:
    button_function_conf = subprocess.check_output(get_button_conf_command, shell=True, text=True)
except subprocess.CalledProcessError:
    print("No matching lines found or error in grep command.")
    button_function_conf = ""

if button_function_conf:
    try:
        exec(button_function_conf)
    except Exception as e:
        print(f"Error executing code: {e}")

try:
    kbd_device.grab()
    print(f"Monitoring keyboard events on {kbd_device.path}...")
    for event in kbd_device.read_loop():
        if event.type == ecodes.EV_KEY:
            key_event = categorize(event)
            key_code = key_event.scancode
            key_state = key_event.keystate

            if key_state == 1:
                key_press_time[key_code] = time.time()
                print(f"Key {key_event.keycode} pressed.")
            elif key_state == 0:
                press_duration = time.time() - key_press_time.get(key_code, 0)
                if press_duration >= LONG_PRESS_THRESHOLD:
                    # long press
                    print(f"Key {key_event.keycode} long pressed for {press_duration:.2f} seconds.")
                    if key_code == KEY_QUIT:
                        print("KEY_Q long press detected, quit now. ")
                        break
                    elif key_code == BTN_Q1:
                        os.system(f"{button_script} {BTN_Q1_long_press}")
                    elif key_code == BTN_Q2:
                        os.system(f"{button_script} {BTN_Q2_long_press}")
                    elif key_code == BTN_Q3:
                        os.system(f"{button_script} {BTN_Q3_long_press}")
                    elif key_code == BTN_CU:
                        os.system(f"{button_script} {BTN_CU_long_press}")
                    elif key_code == BTN_CD:
                        os.system(f"{button_script} {BTN_CD_long_press}")
                    elif key_code == BTN_CL:
                        os.system(f"{button_script} {BTN_CL_long_press}")
                    elif key_code == BTN_CR:
                        os.system(f"{button_script} {BTN_CR_long_press}")
                    elif key_code == KEY_SHUTDOWN:
                        os.system(f"{button_script} shutdown_gs")
                    elif key_code == KEY_REBOOT:
                        os.system(f"{button_script} reboot_gs")
                else:
                    # single press
                    print(f"Key {key_event.keycode} short pressed for {press_duration:.2f} seconds.")
                    if key_code == BTN_Q1:
                        os.system(f"{button_script} {BTN_Q1_single_press}")
                    elif key_code == BTN_Q2:
                        os.system(f"{button_script} {BTN_Q2_single_press}")
                    elif key_code == BTN_Q3:
                        os.system(f"{button_script} {BTN_Q3_single_press}")
                    elif key_code == BTN_CU:
                        os.system(f"{button_script} {BTN_CU_single_press}")
                    elif key_code == BTN_CD:
                        os.system(f"{button_script} {BTN_CD_single_press}")
                    elif key_code == BTN_CL:
                        os.system(f"{button_script} {BTN_CL_single_press}")
                    elif key_code == BTN_CR:
                        os.system(f"{button_script} {BTN_CR_single_press}")

                # Clean after releasing the key
                key_press_time.pop(key_code, None)
finally:
    kbd_device.ungrab()
    print("quit button-kbd")

