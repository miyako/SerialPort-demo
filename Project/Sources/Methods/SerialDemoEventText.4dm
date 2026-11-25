//%attributes = {"invisible":true}
/*  Log one unsolicited component event in a compact, readable form.

    Events are the asynchronous half of the protocol: data is handled as a
    chunk, everything else lands here.
*/
#DECLARE($event : Object)

var $name; $level; $text; $connection : Text

$name:=""
If (Value type($event.event)=Is text)
	$name:=$event.event
End if
$connection:=""
If (Value type($event.connection)=Is text)
	$connection:=$event.connection
End if

$level:="in"
$text:=$name
If ($connection#"")
	$text+=" on "+$connection
End if

Case of
	: ($name="error")
		$level:="error"
		If (Value type($event.error)=Is object)
			$text+=" — "+String($event.error.code)+": "+String($event.error.message)
		End if
		Form.lastError:=$event.error
		Form.errorText:=JSON Stringify($event.error; *)
		Form.errorHeadline:="error "+String(Form.lastError.code)

	: ($name="disconnected")
		$level:="warn"
		$text+=" — the device closed the connection"

	: ($name="session_limit")
		$level:="error"
		$text+=" — the session reached its cap and is no longer usable"

	: ($name="terminated")
		$level:="state"
		If (Value type($event.result)=Is object)
			If (SerialDemoIsNumber($event.result.exitCode))
				$text+=" — exit code "+String($event.result.exitCode)
			End if
		End if

	: ($name="diagnostic")
		$level:="warn"
		If (Value type($event.result)=Is object)
			$text+=" — "+JSON Stringify($event.result; *)
		End if
End case

SerialDemoAppend($level; "event"; $text)
