//%attributes = {"invisible":true}
/*  True when a value is any kind of 4D number.

    JSON payloads and component replies do not distinguish Retained integer
    widths, and "Is number" is not a Value type constant, so the widths 4D can
    return are all tested explicitly.
*/
#DECLARE($value : Variant)->$isNumber : Boolean

Case of
	: (Value type($value)=Is real)
		$isNumber:=True
	: (Value type($value)=Is integer)
		$isNumber:=True
	: (Value type($value)=Is longint)
		$isNumber:=True
	Else
		$isNumber:=False
End case
