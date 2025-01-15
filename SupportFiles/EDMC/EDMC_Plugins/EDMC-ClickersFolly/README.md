# Live streaming software plugin for [ED Market Connector](https://github.com/EDCD/EDMarketConnector/wiki)

This plugin outputs status info from the game
[Elite Dangerous](https://www.elitedangerous.com/) to files for use as
[text sources](https://obsproject.com/wiki/Sources-Guide#text-gdi)

## Installation

* On EDMC's Plugins settings tab press the “Open” button. This reveals the
  `plugins` folder where EDMC looks for plugins.
* Copy this folder into the EDMC `plugins` folder.

You will need to re-start EDMC for it to notice and load the new/updated 
plugin.

## Output

The plugin writes the following status files into the folder that you specify
in EDMC's Output settings tab:

* `EDMC ShipName.txt` - Ship name, if the ship has been named. Otherwise, ship type.
* `EDMC CmdrName.txt` - Your Commander name. Compatible with multiple accounts

If the app is started while the game is not running these files hold
placeholder values, which can be used to position the text in OBS Studio and
other streaming software.

## License

Copyright © 2019 Jonathan Harris.
Copyright © 2022 Athanasius.

Licensed under the
[GNU Public License (GPL)](http://www.gnu.org/licenses/gpl-2.0.html) version 2
or later.
