//%attributes = {"invisible":true}
/*  Initial form model of the Main window.

    Every field the worker's messages or SerialDemoRefresh write is created
    here first: reflection on Form must never depend on a field appearing by
    accident, and a typed Object field is not a reliable "not yet created" test.
*/
#DECLARE()

Form.status:=New object
Form.status.phase:="idle"
Form.status.target:=""
Form.status.pending:=0
Form.status.connections:=New collection
Form.status.stats:=New object("sent"; 0; "received"; 0; "chunks"; 0; "replies"; 0; "errors"; 0)
Form.stats:=Form.status.stats
Form.phase:="idle"
Form.running:=False
Form.startTime:=0
Form.uptimeSeconds:=0

Form.ports:=New collection
Form.chunks:=New collection
Form.log:=New collection
Form.rx:=""
Form.connection:=""
Form.lastId:=""
Form.lastOperation:=""
Form.lastError:=Null
Form.errorText:=""
Form.errorHeadline:=""

Form.pathInput:=""
Form.sendText:="PING"
Form.deviceState:="stopped"
Form.devicePort:=""
Form.deviceText:="no device"
Form.deviceLines:=New collection
Form.device:=Null

Form.dropBaud:=New object
Form.dropBaud.values:=New collection("9600"; "19200"; "38400"; "57600"; "115200")
Form.dropBaud.index:=4
Form.dropDataBits:=New object
Form.dropDataBits.values:=New collection("7"; "8")
Form.dropDataBits.index:=1
Form.dropParity:=New object
Form.dropParity.values:=New collection("none"; "even"; "odd")
Form.dropParity.index:=0
Form.dropStopBits:=New object
Form.dropStopBits.values:=New collection("one"; "two")
Form.dropStopBits.index:=0

SerialDemoRefresh
