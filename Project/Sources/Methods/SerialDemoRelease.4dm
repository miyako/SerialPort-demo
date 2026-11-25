//%attributes = {"invisible":true}
/*  Flush and forget the decoder of a connection.

    Whatever the decoder was still withholding is delivered as a final partial
    chunk, so a connection that ends mid-character does not silently lose bytes.
*/
#DECLARE($connection : Text)

var SERIAL_State : Object
var $decoder : Object
var $flushed : Object

If (Value type(SERIAL_State)#Is object)
	return
End if
$decoder:=SERIAL_State.decoders[$connection]
If (OB Instance of($decoder; cs.SerialDemoDecoder))
	$flushed:=$decoder.flush()
	If ($flushed.size>0)
		SerialDemoNotify(New object("kind"; "chunk"; "connection"; $connection; "decoded"; $flushed; "partial"; True))
	End if
	OB REMOVE(SERIAL_State.decoders; $connection)
End if
