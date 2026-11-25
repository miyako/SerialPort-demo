//%attributes = {"invisible":true}
/*  Local error handler.

    Installed only around risky calls with ek local, and restored immediately,
    so a failure in one demo action is reported instead of stopping the worker.
*/
#DECLARE($errorType : Integer)

var $entry : Object

If ($errorType=2)
	$entry:=New object("code"; String(Error code); "message"; Error description; "method"; Error method; "line"; Error line)
	If (Value type(Form)=Is object)
		If (Value type(Form.lastError)=Is object)
			Form.lastError:=$entry
			Form.errorText:=JSON Stringify($entry; *)
		End if
	End if
	// Visible in a headless run (tool4d writes this to its console).
	LOG EVENT(Into system standard outputs; "4D error "+$entry.code+" in "+$entry.method+":"+String($entry.line)+" — "+$entry.message)
End if
