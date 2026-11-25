//%attributes = {"invisible":true}
/*  Serial configuration currently selected in the window.

    The drop-down lists are object based, so their selection is read back from
    "index" and mapped onto the values the component expects.
*/
#DECLARE()->$config : Object

var $baudRates; $dataBits; $parities; $stopBits : Collection

$baudRates:=New collection("9600"; "19200"; "38400"; "57600"; "115200")
$dataBits:=New collection("7"; "8")
$parities:=New collection("none"; "even"; "odd")
$stopBits:=New collection("one"; "two")

$config:=New object
$config.baudRate:=Num(SerialDemoChoice($baudRates; Form.dropBaud.index))
$config.dataBits:=Num(SerialDemoChoice($dataBits; Form.dropDataBits.index))
$config.parity:=SerialDemoChoice($parities; Form.dropParity.index)
$config.stopBits:=SerialDemoChoice($stopBits; Form.dropStopBits.index)
$config.flowControl:="none"
