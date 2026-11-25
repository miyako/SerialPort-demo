//%attributes = {"invisible":true}
/*  Append one line to the activity log shown in the window.

    The log is capped so a streaming device cannot grow the form object without
    bound; the oldest lines are dropped first.
*/
#DECLARE($level : Text; $source : Text; $text : Text)

var $entry : Object

If (Value type(Form.log)#Is collection)
	return
End if

$entry:=New object
$entry.at:=Time string(Current time)
$entry.level:=$level
$entry.source:=$source
$entry.message:=$text
Form.log.push($entry)
While (Form.log.length>300)
	Form.log.shift()
End while
