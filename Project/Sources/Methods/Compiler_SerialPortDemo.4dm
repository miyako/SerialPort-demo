//%attributes = {"invisible":true}
/*  Interprocess variable declarations for the demo.

    The window handle has to be shared: the session owner runs in a worker, so
    it needs a handle it can hand to CALL FORM. Interprocess variables are the
    honest way to share one; per-process variables would only be visible to the
    worker that declares them.
*/
var <>SERIAL_TRACE : Text
var SERIAL_StatusPath : Text
var SERIAL_AppliedSeq : Integer
