//%attributes = {"invisible":true}
/*  Wait until the window and the session reach a state, pumping as we go.

    Two processes are involved: the window owns the form, the worker owns the
    session. Neither can be polled by simply delaying, because an unattended
    macOS application has its timers and background processes stretched. So
    every round pumps the window and re-reads the published session document,
    and the wait ends on observed state rather than on elapsed time.

    $selector is one of phase, ports, connections, chunks, errors, replies,
    sent or text. $minimum is the required count (0 means "empty" for
    connections) and $expected carries a phase name or the text to find.
*/
#DECLARE($window : Integer; $statusFile : 4D.File; $selector : Text; $expected : Text; $minimum : Integer; $rounds : Integer)->$status : Object

var $text : Text
var $parsed : Object
var $done : Boolean
var $round : Integer
var $count : Integer

$status:=New object("phase"; ""; "text"; ""; "ports"; New collection; "connections"; New collection; "stats"; New object("sent"; 0; "received"; 0; "chunks"; 0; "replies"; 0; "errors"; 0))
$round:=0
Repeat
	// Keep the window's model current; this is what the form timer would do.
	CALL FORM($window; Formula(SerialDemoPump))
	$text:=""
	If ($statusFile.exists)
		$text:=$statusFile.getText()
	End if
	If ($text#"")
		ON ERR CALL("SerialDemoError"; ek local)
		$parsed:=JSON Parse($text)
		ON ERR CALL(""; ek local)
		If (Value type($parsed)=Is object)
			$status:=$parsed
		End if
	End if
	If (Value type($status.stats)#Is object)
		$status.stats:=New object("sent"; 0; "received"; 0; "chunks"; 0; "replies"; 0; "errors"; 0)
	End if
	If (Value type($status.ports)#Is collection)
		$status.ports:=New collection
	End if
	If (Value type($status.connections)#Is collection)
		$status.connections:=New collection
	End if

	$done:=False
	Case of
		: ($selector="phase")
			$done:=(String($status.phase)=$expected)
			If (($expected="shutdown") & ((String($status.phase)="terminated") | (String($status.phase)="shutdown")))
				$done:=True
			End if
		: ($selector="ports")
			$done:=($status.ports.length>=$minimum)
		: ($selector="connections")
			If ($minimum=0)
				$done:=($status.connections.length=0)
			Else
				$done:=($status.connections.length>=$minimum)
			End if
		: ($selector="text")
			$done:=(Position($expected; String($status.text); *)>0)
		Else
			$count:=0
			If (SerialDemoIsNumber($status.stats[$selector]))
				$count:=$status.stats[$selector]
			End if
			$done:=($count>=$minimum)
	End case

	If (Not($done))
		DELAY PROCESS(Current process; 2)
		$round:=$round+1
	End if
Until ($done | ($round>=$rounds))
