Start-Transcript -Path "C:\TS\log\LunchMenu_v1_GetData\script.log" -Append
$LogPath = "C:\TS\log\LunchMenu_v1_GetData";
$LogRetention = New-TimeSpan -Start (Get-Date).AddYears(-10) -End (Get-Date);

$OutputDir = "D:\VirtualSites\LunchAPI\v1";

Import-Module LunchProvider, LogUtil -Force;

if (($Result = Get-LunchWeekhMenu)) {

    $menu = $Result.Menu;
    $weeknumber = $Result.Weeknumber;
    $frag = @()
    $outfilehtml = "$OutputDir\$(Get-Date -UFormat "%Y")-$($weeknumber).html"
    $outfilehtmllatest = "$OutputDir\latest.html"

    $outfilejson = "$OutputDir\$(Get-Date -UFormat "%Y")-$($weeknumber).json";
    $outfilejsonlatest = "$OutputDir\latest.json";

    $Result | ConvertTo-Json -Depth 10 | Out-File -Encoding UTF8 -FilePath $outfilejson;
    Write-Log -LogPath $LogPath -LogRetention $LogRetention -Level 8 -Text "Saved result to $outfilejson.";
    Copy-Item -Path $outfilejson -Destination $outfilejsonlatest -Force;
    Write-Log -LogPath $LogPath -LogRetention $LogRetention -Level 8 -Text "Updated $outfilejsonlatest.";

    foreach ($Day in $menu) {
    
        $weekday = $Day.Menu;
        $dayofweek = $day.Day;
        $dayofweekindex = $Day.DayIndex;

        # Add a picture column to each dish.
        foreach ($Dish in $weekday) {
            $AssetUri = "assets/$(Get-Date -UFormat "%Y")-$($weeknumber)/$dayofweekindex/$(($Dish.Type -replace ' ','').ToLower()).png"
            $Picture = "<a href='#$dayofweekindex' onclick=`"window.open('$AssetUri','popUpWindow','height=500,width=500,left=100,top=100,resizable=yes,scrollbars=no,toolbar=no,menubar=no,location=no,directories=no, status=yes');`"><img src='$AssetUri' style='width: 10vw;' /></a>";
            Add-Member -InputObject $Dish -Type NoteProperty -Name Picture -Value $Picture;
        }
        
        $frag += $weekday | select Type, Dish, Allergener, Picture | ConvertTo-Html -Fragment -PreContent "<h2 id='$dayofweekindex'>$dayofweek</h2>" | Out-String
    
    }


    $head = @’
<style>
body { background-color:#dddddd;
font-family:Tahoma;
font-size:12pt; }
td, th { border:1px solid black;
border-collapse:collapse;
font-size: 1.5em; }
th { color:white;
background-color:black; }
table, tr, td, th { padding: 2px; margin: 0px }
table { padding-left:50px;padding-right:50px;width:100%; }
</style>
‘@
    
    Add-Type -AssemblyName System.Web

    $HTML = ConvertTo-HTML -head $head -PostContent $frag -PreContent “<h1>Ugens menu $($weeknumber)</h1><p>Opdateret: $($Result.Timestamp)</p>”
    [System.Web.HttpUtility]::HtmlDecode($HTML) | Out-File $outfilehtml;
    Write-Log -LogPath $LogPath -LogRetention $LogRetention -Level 8 -Text "Saved result to $outfilehtml.";
    Copy-Item -Path $outfilehtml -Destination $outfilehtmllatest -Force;
    Write-Log -LogPath $LogPath -LogRetention $LogRetention -Level 8 -Text "Updated $outfilehtmllatest.";

    Get-LunchAssets | % {
        if (!($_.href -like "*platefall*")) {
            
            if (!(Test-Path ($dir = "$OutputDir\assets\$(Get-Date -UFormat "%Y")-$($weeknumber)\$(Get-Date -UFormat %u)") )) {
                mkdir $dir
            }

            $outfile = "$dir\$(($_.Dish -replace ' ','').ToLower()).png";

            if (!(Test-Path -Path $outfile) -or $true) {
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