$SrcDir =  "C:\Users\admin_tosi\Documents\GitHub\LunchMenu\api\api";
$DstDir = "D:\VirtualSites\LunchAPI\v2\2.0.0"
&robocopy `"$SrcDir`" `"$DstDir`" /MIR /XF `".*`"
pushd $DstDir;

&composer install
&php artisan config:cache
&php artisan migrate
popd