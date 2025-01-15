# -*- coding: utf-8 -*-
"""
Output status info to text files for use with streaming software.

Examples of such are Open Broadcaster Software, GameShow, XSplit, etc.

* https://obsproject.com/wiki/Sources-Guide#text-gdi
* https://telestream.force.com/kb2/articles/Knowledge_Article/Gameshow-Add-Text
* https://www.xsplit.com/broadcaster/getting-started/adding-text
"""

# For Python 2&3 a version of open that supports both encoding and universal newlines
from io import open
from os.path import join
from typing import Any, Mapping, MutableMapping, Optional, Tuple

from config import config
from edmc_data import coriolis_ship_map as ship_map
from l10n import Locale

VERSION = '1.10'


class StreamSource:
    """Hold the global data."""

    def __init__(self):
        # Info recorded, with initial placeholder values
        self.system: str = 'System'
        self.station: str = 'Station'
        self.star_pos: Tuple[Any, ...] = (0.0, 0.0, 0.0)
        self.body: Optional[str] = 'Body'
        self.latlon: Optional[Tuple[Any, ...]] = (0.0, 0.0)
        self.station_or_body: Optional[str] = 'Station or Body'
        self.station_or_body_or_system: str = 'Station or Body or System'
        self.ship_type: str = 'Ship type'
        self.ship_name: str = 'Ship name'
        self.cmdr_name: str = 'CMDR Name'

        self.outdir = config.get_str('outdir')


stream_source = StreamSource()


def write_all() -> None:
    """Write all data out to respective files."""
    write_file('EDMC System.txt', stream_source.system)
    write_file(
        'EDMC StarPos.txt',
        f'{Locale.string_from_number(stream_source.star_pos[0], 5)} '
        f'{Locale.string_from_number(stream_source.star_pos[1], 5)} '
        f'{Locale.string_from_number(stream_source.star_pos[2], 5)}'
    )
    write_file('EDMC Station.txt', stream_source.station)
    write_file('EDMC Body.txt', stream_source.body)
    write_file(
        'EDMC LatLon.txt',
        f'{Locale.string_from_number(stream_source.latlon[0], 6)} '  # type: ignore # because Optional
        f'{Locale.string_from_number(stream_source.latlon[1], 6)}'  # type: ignore # because Optional
    )
    write_file('EDMC Station or Body.txt', stream_source.station_or_body)
    write_file('EDMC Station or Body or System.txt', stream_source.station_or_body_or_system)
    write_file('EDMC ShipType.txt', stream_source.ship_type)
    write_file('EDMC ShipName.txt', stream_source.ship_name)
    write_file('EDMC CmdrName.txt', stream_source.cmdr_name)

    return None


def write_file(name: str, text: str = None) -> None:
    """Write one file's text."""
    # File needs to be closed for the streaming software to notice its been updated.
    with open(join(stream_source.outdir, name), 'w', encoding='utf-8') as h:
        h.write(f'{text or ""}\n')
        h.close()

    return None


def plugin_start3(plugin_dir: str) -> str:
    """Handle start-up of plugin."""
    # Write placeholder values for positioning
    write_all()

    return 'EDMC-StreamSource'


def prefs_changed(cmdr: str, is_beta: bool) -> None:
    """Handle any changes to application preferences."""
    # Write all files in new location if output directory changed.
    if stream_source.outdir != config.get_str('outdir'):
        stream_source.outdir = config.get_str('outdir')
        write_all()


def journal_entry(  # noqa: CCR001
        cmdr: str,
        is_beta: bool,
        system: str,
        station: str,
        entry: MutableMapping[str, Any],
        state: Mapping[str, Any]
) -> Optional[str]:
    """
    Process a journal event.

    :param cmdr:
    :param system:
    :param station:
    :param entry:
    :param state:
    :return:
    """
    # Write any files with changed data
    if stream_source.cmdr_name != cmdr:
        stream_source.cmdr_name = cmdr
        write_file('EDMC CmdrName.txt', stream_source.cmdr_name)
        
    if stream_source.system != system:
        stream_source.system = system
        write_file('EDMC System.txt', stream_source.system)

    if entry.get('StarPos') is not None and stream_source.star_pos != tuple(entry['StarPos']):
        stream_source.star_pos = tuple(entry['StarPos'])
        write_file(
            'EDMC StarPos.txt',
            f'{Locale.string_from_number(stream_source.star_pos[0], 5)} '
            f'{Locale.string_from_number(stream_source.star_pos[1], 5)} '
            f'{Locale.string_from_number(stream_source.star_pos[2], 5)}'
        )

    if stream_source.station != station:
        stream_source.station = station
        write_file('EDMC Station.txt', stream_source.station)

    if (
        entry['event'] in ['FSDJump', 'LeaveBody', 'Location', 'SupercruiseEntry', 'SupercruiseExit']
            and entry.get('BodyType') in [None, 'Station']
    ):
        if stream_source.body:
            stream_source.body = None
            write_file('EDMC Body.txt')

    elif 'Body' in entry:
        # StartUp, ApproachBody, Location, SupercruiseExit
        if stream_source.body != entry['Body']:
            stream_source.body = entry['Body']
            write_file('EDMC Body.txt', stream_source.body)

    elif entry['event'] == 'StartUp':
        stream_source.body = None
        write_file('EDMC Body.txt')

    if stream_source.station_or_body != (stream_source.station or stream_source.body):
        stream_source.station_or_body = (stream_source.station or stream_source.body)
        write_file('EDMC Station or Body.txt', stream_source.station_or_body)

    if stream_source.station_or_body_or_system != (stream_source.station or stream_source.body or stream_source.system):
        stream_source.station_or_body_or_system = (stream_source.station or stream_source.body or stream_source.system)
        write_file('EDMC Station or Body or System.txt', stream_source.station_or_body_or_system)

    if stream_source.ship_type != state['ShipType']:
        stream_source.ship_type = state['ShipType']
        write_file('EDMC ShipType.txt', ship_map.get(stream_source.ship_type, stream_source.ship_type))

    if stream_source.ship_name != (state['ShipName'] or stream_source.ship_type):
        stream_source.ship_name = (state['ShipName'] or stream_source.ship_type)
        write_file(
            'EDMC ShipName.txt',
            state['ShipName'] and state['ShipName'] or ship_map.get(stream_source.ship_type, stream_source.ship_type)
        )

    return None


def dashboard_entry(
        cmdr: str,
        is_beta: bool,
        entry: MutableMapping
) -> Optional[str]:
    """Handle new Status.json data."""
    # Write any files with changed data
    if 'Latitude' in entry and 'Longitude' in entry:
        if stream_source.latlon != (entry['Latitude'], entry['Longitude']):
            stream_source.latlon = (entry['Latitude'], entry['Longitude'])
            write_file(
                'EDMC LatLon.txt',
                f'{Locale.string_from_number(stream_source.latlon[0], 6)} '
                f'{Locale.string_from_number(stream_source.latlon[1], 6)}'
            )

    elif stream_source.latlon:
        stream_source.latlon = None
        write_file('EDMC LatLon.txt')

    return None
