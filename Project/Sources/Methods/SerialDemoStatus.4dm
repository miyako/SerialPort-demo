//%attributes = {"invisible":true}
/*  Publish the worker-side session state.

    The UI never receives the session object, only this document, so a stuck or
    terminated session cannot block the form's process. The document also
    carries the numbered messages the UI has not applied yet.
*/
#DECLARE()

var SERIAL_StatusFile : 4D.File
var $status : Object

If (OB Keys(SERIAL_State).length=0)
	return
End if

$status:=New object
$status.phase:=SERIAL_State.phase
$status.target:=SERIAL_State.target
$status.startedAt:=SERIAL_State.startedAt
$status.pending:=OB Keys(SERIAL_State.pending).length
$status.connections:=OB Keys(SERIAL_State.connections)
$status.ports:=SERIAL_State.ports.copy()
$status.text:=SERIAL_State.text
$status.stats:=OB Copy(SERIAL_State.stats)
$status.lastExit:=SERIAL_State.lastExit
$status.seq:=SERIAL_State.seq
$status.outbox:=SERIAL_State.outbox.copy()

If (SERIAL_StatusFile#Null)
	// Best effort: a failing observer file must never break the session.
	SERIAL_StatusFile.setText(JSON Stringify($status))
End if
