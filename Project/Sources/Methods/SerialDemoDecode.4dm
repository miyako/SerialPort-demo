//%attributes = {"invisible":true}
/*  Decode one received chunk for a connection.

    The decoder instance is kept per connection in the worker's own decoder
    table, so a multibyte character split across two component callbacks is
    still decoded exactly once.
*/
#DECLARE($decoders : Object; $connection : Text; $bytes : Blob)->$decoded : Object

var $decoder : cs.SerialDemoDecoder

$decoder:=$decoders[$connection]
If (Not(OB Instance of($decoder; cs.SerialDemoDecoder)))
	$decoder:=cs.SerialDemoDecoder.new($connection)
End if
$decoded:=$decoder.feed($bytes)
$decoders[$connection]:=$decoder
