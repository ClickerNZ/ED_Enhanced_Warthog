load.py is a python applet used in the EDMC EDMC_StreamSource plugin.
I have included a working copy of this here for you to review.

I have modified it to write your commander name to the EDMC CmdrName.txt file at the location set within EDMC for output folder.
The Thrustmaster TARGET script will go looking for EDMC CmdrName.txt and read the contents so it can call you by your commander name at startup.

If you plan to use this functionality, you need to do the following;

1) Install EDMC if you are not already using it
2) Set the EDMC output folder location correctly in ED_UserSettings.tmh
3) Download the latest EDMC StreamSource zip file and unzip to the EDMC plugins folder

WARNING: Do not just copy the load.py file from this folder to the StreamSource plugin folder as there may have been updates since I edited this one

4) Navigate to the EDMC StreamSource plugin folder
5) Copy load.py as load.py.orig (so we can restore it if we stuff it up)
6) If the author has already included this functionality,  then it is easier to modify his version than edit my script
	a) ensure the filename written by load.py matches "EDMC CmdrName.txt", otherwise
7) If the author has not already included this functionality, then...
	a) edit load.py using notepad or notepad++
	b) find section		def __init__(self):
		- add			self.cmdr_name: str = 'CMDR Name'
		
	c) find section		def write_all() -> None:
		- add		    write_file('EDMC CmdrName.txt', stream_source.cmdr_name)
		
	d) find section		def journal_entry(  # noqa: CCR001
		- find section under comment	# Write any files with changed data
		- add			    if stream_source.cmdr_name != cmdr:
								stream_source.cmdr_name = cmdr
								write_file('EDMC CmdrName.txt', stream_source.cmdr_name)

