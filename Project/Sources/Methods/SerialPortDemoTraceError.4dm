//%attributes = {"invisible":true}
/*  Record an unexpected error instead of letting it kill the run silently. */
#DECLARE()

var $last : Object

$last:=New object("errCode"; 0; "message"; "")
If (Last errors#Null)
	If (Last errors.length>0)
		$last:=Last errors[0]
	End if
End if
SerialPortDemoTrace("ERROR "+String($last.errCode)+" in "+String(Error method)+":"+String(Error line)+" — "+String($last.message))
