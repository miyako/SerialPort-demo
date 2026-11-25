//%attributes = {"invisible":true}
/*  Dispatch one button action into the window process and report it.

    The action runs inside the window, in its own cycle, exactly as a click
    would; the driver only queues it and records that it did so.
*/
#DECLARE($window : Integer; $action : Text; $report : Object; $reportFile : 4D.File)

CALL FORM($window; Formula(SerialDemoAction($1)); $action)
$report.trace.push(New object("action"; $action; "at"; Current time))
SerialPortDemoTrace("dispatched "+$action)
SerialPortDemoWriteReport($reportFile; $report)
