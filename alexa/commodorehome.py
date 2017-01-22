import os
import logging
import datetime
import math
import re
from six.moves.urllib.request import urlopen
from six.moves.urllib.parse import urlencode

import aniso8601
from flask import Flask, json, render_template
from flask_ask import Ask, request, session, question, statement

import uniclient
from uniclient import CommodoreHome


app = Flask(__name__)
ask = Ask(app, "/")
logging.getLogger('flask_ask').setLevel(logging.DEBUG)

UNIJOYSTICLE_IP = '10.0.0.27'


@ask.launch
def launch():
    welcome_text = render_template('welcome')
    help_text = render_template('help')
    return question(welcome_text).reprompt(help_text)


@ask.intent('CommodoreGianaIntent')
def do_giana(state):
    statement_text = render_template('do_giana')
    return statement(statement_text).simple_card("Commodore Home", statement_text)


@ask.intent('CommodoreAlarmIntent',
    mapping={'alarm_state': 'alarm_state'}
        )
def do_alarm(alarm_state):
    on = ('on', 'enable', 'enabled')
    off = ('off', 'disable', 'disabled')

    if alarm_state.lower() in on:
        uniclient.send_packet_v2(UNIJOYSTICLE_IP, 2, 0, CommodoreHome.ALARM_ON)
    else:
        uniclient.send_packet_v2(UNIJOYSTICLE_IP, 2, 0, CommodoreHome.ALARM_OFF)

    statement_text = render_template('do_alarm', alarm_state=alarm_state)
    return statement(statement_text).simple_card("Commodore Home", statement_text)


@ask.intent('CommodoreDimmerIntent',
    mapping={'percent': 'percent'}
    )
def do_dimmer(percent):
    if percent < 50:
        uniclient.send_packet_v2(UNIJOYSTICLE_IP, 2, 0, CommodoreHome.DIMMER_0)
    else:
        uniclient.send_packet_v2(UNIJOYSTICLE_IP, 2, 0, CommodoreHome.DIMMER_100)
    statement_text = render_template('do_dimmer', dimmer_value=percent)
    return statement(statement_text).simple_card("Commodore Home", statement_text)


@ask.intent('CommodorePlayerIntent',
    mapping={'song_number': 'song_number', 'song_name': 'song_name'},
    default={'song_number': None, 'song_name': None}
    )
def do_player(song_number, song_name):
    songs = ('ashes', 'final', 'world', 'jump', 'enola', 'jean', 'paradise', 'change', 'breath')

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
            statement_text = render_template('do_player', song_number=song_number)
    return statement(statement_text).simple_card("Commodore Home", statement_text)


@ask.intent('AMAZON.HelpIntent')
def help():
    help_text = render_template('help')
    reprompt_text = render_template('reprompt')
    return question(help_text).reprompt(reprompt_text)


@ask.intent('AMAZON.StopIntent')
def stop():
    bye_text = render_template('bye')
    return statement(bye_text)


@ask.intent('AMAZON.CancelIntent')
def cancel():
    bye_text = render_template('bye')
    return statement(bye_text)


@ask.session_ended
def session_ended():
    return "", 200

if __name__ == '__main__':
    app.run(debug=True)
