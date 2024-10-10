
function Get-LunchWeekhMenu {
    
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [int] $Language = 0,
        [Parameter(Mandatory=$false)]
        [string] $Uri = "https://www.guckenheimer.dk/banner/weekmenu/42"
    )

    Write-Verbose "Getting Lunch Menu from $Uri";

    $FlatMenu = @();
    $Menu = @();

    $DayNameIndex = @{
        Mandag = 1;
        Tirsdag = 2;
        Onsdag = 3;
        Torsdag = 4;
        Fredag = 5;
    }

    # Get the HTML of the URI.
    $R = Invoke-WebRequest -Uri $Uri;
    if (!($R)) {throw "No response from LunchProvider"}
    $HTML = $R.ParsedHtml;

    [int]$WeekNumber = $HTML.getElementsByClassName("menu-of-the-week")[0].Children[0].Children[0].Children[0].InnerText.Replace("Ugens menu ","");
    Write-Verbose "Detected weeknumber $WeekNumber";

    $WeekMenu = $HTML.getElementsByClassName("weekdays")[$Language];
    $Days = $WeekMenu.getElementsByClassName("days");

    foreach ($Day in $Days) {
    
        # Get list of dish strings for the given day.
        $TextInfo = (Get-Culture).TextInfo
        $DayName = $TextInfo.ToTitleCase($Day.children[0].innerHTML.ToLower());
        Write-Verbose "Parsing menu for $DayName";
        $DayMenu = $Day.children[1].children;
        $strings = $DayMenu | % {$_.innerText};
        
        # Loop through the strings
        Foreach ($string in $strings) {
        
            # Extract the type
            $type = ($string -split ":")[0] -replace '• ', ''
            Write-Verbose "Parsing $type";

            # Split the dishes by '/'
            $dishes = ($string -split ':', 2)[1] -split "\) / " | ForEach-Object {
                $str = $_.Trim();
                if (!($str -match '\)$')) {
                    $str + " )";
                    Write-Verbose "$type has multiple dishes";
                } else {
                    $str;
                    Write-Verbose "$type has one dish";
                }
            }

            # For each dish, extract allergens and create a PSCustomObject with the extracted information
            $dishes | ForEach-Object {
                $dish = $_.Trim() -replace ' \(.*', ''
                $allergener = $_.Trim() -replace '.*\( Allergener: (.*?) \).*', '$1'

                $FlatMenu += [PSCustomObject]@{
                    Day = $DayName
                    Type = $type
                    Dish = $dish
                    Allergener = $allergener
                }
            }
        }
    }

    Write-Verbose "Finished parsing menu";

    # Convert the flat menu to a object groupped by the name of the weekday
    $Collection = $FlatMenu | Group-Object -Property Day
    foreach ($Group in $Collection) {
        $Menu += [PSCustomObject]@{
            Day = $Group.Name
            DayIndex = $DayNameIndex.$($Group.Name)
            Menu = $Group.Group | select Type, Dish, Allergener;
        }
    }

    Write-Verbose "Finished grouping menu by day";

    return [PSCustomObject]@{
        Weeknumber = $WeekNumber
        Menu = $Menu
        Timestamp = Get-Date
    }

}

function Get-LunchAssets {
    
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [string] $Language = "da",
        [Parameter(Mandatory=$false)]
        [int] $LocationID = 42,
        [Parameter(Mandatory=$false)]
        [int[]] $Stations = (5,6,7),
        [Parameter(Mandatory=$false)]
        [string] $uri = "https://www.guckenheimer.dk/banner/menu-of-the-day/station"
    )

    $result = @();

    foreach ($Station in $Stations) {
        
        $FullUri = "$uri/$Station/$LocationID/$Language";

        Write-Verbose "Getting assets from $FullUri"

        $R = Invoke-WebRequest -Uri $FullUri
        if (!($R)) {throw "No response from LunchProvider"}
        $HTML = $R.ParsedHtml;

        if (($Dishes = $HTML.GetElementsByClassName("normal-image")) -ne $null) {
            foreach ($Dish in $Dishes) {
                $result += [PSCustomObject]@{
                    Timestamp = Get-Date
                    Dish = $Dish.GetElementsByClassName("title")[0].innerText
                    href = $Dish.GetElementsByClassName("station-plate-image")[0].Children[0].href
                }
            }
        } else {
            $result += [PSCustomObject]@{
                Timestamp = Get-Date
                Dish = $HTML.GetElementsByClassName("heading")[0].innerText
                href = $HTML.GetElementsByClassName("station-plate-image")[0].Children[0].href
            }
        }
    }
    return $result;

}