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


app = Flask(__name__)
ask = Ask(app, "/")
logging.getLogger('flask_ask').setLevel(logging.DEBUG)


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
    mapping={'state': 'alarm_state'}
        )
def do_alarm(state):
    on = ('on', 'enable', 'enabled')
    off = ('off', 'disable', 'disabled')

    if state in on:
        uniclient.send_packet_v2('10.0.0.15', 2, CommdoreHome.ALARM_ON)
    else:
        uniclient.send_packet_v2('10.0.0.15', 2, CommdoreHome.ALARM_OFF)

    statement_text = render_template('do_alarm', alarm_state=state)
    return statement(statement_text).simple_card("Commodore Home", statement_text)


@ask.intent('CommodoreDimmerIntent',
    mapping={'percent': 'percent'}
    )
def do_dimmer(percent):
    on = ('on', 'enable', 'enabled')
    off = ('off', 'disable', 'disabled')

    if state in on:
        uniclient.send_packet_v2('10.0.0.15', 2, CommdoreHome.ALARM_ON)
    else:
        uniclient.send_packet_v2('10.0.0.15', 2, CommdoreHome.ALARM_OFF)
    statement_text = render_template('do_dimmer', dimmer_value=percent)
    return statement(statement_text).simple_card("Commodore Home", statement_text)


@ask.intent('CommodorePlayerIntent',
    mapping={'number': 'song_number'},
    default={'number': '0'}
    )
def do_player(number):
    statement_text = render_template('do_player', song_number=number)
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
