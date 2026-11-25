//%attributes = {"invisible":true}
/*  Compact one-line description of a port inventory for the log. */
#DECLARE($ports : Collection)->$text : Text

var $index; $count : Integer
var $port : Object
var $path; $name : Text

$text:=""
$count:=$ports.length
If ($count>4)
	$count:=4
End if
For ($index; 0; $count-1)
	$port:=$ports[$index]
	$path:=""
	If (Value type($port.path)=Is text)
		$path:=$port.path
	End if
	$name:=""
	If (Value type($port.name)=Is text)
		$name:=$port.name
	End if
	If ($index>0)
		$text+=", "
	End if
	If ($name="")
		$text+=$path
	Else
		$text+=$name+" ("+$path+")"
	End if
End for
If ($ports.length=0)
	$text:="no serial device reported by the CLI"
End if
