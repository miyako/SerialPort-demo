//%attributes = {"invisible":true}
/*  Local error handler.

    Installed only around risky calls with ek local, and restored immediately,
    so a failure in one demo action is reported instead of stopping the worker.

    A handler receives no parameters, and "Error description" is not a 4D
    command (it compiles as an undeclared variable and stays empty): the text
    of the failure is the first entry of Last errors.
*/
#DECLARE()

var $entry; $last : Object

// A failure inside the handler must not call the handler again (4D answers with
// "Stack is full"). Form is not usable here either: outside a window it is an
// empty object, so the handler only reports and never writes form state.
ON ERR CALL(""; ek local)

$last:=New object("errCode"; 0; "message"; "")
If (Last errors#Null)
	If (Last errors.length>0)
		$last:=Last errors[0]
	End if
End if
$entry:=New object("code"; String($last.errCode); "message"; String($last.message); "method"; Error method; "line"; Error line)
// Visible in a headless run (tool4d writes this to its console).
LOG EVENT(Into system standard outputs; "4D error "+$entry.code+" in "+$entry.method+":"+String($entry.line)+" — "+$entry.message)
