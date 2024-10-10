$Sources = @(
    @{
        Source="C:\Users\admin_tosi\Documents\GitHub\LunchMenu\guckenheimer\Modules\LogUtil"
        Destination="C:\Program Files\WindowsPowerShell\Modules\LogUtil"
    },
    @{
        Source="C:\Users\admin_tosi\Documents\GitHub\LunchMenu\guckenheimer\Modules\LunchProvider"
        Destination="C:\Program Files\WindowsPowerShell\Modules\LunchProvider"
    },
    @{
        Source="C:\Users\admin_tosi\Documents\GitHub\LunchMenu\guckenheimer\Scripts"
        Destination="C:\TS\Scripts"
    }
)

foreach ($Source in $Sources) {

    if (!(Test-Path -Path $Source.Source)) {throw "Expected to find $Source."}

    $ChildItem = Get-ChildItem -Path $Source.Source;
    if ($ChildItem) {
        $ChildItem | Copy-Item -Destination $Source.Destination -Force -Verbose;
    } else {
        throw "No ChildItems found in $Source";
    }

}