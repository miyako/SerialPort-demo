/*  Stateful UTF-8 decoder for one serial connection.

    The component delivers *byte chunks*; a device message or a multibyte
    character can straddle two chunks. Converting each chunk on its own
    corrupts the text, so the trailing incomplete sequence is withheld until
    the next chunk completes it.

    Blobs are not indexable in 4D, so the raw bytes are held in a Text where
    every character is exactly one byte (ISO-8859-1 is a one-to-one byte to
    code point mapping). This keeps the scan of the last three bytes readable
    without copying the payload.
*/

property connection : Text
property pendingText : Text
property received : Integer

Class constructor($connection : Text)
	This.connection:=$connection
	This.pendingText:=""
	This.received:=0

/*  Length in bytes of the incomplete UTF-8 sequence at the end of $raw.
    0 means the data ends on a character boundary.
*/
Function incompleteTail($raw : Text)->$length : Integer
	var $size; $start; $available; $needed; $lead : Integer
	$length:=0
	$size:=Length($raw)
	If ($size=0)
		return 0
	End if
	// Walk back over continuation bytes (10xxxxxx) to the lead byte.
	$start:=$size
	While (($start>0) & ((Character code(Substring($raw; $start; 1)) & 0xC0)=0x80))
		$start-=1
	End while
	If ($start=0)
		// Only continuation bytes: a sequence started before this chunk.
		If ($size>3)
			return 3
		End if
		return $size
	End if
	$lead:=Character code(Substring($raw; $start; 1))
	Case of
		: (($lead & 0xF8)=0xF0)
			$needed:=4
		: (($lead & 0xF0)=0xE0)
			$needed:=3
		: (($lead & 0xE0)=0xC0)
			$needed:=2
		Else
			// ASCII, or an invalid lead byte: nothing to withhold.
			return 0
	End case
	$available:=$size-$start+1
	If ($available<$needed)
		return $available
	End if
	return 0

/*  Hex preview of the first bytes, for payloads that must not be guessed at
    as text.
*/
Function hex($bytes : Blob; $limit : Integer)->$preview : Text
	var $raw : Text
	var $index; $size; $byte : Integer
	$raw:=Convert to text($bytes; "ISO-8859-1")
	$size:=Length($raw)
	If ($size>$limit)
		$size:=$limit
	End if
	$preview:=""
	For ($index; 1; $size)
		$byte:=Character code(Substring($raw; $index; 1))
		$preview+=This.digits(($byte>>4)+1)
		$preview+=This.digits(($byte & 15)+1)
		If ($index<$size)
			$preview+=" "
		End if
	End for
	If (BLOB size($bytes)>$limit)
		$preview+=" … "+String(BLOB size($bytes))+" bytes"
	End if

Function digits($position : Integer)->$character : Text
	return Substring("0123456789ABCDEF"; $position; 1)

/*  Feed one chunk. Returns the text that is now complete, the hex preview of
    the chunk and how many bytes are still withheld.
*/
Function feed($bytes : Blob)->$result : Object
	var $raw; $complete : Text
	var $size; $keep : Integer
	var $utf8 : Blob
	var $text : Text
	$raw:=This.pendingText+Convert to text($bytes; "ISO-8859-1")
	$size:=Length($raw)
	This.received+=$size
	$keep:=This.incompleteTail($raw)
	$text:=""
	If (($size-$keep)>0)
		// Only complete sequences reach the UTF-8 conversion.
		$complete:=Substring($raw; 1; $size-$keep)
		CONVERT FROM TEXT($complete; "ISO-8859-1"; $utf8)
		$text:=Convert to text($utf8; "UTF-8")
	End if
	This.pendingText:=Substring($raw; $size-$keep+1)
	$result:=New object
	$result.text:=$text
	$result.hex:=This.hex($bytes; 24)
	$result.size:=$size
	$result.withheld:=Length(This.pendingText)

/*  Release the withheld bytes when a connection ends. They cannot be decoded
    as text (they are part of a character that never arrived), so only the hex
    preview is returned.
*/
Function flush()->$result : Object
	var $raw : Text
	var $bytes : Blob
	$raw:=This.pendingText
	This.pendingText:=""
	CONVERT FROM TEXT($raw; "ISO-8859-1"; $bytes)
	$result:=New object
	$result.text:=""
	$result.hex:=This.hex($bytes; 24)
	$result.size:=BLOB size($bytes)
	$result.withheld:=0
