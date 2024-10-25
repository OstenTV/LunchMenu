$VerbosePreference = "Continue";
Start-Transcript -Path "C:\TS\log\LunchMenu_v2_GetData\script.log" -Append
$LogPath = "C:\TS\log\LunchMenu_v2_GetData";
$LogRetention = New-TimeSpan -Start (Get-Date).AddYears(-10) -End (Get-Date);
$AssetsDir = "D:\VirtualSites\LunchAPI\v2\assets";
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

    Write-Log -LogPath $LogPath -LogRetention $LogRetention -Level 8 -Text "Execute reading SQL Query." -AdditionalFields @{"Query"=$Query};
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

    $SQLCommand = $SQLConnection.CreateCommand();
    $SQLCommand.CommandText = $query;

    if ($SQLParameters) {
        foreach ($Name in $SQLParameters.Keys) {
            $Value = $SQLParameters.$Name;
            $SQLCommand.Parameters.Add((New-Object Data.SqlClient.SqlParameter("$Name", $Value))) | Out-Null;
        }
    }

    Write-Log -LogPath $LogPath -LogRetention $LogRetention -Level 8 -Text "Execute writing SQL Query." -AdditionalFields @{"Query"=$Query};
    $SQLAffectedRows = $SQLCommand.ExecuteNonQuery();
    $SQLCommand.Dispose()

    return $SQLAffectedRows;

}

if ($env:USERNAME -like "admin*") {
    Import-Module "C:\Users\$($env:USERNAME)\Documents\GitHub\LunchMenu\collector\Modules\LunchProvider\LunchProvider.psm1", "C:\Users\$($env:USERNAME)\Documents\GitHub\LunchMenu\collector\Modules\LogUtil\LogUtil.psm1" -Force;
} else {
    Import-Module LunchProvider, LogUtil -Force;
}
if (!(Test-Path -Path $AssetsDir )) {
    mkdir $AssetsDir
}

$CurrentDayOFWeek = (Get-Date).DayOfWeek.value__;
$LocationID = 1;
$Languages = Read-SQL -SQLConnection $SQLConnection -Query "SELECT * FROM [$($TablePrefix)_language]"
$DishTypes = Read-SQL -SQLConnection $SQLConnection -Query "SELECT * FROM [$($TablePrefix)_type]";


if (($Result = Get-GuckenheimerLunchWeekhMenu)) {
    
    # Detect and add missing dish types.
    $ProviderDishTypes = $Result.Menus.Menu.Menu.Type | select -Unique;
    $MissingDushTypes = $ProviderDishTypes | ? {($_ -replace "[^a-zA-Z]", "").ToLower() -notin $DishTypes.name};
    if ($MissingDushTypes) {
        foreach ($MissingDushType in $MissingDushTypes) {
            $MissingDushTypeName = ($MissingDushType -replace "[^a-zA-Z]", "").ToLower();
            Write-Log -LogPath $LogPath -LogRetention $LogRetention -Level 6 -Text "Found new dish type with name: $MissingDushTypeName.";
            $DishTypeParameters = @{
                "@name" = $MissingDushTypeName;
                "@displayname" = $MissingDushType;
            }
            $Query = "INSERT INTO [$($TablePrefix)_type] ([name], [displayname] VALUES (@name,@displayname)";
            $SQLResult = Write-SQL -SQLConnection $SQLConnection -Query $Query -SQLParameters $DishTypeParameters;
        }
        $DishTypes = Read-SQL -SQLConnection $SQLConnection -Query "SELECT * FROM [$($TablePrefix)_dish_type]";
    }
    
    $Weeknumber = $Result.Weeknumber;
    $Year = $Result.Timestamp | Get-Date -UFormat "%Y"
    $UnixTimestamp  = ([DateTimeOffset]$Result.Timestamp).ToUnixTimeSeconds();
    $MenuInAllLanguages = $Result.Menus;

    foreach ($MenuData in $MenuInAllLanguages) {
        
        $WeekMenu = $MenuData.Menu;
        $LanguageID = $MenuData.Language+1;
        foreach ($Day in $WeekMenu) {
            
            $Menu = $Day.Menu;
            $DayIndex = $Day.DayIndex;
            foreach ($Dish in $Menu) {
                
                $TypeName = ($Dish.Type -replace "[^a-zA-Z]", "").ToLower()
                $TypeID = ($DishTypes | ? {$_.name -eq $TypeName}).id
                
                #Check if the same dish already exist in DB.
                $Query = "SELECT [dish],[allergens] FROM [$($TablePrefix)_dish] WHERE [location_id] = @locationid AND [language_id] = @languageid AND [year] = @Year AND [week] = @weeknumber AND [day] = @dayindex AND [type_id] = @typeid AND [dish] = @dish AND [allergens] = @allergens AND [iterator] = @iterator";
                $DishParameters = @{
                    "@locationid" = $LocationID;
                    "@languageid" = $LanguageID;
                    "@year" = $year;
                    "@weeknumber" = $Weeknumber;
                    "@dayindex" = $DayIndex;
                    "@typeid" = $TypeID;
                    "@dish" = $Dish.Dish;
                    "@allergens" = $Dish.Allergener;
                    "@iterator" = $Dish.Iterator;
                }
                
                $ExistingDish = Read-SQL -SQLConnection $SQLConnection -Query $Query -SQLParameters $DishParameters;
                if (!($ExistingDish)) {
                    $Query = "INSERT INTO [$($TablePrefix)_dish] ([location_id], [language_id], [year], [week], [day], [type_id], [dish], [allergens], [iterator]) VALUES (@locationid,@languageid,@Year,@weeknumber,@dayindex,@typeid,@dish,@allergens,@iterator)";
                    $SQLResult = Write-SQL -SQLConnection $SQLConnection -Query $Query -SQLParameters $DishParameters;
                }

            }
        }
    }

    Write-Log -LogPath $LogPath -LogRetention $LogRetention -Level 8 -Text "Finished processing lunch data.";

}

$LunchAssets = Get-GuckenheimerLunchAssets

foreach ($AssetData in $LunchAssets) {
    if (!($AssetData.href -like "*platefall*")) {
        $OutFile = "$AssetsDir\$($AssetData.asset).png";
        
        #Check if the same asset already exist in DB.
        $Query = "SELECT [asset] FROM [$($TablePrefix)_asset] WHERE [asset] = @asset";
        $AssetParameters = @{
            "@asset" = $AssetData.asset;
        }
        $ExistingAsset = Read-SQL -SQLConnection $SQLConnection -Query $Query -SQLParameters $AssetParameters;
        if (!($ExistingAsset)) {
            Write-Log -LogPath $LogPath -LogRetention $LogRetention -Level 8 -Text "Downloading asset $OutFile.";
            $Query = "INSERT INTO [$($TablePrefix)_asset] ([asset]) VALUES (@asset)";
            $SQLResult = Write-SQL -SQLConnection $SQLConnection -Query $Query -SQLParameters $AssetParameters;
            Invoke-WebRequest -Uri $AssetData.href -OutFile $OutFile;
        } else {
            Write-Log -LogPath $LogPath -LogRetention $LogRetention -Level 8 -Text "Asset $outfile already exists.";
        }

        # Here we need to link the asset to the dish via lunch_dish_asset table.

    } else {
        Write-Log -LogPath $LogPath -LogRetention $LogRetention -Level 8 -Text "No assets available for $($_.Dish).";
    }
}

$SQLConnection.Close();

Stop-Transcript