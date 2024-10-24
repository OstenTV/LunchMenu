function Write-Log
{
    Param
    (
        [Parameter(mandatory=$true)]
        [string]$Text,
        [Parameter(mandatory=$true)]
        [int]$Level,
        [Parameter(mandatory=$false)]
        [int32]$ExitCode,
        [Parameter(mandatory=$false)]
        [hashtable]$AdditionalFields,
        [Parameter(mandatory=$true)]
        [string]$LogPath,
        [Parameter(mandatory=$false)]
        [timespan]$LogRetention = (New-TimeSpan -Days 7)
    )

    # Date and timestamp used for filename and log entry timestamp.
    $Date = Get-Date -format "yyyy-MM-dd";
    $Timestamp = Get-Date -UFormat "%Y-%m-%d %T %Z";

    # Map the log level to the corresponding string.
    $LevelText =@{
        1="Emergency";
        2="Alert";
        3="Critical";
        4="Error";
        5="Warning";
        6="Notice";
        7="Informational";
        8="Debug";
    }

    # Make sure the log level provided to the function is within the expected range.
    if (($Level -lt 1) -or ($Level -gt $LevelText.Count)) {
        Write-Error "Level must be between 1 and $($LevelText.Count). Value provided $Level."
    }

    # Crreate the log path if it does not exist.
    if (-not (Test-Path -Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory;
    }
    
    # Define the name of the log file with today's date.
    $FilePath = "$LogPath\$Date-Events.log";

    # Put together the log entry with the required variables, in a Splunk readable format.
    $LogEntry = "";
    $LogEntry += "$timestamp ";
    $LogEntry += "LevelString=`"$($LevelText.$Level)`",";
    $LogEntry += "Level=$Level,";
    $LogEntry += "Message=`"$Text`",";
    # Add the exit code to the log entry, if it was probided when calling this function.
    if ($ExitCode) {
        $LogEntry += "ExitCode=$ExitCode,";
    }
    if ($AdditionalFields) {
        foreach ($Key in $AdditionalFields.Keys) {
            $LogEntry += "$Key=`"$($AdditionalFields[$Key].ToString())`",";
        }
    }

    # Append the finished log entry to the log file.
    Write-Output $LogEntry | Out-File -FilePath $FilePath -Append;
    Write-Verbose $LogEntry;

    # Decide which logs to delete and then delete them. The timespan is a param to this function.
    $PurgeLogsDateTime = ((Get-Date)-$LogRetention)
    $PurgeLogsFiles = Get-ChildItem -Path $LogPath | ? -Property Extension -EQ ".log" | ? -Property LastWriteTime -LT $PurgeLogsDateTime;
    $PurgeLogsFiles | Remove-Item -Force;

}