//%attributes = {"invisible":true}
/*  Publish one worker message for the window.

    The session lives in a worker process; the window lives in another. The
    worker therefore never calls the form directly: it queues numbered messages
    and SerialDemoStatus writes them next to the session snapshot. The window
    applies whatever it has not applied yet, so a throttled or busy window
    loses nothing and never blocks the session.
*/
#DECLARE($message : Object)

If (Value type(SERIAL_State)#Is object)
	return
End if
If (OB Keys(SERIAL_State).length=0)
	return
End if

SERIAL_State.seq+=1
$message.seq:=SERIAL_State.seq
SERIAL_State.outbox.push($message)
While (SERIAL_State.outbox.length>200)
	SERIAL_State.outbox.shift()
End while
