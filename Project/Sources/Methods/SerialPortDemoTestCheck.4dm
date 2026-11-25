//%attributes = {"invisible":true}
/*  Record one end-to-end case in the shared report. */
#DECLARE($report : Object; $name : Text; $ok : Boolean; $detail : Variant)

$report.cases.push(New object("name"; $name; "ok"; $ok; "detail"; $detail))
If (Not($ok))
	$report.success:=False
End if
