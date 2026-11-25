//%attributes = {"invisible":true}
/*  Poll the session status file until a condition holds (or time is up).

    Used by the headless end-to-end test: the component's replies and events
    arrive in the owner worker's event loop, so a test process can only observe
    them through a shared file. Polling never blocks the session itself.
*/
#DECLARE($statusFile : 4D.File; $phase : Text; $minReplies : Integer; $minErrors : Integer; $minChunks : Integer; $needText : Text; $ticks : Integer)->$status : Object

var $waited : Integer
var $text : Text
var $parsed : Object
var $done : Boolean

$status:=New object
$status.phase:=""
$status.text:=""
$status.stats:=New object("sent"; 0; "received"; 0; "chunks"; 0; "replies"; 0; "errors"; 0)
$waited:=0
Repeat
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
		// A half written file has no counters yet; the status is not ready.
		$status.stats:=New object("sent"; 0; "received"; 0; "chunks"; 0; "replies"; 0; "errors"; 0)
	End if
	$done:=True
	If ($phase#"")
		If (String($status.phase)#$phase)
			$done:=False
		End if
	End if
	If (($minReplies>0) & (Num($status.stats.replies)<$minReplies))
		$done:=False
	End if
	If (($minErrors>0) & (Num($status.stats.errors)<$minErrors))
		$done:=False
	End if
	If (($minChunks>0) & (Num($status.stats.chunks)<$minChunks))
		$done:=False
	End if
	If (($needText#"") & (Position($needText; String($status.text); *)<1))
		$done:=False
	End if
	If (Not($done))
		DELAY PROCESS(Current process; 6)
		$waited+=1
	End if
Until ($done | ($waited>=$ticks))
