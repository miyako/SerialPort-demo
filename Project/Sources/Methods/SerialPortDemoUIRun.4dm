//%attributes = {"invisible":true}
/*  Startup method of an automated interactive run.

    Opens the real window (so On Load, the timer and every CALL FORM message
    are exercised) and hands the window number to a driver worker, which then
    clicks the demo's own buttons programmatically.

    --user-param "<absolute status path>|<absolute report path>"
*/
#DECLARE()

var $userParam : Text
var $parts : Collection
var $statusPath; $reportPath : Text
var $window : Integer

$userParam:=""
Get database parameter(User param value; $userParam)
$parts:=Split string($userParam; "|")
If ($parts.length<2)
	LOG EVENT(Into system standard outputs; "SerialPortDemoUIRun: expected a status path and a report path")
	QUIT 4D 2
	return
End if
$statusPath:=$parts[0]
$reportPath:=$parts[1]
File($reportPath; fk posix path).setText("startup")

$window:=Open form window("Main")
If ($window=0)
	LOG EVENT(Into system standard outputs; "SerialPortDemoUIRun: the Main form could not be opened")
	QUIT 4D 3
	return
End if

// A non-blocking DIALOG keeps the window alive on its own event loop.
DIALOG("Main"; New object; *)

// The window reads this document; the owner writes it.
SERIAL_StatusPath:=$statusPath
CALL WORKER("SerialDemoOwner"; "SerialDemoWorker"; "statusfile"; New object("path"; $statusPath))
CALL WORKER("SerialPortDemoUIDriver"; "SerialPortDemoUIDriver"; $window; $statusPath; $reportPath)
