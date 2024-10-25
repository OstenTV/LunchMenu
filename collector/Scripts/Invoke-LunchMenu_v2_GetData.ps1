Start-Transcript -Path "C:\TS\log\LunchMenu_v2_GetData\script.log" -Append
$LogPath = "C:\TS\log\LunchMenu_v2_GetData";
$LogRetention = New-TimeSpan -Start (Get-Date).AddYears(-10) -End (Get-Date);
$OutputDir = "D:\VirtualSites\LunchAPI\v2";
$DateFormat = "yyyy-MM-dd";
$DateTimeUFormat = "%Y-%m-%d %T %Z";
$SQLConnectionString = "Server=localhost;Database=FoodService;Encrypt=True;TrustServerCertificate=True;Integrated Security=SSPI"
$TablePrefix = "lunch";

$SQLConnection = New-Object System.Data.SqlClient.SqlConnection;
$SQLConnection.ConnectionString = $SQLConnectionString;
$SQLConnection.Open();

function Read-SQL {
    
    Param (
        [Parameter(Mandatory=$true)]
        [System.Data.Common.DbConnection]$SQLConnection,
        [Parameter(Mandatory=$true)]
        [string] $Query,
        [Parameter(Mandatory=$false)]
        [HashTable]$SQLParameters
    )

    $DataTable = New-Object System.Data.DataTable
    $SQLCommand = $SQLConnection.CreateCommand();
    $SQLCommand.CommandText = $Query;

    if ($SQLParameters) {
        foreach ($Name in $SQLParameters.Keys) {
            $Value = $SQLParameters.$Name;
            $SQLCommand.Parameters.Add((New-Object Data.SqlClient.SqlParameter("$Name", $Value))) | Out-Null;
        }
    }

    $SQLReader = $SQLCommand.ExecuteReader();
    $DataTable.Load($SQLReader);
    $SQLReader.Close();
    $SQLCommand.Dispose();

    return $DataTable;

}

function Write-SQL {
    
    Param (
        [Parameter(Mandatory=$true)]
        [System.Data.Common.DbConnection]$SQLConnection,
        [Parameter(Mandatory=$true)]
        [string] $Query,
        [Parameter(Mandatory=$false)]
        [HashTable]$SQLParameters
    )

    $QUery = $Query;
    $SQLCommand = $SQLConnection.CreateCommand();
    $SQLCommand.CommandText = $query;

    if ($SQLParameters) {
        foreach ($Name in $SQLParameters.Keys) {
            $Value = $SQLParameters.$Name;
            $SQLCommand.Parameters.Add((New-Object Data.SqlClient.SqlParameter("$Name", $Value))) | Out-Null;
        }
    }

    $SQLAffectedRows = $SQLCommand.ExecuteNonQuery();

    return $SQLAffectedRows;

}

Import-Module SQLServer -Force;
if ($env:USERNAME -like "admin*") {
    Import-Module "C:\Users\$($env:USERNAME)\Documents\GitHub\LunchMenu\collector\Modules\LunchProvider\LunchProvider.psm1", "C:\Users\$($env:USERNAME)\Documents\GitHub\LunchMenu\collector\Modules\LogUtil\LogUtil.psm1" -Force;
} else {
    Import-Module LunchProvider, LogUtil -Force;
}

$LocationID = 1;
$Languages = Read-SQL -SQLConnection $SQLConnection -Query "SELECT * FROM [$($TablePrefix)_language]"
$DishTypes = Read-SQL -SQLConnection $SQLConnection -Query "SELECT * FROM [$($TablePrefix)_dish_type]";

if (($Result = Get-GuckenheimerLunchWeekhMenu)) {

    $Weeknumber = $Result.Weeknumber;
    $Year = $Result.Timestamp | Get-Date -UFormat "%Y"
    $UnixTimestamp  = ([DateTimeOffset]$Result.Timestamp).ToUnixTimeSeconds();
    $MenuInAllLanguages = $Result.Menus;

    foreach ($MenuData in $MenuInAllLanguages) {
        
        $WeekMenu = $MenuData.Menu;
        $LanguageID = $MenuData.Language;
        foreach ($Day in $WeekMenu) {
            
            $Menu = $Day.Menu;
            $DayIndex = $Day.DayIndex;
            $MealByType = ($Menu | group -Property Type);
            foreach ($MealGroup in $MealByType) {
                
                [Array]$Meal = $MealGroup.Group;
                $DishAsJSON = $Meal.Dish | ConvertTo-Json;
                $AllergenerAsJSON = $Meal.Allergener | ConvertTo-Json;

                #Check if the same dish already exist in DB.
                $TypeName = $Dish.Type.ToLower().Replace(" ","")
                $TypeID = ($DishTypes | ? {$_.name -eq $TypeName}).id
                $Query = "SELECT [dish],[allergens] FROM [lunch_dish] WHERE [year] = $Year AND [week] = $Weeknumber AND [day] = $DayIndex AND [type_id] = $TypeID AND [dish] = @dish AND [allergens] = @allergens";
                $Parameters = @{
                    "@dish" = $DishAsJSON;
                    "@allergens" = $AllergenerAsJSON
                }
                $ExistingDishes = Read-SQL -SQLConnection $SQLConnection -Query $Query -SQLParameters $Parameters;
                


            }
        }
    }






    Get-GuckenheimerLunchAssets | % {
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

$SQLConnection.Close();

Stop-Transcript