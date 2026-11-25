//%attributes = {"invisible":true}
/*  Headless end-to-end test entry point.

    tool4d has no argument channel for a project method, so the runner drops
    demo-test-input.json in the database folder:

      {"port": "/dev/ttysNNN", "status": "...", "report": "..."}

    and reads demo-test-report.json afterwards. See tools/run_smoke.py.

    Run with:
      tool4d --dataless --skip-onstartup
        --startup-method=SerialPortDemoTest
        --project=.../SerialPort-demo.4DProject
*/
#DECLARE()

var $root; $port; $statusPath; $reportPath : Text
var $report; $input : Object
var $inputFile; $reportFile; $statusFile : 4D.File
var $text : Text

$root:=Get 4D folder(Database folder)
$inputFile:=File($root+"demo-test-input.json"; fk platform path)
$reportFile:=File($root+"demo-test-report.json"; fk platform path)
$statusFile:=File($root+"demo-test-status.json"; fk platform path)

$report:=New object
$report.success:=True
$report.finished:=False
$report.phase:="boot"
$report.port:=""
$report.root:=$root
$report.cases:=New collection

If (Not($inputFile.exists))
	$report.success:=False
	$report.finished:=True
	$report.phase:="missing demo-test-input.json"
	$reportFile.setText(JSON Stringify($report))
	QUIT 4D 1
End if

$text:=$inputFile.getText()
ON ERR CALL("SerialDemoError"; ek local)
$input:=JSON Parse($text)
ON ERR CALL(""; ek local)
If (Value type($input)#Is object)
	$report.success:=False
	$report.finished:=True
	$report.phase:="unreadable demo-test-input.json"
	$reportFile.setText(JSON Stringify($report))
	QUIT 4D 1
End if

$port:=String($input.port)
$report.port:=$port
// The worker opens these with fk posix path, so convert: platformPath is an
// HFS path on macOS and File(colonPath; fk posix path) is rejected.
$statusPath:=Convert path system to POSIX($statusFile.platformPath)
$reportPath:=Convert path system to POSIX($reportFile.platformPath)

$report.statusPath:=$statusPath
$report.reportPath:=$reportPath

// A stale status file would satisfy the first wait before the session exists.
If ($statusFile.exists)
	$statusFile.delete()
End if

If ($port="")
	$report.success:=False
	$report.finished:=True
	$report.phase:="no port in demo-test-input.json"
	$reportFile.setText(JSON Stringify($report))
	QUIT 4D 1
End if

CALL WORKER("SerialPortDemoTest"; "SerialPortDemoTestWorker"; $report; $port; $statusPath; $reportPath)

// The session lives in a worker, so this process must stay alive for the
// component callbacks to arrive. It polls the report instead of sleeping a
// fixed time: the worker sets "finished" as its very last action.
var $waited; $limit : Integer
var $done : Boolean

var $check : Object
var $checkText : Text

$waited:=0
$limit:=600
Repeat
	DELAY PROCESS(Current process; 30)
	$waited+=1
	// The worker owns its own copy of the report object, so the finished flag
	// is observed through the report file rather than the shared reference.
	If ($reportFile.exists)
		$checkText:=$reportFile.getText()
		If ($checkText#"")
			ON ERR CALL("SerialDemoError"; ek local)
			$check:=JSON Parse($checkText)
			ON ERR CALL(""; ek local)
			If (Value type($check)=Is object)
				$done:=($check.finished=True)
			End if
		End if
	End if
Until ($done | ($waited>=$limit))

If ($done)
	$report:=$check
End if

If (Not($done))
	// The worker never finished: leave a diagnosable report behind.
	$report.success:=False
	$report.finished:=True
	$report.phase:="timeout"
	$reportFile.setText(JSON Stringify($report))
	QUIT 4D 1
End if

If ($report.success)
	QUIT 4D 0
End if
QUIT 4D 1
