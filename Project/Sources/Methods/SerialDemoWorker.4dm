//%attributes = {"invisible":true}
/*  Owner worker of the SerialPort session.

    The component requires its session to be constructed, retained and called
    from a live worker process, and the worker must return to its event loop so
    SystemWorker callbacks can be delivered. This method is that loop body: one
    command in, one component call out, and the reply arrives later in
    SerialDemoEvent.

    The session instance lives in a process variable of this worker, never in a
    window or a form; the UI only ever sees snapshots. Note that a typed object
    process variable is already an empty object before the first command runs,
    so the state is initialised by testing its contents, not its Value type.
*/
#DECLARE($command : Text; $payload : Object)

var SERIAL_Session : cs.Serial.SerialPort
var SERIAL_State : Object
var SERIAL_StatusFile : 4D.File
var $result : Object
var $id : Text

// A failing command must never leave a half-updated worker behind.
ON ERR CALL("SerialDemoError"; ek local)

If (OB Keys(SERIAL_State).length=0)
	SERIAL_State:=New object
	SERIAL_State.phase:="idle"
	SERIAL_State.target:=""
	SERIAL_State.startedAt:=""
	SERIAL_State.pending:=New object
	SERIAL_State.connections:=New object
	SERIAL_State.decoders:=New object
	SERIAL_State.ports:=New collection
	SERIAL_State.text:=""
	SERIAL_State.stats:=New object("sent"; 0; "received"; 0; "chunks"; 0; "replies"; 0; "errors"; 0)
	SERIAL_State.seq:=0
	SERIAL_State.outbox:=New collection
	SERIAL_State.lastExit:=Null
End if

If ($payload=Null)
	$payload:=New object
End if

Case of
	: ($command="statusfile")
		// An external observer (the headless test, a script) can follow the
		// session through this file while the window is not open. File objects
		// cannot cross a CALL WORKER boundary, so only the path travels.
		SERIAL_StatusFile:=File(String($payload.path); fk posix path)
		SerialDemoStatus

	: ($command="start")
		If (SERIAL_Session#Null)
			SerialDemoNotify(New object("kind"; "error"; "error"; New object("code"; "session_exists"; "message"; "A session already exists; shut it down first")))
		Else
			SERIAL_State.phase:="starting"
			SERIAL_State.target:=$payload.target
			SerialDemoStatus
			SERIAL_Session:=cs.Serial.SerialPort.new($payload.target; Formula(SerialDemoEvent($1)))
			$result:=SERIAL_Session.start()
			If ($result.ok)
				SERIAL_State.phase:="running"
				SERIAL_State.startedAt:=Timestamp
				SerialDemoSubmit("list"; New object)
			Else
				SERIAL_State.phase:="failed"
				SerialDemoNotify(New object("kind"; "error"; "error"; $result.error))
			End if
			SerialDemoStatus
		End if

	: ($command="list")
		SerialDemoSubmit("list"; New object)

	: ($command="open")
		SerialDemoSubmit("open"; New object("path"; $payload.path; "config"; $payload.config))

	: ($command="configure")
		SerialDemoSubmit("configure"; New object("connection"; $payload.connection; "config"; $payload.config))

	: ($command="write")
		SerialDemoSubmit("write"; New object("connection"; $payload.connection; "bytes"; $payload.bytes; "timeoutMs"; $payload.timeoutMs))

	: ($command="close")
		SerialDemoSubmit("close"; New object("connection"; $payload.connection))

	: ($command="cancel")
		SerialDemoSubmit("cancel"; New object("requestId"; $payload.requestId))

	: ($command="shutdown")
		SerialDemoSubmit("shutdown"; New object)

	: ($command="terminate")
		If (SERIAL_Session#Null)
			$result:=SERIAL_Session.terminate()
			SERIAL_State.phase:="terminated"
			If ($result.ok=False)
				SerialDemoNotify(New object("kind"; "error"; "error"; $result.error))
			End if
		End if
		SerialDemoStatus

	: ($command="forget")
		// Drop a session that has already ended so the demo can start again.
		SERIAL_State.phase:="idle"
		SERIAL_State.target:=""
		SERIAL_State.startedAt:=""
		SERIAL_State.pending:=New object
		SERIAL_State.connections:=New object
		SERIAL_State.decoders:=New object
		SERIAL_State.ports:=New collection
		SERIAL_State.text:=""
		SERIAL_State.lastExit:=Null
		SerialDemoStatus

	: ($command="state")
		SerialDemoStatus

	Else
		SerialDemoNotify(New object("kind"; "error"; "error"; New object("code"; "unknown_command"; "message"; "Unknown demo command: "+$command)))
End case

ON ERR CALL(""; ek local)
