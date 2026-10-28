/// Use-case operations on patients: bulk import/export and the merge-safe update.
/// Every operation returns a %Status whose text starts with a stable Pr-* code on failure.
Class PatientRegistry.Service.PatientService
{
    /// Second to wait for a patient lock.
    Parameter LOCKTIMEOUT = 5;
    Parameter IMPORTDIR = "/home/irisowner/dev/fixtures/";
    Parameter ERRINVALID = "PR-INVALID-INPUT";
    Parameter ERRNOTFOUND = "PR-NOT-FOUND";
    Parameter ERRVERSION = "PR-VERSION-CONFLICT";
    Parameter ERRIMMUTABLE = "PR-IDENTITY-IMMUTABLE";
    Parameter ERRLOCK = "PR-LOCK-TIMEOUT";
    Parameter ERRIMPORT = "PR-IMPORT-REJECTED";
    Parameter ERRNESTED = "PR-NESTED-TRANSACTION";

    /// Merge-patch update of one patient, safe against concurrent writes. 
    /// pExpectedVersion (optional): the version the caller last read; a mismatch is refused.
    /// pVersion (output): the new version after a successful update.
    /// pLockTimeout (optional): seconds to wait for the lock; defaults to the LOCKTIMEOUT parameter. 
    ClassMethod MergeUpdate(pAuthority As %String, pMRN As %String, pChanges As %DynamicObject, 
                            pExpectedVersion As %Integer = "", Output pVersion As %Integer, pLockTimeout As %Integer = "") As %Status
    {
        Set sc = $$$OK
        Set inTx = 0
        Set pVersion = ""
        If pLockTimeout = "" {
            Set pLockTimeout = ..#LOCKTIMEOUT
        } 
        If $TLEVEL > 0 {
            Quit ..Fail(..#ERRNESTED, "MergeUpdate must run outside an open transaction")
        }
        If ('$ISOBJECT(pChanges)) || ($CLASSNAME(pChanges) '= "%Library.DynamicObject"){
            Quit ..Fail(..#ERRINVALID, "changes must be a JSON object")
        }
        If pChanges.%IsDefined("assigningAuthority") || pChanges.%IsDefined("mrn"){
            Quit ..Fail(..#ERRIMMUTABLE, "identity fields cannot be changed")
        }
        Set fields = ""
        For key = "familyName", "givenName", "birthDate", "administrativeSex", "homeAddress", "active" {
            If pChanges.%IsDefined(key){
                Set fields = fields_$SELECT(fields = "":"", 1:",")_key
            }
        }
        If fields = "" {
            Quit ..Fail(..#ERRINVALID, "no editable fields in changes")
        }

        // One lock name per identity, built from the upper-cased parts so it matches the case-insensitive index.
        Set authKey = $ZCONVERT(pAuthority, "U")
        Set mrnKey = $ZCONVERT(pMRN, "U")
        Lock +^PatReg.PatientLock(authKey, mrnKey):pLockTimeout
        If '$TEST {
            Quit ..Fail(..#ERRLOCK, "could not lock the patient within "_pLockTimeout_" seconds")
        }

        Try {
            Set patient = ##class(PatientRegistry.Model.Patient).FindByIdentifier(pAuthority, pMRN)
            If '$ISOBJECT(patient) {
                Set sc = ..Fail(..#ERRNOTFOUND, "no patient with that identity")
            } ElseIf (pExpectedVersion '= "") && (patient.Version '= pExpectedVersion) {
                Set sc = ..Fail(..#ERRVERSION, "expected version "_pExpectedVersion_" but current is "_patient.Version)
            } Else {
                Tstart
                Set inTx = 1
                $$$ThrowOnError(patient.ApplyChanges(pChanges))
                Set patient.Version = patient.Version + 1
                $$$ThrowOnError(patient.%Save())

                If $DATA(^||PatReg.FailAfterSave){
                    $$$ThrowStatus(..Fail("PR-INJECTED", "failure injected after save (test seam)"))
                }

                Do ..WriteAudit(patient.%Id(), patient.Version, "MergeUpdate", fields)
                Tcommit
                Set inTx = 0
                Set pVersion = patient.Version
            }
        } Catch ex {
            If inTx {
                Trollback
                Set inTx = 0
            }
            Set sc = ex.AsStatus()
        }

        Lock -^PatReg.PatientLock(authKey, mrnKey)
        Quit sc
    }

    /// Imports a canonical document { "data": [ ...] } from a file below IMPORTDIR. All rows or none.
    ClassMethod ImportFile(pPath As %String, Output pCount As %Integer) As %Status
    {
        Set pCount = 0
        If ($FIND(pPath, "..") > 0) || ($EXTRACT(pPath, 1, $LENGTH(..#IMPORTDIR)) '= ..#IMPORTDIR) {
            Quit ..Fail(..#ERRINVALID, "path must be inside "_..#IMPORTDIR)
        }

        Set sc = $$$OK
        Try {
            Set document = ##class(%DynamicAbstractObject).%FromJSONFile(pPath)
        } Catch ex {
            Set sc = ..Fail(..#ERRINVALID, "file could not be read as JSON")
        }

        If $$$ISERR(sc) {
            Quit sc
        }

        Quit ..ImportDocument(document, .pCount)
    }

    /// Imports a parsed canonical document in ONE transaction: if any row is rejected, nothing is imported.
    ClassMethod ImportDocument(pDocument AS %DynamicObject, Output pCount As %Integer) As %Status
    {
        Set sc = $$$OK
        Set pCount = 0
        Set inTx = 0
        If $TLEVEL > 0 {
            Quit ..Fail(..#ERRNESTED, "import must run outside an open transaction")
        }

        Try {
            If ('$ISOBJECT(pDocument)) || ('$ISOBJECT(pDocument.data)) || ($CLASSNAME(pDocument.data) '= "%Library.DynamicArray") {
                Set sc = ..Fail(..#ERRINVALID, "document must contain a data array")
            } Else {
                Tstart
                Set inTx = 1
                Set iter = pDocument.data.%GetIterator()
                While iter.%GetNext(.key, .item){
                    Set rowStatus = ..ImportRow(item)
                    If $$$ISERR(rowStatus) {
                        Set sc = ..Fail(..#ERRIMPORT, "row "_(key+1)_" rejected, error codes "_$SYSTEM.Status.GetErrorCodes(rowStatus))
                        Quit
                    }
                    Set pCount = pCount + 1
                }

                If $$$ISOK(sc) {
                    Tcommit
                    Set inTx = 0
                } Else {
                    Trollback
                    Set inTx = 0
                    Set pCount = 0
                }
            }
        } Catch ex {
            If inTx {
                Trollback
                Set inTx = 0
            }
            Set pCount = 0
            Set sc = ex.AsStatus()
        }
        Quit sc
    }

    /// Exports every patient as { "data": [ ... ], "meta": { "schemaVersion", "count"} }, ordered by ID.
    ClassMethod ExportAll(Output pDocument As %DynamicObject) As %Status
    {
        Set sc = $$$OK
        Set pDocument = ""
        Try {
            Set data = []
            &sql(DECLARE ExportCursor CURSOR FOR
                SELECT ID INTO :id 
                FROM PatientRegistry_Model.Patient
                ORDER BY ID
            )
            &sql(OPEN ExportCursor)
            If SQLCODE < 0 {
                $$$ThrowStatus(##class(%SYSTEM.Error).FromSQLCode(SQLCODE, %msg))
            }
            For {
                &sql(FETCH ExportCursor)
                Quit:SQLCODE'=0
                Set patient = ##class(PatientRegistry.Model.Patient).%OpenId(id)
                If $ISOBJECT(patient) {
                    Do data.%Push(patient.ToDynamicObject())
                }
            }

            Set fetchCode = SQLCODE
            &sql(CLOSE ExportCursor)
            If fetchCode < 0 {
                $$$ThrowStatus(##class(%SYSTEM.Error).FromSQLCode(fetchCode, %msg))
            }
            Set pDocument = {}
            Do pDocument.%Set("data", data)
            Do pDocument.%Set("meta", {"schemaVersion": (##class(PatientRegistry.Model.Patient).#SCHEMAVERSION), "count": (data.%Size())})

        } Catch ex {
            Set sc = ex.AsStatus()
        }

        Quit sc
    }

    /// Number of patients (any state), or -1 on a SQL error
    ClassMethod Count() As %Integer
    {
        Set n = 0
        &sql(SELECT COUNT(*) INTO :n FROM PatientRegistry_Model.Patient)
        If SQLCODE'=0 {
            Quit -1
        }
        Quit n
    }

    /// DEV ONLY: entry point for the debugger. Needs patient SYNTH-HOSP-A / 10000016.
    ClassMethod MergeDemo() As %Status
    {
        Set sc = ..MergeUpdate("SYNTH-HOSP-A", "10000016", {"givenName": "Debugged"}, "", .version)
        Write "ok=", $SYSTEM.Status.IsOK(sc), " version=", $GET(version), !
        Quit sc
    }

    /// Appends an audit record: when, which record (surrogate ID), which version, what, which FIELD NAMES (never values).
    ClassMethod WriteAudit(pId As %Integer, pVersion As %Integer, pAction As %String, pFields As %String = "") [ Private ]
    {
        Set n = $INCREMENT(^PatReg.Audit)
        Set ^PatReg.Audit(n) = $LISTBUILD($ZDATETIME($ZTIMESTAMP, 3, 1, 3), pId, pVersion, pAction, pFields)
    }

    ClassMethod ImportRow(pItem As %DynamicObject) As %Status [Private]
    {
        Set sc = ##class(PatientRegistry.Model.Patient).FromDynamicObject(pItem, .patient)
        If $$$ISERR(sc){
            Quit sc
        }
        Set sc = patient.%Save()
        If $$$ISOK(sc){
            Do ..WriteAudit(patient.%Id(), patient.Version, "Import", "")
        }
        Quit sc
    }

    ClassMethod Fail(pCode As %String, pText As %String) As %Status [ Private ]
    {
        Quit $$$ERROR($$$GeneralError, pCode_": "_pText)
    }
}
