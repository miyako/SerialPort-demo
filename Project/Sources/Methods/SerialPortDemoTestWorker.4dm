//%attributes = {"invisible":true}
/*  Headless end-to-end script, executed in its own worker process.

    It drives the demo's owner worker through the same commands the window uses
    and observes the session through the status file, so the test exercises the
    real message path rather than a test-only shortcut.
*/
#DECLARE($report : Object; $port : Text; $statusPath : Text; $reportPath : Text)

var SERIAL_TestSession : Text

var $statusFile : 4D.File
var $status; $config; $detail : Object
var $bytes : Blob
var $bigText; $line : Text
var $connection : Text
var $ok : Boolean
var $chunks; $chunksBefore; $errors; $index : Integer

SERIAL_TestSession:="SerialDemoOwner"
$statusFile:=File($statusPath; fk posix path)

$config:=New object
$config.baudRate:=9600
$config.dataBits:=8
$config.stopBits:="one"
$config.parity:="none"
$config.flowControl:="none"

/*  Session start ----------------------------------------------------------- */
$report.phase:="start session"
CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "statusfile"; New object("path"; $statusPath))
$status:=SerialPortDemoTestAwait($statusFile; ""; 0; 0; 0; ""; 30)
CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "start"; New object("target"; "macOS-universal"))
$status:=SerialPortDemoTestAwait($statusFile; "running"; 1; 0; 0; ""; 300)
$ok:=((String($status.phase)="running") & (Num($status.stats.replies)>=1))
$detail:=New object
$detail.phase:=$status.phase
$detail.replies:=$status.stats.replies
$detail.ports:=$status.ports.length
SerialPortDemoTestCheck($report; "session starts and answers list"; $ok; $detail)

/*  Open the virtual port --------------------------------------------------- */
$report.phase:="open"
CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "open"; New object("path"; $port; "config"; $config))
$status:=SerialPortDemoTestAwait($statusFile; ""; 2; 0; 0; ""; 300)
$connection:=""
If (Value type($status.connections)=Is collection)
	If ($status.connections.length>0)
		$connection:=String($status.connections[0])
	End if
End if
$report.connection:=$connection
$report.port:=$port
$detail:=New object
$detail.connection:=$connection
$detail.errors:=$status.stats.errors
SerialPortDemoTestCheck($report; "open returns a connection id"; ($connection#""); $detail)

/*  Text round trip --------------------------------------------------------- */
$report.phase:="write text"
CONVERT FROM TEXT("PING"+Char(13)+Char(10); "UTF-8"; $bytes)
CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "write"; New object("connection"; $connection; "bytes"; $bytes; "timeoutMs"; 3000))
$status:=SerialPortDemoTestAwait($statusFile; ""; 0; 0; 0; "PONG"; 200)
$detail:=New object
$detail.text:=$status.text
$detail.received:=$status.stats.received
$detail.sent:=$status.stats.sent
SerialPortDemoTestCheck($report; "device answers PING"; (Position("PONG"; String($status.text); *)>0); $detail)

/*  Multibyte round trip ---------------------------------------------------- */
$report.phase:="write kanji"
CONVERT FROM TEXT("KANJI"+Char(13)+Char(10); "UTF-8"; $bytes)
CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "write"; New object("connection"; $connection; "bytes"; $bytes; "timeoutMs"; 3000))
$status:=SerialPortDemoTestAwait($statusFile; ""; 0; 0; 0; "温度"; 200)
$detail:=New object
$detail.text:=Substring(String($status.text); 1; 80)
$detail.received:=$status.stats.received
SerialPortDemoTestCheck($report; "multibyte answer survives chunk boundaries"; (Position("温度"; String($status.text); *)>0); $detail)

/*  Binary payload ---------------------------------------------------------- */
$report.phase:="write binary"
$chunksBefore:=Num($status.stats.chunks)
CONVERT FROM TEXT("BIN"+Char(13)+Char(10); "UTF-8"; $bytes)
CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "write"; New object("connection"; $connection; "bytes"; $bytes; "timeoutMs"; 3000))
$status:=SerialPortDemoTestAwait($statusFile; ""; 0; 0; $chunksBefore+1; ""; 200)
$detail:=New object
$detail.received:=$status.stats.received
$detail.chunks:=$status.stats.chunks
SerialPortDemoTestCheck($report; "binary payload is delivered byte for byte"; (Num($status.stats.received)>=8); $detail)

/*  Streaming --------------------------------------------------------------- */
$report.phase:="stream"
$chunks:=Num($status.stats.chunks)
$chunksBefore:=$chunks
CONVERT FROM TEXT("STREAM"+Char(13)+Char(10); "UTF-8"; $bytes)
CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "write"; New object("connection"; $connection; "bytes"; $bytes; "timeoutMs"; 3000))
$status:=SerialPortDemoTestAwait($statusFile; ""; 0; 0; $chunks+3; ""; 120)
$detail:=New object
$detail.chunksBefore:=$chunks
$detail.chunksAfter:=$status.stats.chunks
SerialPortDemoTestCheck($report; "streaming arrives as several chunks"; (Num($status.stats.chunks)>=($chunks+2)); $detail)

/*  Failure injection ------------------------------------------------------- */
$report.phase:="failures"
$errors:=Num($status.stats.errors)

CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "open"; New object("path"; "/dev/definitely-not-a-port"; "config"; $config))
$status:=SerialPortDemoTestAwait($statusFile; ""; 0; $errors+1; 0; ""; 200)
$detail:=New object("errors"; $status.stats.errors)
SerialPortDemoTestCheck($report; "opening a missing path reports an error"; (Num($status.stats.errors)>$errors); $detail)
$errors:=Num($status.stats.errors)

CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "write"; New object("connection"; "connection-99"; "bytes"; $bytes; "timeoutMs"; 1000))
$status:=SerialPortDemoTestAwait($statusFile; ""; 0; $errors+1; 0; ""; 200)
$detail:=New object("errors"; $status.stats.errors)
SerialPortDemoTestCheck($report; "writing to an unknown connection is rejected"; (Num($status.stats.errors)>$errors); $detail)
$errors:=Num($status.stats.errors)

CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "configure"; New object("connection"; $connection; "config"; New object("baudRate"; 0)))
$status:=SerialPortDemoTestAwait($statusFile; ""; 0; $errors+1; 0; ""; 200)
$detail:=New object("errors"; $status.stats.errors)
SerialPortDemoTestCheck($report; "an out-of-range baud rate is rejected"; (Num($status.stats.errors)>$errors); $detail)
$errors:=Num($status.stats.errors)

// 40000 ASCII characters exceed the 32768-byte decoded write limit.
$line:="0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"
$bigText:=""
For ($index; 1; 400)
	$bigText+=$line
End for
CONVERT FROM TEXT($bigText; "UTF-8"; $bytes)
CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "write"; New object("connection"; $connection; "bytes"; $bytes; "timeoutMs"; 1000))
$status:=SerialPortDemoTestAwait($statusFile; ""; 0; $errors+1; 0; ""; 200)
$detail:=New object
$detail.bytes:=BLOB size($bytes)
$detail.errors:=$status.stats.errors
SerialPortDemoTestCheck($report; "writes above 32768 bytes are rejected"; (Num($status.stats.errors)>$errors); $detail)
$errors:=Num($status.stats.errors)

CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "cancel"; New object("requestId"; "request-99"))
$status:=SerialPortDemoTestAwait($statusFile; ""; 0; $errors+1; 0; ""; 200)
$detail:=New object("errors"; $status.stats.errors)
SerialPortDemoTestCheck($report; "cancelling an unknown request is rejected"; (Num($status.stats.errors)>$errors); $detail)

/*  Close and shut down ----------------------------------------------------- */
$report.phase:="shutdown"
CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "close"; New object("connection"; $connection))
$status:=SerialPortDemoTestAwait($statusFile; ""; 0; $errors+1; 0; ""; 200)
CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "shutdown"; New object)
$status:=SerialPortDemoTestAwait($statusFile; "terminated"; 0; 0; 0; ""; 400)
$report.exitCode:=-1
If (Value type($status.lastExit)=Is object)
	$report.exitCode:=Num($status.lastExit.exitCode)
End if
$report.finalPhase:=$status.phase
$report.finalStats:=$status.stats
$detail:=New object
$detail.phase:=$status.phase
$detail.exitCode:=$report.exitCode
SerialPortDemoTestCheck($report; "shutdown terminates the session cleanly"; ((String($status.phase)="terminated") & ($report.exitCode=0)); $detail)

/*  Restart ------------------------------------------------------------------
    A session that has ended must not block the next one: "start" used to be
    refused with session_exists until the worker was restarted. */
$report.phase:="restart"
CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "start"; New object("target"; "macOS-universal"))
$status:=SerialPortDemoTestAwait($statusFile; "running"; 0; 0; 0; ""; 300)
$detail:=New object("phase"; $status.phase)
SerialPortDemoTestCheck($report; "a session can be started again after shutdown"; (String($status.phase)="running"); $detail)
CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "shutdown"; New object)
$status:=SerialPortDemoTestAwait($statusFile; "terminated"; 0; 0; 0; ""; 400)

$report.finished:=True
$report.finishedAt:=Timestamp
File($reportPath; fk posix path).setText(JSON Stringify($report))

CALL WORKER(SERIAL_TestSession; "SerialDemoWorker"; "forget"; New object)
If ($report.success)
	QUIT 4D 0
Else
	QUIT 4D 1
End if
