//%attributes = {"invisible":true}
/*  Record an unexpected error instead of letting it kill the run silently. */
#DECLARE($errorType : Integer)

SerialPortDemoTrace("ERROR "+String(Error code)+" in "+String(Error method)+":"+String(Error line)+" — "+Error description)
