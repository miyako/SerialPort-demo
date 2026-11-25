//%attributes = {"invisible":true}
/*  Write the interactive run's report.

    OB Copy is explicit because assigning an Object to another Object variable
    shares it, and OB REMOVE on the copy would strip the driver's own trace.
*/
#DECLARE($file : 4D.File; $report : Object)

var $copy : Object

$copy:=OB Copy($report)
OB REMOVE($copy; "trace")
$file.setText(JSON Stringify($copy; *))
