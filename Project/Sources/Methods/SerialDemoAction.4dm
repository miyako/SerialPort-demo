//%attributes = {"invisible":true}
/*  One entry point for every button in the window.

    The form has no per object methods: it subscribes to On Clicked and passes
    the clicked object name here, so the demo's behaviour is readable in one
    place instead of being scattered over twenty three-line methods.
*/
#DECLARE($action : Text)

var $worker; $target : Text
var $payload; $config; $result; $request : Object
var $bytes : Blob
var $script : 4D.File
var $root; $chunk; $raw : Text
var $index : Integer

$worker:="SerialDemoOwner"

Case of
	: ($action="start")
		$target:="macOS-universal"
		If (Is Windows)
			$target:="Windows-x64"
		End if
		SerialDemoAppend("state"; "ui"; "start requested for "+$target)
		$payload:=New object("target"; $target)
		CALL WORKER($worker; "SerialDemoWorker"; "start"; $payload)

	: ($action="list")
		CALL WORKER($worker; "SerialDemoWorker"; "list"; New object)

	: ($action="open")
		If (Form.pathInput="")
			SerialDemoAppend("warn"; "ui"; "no device path: start the virtual device first")
		Else
			$config:=SerialDemoConfig
			$request:=New object("path"; Form.pathInput; "config"; $config)
			CALL WORKER($worker; "SerialDemoWorker"; "open"; $request)
		End if

	: ($action="close")
		If (Form.connection="")
			SerialDemoAppend("warn"; "ui"; "no connection to close")
		Else
			CALL WORKER($worker; "SerialDemoWorker"; "close"; New object("connection"; Form.connection))
		End if

	: ($action="send")
		SerialDemoSend(Form.sendText; False)

	: ($action="sendhex")
		SerialDemoSend(Form.sendText; True)

	: ($action="ping")
		SerialDemoSend("PING"; False)

	: ($action="read")
		SerialDemoSend("READ"; False)

	: ($action="kanji")
		SerialDemoSend("KANJI"; False)

	: ($action="bin")
		SerialDemoSend("BIN"; False)

	: ($action="stream")
		SerialDemoSend("STREAM"; False)

	: ($action="stall")
		SerialDemoSend("STALL"; False)

	: ($action="shutdown")
		CALL WORKER($worker; "SerialDemoWorker"; "shutdown"; New object)

	: ($action="terminate")
		CALL WORKER($worker; "SerialDemoWorker"; "terminate"; New object)

	: ($action="forget")
		CALL WORKER($worker; "SerialDemoWorker"; "forget"; New object)

	: ($action="failMissing")
		// Failure showcase: the CLI must report the error without killing the
		// session, which is what the next real request proves.
		$request:=New object("path"; "/dev/serial-demo-missing"; "config"; SerialDemoConfig)
		CALL WORKER($worker; "SerialDemoWorker"; "open"; $request)

	: ($action="failConnection")
		$raw:="X"
		CONVERT FROM TEXT($raw; "ISO-8859-1"; $bytes)
		$request:=New object("connection"; "connection-99"; "bytes"; $bytes; "timeoutMs"; 1000)
		CALL WORKER($worker; "SerialDemoWorker"; "write"; $request)

	: ($action="failBaud")
		$config:=SerialDemoConfig
		$config.baudRate:=0
		$request:=New object("connection"; Form.connection; "config"; $config)
		CALL WORKER($worker; "SerialDemoWorker"; "configure"; $request)

	: ($action="failOversize")
		// 40000 bytes exceeds the component's decoded write limit of 32768.
		$chunk:=""
		For ($index; 1; 40)
			$chunk+="0123456789"
		End for
		$raw:=""
		For ($index; 1; 100)
			$raw+=$chunk
		End for
		CONVERT FROM TEXT($raw; "ISO-8859-1"; $bytes)
		$request:=New object("connection"; Form.connection; "bytes"; $bytes; "timeoutMs"; 1000)
		CALL WORKER($worker; "SerialDemoWorker"; "write"; $request)

	: ($action="failCancel")
		CALL WORKER($worker; "SerialDemoWorker"; "cancel"; New object("requestId"; "request-99"))

	: ($action="deviceStart")
		// Database folder is an HFS path on macOS, so join its children with
		// colons rather than slashes. The simulator needs a POSIX pseudo terminal,
		// which Windows does not offer.
		$root:=Get 4D folder(Database folder)
		$script:=File($root+"tools:virtual-serial:virtual_serial.py"; fk platform path)
		SerialDemoAppend("info"; "device"; "script exists="+String($script.exists))
		If (Not(OB Instance of(Form.device; cs.VirtualSerialDevice)))
			Form.device:=cs.VirtualSerialDevice.new()
		End if
		If (Is Windows)
			$result:=New object("ok"; False; "error"; New object("code"; "unsupported"; "message"; "The virtual device needs a POSIX pseudo terminal; point the path at a COM port instead"))
		Else
			$result:=Form.device.start($script)
		End if
		If ($result.ok)
			// The path arrives asynchronously: the form timer mirrors the
			// device as soon as it announces its PTY, and Open then uses it.
			// Waiting here would block the very callback that carries it.
			SerialDemoDeviceChanged
			SerialDemoAppend("info"; "device"; "waiting for the virtual device to announce its path")
		Else
			Form.errorText:=JSON Stringify($result.error; *)
			SerialDemoAppend("error"; "device"; String($result.error.message))
			SerialDemoDeviceChanged
		End if

	: ($action="deviceStop")
		If (OB Instance of(Form.device; cs.VirtualSerialDevice))
			$result:=Form.device.stop()
		End if
		SerialDemoDeviceChanged

	: ($action="quit")
		// The helper process outlives the window unless it is stopped here.
		If (OB Instance of(Form.device; cs.VirtualSerialDevice))
			$result:=Form.device.stop()
		End if
		QUIT 4D

	Else
		SerialDemoAppend("warn"; "ui"; "unhandled action: "+$action)
End case

SerialDemoRefresh
