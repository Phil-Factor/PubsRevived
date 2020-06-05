Import-Module SqlChangeAutomation

<#
  .SYNOPSIS
  
  .DESCRIPTION
  
  .EXAMPLE
  
  .NOTES
#>

function SourceControl($TheDetails)
{
  
  if ($TheDetails.source -ne $null)
  {
    $DatabaseSpecified = 'source'; $TheDatabase = $TheDetails.source;
    if ($TheDetails.target -ne $null) { write-error 'both target and source databases are specified' }
  }
  else
  {
    if ($TheDetails.target -ne $null) { $DatabaseSpecified = 'target'; $TheDatabase = $TheDetails.target }
    else { write-error 'you need to specify either a source or target database' }
  }
  
  $TheDetails
  
  
  $SqlUserName = $TheDatabase.uid
  $SQLInstance = $TheDatabase.Server
<# ------- Create a connection --------#>
  if ($TheDatabase.uid -eq '') <# then it is simple #>
  {
    $MyConnection = New-DatabaseConnection  `
                         -ServerInstance $TheDatabase.Server `
                         -Database $TheDatabase.Database
  }
  else
  { <# Oh dear, we need to get the password, if we don't already know it #>
    $SqlEncryptedPasswordFile = `
    "$env:USERPROFILE\$($TheDatabase.uid)-$($TheDatabase.server.Replace('\', $slash)).xml"
    # test to see if we know about the password in a secure string stored in the user area
    if (Test-Path -path $SqlEncryptedPasswordFile -PathType leaf)
    {
      #has already got this set for this login so fetch it
      $SqlCredentials = Import-CliXml $SqlEncryptedPasswordFile
      
    }
    else #then we have to ask the user for it (once only)
    {
      #hasn't got this set for this login
      $SqlCredentials = get-credential -Credential $SqlUserName
      $SqlCredentials | Export-CliXml -Path $SqlEncryptedPasswordFile
    }
    $MyConnection = New-DatabaseConnection  `
                         -ServerInstance $TheDatabase.Server -Database $TheDatabase.Database `
                         -Username $SqlUserName  `
                         -password $SqlCredentials.GetNetworkCredential().password
  }
  
<# ------- Test the connection --------#>
  try { $Source = Test-DatabaseConnection $MyConnection }
  catch
  {
    Write-error "Sorry but the connection string $(
      $MyConnection.ConnectionString.MaskedValue) to $(
      $MyConnection.FriendlyName)  didn't work. Try again"
  }
  
<# ------- we create a blank target directory --------#>
  $BlankTarget = "$env:TEMP\BlankTarget"
<# ------- create a  directory for this file   --------#>
  if (Test-Path -path "$BlankTarget\*" -PathType Leaf)
  { Get-ChildItem "$BlankTarget" -Include * -Recurse | Remove-Item -Force }
  if (!(Test-Path -path "$BlankTarget" -PathType Container))
  { New-Item -ItemType Directory -Force -Path $BlankTarget }
  
  
<# ------- check to see if the specified source-code directory exists 
           and create it if not                                     --------#>
  if (!(Test-Path -path "$($TheDetails.directory)\Build" -PathType Container))
  { New-Item -ItemType Directory -Force -Path "$($TheDetails.directory)\Build" }
  $InitialScript = (!(Test-Path "$($TheDetails.directory)\Build\*"))
<# ------- has this an existing version in source control?  -------#>
  # set a default just in case
  $currentVersion = 'unknown';
  $versionFileContents = @{
    #specify whatever json schema you use for your version record.
    '$schema' = 'https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/master/src/NerdBank.GitVersioning/version.schema.json';
    'version' = "$($TheDatabase.version)"
  }
<# ------- read the current version of the database in git source control  --------#>
  if (Test-Path -path "$($TheDetails.directory)\version.json" -PathType Leaf)
  {
    $versionFileContents = Get-Content -Raw -Path "$($TheDetails.directory)\version.json" | convertfrom-json
    $currentVersion = $versionFileContents.version
  }
  
<# -------create a release artifact so we can get the object-level scripts from it  --------#>
  $TempExportLocation = "$env:TEMP\Release$($TheDatabase.database)"
<# -------Synchronize a target with the build subdirectory of the scripts directory --------#>
  if ($DatabaseSpecified -eq 'source')
  {
    $iReleaseArtifact = New-DatabaseReleaseArtifact -source $MyConnection -Target "$($TheDetails.directory)\Build" `
                            -SQLCompareOptions '-IgnoreExtendedProperties'
  }
  else # the user wants to get a migration script from the previous sprint or release
  {
    $iReleaseArtifact = New-DatabaseReleaseArtifact -target $MyConnection -source "$($TheDetails.directory)\Build" `
                            -SQLCompareOptions '-IgnoreExtendedProperties'
  }
  if ($iReleaseArtifact -eq $null) { Throw "$DatabaseSpecified comparison with $($TheDetails.directory)\Build failed" }
<# -------Display any warnings --------#>
  $high = 0
  $iReleaseArtifact.warnings | foreach{ if ($_ -like '*(high)*') { $high++ }; Write-warning $_ }
  if ($high -gt 0) { pause }
<# -------If that went well, get the contents of the release artefect into a tmp directory --------#>
  if ($DatabaseSpecified -eq 'source') #only necessary if we want the object-level spurce 
  {<# -------first clear out the temp directory if it exists --------#>
    if (!(Test-Path -path "$TempExportLocation" -PathType Container))
    { New-Item -ItemType Directory -Force -Path "$TempExportLocation" }
    
    if (Test-Path -path "$TempExportLocation\*" -PathType Leaf)
    { Get-ChildItem "$TempExportLocation" -Include * -Recurse | Remove-Item -Recurse -Force }
    
<# ------- Now export the contents of the release object  --------#>
    Export-DatabaseReleaseArtifact -InputObject $iReleaseArtifact -Path "$TempExportLocation"
<# ------- copy the source-level scripts into our build directory --------#>
    Get-ChildItem "$($TheDetails.directory)\Build" -Include *.sql -Recurse | Remove-Item -Force
    Copy-Item -Path "$TempExportLocation\States\Source\*"  `
          -Destination "$($TheDetails.directory)\Build" -container –Recurse -force
  }
  
<# ------- create a scripts directory if necessary  --------#>
  if (!(Test-Path -path "$($TheDetails.directory)\Scripts" -PathType Container))
  { New-Item -ItemType Directory -Force -Path "$($TheDetails.directory)\Scripts" }
<# --- make sure we have the directions right! --- #>
  if ($DatabaseSpecified -eq 'source')
  {
    $beforeVersion = $currentVersion;
    $AfterVersion = $TheDatabase.version;
  }
  else
  {
    $beforeVersion = $TheDatabase.version;
    $AfterVersion = $currentVersion;
  }
<# --- generate an HTML report if necessary #>
  
  $HTMLReportFile = "$($env:TEMP)report-$($BeforeVersion.replace(".", "-") + '_' + $AfterVersion.replace(".", "-")).html"
  $iReleaseArtifact.ReportHtml> $HTMLReportFile
  Start $HTMLReportFile
<# ------- name the scripts file accordingly  --------#>
  if ($InitialScript)
  {
    $ScriptFilename = "$($TheDetails.directory)\Scripts\InitialBuild_$($AfterVersion.replace(".", "-")).sql"
    $iReleaseArtifact.UpdateSQL > "$ScriptFilename"
  }
  else
  {
    $ScriptFilename = "$($TheDetails.directory)\Scripts\Migration_$($BeforeVersion.replace(".", "-") + '_' + $AfterVersion.replace(".", "-")).sql"
    @"
--inserted code
/* this script upgrades the database from $BeforeVersion to $AfterVersion 
First we check that this is a legitimate target to upgrade */
Declare @version varchar(25);
SELECT @version= Coalesce(Json_Value(
 ( SELECT Convert(NVARCHAR(3760), value) 
   FROM sys.extended_properties AS EP
   WHERE major_id = 0 AND minor_id = 0 
    AND name = 'Database_Info'),'$[0].Version'),'that was not recorded');
IF @version <> '$BeforeVersion'
 BEGIN
 RAISERROR ('We could not upgrade this to version $afterversion. The Target was at version %s, not the correct version ($BeforeVersion)',16,1,@version)
 SET NOEXEC ON;
 END
--end of inserted code
"@ > $ScriptFilename
<# ------- and save the synch script into the script directory --------#>
    $iReleaseArtifact.UpdateSQL >> "$ScriptFilename"
  }
  
  if ($DatabaseSpecified -eq 'source')
  {
    $versionFileContents.version = $($AfterVersion)
    $versionFileContents | convertto-JSON >"$($TheDetails.directory)\version.json"
  }
<# ------- if this isn't an initial script save a build script --------#>
  if (!($InitialScript))
  {
    $ScriptFilename = "$($TheDetails.directory)\Scripts\InitialBuild_$($AfterVersion.replace(".", "-")).sql"
    (New-DatabaseReleaseArtifact -source "$($TheDetails.directory)\Build" -Target $BlankTarget).UpdateSql>$ScriptFilename
  }
  
}

