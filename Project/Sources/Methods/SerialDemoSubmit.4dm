//%attributes = {"invisible":true}
/*  Submit one component request from the owner worker.

    Every queued component method returns {ok:true;id} meaning "accepted for
    submission", never "completed". The id is remembered here so the later
    callback in SerialDemoEvent can be matched to the operation that caused it.
*/
#DECLARE($operation : Text; $request : Object)

var SERIAL_Session : cs.Serial.SerialPort
var SERIAL_State : Object
var $result : Object
var $size : Integer

If (SERIAL_Session=Null)
	SerialDemoNotify(New object("kind"; "error"; "operation"; $operation; "error"; New object("code"; "session_closed"; "message"; "No live session; start one first")))
	return
End if

$size:=0
Case of
	: ($operation="list")
		$result:=SERIAL_Session.list()
	: ($operation="open")
		$result:=SERIAL_Session.open($request.path; $request.config)
	: ($operation="configure")
		$result:=SERIAL_Session.configure($request.connection; $request.config)
	: ($operation="write")
		var $bytes : Blob
		$bytes:=$request.bytes
		$size:=BLOB size($bytes)
		$result:=SERIAL_Session.write($request.connection; $bytes; $request.timeoutMs)
	: ($operation="close")
		$result:=SERIAL_Session.close($request.connection)
	: ($operation="cancel")
		$result:=SERIAL_Session.cancel($request.requestId)
	: ($operation="shutdown")
		$result:=SERIAL_Session.shutdown()
		If ($result.ok)
			SERIAL_State.phase:="closing"
		End if
	Else
		SerialDemoNotify(New object("kind"; "error"; "operation"; $operation; "error"; New object("code"; "unknown_operation"; "message"; $operation)))
		return
End case

If ($result.ok)
	$entry:=New object
	$entry.operation:=$operation
	$entry.connection:=$request.connection
	$entry.size:=$size
	$entry.at:=Timestamp
	SERIAL_State.pending[$result.id]:=$entry
	SerialDemoNotify(New object("kind"; "submitted"; "operation"; $operation; "id"; $result.id; "connection"; $request.connection; "size"; $size; "pending"; OB Keys(SERIAL_State.pending).length))
Else
	// The component can reject a request without ever submitting it (for
	// example a write larger than the decoded payload limit).
	SERIAL_State.stats.errors+=1
	SerialDemoNotify(New object("kind"; "error"; "operation"; $operation; "connection"; $request.connection; "error"; $result.error))
	SerialDemoStatus
End if
