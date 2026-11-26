/*  Owns the PTY-backed virtual serial device used by the demo.

    No serial hardware is attached to the machine running this project, so the
    demo drives a Python script that owns a pseudo terminal pair and publishes
    the slave path. This class launches that script through a SystemWorker,
    reads its announcement and keeps a short transcript for the UI.

    The simulator is not part of the SerialPort component: the component only
    ever sees an ordinary device path.
*/

property worker : 4D.SystemWorker
property port : Text
property state : Text
property buffer : Text
property transcript : Collection
property errorText : Text
property onChange : Object
property failed : Boolean
property dataType : Text
property encoding : Text
property hideWindow : Boolean
property timeout : Integer

Class constructor()
	This.worker:=Null
	This.port:=""
	This.state:="stopped"
	This.buffer:=""
	This.transcript:=[]
	This.errorText:=""
	This.onChange:=Null
	This.failed:=False
	This.dataType:="text"
	This.encoding:="UTF-8"
	This.hideWindow:=True
	This.timeout:=86400

/*  Quote one argument for the SystemWorker command line. SystemWorker does not
    run a shell, so this is not shell escaping: it only satisfies the process
    argument parser.
*/
Function quote($argument : Text)->$quoted : Text
	var $index : Integer
	var $character : Text
	$quoted:="\""
	For ($index; 1; Length($argument))
		$character:=Substring($argument; $index; 1)
		If (($character="\\") | ($character="\""))
			$quoted+="\\"
		End if
		$quoted+=$character
	End for
	$quoted+="\""

Function start($script : 4D.File)->$result : Object
	var $command; $path : Text
	var $previous : Text
	// A failed or exited device is as good as stopped: it can be started again.
	If ((This.state#"stopped") & (This.state#"failed"))
		return New object("ok"; False; "error"; New object("code"; "already_running"; "message"; "The virtual device is already running"))
	End if
	If (Not($script.exists))
		return New object("ok"; False; "error"; New object("code"; "missing_script"; "message"; "Virtual device script not found: "+$script.platformPath))
	End if
	// SystemWorker hands this Text straight to the process, without a shell, so
	// macOS needs the POSIX form: a File built from an HFS string keeps an HFS
	// platformPath.
	If (Is Windows)
		$path:=$script.platformPath
	Else
		$path:=Convert path system to POSIX($script.platformPath)
	End if
	$command:=This.quote($path)
	$previous:=Method called on error(ek local)
	ON ERR CALL("SerialDemoError"; ek local)
	This.worker:=4D.SystemWorker.new("/usr/bin/env python3 "+$command; This)
	ON ERR CALL($previous; ek local)
	If (This.worker=Null)
		This.state:="failed"
		This.errorText:=This.lastErrorText()
		return New object("ok"; False; "error"; New object("code"; "launch_failed"; "message"; This.errorText))
	End if
	This.state:="starting"
	This.transcript:=[]
	return New object("ok"; True; "state"; This.state)

/*  Text of the failure that just happened. "Error description" is not a 4D
    command; the message is in Last errors.
*/
Function lastErrorText()->$text : Text
	$text:=""
	If (Last errors#Null)
		If (Last errors.length>0)
			$text:=String(Last errors[0].errCode)+" "+String(Last errors[0].message)
		End if
	End if

/*  SystemWorker callbacks. They run in the process that created the worker,
    after that process returns to its event loop.
*/
Function onData($worker : Object; $info : Object)
	var $line : Text
	var $cut : Integer
	If (Value type($info.data)#Is text)
		This.transcript.push("non-text output ignored")
		return
	End if
	This.buffer+=Replace string($info.data; Char(13); "")
	$cut:=Position(Char(10); This.buffer)
	While ($cut>0)
		$line:=Substring(This.buffer; 1; $cut-1)
		This.buffer:=Substring(This.buffer; $cut+1)
		This.receive($line)
		$cut:=Position(Char(10); This.buffer)
	End while

Function onResponse($worker : Object; $info : Object)
	// Not used: the simulator writes diagnostics to stderr only.

/*  The helper process ended without stop() having been called (it crashed, or
    was killed). Without this the window keeps offering a device path that
    nobody serves. A worker that stop() already released no longer matches
    This.worker, so a late callback cannot clobber a device started since.
*/
Function onTerminate($worker : Object; $info : Object)
	If (This.worker=Null)
		return
	End if
	If ($worker.pid#This.worker.pid)
		return
	End if
	This.worker:=Null
	This.state:="stopped"
	This.port:=""
	This.transcript.push("device process exited")

Function receive($line : Text)
	If ($line="")
		return
	End if
	If ($line="PORT=")
		return
	End if
	If (Substring($line; 1; 5)="PORT=")
		This.port:=Substring($line; 6)
		This.state:="ready"
		This.transcript.push("device ready on "+This.port)
		return
	End if
	This.transcript.push($line)
	While (This.transcript.length>60)
		This.transcript.shift()
	End while

/*  Sending a line to stdin is the simulator's console, not the serial line.
    The demo does not need it, but it makes the device scriptable.
*/
Function sendCommand($command : Text)->$ok : Boolean
	$ok:=False
	If ((This.worker#Null) & (This.state#"stopped"))
		This.worker.postMessage($command+Char(10))
		$ok:=True
	End if

Function stop()->$result : Object
	If (This.worker#Null)
		This.worker.terminate()
		This.worker:=Null
	End if
	This.state:="stopped"
	This.port:=""
	$result:=New object("ok"; True)


Function snapshot()->$snapshot : Object
	$snapshot:=New object
	$snapshot.state:=This.state
	$snapshot.port:=This.port
	$snapshot.transcript:=This.transcript.copy()
	$snapshot.error:=This.errorText
