//%attributes = {"invisible":true}
/*  Submit one write request built from the text field.

    Bytes are built here, in the window process, because the component takes a
    Blob: text is encoded as UTF-8, hexadecimal input is decoded byte by byte.
    A Blob has no indexable bytes in 4D, so the hex decoder accumulates a Text
    where one character is exactly one byte and converts once.
*/
#DECLARE($text : Text; $asHex : Boolean)

var $bytes : Blob
var $raw; $clean; $digits; $pair : Text
var $index; $high; $low : Integer

If (Form.connection="")
	SerialDemoAppend("warn"; "ui"; "open a connection before writing")
	SerialDemoRefresh
	return
End if

If ($asHex)
	// Keep only hexadecimal digits.
	$digits:="0123456789ABCDEF"
	$clean:=""
	$pair:=Uppercase($text)
	For ($index; 1; Length($pair))
		If (Position(Substring($pair; $index; 1); $digits; *)>0)
			$clean+=Substring($pair; $index; 1)
		End if
	End for
	If (((Length($clean)%2)#0) | (Length($clean)=0))
		SerialDemoAppend("error"; "ui"; "hexadecimal input needs an even number of digits")
		SerialDemoRefresh
		return
	End if
	$raw:=""
	For ($index; 1; Length($clean); 2)
		$high:=(Position(Substring($clean; $index; 1); $digits))-1
		$low:=(Position(Substring($clean; $index+1; 1); $digits))-1
		$raw+=Char($high*16+$low)
	End for
	CONVERT FROM TEXT($raw; "ISO-8859-1"; $bytes)
Else
	$raw:=$text
	// Line-oriented devices answer on the line terminator, and the terminator
	// they split on is LF: a bare CR is buffered forever and the device looks
	// silent. Send the CRLF a terminal sends.
	If (Length($raw)>0)
		If (Substring($raw; Length($raw); 1)#Char(10))
			If (Substring($raw; Length($raw); 1)=Char(13))
				$raw+=Char(10)
			Else 
				$raw+=Char(13)+Char(10)
			End if 
		End if 
	End if
	CONVERT FROM TEXT($raw; "UTF-8"; $bytes)
End if

SerialDemoAppend("out"; "ui"; "write "+String(BLOB size($bytes))+" byte(s)")
SerialDemoRefresh
CALL WORKER("SerialDemoOwner"; "SerialDemoWorker"; "write"; New object("connection"; Form.connection; "bytes"; $bytes; "timeoutMs"; 2000))
