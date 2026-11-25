//%attributes = {"invisible":true}
/*  Bring the form model up to date.

    Called by the form timer for a window someone is looking at, and by the
    automated driver before each assertion: an unattended window has its timer
    stretched by App Nap, so a test cannot wait for a tick to arrive.
*/
#DECLARE()

SerialDemoRefresh
SerialDemoStatusPoll
SerialDemoDeviceChanged
