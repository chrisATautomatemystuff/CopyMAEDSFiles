<#
.SYNOPSIS
  Gathers and downloads files from MAEDS Fall Conference sessions
.DESCRIPTION
  This script gathers and downloads files from MAEDS Fall Conference sessions. You must
  have a valid login to Sched for the year you're attempting to download.
.INPUTS
  None
.OUTPUTS
  All session content from the specified years.
.NOTES
  Version:        1.0
  Author:         Chris Thomas
  Modified Date:  10/28/2024
  Purpose/Change: Forked from MMS Flamingo Edition version to MAEDS version

  Original author (2024 script): Andrew Johnson - https://www.andrewj.net/
  Original author (2015 script): Duncan Russell - http://www.sysadmintechnotes.com
  Edits made by:
    Evan Yeung - https://www.forevanyeung.com
    Chris Kibble - https://www.christopherkibble.com
    Jon Warnken - https://www.mrbodean.net
    Oliver Baddeley - Edited for Desert Edition
    Benjamin Reynolds - https://sqlbenjamin.wordpress.com/
    Jorge Suarez - https://github.com/jorgeasaurus
    Nathan Ziehnert - https://z-nerd.com

  TODO:
  [ ] Create a version history in these notes? Something like this:
  Version History/Notes:
    Date          Version    Author                    Notes
    ??/??/2015    1.0        Duncan Russell            Initial Creation?
    11/13/2019    1.1        Andrew Johnson            Added logic to only authenticate if content for the specified sessions has not been made public
    11/02/2021    1.2        Benjamin Reynolds         Added SingleEvent, MultipleEvent, and AllEvent parameters/logic; simplified logic; added a Session Info
                                                       text file containing details of the event
    04/05/2023    1.3        Jorge Suarez              Modified login body string for downloading session content
    11/06/2023    1.4        Nathan Ziehnert           Adds support for PowerShell 7.x, revamps the webscraping bit to be cross platform (no html parser in core). 
                                                       Sets default directory for non-Microsoft OS to be $HOME\Downloads\MMSContent. Ugly basic HTML parser for the
                                                       session info file, but it should suffice for now.
    04/28/2024    1.5        Andrew Johnson            Updated and tested to include 2024 at MOA
    10/20/2024    1.6        Andrew Johnson            Updated and tested to include MMS Flamingo Edition
    10/28/2024    1.0        Chris Thomas              Forked the MMS Flamingo Edition script to use for MAEDS members

.EXAMPLE
  .\Get-MAEDSSessionContent.ps1 -ConferenceList @('2023','2024');

  Downloads all MAEDS session content from 2023 and 2024 to C:\Conferences\MAEDS\

.EXAMPLE
  .\Get-MAEDSSessionContent.ps1 -DownloadLocation "C:\Temp\MAEDSS" -ConferenceId 2024

  Downloads all MAEDS session content from 2024 to C:\Temp\MAEDS\

.EXAMPLE
  .\Get-MAEDSSessionContent.ps1 -All

  Downloads all MAEDS session content from all years to C:\Conferences\MAEDS\

.EXAMPLE
  .\Get-MAEDSSessionContent.ps1 -All -ExcludeSessionDetails;

  Downloads all MAEDS session content from all years to C:\Conferences\MAEDS\ BUT does not include a "Session Info.txt" file for each session containing the session details

.LINK
  Project URL - https://github.com/chrisATautomatemystuff/CopyMAEDSFiles
#>
[cmdletbinding(PositionalBinding = $false)]
Param(
  [Parameter(Mandatory = $false)][string]$DownloadLocation = "C:\Conferences\MAEDS", # could validate this: [ValidateScript({(Test-Path -Path (Split-Path $PSItem))})]
  [Parameter(Mandatory = $true, ParameterSetName = 'SingleEvent')]
  [ValidateSet("2023","2024")]
  [string]$ConferenceId,
  [Parameter(Mandatory = $true, ParameterSetName = 'MultipleEvents', HelpMessage = "This needs to bwe a list or array of conference ids/years!")]
  [System.Collections.Generic.List[string]]$ConferenceList,
  [Parameter(Mandatory = $true, ParameterSetName = 'AllEvents')][switch]$All,
  [Parameter(Mandatory = $false)][switch]$ExcludeSessionDetails
)

function Invoke-BasicHTMLParser ($html) {
  $html = $html.Replace("<br>","`r`n").Replace("<br/>","`r`n").Replace("<br />","`r`n") # replace <br> with new line

  # Speaker Spacing
  $html = $html.Replace("<div class=`"sched-person-session`">","`r`n`r`n")

  # Link parsing
  $linkregex = '(?<texttoreplace><a.*?href="(?<link>.*?)".*?>(?<content>.*?)<\/a>)'
  $links = [regex]::Matches($html, $linkregex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  foreach($l in $links)
  {
    if(-not $l.Groups['link'].Value.StartsWith("http")){$link = "$SchedBaseURL/$($l.Groups['link'].Value)"}else{$link = $l.Groups['link'].Value}
    $html = $html.Replace($l.Groups['texttoreplace'].Value, " [$($l.Groups['content'].Value)]($link)")
  }

  # List Parsing
  $listRegex = '(?<texttoreplace><ul[^>]?>(?<content>.*?)<\/ul>)'
  $lists = [regex]::Matches($html, $listRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  foreach($l in $lists)
  {
    $content = $l.Groups['content'].Value.Replace("<li>","`r`n* ").Replace("</li>","")
    $html = $html.Replace($l.Groups['texttoreplace'].Value, $content)
  }

  # General Cleanup
  $html = $html.replace("&rarr;", "")
  $html = $html -replace '<div[^>]+>', "`r`n"
  $html = $html -replace '<[^>]+>', '' # Strip all HTML tags

  ## Future revisions
  # do something about <b> / <i> / <strong> / etc...
  # maybe a converter to markdown
  
  return $html
}
## Hide Invoke-WebRequest progress bar. There's a bug that doesn't clear the bar after a request is finished. 
$ProgressPreference = "SilentlyContinue"
## Determine OS... sorta
if($PSEdition -eq "Desktop" -or $isWindows){$win = $true}
else
{ 
  $win = $false
  if($DownloadLocation -eq "C:\Conferences\MAEDS"){$DownloadLocation = "$HOME\Downloads\MAEDSContent"}
}

## Make sure there aren't any trailing backslashes:
$DownloadLocation = $DownloadLocation.Trim('\')

## Setup
$PublicContentYears = @()
$PrivateContentYears = @('2023','2024')
$ConferenceYears = New-Object -TypeName System.Collections.Generic.List[string]
[int]$PublicYearsCount = $PublicContentYears.Count
[int]$PrivateYearsCount = $PrivateContentYears.Count

if ($All) {
  for ($i = 0; $i -lt $PublicYearsCount; $i++) {
    $ConferenceYears.Add($PublicContentYears[$i])
  }
  Remove-Variable -Name i -ErrorAction SilentlyContinue
  for ($i = 0; $i -lt $PrivateYearsCount; $i++) {
    $ConferenceYears.Add($PrivateContentYears[$i])
  }
  Remove-Variable -Name i -ErrorAction SilentlyContinue
} elseif ($PsCmdlet.ParameterSetName -eq 'SingleEvent') {
  $ConferenceYears.Add($ConferenceId)
} else {
  $ConfListCount = $ConferenceList.Count
  for ($i = 0; $i -lt $ConfListCount; $i++) {
    if ($ConferenceList[$i] -in ($PublicContentYears + $PrivateContentYears)) {
      $ConferenceYears.Add($ConferenceList[$i])
    } else {
      Write-Output "The Conference Id '$($ConferenceList[$i])' is not valid. Item will be skipped."
    }
  }
  Remove-Variable -Name i -ErrorAction SilentlyContinue
}

Write-Output "Base Download URL is $DownloadLocation"
Write-Output "Searching for content from these sessions: $([String]::Join(',',$ConferenceYears))"

##
$ConferenceYears | ForEach-Object -Process {
  [string]$Year = $_

  if ($Year -in $PrivateContentYears) {
    $creds = $host.UI.PromptForCredential('Sched Credentials', "Enter Credentials for the MAEDS Event: $Year", '', '')
  }

  $SchedBaseURL = "https://maeds" + $Year + ".sched.com"
  $SchedLoginURL = $SchedBaseURL + "/login"
  Add-Type -AssemblyName System.Web
  $web = Invoke-WebRequest $SchedLoginURL -SessionVariable mms
   ## Connect to Sched

  if ($creds) {
    #$form = $web.Forms[1]
    #$form.fields['username'] = $creds.UserName;
    #$form.fields['password'] = $creds.GetNetworkCredential().Password;

    $username = $creds.UserName
    $password = $creds.GetNetworkCredential().Password

    # Updated POST body
    $body = "landing_conf=" + [System.Uri]::EscapeDataString($SchedBaseURL) + "&username=" + [System.Uri]::EscapeDataString($username) + "&password=" + [System.Uri]::EscapeDataString($password) + "&login="

    # SEND IT
    $web = Invoke-WebRequest $SchedLoginURL -SessionVariable maeds -Method POST -Body $body

  } else {
    $web = Invoke-WebRequest $SchedLoginURL -SessionVariable maeds
  }

  $SessionDownloadPath = $DownloadLocation + '\maeds' + $Year
  Write-Output "Logging in to $SchedBaseURL"

  ## Check if we connected (if required):
  if ((-Not ($web.InputFields.FindByName("login")) -and ($Year -in $PrivateContentYears)) -or ($Year -in $PublicContentYears)) {
    ##
    Write-Output "Downloaded content can be found in $SessionDownloadPath"

    $sched = Invoke-WebRequest -Uri $($SchedBaseURL + "/list/descriptions") -WebSession $maeds
    $links = $sched.Links

    # For indexing available downloads later
    $eventsList = New-Object -TypeName System.Collections.Generic.List[int]
    $links | ForEach-Object -Process {
      if ($_.href -like "event/*") {
        [void]$eventsList.Add($links.IndexOf($_))
      }
    }
    $eventCount = $eventsList.Count

    for($i = 0; $i -lt $eventCount; $i++)
    {
      [int]$linkIndex = $eventsList[$i]
      [int]$nextLinkIndex = $eventsList[$i + 1]
      $eventobj = $links[($eventsList[$i])]

      # Get/Fix the Session Title:
      $titleRegex = '<a.*?href="(?<url>.*?)".*?>(?<title>.*?)<\/a>'
      $titleMatches = [regex]::Matches($eventobj.outerHTML.Replace("`r","").Replace("`n",""), $titleRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
      [string]$eventTitle = $titleMatches.Groups[0].Groups['title'].Value.Trim()
      [string]$eventUrl = $titleMatches.Groups[0].Groups['url'].Value.Trim()

      # Generate session info string
      [string]$sessionInfoText = ""
      $sessionInfoText += "Session Title: `r`n$eventTitle`r`n`r`n"
      $downloadTitle = $eventTitle -replace "[^A-Za-z0-9-_. ]", ""
      $downloadTitle = $downloadTitle.Trim()
      $downloadTitle = $downloadTitle -replace "\W+", "_"

      ## Set the download destination:
      $downloadPath = $SessionDownloadPath + "\" + $downloadTitle

      ## Get session info if required:
      if(-not $ExcludeSessionDetails) {
        $sessionLinkInfo = (Invoke-WebRequest -Uri $($SchedBaseURL + "/" + $eventUrl) -WebSession $mms).Content.Replace("`r","").Replace("`n","")

        $descriptionPattern = '<div class="tip-description">(?<description>.*?)<hr style="clear:both"'
        $description = [regex]::Matches($sessionLinkInfo, $descriptionPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if($description.Count -gt 0){$sessionInfoText += "$(Invoke-BasicHTMLParser -html $description.Groups[0].Groups['description'].Value)`r`n`r`n"}

        $rolesPattern = "<div class=`"tip-roles`">(?<roles>.*?)<br class='s-clr'"
        $roles = [regex]::Matches($sessionLinkInfo, $rolesPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if($roles.Count -gt 0){$sessionInfoText += "$(Invoke-BasicHTMLParser -html $roles.Groups[0].Groups['roles'].Value)`r`n`r`n"}

        if ((Test-Path -Path $($downloadPath)) -eq $false) { New-Item -ItemType Directory -Force -Path $downloadPath | Out-Null }
        Out-File -FilePath "$downloadPath\Session Info.txt" -InputObject $sessionInfoText -Force -Encoding default
      }

      $downloads = $links[($linkIndex + 1)..($nextLinkIndex - 1)] | Where-Object {$_.href -like "*hosted_files*"} #prefilter
      foreach($download in $downloads){
        $filename = Split-Path $download.href -Leaf
        # Replace HTTP Encoding Characters (e.g. %20) with the proper equivalent.
        $filename = [System.Web.HttpUtility]::UrlDecode($filename)
        # Replace non-standard characters
        $filename = $filename -replace "[^A-Za-z0-9\.\-_ ]", ""

        $outputFilePath = $downloadPath + '\' + $filename

        # Reduce Total Path to 255 characters.
        $outputFilePathLen = $outputFilePath.Length
        if ($outputFilePathLen -ge 255) {
          $fileExt = [System.IO.Path]::GetExtension($outputFilePath)
          $newFileName = $outputFilePath.Substring(0, $($outputFilePathLen - $fileExt.Length))
          $newFileName = $newFileName.Substring(0, $(255 - $fileExt.Length)).trim()
          $newFileName = "$newFileName$fileExt"
          $outputFilePath = $newFileName
        }

        # Download the file
        if ((Test-Path -Path $($downloadPath)) -eq $false) { New-Item -ItemType Directory -Force -Path $downloadPath | Out-Null }
        if ((Test-Path -Path $outputFilePath) -eq $false) {
          Write-Output "...attempting to download '$filename'"
          try {
            Invoke-WebRequest -Uri $download.href -OutFile $outputfilepath -WebSession $mms
            if($win){Unblock-File $outputFilePath}
          } catch {
            Write-Output ".................$($PSItem.Exception) for '$($download.href)'...moving to next file..."
          }
        }
      } # end procesing downloads
    } # end processing session
  } # end connectivity/login check
  else {
    Write-Output "Login to $SchedBaseUrl failed."
  }
}
