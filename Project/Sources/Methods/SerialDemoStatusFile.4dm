//%attributes = {"invisible":true}
/*  The document the session owner publishes and the window polls.

    Folder(fk database folder) is the project's parent folder. Its .path is a
    4D-relative "/PACKAGE/..." path, not a POSIX one, so the POSIX path the
    worker needs is derived from the platform path. The Logs folder must exist
    before anything is written into it.
*/
#DECLARE()->$file : 4D.File

$file:=Folder(fk database folder).folder("Logs").file("session-status.json")
$file.parent.create()
