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


app = Flask(__name__)
ask = Ask(app, "/")
logging.getLogger('flask_ask').setLevel(logging.DEBUG)


@ask.launch
def launch():
    welcome_text = render_template('welcome')
    help_text = render_template('help')
    return question(welcome_text).reprompt(help_text)


@ask.intent('OneshotTideIntent',
    mapping={'city': 'City', 'date': 'Date'},
    convert={'date': 'date'},
    default={'city': 'seattle', 'date': datetime.date.today })
def one_shot_tide(city, date):
    if city.lower() not in STATIONS:
        return supported_cities()
    return _make_tide_request(city, date)


@ask.intent('DialogTideIntent',
    mapping={'city': 'City', 'date': 'Date'},
    convert={'date': 'date'})
def dialog_tide(city, date):
    if city is not None:
        if city.lower() not in STATIONS:
            return supported_cities()
        if SESSION_DATE not in session.attributes:
            session.attributes[SESSION_CITY] = city
            return _dialog_date(city)
        date = aniso8601.parse_date(session.attributes[SESSION_DATE])
        return _make_tide_request(city, date)
    elif date is not None:
        if SESSION_CITY not in session.attributes:
            session.attributes[SESSION_DATE] = date.isoformat()
            return _dialog_city(date)
        city = session.attributes[SESSION_CITY]
        return _make_tide_request(city, date)
    else:
        return _dialog_no_slot()


@ask.intent('CommodoreAlarmIntent',
    mapping={'state': 'alarm_state'}
        )
def do_alarm(state):
    statement_text = render_template('do_alarm', alarm_state=state)
    return statement(statement_text).simple_card("Commodore Home", statement_text)


@ask.intent('CommodoreDimmerIntent',
    mapping={'percent': 'percent'}
    )
def do_dimmer(percent):
    statement_text = render_template('do_dimmer', dimmer_value=percent)
    return statement(statement_text).simple_card("Commodore Home", statement_text)


@ask.intent('CommodorePlayerIntent',
    mapping={'number': 'song_number'}
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
