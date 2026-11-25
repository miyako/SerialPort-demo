//%attributes = {"invisible":true}
/*  Recompute the display strings bound to the window.

    The form binds a few Text inputs to these summaries so the thread of state
    (phase, counters, pending requests, connection) is readable without opening
    the log.
*/
#DECLARE()

var $stats; $status : Object
var $connections : Collection
var $connection : Text
var $index : Integer

If (Value type(Form.log)#Is collection)
	return
End if

$status:=Form.status
$stats:=Form.stats

Form.statusText:="phase "+String($status.phase)+"  ·  target "+String($status.target)
Form.statsText:="sent "+String($stats.sent)+" B  ·  received "+String($stats.received)+" B  ·  chunks "+String($stats.chunks)+"  ·  replies "+String($stats.replies)+"  ·  errors "+String($stats.errors)
Form.pendingText:="pending requests: "+String($status.pending)

$connections:=$status.connections
$connection:=""
If (Form.connection#"")
	$index:=$connections.indexOf(Form.connection)
	If ($index<0)
		// The connection this window was writing to has gone away.
		Form.connection:=""
	End if
	$connection:=Form.connection
End if
If ($connection="")
	Form.connectionText:="no connection"
Else
	Form.connectionText:=$connection
End if

Form.portsText:=String(Form.ports.length)+" port(s) reported"
Form.chunkCountText:=String(Form.chunks.length)+" chunk(s)  ·  "+String(Length(Form.rx))+" character(s) decoded"
Form.logCountText:=String(Form.log.length)+" line(s)"
Form.uptimeText:="uptime "+String(Form.uptimeSeconds)+" s"
Form.deviceText:=String(Form.deviceState)+"  "+Form.devicePort
