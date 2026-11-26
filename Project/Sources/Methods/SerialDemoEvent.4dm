//%attributes = {"invisible":true}
/*  Component callback, executed in the owner worker.

    One method receives both halves of the protocol:
    * a reply carries an id that SerialDemoSubmit remembered, so it can be
      matched to the operation that caused it;
    * an unsolicited event (data, error, disconnected, session_limit,
      diagnostic, terminated) carries no id.
*/
#DECLARE($event : Object)

var SERIAL_State : Object
var SERIAL_StatusFile : 4D.File
var $entry; $decoded; $decoder; $notice : Object
var $bytes : Blob
var $name; $connection : Text
var $keys : Collection
var $index : Integer

If (Value type(SERIAL_State)#Is object)
	return
End if


/*  Replies ------------------------------------------------------------------ */
If (Value type($event.id)=Is text)
	$entry:=SERIAL_State.pending[$event.id]
	If (Value type($entry)#Is object)
		$entry:=New object("operation"; "unknown"; "connection"; ""; "size"; 0)
	End if
	OB REMOVE(SERIAL_State.pending; $event.id)
	SERIAL_State.stats.replies+=1
	If ($event.ok)
		Case of
			: ($entry.operation="list")
				If (Value type($event.result.ports)=Is collection)
					SERIAL_State.ports:=$event.result.ports
				End if
				SerialDemoNotify(New object("kind"; "ports"; "ports"; SERIAL_State.ports))
			: ($entry.operation="open")
				If (Value type($event.result.connection)=Is text)
					SERIAL_State.connections[$event.result.connection]:=New object("openedAt"; Timestamp)
				End if
			: ($entry.operation="close")
				OB REMOVE(SERIAL_State.connections; $entry.connection)
				OB REMOVE(SERIAL_State.decoders; $entry.connection)
			: ($entry.operation="write")
				If (SerialDemoIsNumber($event.result.transferred))
					SERIAL_State.stats.sent+=$event.result.transferred
				End if
		End case
		$notice:=New object
		$notice.kind:="reply"
		$notice.operation:=$entry.operation
		$notice.id:=$event.id
		$notice.connection:=$entry.connection
		$notice.size:=$entry.size
		$notice.result:=$event.result
		SerialDemoNotify($notice)
	Else
		SERIAL_State.stats.errors+=1
		$notice:=New object
		$notice.kind:="error"
		$notice.operation:=$entry.operation
		$notice.connection:=$entry.connection
		$notice.error:=$event.error
		SerialDemoNotify($notice)
	End if
	SerialDemoStatus
	return
End if

/*  Events ------------------------------------------------------------------- */
$name:=""
If (Value type($event.event)=Is text)
	$name:=$event.event
End if
$connection:=""
If (Value type($event.connection)=Is text)
	$connection:=$event.connection
End if

Case of
	: ($name="data")
		$bytes:=$event.bytes
		$decoded:=SerialDemoDecode(SERIAL_State.decoders; $connection; $bytes)
		SERIAL_State.stats.received+=$decoded.size
		SERIAL_State.stats.chunks+=1
		SERIAL_State.text+=String($decoded.text)
		If (Length(SERIAL_State.text)>4000)
			SERIAL_State.text:=Substring(SERIAL_State.text; Length(SERIAL_State.text)-3999)
		End if
		SerialDemoNotify(New object("kind"; "chunk"; "connection"; $connection; "decoded"; $decoded))
		// An external observer follows the counters, so a chunk refreshes them.
		If (SERIAL_StatusFile#Null)
			SerialDemoStatus
		End if

	: ($name="disconnected")
		SerialDemoRelease($connection)
		OB REMOVE(SERIAL_State.connections; $connection)
		SerialDemoNotify(New object("kind"; "event"; "event"; $event; "connection"; $connection))

	: ($name="session_limit")
		$keys:=OB Keys(SERIAL_State.decoders)
		For ($index; 1; $keys.length)
			SerialDemoRelease(String($keys[$index]))
		End for
		SERIAL_State.phase:="terminated"
		SerialDemoNotify(New object("kind"; "event"; "event"; $event))
		SerialDemoStatus

	: ($name="terminated")
		$keys:=OB Keys(SERIAL_State.decoders)
		For ($index; 1; $keys.length)
			SerialDemoRelease(String($keys[$index]))
		End for
		SERIAL_State.phase:="terminated"
		If (SerialDemoIsNumber($event.exitCode))
			SERIAL_State.lastExit:=New object("exitCode"; $event.exitCode)
		Else
			If (Value type($event.result)=Is object)
				SERIAL_State.lastExit:=$event.result
			End if
		End if
		SerialDemoNotify(New object("kind"; "event"; "event"; $event))
		SerialDemoStatus

	Else
		// error, diagnostic and anything the component adds later
		SerialDemoNotify(New object("kind"; "event"; "event"; $event; "connection"; $connection))
End case
