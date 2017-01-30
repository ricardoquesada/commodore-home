#!/usr/bin/python
from __future__ import division, unicode_literals, print_function
import socket
import sys
import struct
import os
import time

UDP_PORT = 6464

DEBUG = 1

# Commodore Home Commands

class CommodoreHome:
    _,              \
    SONG_0,         \
    SONG_1,         \
    SONG_2,         \
    SONG_3,         \
    SONG_4,         \
    SONG_5,         \
    SONG_6,         \
    SONG_7,         \
    SONG_8,         \
    _,              \
    SONG_STOP,      \
    SONG_PLAY,      \
    SONG_PAUSE,     \
    SONG_RESUME,    \
    SONG_NEXT,      \
    SONG_PREV,      \
    DIMMER_0,       \
    DIMMER_25,      \
    DIMMER_50,      \
    DIMMER_75,      \
    DIMMER_100,     \
    ALARM_OFF,      \
    ALARM_ON,       \
    ALARM_TRIGGER,  \
    _,              \
    _,              \
    _,              \
    _,              \
    _,              \
    _,              \
    _ = range(32)


def log(mesg):
    if DEBUG is not 0:
        print(mesg)

def discover_devices(callback):
    pass

def send_packet_v2(ipaddress, port, joyvalue1, joyvalue2):
    _send_packet_v2(ipaddress, port, joyvalue1, joyvalue2)
    time.sleep(0.2)
    _send_packet_v2(ipaddress, port, joyvalue1, joyvalue2)
    time.sleep(0.3)
    _send_packet_v2(ipaddress, 3, 0, 0)

def _send_packet_v2(ipaddress, port, joyvalue1, joyvalue2):

    joyvalue1 = int(joyvalue1)
    joyvalue2 = int(joyvalue2)
    port = int(port)

    message = struct.pack("BBBB", 2, port, joyvalue1, joyvalue2)

    log("target IP/Port %s/%d" % (ipaddress, UDP_PORT))
    log("Sending to control port:%d  joy=%d joy=%d" % (port, joyvalue1, joyvalue2))
    log(message)

    sock = socket.socket(socket.AF_INET, # Internet
                         socket.SOCK_DGRAM) # UDP

    # send it twice... since it is UDP it might fail
    for i in range(1):
        time.sleep(0.005)
        sock.sendto(message, (ipaddress, UDP_PORT))
#    time.sleep(0.005)
#    sock.sendto(message, (ipaddress, UDP_PORT))

def send_packet_v3(ipaddress, port, joyvalue1, pot1x=0, pot1y=0):

    log("target IP/Port %s/%d" % (ipaddress, UDP_PORT))

    joyvalue1 = int(joyvalue1)
    port = int(port)
    pot1x = int(pot1x)
    pot1y = int(pot1y)

    print("Sending to control port:%d  joy=%d, potx=%d, poty=%d" % (port, joyvalue1, pot1x, pot1y))

    message = struct.pack("BBBBBBBB", 3, port, joyvalue1, 0, pot1x, pot1y, 0, 0)
    sock = socket.socket(socket.AF_INET, # Internet
                         socket.SOCK_DGRAM) # UDP
    sock.sendto(message, (ipaddress, UDP_PORT))

def help():
    print("%s v0.1 - A tool to test the UniJoystiCle\n" % os.path.basename(sys.argv[0]))
    print("%s ip_address port joy_value potx_value poty_value")
    print("Example:\n%s 192.168.4.1 0 255 0 0" % os.path.basename(sys.argv[0]))
    sys.exit(-1)


if __name__ == "__main__":
    if len(sys.argv) <= 4:
        help()

    args = sys.argv[1:]

    for i in range(1,2):
        send_packet_v3(*args)


