//%attributes = {"invisible":true}
/*  Apply one session message to the form model.

    Runs in the window's process, on the form timer, for messages the worker
    published and the window has not shown yet. Never blocks.
*/
#DECLARE($message : Object)

var $kind; $level; $source : Text
var $status; $chunk; $entry; $error; $row : Object
var $text; $description : Text


// Nothing to apply to until the form model exists.
If (Value type(Form.log)#Is collection)
	return
End if

If (Value type($message)#Is object)
	return
End if

$kind:=""
If (Value type($message.kind)=Is text)
	$kind:=$message.kind
End if

Case of
	: ($kind="status")
		$status:=$message.status
		If (String(Form.phase)#String($status.phase))
			SerialDemoAppend("state"; "session"; "phase "+String($status.phase))
		End if
		Form.status:=$status
		Form.phase:=$status.phase
		Form.stats:=$status.stats
		If ($status.phase="running")
			If (Form.running=False)
				Form.running:=True
				Form.startTime:=Current time
				Form.uptimeSeconds:=0
			End if
		Else
			Form.running:=False
		End if

	: ($kind="ports")
		Form.ports:=$message.ports
		SerialDemoAppend("info"; "ports"; String(Form.ports.length)+" port(s): "+SerialDemoPortNames($message.ports))

	: ($kind="submitted")
		Form.lastId:=$message.id
		Form.lastOperation:=$message.operation
		If (String($message.operation)="open")
			SerialDemoAppend("out"; "request"; $message.operation+" queued as "+String($message.id))
		Else
			SerialDemoAppend("out"; "request"; $message.operation+" queued as "+String($message.id)+" ("+String($message.size)+" B)")
		End if

	: ($kind="reply")
		$entry:=$message.result
		Case of
			: (String($message.operation)="open")
				Form.connection:=String($entry.connection)
				SerialDemoAppend("in"; "reply"; "open accepted → "+Form.connection)
			: (String($message.operation)="write")
				SerialDemoAppend("in"; "reply"; "write accepted → transferred "+String($entry.transferred)+" B")
			: (String($message.operation)="list")
				SerialDemoAppend("in"; "reply"; "list accepted → "+String(Form.ports.length)+" port(s)")
			Else
				SerialDemoAppend("in"; "reply"; String($message.operation)+" accepted")
		End case

	: ($kind="error")
		$error:=$message.error
		Form.lastError:=$error
		Form.errorText:=JSON Stringify($error; *)
		Form.errorHeadline:="error "+String($error.code)
		SerialDemoAppend("error"; "error"; String($error.code)+" — "+String($error.message))

	: ($kind="chunk")
		$chunk:=$message.decoded
		$row:=New object
		$row.at:=Time string(Current time)
		$row.direction:="in"
		$row.connection:=String($message.connection)
		$row.bytes:=$chunk.size
		$row.withheld:=$chunk.withheld
		$row.hex:=String($chunk.hex)
		$row.text:=String($chunk.text)
		Form.chunks.push($row)
		While (Form.chunks.length>400)
			Form.chunks.shift()
		End while
		If ($message.partial)
			SerialDemoAppend("warn"; "decoder"; "connection closed: "+String($chunk.size)+" withheld byte(s) released as a partial chunk")
		End if
		If (String($chunk.text)#"")
			Form.rx+=String($chunk.text)
			If (Length(Form.rx)>20000)
				Form.rx:=Substring(Form.rx; Length(Form.rx)-19999)
			End if
		End if

	: ($kind="event")
		$entry:=$message.event
		SerialDemoEventText($entry)

	Else
		SerialDemoAppend("warn"; "ui"; "unknown message kind: "+$kind)
End case

SerialDemoRefresh
