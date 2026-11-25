//%attributes = {"invisible":true}
/*  Value of a collection at a drop-down index, clamped to a valid entry.

    A drop-down that has never been touched reports index -1, and 4D's Min/Max
    are flagged by the 21R4 syntax checker, so the clamp is explicit.
*/
#DECLARE($values : Collection; $index : Integer)->$value : Variant

var $last : Integer

$value:=Null
$last:=$values.length-1
If ($last<0)
	return
End if
If ($index<0)
	$index:=0
End if
If ($index>$last)
	$index:=$last
End if
$value:=$values[$index]
