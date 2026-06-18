OpenConsole()

; Supported renderers selected by the optional second command-line argument.
Enumeration
  #OutputTable
  #OutputCsv
  #OutputJson
  #OutputTree
EndEnumeration

; One decoded address-book entry from a MikroTik CDB file.
; The numeric CDB field ids are mapped to these readable column names:
;   $01 -> Address
;   $02 -> User
;   $03 -> Key
;   $04 -> Name
;   $06 -> Owner
;   $08 -> Group
;   $0B -> Note
Structure AddressRecord
  Address.s
  User.s
  Key.s
  Name.s
  Owner.s
  Group.s
  Note.s
EndStructure

; Print command-line help.
Procedure PrintUsage()
  PrintN(" ")
  PrintN("(C)heshirCa 2026")
  PrintN("Mikrotik CDB file reader")
  PrintN("Use: cdb <mikrotik_cdb_file.cdb> [CSV|JSON|TREE]")
  PrintN("Or:  cdb <mikrotik_cdb_file.cdb> /OUTPUT <CSV|JSON|TREE>")
EndProcedure

; Parse an output format value. The default is a human-readable table.
; Accepted forms:
;   cdb file.cdb
;   cdb file.cdb CSV
;   cdb file.cdb JSON
;   cdb file.cdb TREE
;   cdb file.cdb /CSV
;   cdb file.cdb /JSON
;   cdb file.cdb /TREE
;   cdb file.cdb /OUTPUT CSV
;   cdb file.cdb --format JSON
Procedure.i ParseOutputFormat(DefaultFormat.i)
  Format.i = DefaultFormat
  ParameterCount = CountProgramParameters()

  If ParameterCount >= 2
    FormatArgument.s = UCase(ProgramParameter(1))

    Select FormatArgument
      Case "CSV", "/CSV", "-CSV", "--CSV"
        Format = #OutputCsv
      Case "JSON", "/JSON", "-JSON", "--JSON"
        Format = #OutputJson
      Case "TREE", "/TREE", "-TREE", "--TREE"
        Format = #OutputTree
      Case "/OUTPUT", "-OUTPUT", "--OUTPUT", "/FORMAT", "-FORMAT", "--FORMAT"
        If ParameterCount >= 3
          ValueArgument.s = UCase(ProgramParameter(2))

          Select ValueArgument
            Case "CSV"
              Format = #OutputCsv
            Case "JSON"
              Format = #OutputJson
            Case "TREE"
              Format = #OutputTree
            Case "TABLE"
              Format = #OutputTable
            Default
              PrintN("Unknown output format: " + ProgramParameter(2))
              PrintUsage()
              End 1
          EndSelect
        Else
          PrintN("Missing output format after " + ProgramParameter(1))
          PrintUsage()
          End 1
        EndIf
      Case "TABLE"
        Format = #OutputTable
      Default
        PrintN("Unknown output option: " + ProgramParameter(1))
        PrintUsage()
        End 1
    EndSelect
  EndIf

  ProcedureReturn Format
EndProcedure

; Convert one Windows-1251 byte to a PureBasic Unicode character.
; MikroTik WinBox address-book strings in this file are stored as raw CP1251
; bytes, so printing them with Chr(byte) directly produces mojibake for
; Cyrillic text. PureBasic strings are Unicode, so every non-ASCII CP1251 code
; point has to be mapped explicitly.
Procedure.s CP1251Char(ByteValue.i)
  ; CP1251 uses the $80-$BF range for punctuation and several Cyrillic
  ; characters that are not part of the contiguous Russian alphabet block.
  Select ByteValue
    Case $80 : ProcedureReturn Chr($0402)
    Case $81 : ProcedureReturn Chr($0403)
    Case $82 : ProcedureReturn Chr($201A)
    Case $83 : ProcedureReturn Chr($0453)
    Case $84 : ProcedureReturn Chr($201E)
    Case $85 : ProcedureReturn Chr($2026)
    Case $86 : ProcedureReturn Chr($2020)
    Case $87 : ProcedureReturn Chr($2021)
    Case $88 : ProcedureReturn Chr($20AC)
    Case $89 : ProcedureReturn Chr($2030)
    Case $8A : ProcedureReturn Chr($0409)
    Case $8B : ProcedureReturn Chr($2039)
    Case $8C : ProcedureReturn Chr($040A)
    Case $8D : ProcedureReturn Chr($040C)
    Case $8E : ProcedureReturn Chr($040B)
    Case $8F : ProcedureReturn Chr($040F)
    Case $90 : ProcedureReturn Chr($0452)
    Case $91 : ProcedureReturn Chr($2018)
    Case $92 : ProcedureReturn Chr($2019)
    Case $93 : ProcedureReturn Chr($201C)
    Case $94 : ProcedureReturn Chr($201D)
    Case $95 : ProcedureReturn Chr($2022)
    Case $96 : ProcedureReturn Chr($2013)
    Case $97 : ProcedureReturn Chr($2014)
    Case $99 : ProcedureReturn Chr($2122)
    Case $9A : ProcedureReturn Chr($0459)
    Case $9B : ProcedureReturn Chr($203A)
    Case $9C : ProcedureReturn Chr($045A)
    Case $9D : ProcedureReturn Chr($045C)
    Case $9E : ProcedureReturn Chr($045B)
    Case $9F : ProcedureReturn Chr($045F)
    Case $A0 : ProcedureReturn Chr($00A0)
    Case $A1 : ProcedureReturn Chr($040E)
    Case $A2 : ProcedureReturn Chr($045E)
    Case $A3 : ProcedureReturn Chr($0408)
    Case $A4 : ProcedureReturn Chr($00A4)
    Case $A5 : ProcedureReturn Chr($0490)
    Case $A6 : ProcedureReturn Chr($00A6)
    Case $A7 : ProcedureReturn Chr($00A7)
    Case $A8 : ProcedureReturn Chr($0401)
    Case $A9 : ProcedureReturn Chr($00A9)
    Case $AA : ProcedureReturn Chr($0404)
    Case $AB : ProcedureReturn Chr($00AB)
    Case $AC : ProcedureReturn Chr($00AC)
    Case $AD : ProcedureReturn Chr($00AD)
    Case $AE : ProcedureReturn Chr($00AE)
    Case $AF : ProcedureReturn Chr($0407)
    Case $B0 : ProcedureReturn Chr($00B0)
    Case $B1 : ProcedureReturn Chr($00B1)
    Case $B2 : ProcedureReturn Chr($0406)
    Case $B3 : ProcedureReturn Chr($0456)
    Case $B4 : ProcedureReturn Chr($0491)
    Case $B5 : ProcedureReturn Chr($00B5)
    Case $B6 : ProcedureReturn Chr($00B6)
    Case $B7 : ProcedureReturn Chr($00B7)
    Case $B8 : ProcedureReturn Chr($0451)
    Case $B9 : ProcedureReturn Chr($2116)
    Case $BA : ProcedureReturn Chr($0454)
    Case $BB : ProcedureReturn Chr($00BB)
    Case $BC : ProcedureReturn Chr($0458)
    Case $BD : ProcedureReturn Chr($0405)
    Case $BE : ProcedureReturn Chr($0455)
    Case $BF : ProcedureReturn Chr($0457)
  EndSelect

  ; The main Russian alphabet in CP1251 is contiguous:
  ; $C0-$FF maps to Unicode $0410-$044F.
  If ByteValue >= $C0 And ByteValue <= $FF
    ProcedureReturn Chr($0410 + ByteValue - $C0)
  EndIf

  ; ASCII and control characters are identical for the values used here.
  ProcedureReturn Chr(ByteValue)
EndProcedure

; Decode a CP1251 byte sequence from the CDB buffer into a PureBasic string.
; The buffer pointer points directly into the loaded file; Length is the string
; length taken from the CDB field header.
Procedure.s DecodeCP1251(*Buffer, Length.i)
  Result.s = ""

  For i = 0 To Length - 1
    Result + CP1251Char(PeekA(*Buffer + i) & $FF)
  Next

  ProcedureReturn Result
EndProcedure

; Detect the common address-item header inside the MikroTik CDB stream.
; Observed records start with several service bytes, then this stable marker:
;   00 00 00 4D 32
; Some files have an item-size byte immediately before the marker. The older
; file also contains 00 FF 88 00 inside the header, but newer files do not
; always use that sequence. Therefore the 00 00 00 4D 32 marker is the safer
; record boundary for both tested file variants.
Procedure.i IsRecordHeader(*Buffer, Position.i, FileLength.i)
  If Position <= FileLength - 5
    If PeekA(*Buffer + Position) = 0 And
       PeekA(*Buffer + Position + 1) = 0 And
       PeekA(*Buffer + Position + 2) = 0 And
       PeekA(*Buffer + Position + 3) = $4D And
       PeekA(*Buffer + Position + 4) = $32
      ProcedureReturn #True
    EndIf
  EndIf

  ProcedureReturn #False
EndProcedure

; Small helper used while calculating column widths.
Procedure.i MaxInt(Value1.i, Value2.i)
  If Value1 > Value2
    ProcedureReturn Value1
  EndIf

  ProcedureReturn Value2
EndProcedure

; Build a repeated text fragment. Used for ASCII table borders.
Procedure.s RepeatText(Text.s, Count.i)
  Result.s = ""

  For i = 1 To Count
    Result + Text
  Next

  ProcedureReturn Result
EndProcedure

; Pad text on the right so all console table columns have a stable width.
Procedure.s PadRight(Text.s, Width.i)
  If Len(Text) < Width
    ProcedureReturn Text + Space(Width - Len(Text))
  EndIf

  ProcedureReturn Text
EndProcedure

; Print a horizontal separator for the current table layout.
; The +2 in every column accounts for one leading and one trailing space.
Procedure PrintSeparator(WName.i, WAddress.i, WUser.i, WGroup.i, WOwner.i, WKey.i, WNote.i)
  PrintN("+" + RepeatText("-", WName + 2) +
         "+" + RepeatText("-", WAddress + 2) +
         "+" + RepeatText("-", WUser + 2) +
         "+" + RepeatText("-", WGroup + 2) +
         "+" + RepeatText("-", WOwner + 2) +
         "+" + RepeatText("-", WKey + 2) +
         "+" + RepeatText("-", WNote + 2) + "+")
EndProcedure

; Print one data row or the header row using the same column widths.
Procedure PrintTableRow(Name.s, Address.s, User.s, Group.s, Owner.s, Key.s, Note.s,
                        WName.i, WAddress.i, WUser.i, WGroup.i, WOwner.i, WKey.i, WNote.i)
  PrintN("| " + PadRight(Name, WName) +
         " | " + PadRight(Address, WAddress) +
         " | " + PadRight(User, WUser) +
         " | " + PadRight(Group, WGroup) +
         " | " + PadRight(Owner, WOwner) +
         " | " + PadRight(Key, WKey) +
         " | " + PadRight(Note, WNote) + " |")
EndProcedure

; Print all decoded address records as an aligned ASCII table.
; The first pass finds the widest value in every column, then the second pass
; prints the header and all rows using those widths.
Procedure PrintRecords(List Records.AddressRecord())
  ; Start with header widths so even an empty file still has a valid table.
  WName = Len("Name")
  WAddress = Len("Address")
  WUser = Len("User")
  WGroup = Len("Group")
  WOwner = Len("Owner")
  WKey = Len("Key")
  WNote = Len("Note")

  ; Grow every width to fit the longest decoded value in that column.
  ForEach Records()
    WName = MaxInt(WName, Len(Records()\Name))
    WAddress = MaxInt(WAddress, Len(Records()\Address))
    WUser = MaxInt(WUser, Len(Records()\User))
    WGroup = MaxInt(WGroup, Len(Records()\Group))
    WOwner = MaxInt(WOwner, Len(Records()\Owner))
    WKey = MaxInt(WKey, Len(Records()\Key))
    WNote = MaxInt(WNote, Len(Records()\Note))
  Next

  ; Header.
  PrintSeparator(WName, WAddress, WUser, WGroup, WOwner, WKey, WNote)
  PrintTableRow("Name", "Address", "User", "Group", "Owner", "Key", "Note",
                WName, WAddress, WUser, WGroup, WOwner, WKey, WNote)
  PrintSeparator(WName, WAddress, WUser, WGroup, WOwner, WKey, WNote)

  ; Body.
  ForEach Records()
    PrintTableRow(Records()\Name, Records()\Address, Records()\User, Records()\Group,
                  Records()\Owner, Records()\Key, Records()\Note,
                  WName, WAddress, WUser, WGroup, WOwner, WKey, WNote)
  Next

  PrintSeparator(WName, WAddress, WUser, WGroup, WOwner, WKey, WNote)
EndProcedure

; Escape one CSV cell according to RFC 4180 rules:
; wrap the value in double quotes and double any quote inside the value.
Procedure.s CsvCell(Text.s)
  ProcedureReturn Chr(34) + ReplaceString(Text, Chr(34), Chr(34) + Chr(34)) + Chr(34)
EndProcedure

; Print decoded records as CSV. The column order matches the table output.
Procedure PrintRecordsCsv(List Records.AddressRecord())
  PrintN(CsvCell("Name") + "," +
         CsvCell("Address") + "," +
         CsvCell("User") + "," +
         CsvCell("Group") + "," +
         CsvCell("Owner") + "," +
         CsvCell("Key") + "," +
         CsvCell("Note"))

  ForEach Records()
    PrintN(CsvCell(Records()\Name) + "," +
           CsvCell(Records()\Address) + "," +
           CsvCell(Records()\User) + "," +
           CsvCell(Records()\Group) + "," +
           CsvCell(Records()\Owner) + "," +
           CsvCell(Records()\Key) + "," +
           CsvCell(Records()\Note))
  Next
EndProcedure

; Escape a string for JSON output. Unicode characters can be printed as-is;
; only quotes, backslashes, and JSON control characters need escaping.
Procedure.s JsonString(Text.s)
  Result.s = Chr(34)

  For i = 1 To Len(Text)
    Char.s = Mid(Text, i, 1)
    Code = Asc(Char)

    Select Code
      Case 8
        Result + "\b"
      Case 9
        Result + "\t"
      Case 10
        Result + "\n"
      Case 12
        Result + "\f"
      Case 13
        Result + "\r"
      Case 34
        Result + "\" + Chr(34)
      Case 92
        Result + "\\"
      Default
        If Code < 32
          Result + "\u" + Right("0000" + Hex(Code), 4)
        Else
          Result + Char
        EndIf
    EndSelect
  Next

  Result + Chr(34)
  ProcedureReturn Result
EndProcedure

; Print decoded records as a JSON array of objects.
Procedure PrintRecordsJson(List Records.AddressRecord())
  PrintN("[")

  ForEach Records()
    Line.s = "  {" +
             Chr(34) + "Name" + Chr(34) + ": " + JsonString(Records()\Name) + ", " +
             Chr(34) + "Address" + Chr(34) + ": " + JsonString(Records()\Address) + ", " +
             Chr(34) + "User" + Chr(34) + ": " + JsonString(Records()\User) + ", " +
             Chr(34) + "Group" + Chr(34) + ": " + JsonString(Records()\Group) + ", " +
             Chr(34) + "Owner" + Chr(34) + ": " + JsonString(Records()\Owner) + ", " +
             Chr(34) + "Key" + Chr(34) + ": " + JsonString(Records()\Key) + ", " +
             Chr(34) + "Note" + Chr(34) + ": " + JsonString(Records()\Note) + "}"

    If ListIndex(Records()) < ListSize(Records()) - 1
      Line + ","
    EndIf

    PrintN(Line)
  Next

  PrintN("]")
EndProcedure

; Return a stable group title for tree output. Empty group names are possible in
; malformed or partial files, so they are displayed explicitly.
Procedure.s TreeGroupTitle(GroupName.s)
  If GroupName = ""
    ProcedureReturn "(no group)"
  EndIf

  ProcedureReturn GroupName
EndProcedure

; Return the visible record label for tree output. Prefer the human-readable
; name, then fall back to the address, then to a generic placeholder.
Procedure.s TreeRecordTitle(Name.s, Address.s)
  If Name <> ""
    ProcedureReturn Name
  EndIf

  If Address <> ""
    ProcedureReturn Address
  EndIf

  ProcedureReturn "(unnamed)"
EndProcedure

; Print one field under a record node.
Procedure PrintTreeField(Prefix.s, IsLast.i, Label.s, Value.s)
  If IsLast
    PrintN(Prefix + "`-- " + Label + ": " + Value)
  Else
    PrintN(Prefix + "|-- " + Label + ": " + Value)
  EndIf
EndProcedure

; Print decoded records as a group-based tree. Group names are roots, records
; are children, and selected record fields are printed as leaves.
Procedure PrintRecordsTree(List Records.AddressRecord())
  NewList Groups.s()
  NewMap SeenGroups.i()

  ; Preserve the original CDB order: add each group the first time it appears.
  ForEach Records()
    GroupKey.s = Records()\Group

    If FindMapElement(SeenGroups(), GroupKey) = 0
      AddMapElement(SeenGroups(), GroupKey)
      SeenGroups() = #True

      AddElement(Groups())
      Groups() = GroupKey
    EndIf
  Next

  ForEach Groups()
    If ListIndex(Groups()) > 0
      PrintN("")
    EndIf

    PrintN(TreeGroupTitle(Groups()))

    ; Count records in this group before printing them so the last child can use
    ; the closing tree branch (`-- instead of |--).
    GroupRecordCount = 0
    ForEach Records()
      If Records()\Group = Groups()
        GroupRecordCount + 1
      EndIf
    Next

    GroupRecordIndex = 0
    ForEach Records()
      If Records()\Group = Groups()
        GroupRecordIndex + 1
        IsLastRecord = Bool(GroupRecordIndex = GroupRecordCount)

        If IsLastRecord
          RecordPrefix.s = "    "
          FieldPrefix.s = "    "
          PrintN("`-- " + TreeRecordTitle(Records()\Name, Records()\Address))
        Else
          RecordPrefix = "|   "
          FieldPrefix = "|   "
          PrintN("|-- " + TreeRecordTitle(Records()\Name, Records()\Address))
        EndIf

        ; Address, User, Owner, and Key are always printed. Note is optional, so
        ; it changes which field should be drawn as the last tree leaf.
        FieldCount = 4
        If Records()\Note <> ""
          FieldCount + 1
        EndIf

        PrintTreeField(FieldPrefix, Bool(FieldCount = 1), "Address", Records()\Address)
        PrintTreeField(FieldPrefix, Bool(FieldCount = 2), "User", Records()\User)
        PrintTreeField(FieldPrefix, Bool(FieldCount = 3), "Owner", Records()\Owner)
        PrintTreeField(FieldPrefix, Bool(FieldCount = 4), "Key", Records()\Key)

        If Records()\Note <> ""
          PrintTreeField(FieldPrefix, #True, "Note", Records()\Note)
        EndIf
      EndIf
    Next
  Next
EndProcedure

If CountProgramParameters() <> 0
  FileName.s = ProgramParameter()
  OutputFormat = ParseOutputFormat(#OutputTable)

  ; Open the CDB file shared-read so it can still be inspected by other tools
  ; while this program is reading it.
  If ReadFile(0, FileName, #PB_File_SharedRead)
    Length = Lof(0)
    *MemoryID = AllocateMemory(Length)

    If *MemoryID
      ; Load the complete file into memory. The parser below needs random byte
      ; access and frequently looks ahead a few bytes.
      ReadData(0, *MemoryID, Length)

      NewList Records.AddressRecord()

      ; Temporary fields for the record currently being decoded. A record is
      ; finalized when the parser encounters the next header marker.
      Address.s = ""
      User.s = ""
      Key.s = ""
      Name.s = ""
      Owner.s = ""
      Group.s = ""
      Note.s = ""
      HaveFields = #False
      i = 0

      ; Walk through the file byte by byte. Only two byte patterns are relevant:
      ;   00 00 00 4D 32
      ;     Stable marker found inside each stored address-book item header.
      ;     It is used as the record boundary.
      ;
      ;   <field-id> 00 00 21 <length> <cp1251 bytes>
      ;     String field payload. The length byte tells exactly how many bytes
      ;     belong to the string, so service bytes after the string are ignored
      ;     instead of being printed as garbage characters.
      While i <= Length - 5
        If IsRecordHeader(*MemoryID, i, Length)
          ; A new header marker means the previous item is complete.
          ; Ignore leading markers before any fields have been collected.
          If HaveFields
            AddElement(Records())
            Records()\Address = Address
            Records()\User = User
            Records()\Key = Key
            Records()\Name = Name
            Records()\Owner = Owner
            Records()\Group = Group
            Records()\Note = Note

            ; Clear temporary values before collecting the next record.
            Address = ""
            User = ""
            Key = ""
            Name = ""
            Owner = ""
            Group = ""
            Note = ""
            HaveFields = #False
          EndIf

          i + 5

        ElseIf PeekA(*MemoryID + i + 1) = 0 And PeekA(*MemoryID + i + 2) = 0 And PeekA(*MemoryID + i + 3) = $21
          FieldId = PeekA(*MemoryID + i) & $FF
          StringLength = PeekA(*MemoryID + i + 4) & $FF

          ; Make sure the declared string length stays inside the loaded file.
          ; If it does not, continue scanning one byte later rather than reading
          ; past the buffer end.
          If i + 5 + StringLength <= Length
            FieldValue.s = DecodeCP1251(*MemoryID + i + 5, StringLength)
            HaveFields = #True

            ; Put the decoded string into the proper output column.
            ; Unknown field ids are skipped, but scanning continues normally.
            Select FieldId
              Case $01
                Address = FieldValue
              Case $02
                User = FieldValue
              Case $03
                Key = FieldValue
              Case $04
                Name = FieldValue
              Case $06
                Owner = FieldValue
              Case $08
                Group = FieldValue
              Case $0B
                Note = FieldValue
            EndSelect

            ; Jump over the complete encoded string. This is the important part
            ; that prevents trailing record metadata bytes from being printed.
            i + 5 + StringLength
          Else
            i + 1
          EndIf

        Else
          i + 1
        EndIf
      Wend

      ; The last record is not followed by another marker, so flush it after
      ; the scan finishes.
      If HaveFields
        AddElement(Records())
        Records()\Address = Address
        Records()\User = User
        Records()\Key = Key
        Records()\Name = Name
        Records()\Owner = Owner
        Records()\Group = Group
        Records()\Note = Note
      EndIf

      ; Render the decoded records only after the full file was parsed, because
      ; table column widths depend on all rows. CSV and JSON also benefit from
      ; having one shared parsed representation.
      Select OutputFormat
        Case #OutputCsv
          PrintRecordsCsv(Records())
        Case #OutputJson
          PrintRecordsJson(Records())
        Case #OutputTree
          PrintRecordsTree(Records())
        Default
          PrintRecords(Records())
      EndSelect

      FreeMemory(*MemoryID)
    EndIf

    CloseFile(0)
  Else
    PrintN("Can't open file: " + FileName)
  EndIf
Else
  PrintUsage()
EndIf

; PureBasic IDE metadata.
; IDE Options = PureBasic 6.40 (Windows - x86)
; ExecutableFormat = Console
; EnableXP
; DPIAware
; Executable = cdb.exe
