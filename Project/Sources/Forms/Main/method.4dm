//%attributes = {"invisible":true}
/*  Main window.

    One form method, no object methods: buttons are identified by their object
    name and dispatched through SerialDemoAction, which keeps the demo's whole
    behaviour in one readable method.
*/
#DECLARE()
var $name : Text

Case of
	: (Form event code=On Load)
		SerialDemoModelInit
		SET TIMER(1000)

	: (Form event code=On Timer)
		// One timer runs for the window's lifetime: it counts session uptime
		// only while the session is running and mirrors the virtual device.
		If (Form.running)
			Form.uptimeSeconds:=Form.uptimeSeconds+1
		End if
		// One pump mirrors the session document and the virtual device; both
		// are read here because a worker callback cannot touch form state.
		SerialDemoPump

	: (Form event code=On Unload)
		If (OB Instance of(Form.device; cs.VirtualSerialDevice))
			Form.device.stop()
		End if
		CALL WORKER("SerialDemoOwner"; "SerialDemoWorker"; "shutdown"; New object)

	: (Form event code=On Clicked)
		$name:=String(FORM Event.objectName)
		If ($name#"")
			SerialDemoAction($name)
		End if
End case
