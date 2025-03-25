# -*- coding: utf-8 -*-
"""
Output status info to text files.

"""

# For Python 2&3 a version of open that supports both encoding and universal newlines
from io import open
from os.path import join
from typing import Any, Mapping, MutableMapping, Optional, Tuple

from config import config
from edmc_data import coriolis_ship_map as ship_map
from l10n import Locale

VERSION = '1.00'

class ClickersFolly:
    """Hold the global data."""

    def __init__(self):
        # Info recorded, with initial placeholder values
        self.ship_name: str = 'Ship Name'
        self.cmdr_name: str = 'CMDR Name'
        self.station: str = 'Station'
        self.station_type: str = 'Station Type'
        self.station_name: str = 'Station Name'

        self.outdir = config.get_str('outdir')

stream_source = ClickersFolly()

def write_all() -> None:
    """Write all data out to respective files."""
    write_file('EDMC ShipName.txt', stream_source.ship_name)
    write_file('EDMC CmdrName.txt', stream_source.cmdr_name)
    write_file('EDMC Station.txt', stream_source.station)
    write_file('EDMC StationType.txt', stream_source.station_type)
    write_file('EDMC StationName.txt', stream_source.station_name)
    
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

    return 'EDMC-ClickersFolly'

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
        
    if stream_source.ship_name != shipname:
        stream_source.ship_name = shipname
        write_file('EDMC ShipName.txt', stream_source.ship_name)

    if stream_source.station != station:
        stream_source.station = station
        write_file('EDMC Station.txt', stream_source.station)

    if stream_source.station_type != stationtype:
        stream_source.station_type = stationtype
        write_file('EDMC StationType.txt', stream_source.station_type)

    if stream_source.station_name != stationname:
        stream_source.station_name = stationname
        write_file('EDMC StationName.txt', stream_source.station_name)

    return None
