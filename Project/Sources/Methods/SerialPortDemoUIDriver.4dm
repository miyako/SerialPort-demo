//%attributes = {"invisible":true}
/*  Drive the demo window through its own button actions.

    The driver is a separate worker, so the window process stays free to deliver
    SystemWorker callbacks and to run its own form method: nothing here blocks
    the UI. Every action named below is the same one the form dispatches on a
    real click.

    Each step waits for observed state (the window model and the session's
    published document), never for a fixed delay: an unattended macOS
    application stretches both the form timer and background processes, so a
    tick-based schedule would race on a busy machine and crawl on an idle one.
*/
#DECLARE($window : Integer; $statusPath : Text; $reportPath : Text)

var $report; $status; $entry; $probe : Object
var $statusFile; $reportFile; $dumpFile; $probeFile : 4D.File
var $guard; $replies; $errors; $chunks : Integer
var $midDumpPath; $endDumpPath; $traceFile; $probePath : Text

$traceFile:=$reportPath+".trace.txt"
<>SERIAL_TRACE:=$traceFile
ON ERR CALL("SerialPortDemoTraceError"; ek local)

$statusFile:=File($statusPath; fk posix path)
$reportFile:=File($reportPath; fk posix path)
$midDumpPath:=$reportPath+".mid.json"
$endDumpPath:=$reportPath+".end.json"
$probePath:=$reportPath+".probe.json"
$probeFile:=File($probePath; fk posix path)
$dumpFile:=File($endDumpPath; fk posix path)

// A probe left by an earlier run still names that run's PTY. Waiting for the
// path with it in place returns at once, and "open" is dispatched before the
// device of this run has announced anything.
If ($probeFile.exists)
	$probeFile.delete()
End if

$report:=New object("finished"; False; "success"; True; "phase"; "driving"; "cases"; New collection; "trace"; New collection)
SerialPortDemoTrace("driver started")

// Every action is dispatched as the form would dispatch it on a click.
SerialPortDemoUIDrive($window; "deviceStart"; $report; $reportFile)
SerialPortDemoTrace("dispatched deviceStart")

// The PTY helper announces its slave path asynchronously and the window mirrors
// that announcement, so open exactly the path the window offers.
$probe:=New object
$guard:=0
While (($guard<900) & (String($probe.boundPath)=""))
	CALL FORM($window; Formula(SerialPortDemoUIDump($1)); $probePath)
	DELAY PROCESS(Current process; 6)
	$guard:=$guard+6
	$probe:=New object
	If ($probeFile.exists)
		$probe:=JSON Parse($probeFile.getText())
		If (Value type($probe)#Is object)
			$probe:=New object
		End if
	End if
End while
SerialPortDemoTrace("device path after "+String($guard)+" tick(s): "+String($probe.boundPath))

SerialPortDemoUIDrive($window; "start"; $report; $reportFile)
$status:=SerialDemoUIWait($window; $statusFile; "phase"; "running"; 0; 300)
SerialPortDemoTrace("phase="+String($status.phase))

SerialPortDemoUIDrive($window; "list"; $report; $reportFile)
$status:=SerialDemoUIWait($window; $statusFile; "ports"; ""; 1; 300)
SerialPortDemoTrace("ports="+String($status.ports.length))

SerialPortDemoUIDrive($window; "open"; $report; $reportFile)
$status:=SerialDemoUIWait($window; $statusFile; "connections"; ""; 1; 300)
SerialPortDemoTrace("connections="+String($status.connections.length))

SerialPortDemoUIDrive($window; "ping"; $report; $reportFile)
$status:=SerialDemoUIWait($window; $statusFile; "chunks"; ""; 1; 300)
SerialPortDemoTrace("chunks after ping="+String($status.stats.chunks))

SerialPortDemoUIDrive($window; "kanji"; $report; $reportFile)
$status:=SerialDemoUIWait($window; $statusFile; "chunks"; ""; 2; 300)
SerialPortDemoTrace("chunks after kanji="+String($status.stats.chunks))

SerialPortDemoUIDrive($window; "stream"; $report; $reportFile)
$status:=SerialDemoUIWait($window; $statusFile; "chunks"; ""; 3; 300)
SerialPortDemoTrace("chunks after stream="+String($status.stats.chunks))

// A mid run dump shows what the window holds while the session is live.
CALL FORM($window; Formula(SerialPortDemoUIDump($1)); $midDumpPath)

// The failure showcase: a missing device, an oversized write, an invalid rate.
SerialPortDemoUIDrive($window; "stall"; $report; $reportFile)
SerialPortDemoUIDrive($window; "failMissing"; $report; $reportFile)
$status:=SerialDemoUIWait($window; $statusFile; "errors"; ""; 1; 300)
SerialPortDemoTrace("errors after failMissing="+String($status.stats.errors))

SerialPortDemoUIDrive($window; "failOversize"; $report; $reportFile)
$status:=SerialDemoUIWait($window; $statusFile; "errors"; ""; 2; 300)
SerialPortDemoTrace("errors after failOversize="+String($status.stats.errors))

SerialPortDemoUIDrive($window; "failBaud"; $report; $reportFile)
$status:=SerialDemoUIWait($window; $statusFile; "errors"; ""; 3; 300)
SerialPortDemoTrace("errors after failBaud="+String($status.stats.errors))

SerialPortDemoUIDrive($window; "close"; $report; $reportFile)
$status:=SerialDemoUIWait($window; $statusFile; "connections"; ""; 0; 300)
SerialPortDemoTrace("connections after close="+String($status.connections.length))

SerialPortDemoUIDrive($window; "shutdown"; $report; $reportFile)
SerialPortDemoTrace("script finished")

// The session document is the authority on the session's end.
$status:=SerialDemoUIWait($window; $statusFile; "phase"; "shutdown"; 0; 200)
SerialPortDemoTrace("status phase="+String($status.phase))
// The component reports the session's end two ways: the shutdown request we
// made, then the terminal state the facade publishes.
SerialPortDemoTestCheck($report; "the window session reached phase shutdown"; (String($status.phase)="shutdown") | (String($status.phase)="terminated"); String($status.phase))

$replies:=0
$errors:=0
$chunks:=0
If (Value type($status.stats)=Is object)
	$replies:=$status.stats.replies
	$errors:=$status.stats.errors
	$chunks:=$status.stats.chunks
End if
SerialPortDemoTestCheck($report; "replies were received"; $replies>=4; $replies)
SerialPortDemoTestCheck($report; "chunks were decoded"; $chunks>=3; $chunks)
SerialPortDemoTestCheck($report; "errors were observed"; $errors>=3; $errors)
SerialPortDemoTestCheck($report; "the streamed text reached the session model"; Position("PONG"; String($status.text); *)>0; String($status.text))

// The form holds its own copy of the model and catches up on its own timer, so
// the dump has to be requested after the window has polled the ended session;
// otherwise the assertions would describe the state before shutdown.
$entry:=New object
var $rounds : Integer
$rounds:=0
Repeat 
	If ($dumpFile.exists)
		$dumpFile.delete()
	End if 
	CALL FORM($window; Formula(SerialDemoPump))
	CALL FORM($window; Formula(SerialPortDemoUIDump($1)); $endDumpPath)
	$guard:=0
	While ((Not($dumpFile.exists)) & ($guard<90))
		DELAY PROCESS(Current process; 3)
		$guard:=$guard+3
	End while 
	$entry:=New object
	If ($dumpFile.exists)
		$entry:=JSON Parse($dumpFile.getText())
		If (Value type($entry)#Is object)
			$entry:=New object
		End if 
	End if 
	$rounds:=$rounds+1
Until (($rounds>=10) | (($entry.phase="shutdown") | ($entry.phase="terminated") | ($entry.phase="idle")))
SerialPortDemoTrace("window phase="+String($entry.phase)+" after "+String($rounds)+" round(s)")
SerialPortDemoTestCheck($report; "the window published its model"; OB Keys($entry).length>0; $endDumpPath)
SerialPortDemoTestCheck($report; "the window decoded the PONG reply"; Position("PONG"; String($entry.rx); *)>0; String($entry.rx))
SerialPortDemoTestCheck($report; "the window holds decoded chunks"; SerialDemoIsNumber($entry.chunks) & (Num($entry.chunks)>=1); String($entry.chunks))
SerialPortDemoTestCheck($report; "the window logged the run"; SerialDemoIsNumber($entry.logLines) & (Num($entry.logLines)>=6); String($entry.logLines))
SerialPortDemoTestCheck($report; "the window shows a shutdown phase"; (String($entry.phase)="shutdown") | (String($entry.phase)="terminated") | (String($entry.phase)="idle"); String($entry.phase))
SerialPortDemoTestCheck($report; "the window reports the failure showcase"; String($entry.errorHeadline)#""; String($entry.errorHeadline))

$report.phase:="done"
$report.finished:=True
SerialPortDemoWriteReport($reportFile; $report)
SerialPortDemoTrace("driver finished; success="+String($report.success))

// Quitting does not necessarily unload the form, and an unreleased SystemWorker
// leaves its simulator running: stop the device explicitly.
SerialPortDemoUIDrive($window; "deviceStop"; $report; $reportFile)
DELAY PROCESS(Current process; 30)

If ($report.success)
	QUIT 4D(0)
Else
	QUIT 4D(1)
End if
