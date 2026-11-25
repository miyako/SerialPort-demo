//%attributes = {"invisible":true}
/*  Mirror the session's published state into the form.

    Runs in the window's process on the form timer. The session owner writes
    the document; this method applies whatever is new. Polling is deliberate:
    a window in the background has its timer stretched by App Nap, so pushing
    updates into it would either stall or arrive out of order, while reading
    the last published state is always safe and idempotent.
*/
#DECLARE()

var $file : 4D.File
var $status; $message : Object
var $index : Integer
var $text : Text

If (SERIAL_StatusPath="")
	return 
End if 

$file:=File(SERIAL_StatusPath; fk posix path)
If (Not($file.exists))
	return 
End if 
$text:=$file.getText()
If ($text="")
	return 
End if 

ON ERR CALL("SerialDemoError"; ek local)
$status:=JSON Parse($text)
ON ERR CALL(""; ek local)
If (Value type($status)#Is object)
	return 
End if 

// The snapshot first: phase, counters and ports are always current.
Form.status:=$status
Form.phase:=String($status.phase)
If (Value type($status.stats)=Is object)
	Form.stats:=$status.stats
End if 
If (Value type($status.ports)=Is collection)
	Form.ports:=$status.ports
End if 
If (Value type($status.connections)=Is collection)
	Form.connections:=$status.connections
End if 
If (Value type($status.text)=Is text)
	Form.rx:=String($status.text)
End if 
If (Form.phase="running")
	If (Form.running=False)
		Form.running:=True
		Form.startTime:=Current time
		Form.uptimeSeconds:=0
	End if 
Else 
	Form.running:=False
End if 

// Then the messages this window has not applied yet, in publication order.
// A process-local variable starts as Null in the window's process, and a
// comparison against Null is never true, so the cursor is seeded first.
If (Not(SerialDemoIsNumber(SERIAL_AppliedSeq)))
	SERIAL_AppliedSeq:=0
End if 
If (Value type($status.outbox)=Is collection)
	For ($index; 0; $status.outbox.length-1)
		$message:=$status.outbox[$index]
		If (Value type($message)#Is object)
			continue
		End if 
		If (Not(SerialDemoIsNumber($message.seq)))
			continue
		End if 
		If (Num($message.seq)>SERIAL_AppliedSeq)
			SerialDemoUI($message)
			SERIAL_AppliedSeq:=Num($message.seq)
		End if 
	End for 
End if 
