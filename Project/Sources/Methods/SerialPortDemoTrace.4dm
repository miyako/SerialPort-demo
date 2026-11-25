//%attributes = {"invisible":true}
/*  Append one line to the interactive run's trace file.

    The GUI application does not publish LOG EVENT output to a captured stream,
    so the automated window run writes its own trace to a file instead.
*/
#DECLARE($message : Text)

var $file : 4D.File
var $text : Text

If (Value type(<>SERIAL_TRACE)#Is text)
	return
End if
If (<>SERIAL_TRACE="")
	return
End if

$file:=File(<>SERIAL_TRACE; fk posix path)
$text:=""
If ($file.exists)
	$text:=$file.getText()
End if
$text:=$text+Time string(Current time)+"  "+$message+"\n"
$file.setText($text)
