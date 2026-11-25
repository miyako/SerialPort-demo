//%attributes = {"invisible":true}
/*  Open the demo window and start the session owner.

    The window belongs to the main process; the component session lives in a
    worker, because the component requires a live worker event loop for its
    callbacks. The worker publishes state to a document and this window applies
    it on its timer, so no session object and no window handle ever crosses a
    process boundary.
*/
#DECLARE()

var $window : Integer
var $folder : 4D.Folder

$window:=Open form window("Main")
If ($window=0)
	ALERT("The Main form could not be opened.")
	return
End if

// Where the owner publishes its state; the window reads the same file.
$folder:=Folder(Get 4D folder(Database folder); fk platform path)
SERIAL_StatusPath:=$folder.folder("Logs").file("session-status.json").posixPath
If (SERIAL_StatusPath="")
	SERIAL_StatusPath:=Convert path system to POSIX($folder.file("session-status.json").platformPath)
End if
CALL WORKER("SerialDemoOwner"; "SerialDemoWorker"; "statusfile"; New object("path"; SERIAL_StatusPath))

// A non-blocking DIALOG: the window stays alive on its own event loop, which is
// exactly what lets SystemWorker callbacks arrive in the worker.
DIALOG("Main"; New object; *)
