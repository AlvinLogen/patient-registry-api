Class PatientRegistry.Util.MrnCheck
{
    /// Returns the check digit to append to a numeric payload. Throws on a non-digit payload
    ClassMethod CheckDigit(payload as %String) As %String [Language = python]
    {
        payload = str(payload)
        if not payload or not payload.isascii() or not payload.isdigit():
            raise ValueError("Payload must be a non-empty string of ASCII digits")
        total = 0
        for index, char in enumerate(reversed(payload)):
            digit = int(char)
            if index % 2 == 0:
                digit *= 2
                if digit > 9:
                    digit -=9
            total += digit
        return str((10 - total % 10) % 10)
    }

    /// True when the last digit is the correct check digit for the digits before it. Never throws.
    ClassMethod IsValid(pMRN As %String) As %Boolean
    {
        Set length = $LENGTH(pMRN)
        If length < 2 {
            Quit 0
        }

        Set valid = 0
        Try {
            Set valid = (..CheckDigit($EXTRACT(pMRN, 1, length - 1)) = $EXTRACT(pMRN, length))
        } Catch {
            Set valid = 0
        }

        Quit valid
    }
}
