#!/usr/bin/env python

from __future__ import print_function
from future import standard_library
standard_library.install_aliases()
import urllib.request, urllib.parse, urllib.error
import json
import os

from flask import Flask
from flask import request
from flask import make_response

import uniclient
from uniclient import CommodoreHome

UNIJOYSTICLE_IP = '10.0.0.27'

# Flask app should start in global layout
app = Flask(__name__)


@app.route('/webhook', methods=['POST'])
def webhook():
    req = request.get_json(silent=True, force=True)

    print("Request:")
    print(json.dumps(req, indent=4))

    res = processRequest(req)

    res = json.dumps(res, indent=4)
    # print(res)
    r = make_response(res)
    r.headers['Content-Type'] = 'application/json'
    return r

def action_alarm_setting(req):
    on = ('on', 'enable', 'enabled')
    off = ('off', 'disable', 'disabled')

    if alarm_state.lower() in on:
        uniclient.send_packet_v2(UNIJOYSTICLE_IP, 2, 0, CommodoreHome.ALARM_ON)
    else:
        uniclient.send_packet_v2(UNIJOYSTICLE_IP, 2, 0, CommodoreHome.ALARM_OFF)

def action_dimmer_setting(req):
    percent = int(percent) / 25
    uniclient.send_packet_v2(UNIJOYSTICLE_IP, 2, 0, CommodoreHome.DIMMER_0 + percent)

def action_joystick_movement(req):
    print('joy')
    return {'joystick': True}

def action_play_music(req):
    songs = ('ashes', 'final', 'world', 'jump', 'enola', 'jean', 'paradise', 'change', 'breath')

    parameters = req.get('result').get('parameters')
    song_number = parameters.get('song_number')
    song_name = parameters.get('song_name')

    if song_number is None and song_name is None:
        statement_text = render_template('error_player')
    elif song_name is not None:
        song_number = -1
        for idx,s in enumerate(songs):
            song_name = song_name.lower()
            if song_name.find(s) != -1:
                song_number = idx + 1
                break

    if song_number is None:
        statement_text = render_template('error_player')
    else:
        song_number = int(song_number)
        if song_number == -1:
            statement_text = render_template('error_player')
        else:
            uniclient.send_packet_v2(UNIJOYSTICLE_IP, 2, 0, CommodoreHome.SONG_0 + song_number - 1)

def processRequest(req):
    # actions:
    #  - alarm-setting
    #  - dimmer-setting
    #  - joystick-movement
    #  - play-music
    actions = {'alarm-setting': action_alarm_setting,
            'dimmer-setting': action_dimmer_setting,
            'joystick-movement': action_joystick_movement,
            'play-music': action_play_music}
    action =  req.get("result").get("action")
    if action in actions:
        return actions[action](req)
    else:
        print('invalid action: %s' % action)
    return {}


def makeYqlQuery(req):
    result = req.get("result")
    parameters = result.get("parameters")
    city = parameters.get("geo-city")
    if city is None:
        return None

    return "select * from weather.forecast where woeid in (select woeid from geo.places(1) where text='" + city + "')"


def makeWebhookResult(data):
    query = data.get('query')
    if query is None:
        return {}

    result = query.get('results')
    if result is None:
        return {}

    channel = result.get('channel')
    if channel is None:
        return {}

    item = channel.get('item')
    location = channel.get('location')
    units = channel.get('units')
    if (location is None) or (item is None) or (units is None):
        return {}

    condition = item.get('condition')
    if condition is None:
        return {}

    # print(json.dumps(item, indent=4))

    speech = "Today in " + location.get('city') + ": " + condition.get('text') + \
             ", the temperature is " + condition.get('temp') + " " + units.get('temperature')

    print("Response:")
    print(speech)

    return {
        "speech": speech,
        "displayText": speech,
        # "data": data,
        # "contextOut": [],
        "source": "apiai-weather-webhook-sample"
    }


if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))

    print("Starting app on port %d" % port)

    app.run(debug=False, port=port, host='0.0.0.0')
