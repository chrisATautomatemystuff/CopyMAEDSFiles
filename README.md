# Get-MAEDSSessionContent

These scripts are used to download the session files that were made available during [MAEDS Fall Conference 2023-2024](https://www.maeds.org/). If you are involved in anything technology in Michigan K-12 Schools, consider attending this event!

## Usage

For content just from 2024 in a custom directory (default is C:\Conferences\MAEDS\$conferenceyear), use the following:

``` .\Get-MAEDSSessionContent.ps1 -DownloadLocation "C:\Temp\MAEDS" -ConferenceId 2024```

For multiple years:

``` .\Get-MAEDSSessionContent.ps1 -ConferenceList @('2023','2024')```

To exclude session details:

``` .\Get-MAEDSSessionContent.ps1 -All -ExcludeSessionDetails```

## Acknowledgements

Thank you to:
- [Andrew Johnson](https://www.andrewj.net/) for the script I forked from because I'm lazy...
- [Duncan Russell](http://www.sysadmintechnotes.com/) for providing the initial script for MMS 2014 and helping me test the changes I made for it to work with the more recent conferences.
- [Evan Yeung](https://github.com/forevanyeung) for cleaning up processing and file naming.
- [Chris Kibble](https://www.christopherkibble.com) for continued testing and improvements made to the script.
- [Benjamin Reynolds](https://sqlbenjamin.wordpress.com) for loads of great changes and additional testing.
- [Nathan Ziehnert](https://z-nerd.com/) for adding PowerShell 7 support
- As well as edits by [Jon Warnken](https://github.com/mrbodean), [Oliver Baddeley](https://github.com/BaddMann), and [Jorge Suarez](https://github.com/jorgeasaurus)

This script is provided as-is with no guarantees. As of October 28, 2024, version 1.0 was tested with no errors using the following configurations:

- Windows 11 22H2 using Windows PowerShell 5.1 (I'm EDU ... I'm allowed more time!)
