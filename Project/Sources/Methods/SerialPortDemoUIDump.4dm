//%attributes = {"invisible":true}
/*  Publish the window's own form model to a file.

    Runs inside the window process (CALL FORM), so it reports what the widgets
    are really bound to rather than a copy kept by the driver.
*/
#DECLARE($path : Text)

// Report the model as it is now, not as the last pump left it.
SerialDemoPump

var $dump; $entry : Object
var $line : Text
var $index; $last : Integer

$dump:=New object
$dump.phase:=String(Form.phase)
$dump.running:=Form.running
$dump.uptimeSeconds:=Form.uptimeSeconds
$dump.connection:=String(Form.connection)
$dump.rx:=Form.rx
$dump.chunks:=Form.chunks.length
$dump.logLines:=Form.log.length
$dump.ports:=Form.ports.length
$dump.lastOperation:=String(Form.lastOperation)
$dump.errorHeadline:=String(Form.errorHeadline)
$dump.statusText:=String(Form.statusText)
$dump.statsText:=String(Form.statsText)
$dump.chunkCountText:=String(Form.chunkCountText)
$dump.deviceState:=String(Form.deviceState)
$dump.devicePort:=String(Form.devicePort)
$dump.boundPath:=String(Form.pathInput)

$dump.deviceLines:=New collection
If (Value type(Form.deviceLines)=Is collection)
	For each ($entry; Form.deviceLines)
		If (Value type($entry.text)=Is text)
			$dump.deviceLines.push($entry.text)
		End if
	End for each
End if
$dump.deviceError:=""
If (OB Instance of(Form.device; cs.VirtualSerialDevice))
	$dump.deviceError:=String(Form.device.errorText)
End if

// The tail is written as plain lines so a person can read the report too.
$dump.tail:=New collection
If (Value type(Form.log)=Is collection)
	$last:=(Form.log.length)-1
	For ($index; 0; $last)
		$entry:=Form.log[$index]
		If (Value type($entry)=Is object)
			$line:=String($entry.at)+" "+String($entry.level)+" "+String($entry.source)+": "+String($entry.message)
			$dump.tail.push($line)
		End if
	End for
End if

File($path; fk posix path).setText(JSON Stringify($dump; *))
