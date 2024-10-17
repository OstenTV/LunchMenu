Start-Transcript -Path "C:\TS\log\LunchMenu_v2_GetData\script.log" -Append
$LogPath = "C:\TS\log\LunchMenu_v2_GetData";
$LogRetention = New-TimeSpan -Start (Get-Date).AddYears(-10) -End (Get-Date);

$OutputDir = "D:\VirtualSites\LunchAPI\v2";

$SQLConnectionString = "Server=localhost;Database=FoodService;Encrypt=True;TrustServerCertificate=True;Integrated Security=SSPI"
if (!(Invoke-Sqlcmd -ConnectionString $SQLConnectionString  -Query "SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE'")) {
    Throw "SQL Server not alive!`n$_";
}

Import-Module SQLServer -Force;
if ($env:USERNAME -like "admin*") {
    Import-Module "C:\Users\$($env:USERNAME)\Documents\GitHub\LunchMenu\guckenheimer\Modules\LunchProvider\LunchProvider.psm1", "C:\Users\$($env:USERNAME)\Documents\GitHub\LunchMenu\guckenheimer\Modules\LogUtil\LogUtil.psm1" -Force;
} else {
    Import-Module LunchProvider, LogUtil -Force;
}

if (($Result = Get-LunchWeekhMenu)) {

    # TODO Do stuff with the $Result and import into DB

    Get-LunchAssets | % {
        if (!($_.href -like "*platefall*")) {
            
            if (!(Test-Path ($dir = "$OutputDir\assets\$(Get-Date -UFormat "%Y")-$($weeknumber)\$(Get-Date -UFormat %u)") )) {
                mkdir $dir
            }

            $outfile = "$dir\$(($_.Dish -replace ' ','').ToLower()).png";

            # TODO Make some logic to check if the image is updated or is the same.
            $IsUpdated = $true;

            if (!(Test-Path -Path $outfile) -or $IsUpdated) {
                Write-Log -LogPath $LogPath -LogRetention $LogRetention -Level 8 -Text "Downloading asset $outfile.";
                Invoke-WebRequest -Uri $_.href -OutFile $outfile;
            } else {
                Write-Log -LogPath $LogPath -LogRetention $LogRetention -Level 8 -Text "Asset $outfile already exists.";
            }
            
        } else {
            Write-Log -LogPath $LogPath -LogRetention $LogRetention -Level 8 -Text "No assets available for $($_.Dish).";
        }
    }

}

Stop-Transcript