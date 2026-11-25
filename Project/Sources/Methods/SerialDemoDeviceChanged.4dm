//%attributes = {"invisible":true}
/*  Mirror the virtual device into the form model.

    The device lives in the window's own process: it owns a helper process, not
    part of the serial session, so it needs no worker of its own. This method is
    called from the window's timer and after the device buttons, never from the
    SystemWorker callback itself: 4D abandons a method that touches form state
    from inside a callback delivery.
*/
#DECLARE()

var $line : Text

If (Not(OB Instance of(Form.device; cs.VirtualSerialDevice)))
	return
End if

Form.deviceState:=String(Form.device.state)
Form.devicePort:=String(Form.device.port)
Form.deviceLines:=[]
For each ($line; Form.device.transcript)
	Form.deviceLines.push(New object("text"; $line))
End for each
// Offer the announced path as the next thing to open, without overwriting a
// path the user typed on purpose.
If ((Form.pathInput="") & (Form.devicePort#""))
	Form.pathInput:=Form.devicePort
	SerialDemoAppend("info"; "device"; "virtual device ready on "+Form.devicePort)
End if
SerialDemoRefresh
