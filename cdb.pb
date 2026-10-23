; MikroTik WinBox CDB reader and CP1251 to UTF-8 converter preserving v3 wrapper.
; Experimental writer: always creates a new file. Test with a backup.
; PureBasic 6.x, console executable. No external dependencies.
; Copyright (C) CheshirCa 2026
; https://t.me/cheshircanest

EnableExplicit
OpenConsole()

Enumeration
  #FmtTable
  #FmtCSV
  #FmtJSON
  #FmtTree
EndEnumeration

Structure Entry
  Address.s
  Login.s
  Comment.s
  Group.s
  Session.s
  Workspace.s
  RoMON.s
  Password.s
  Kind.s
  DisplayName.s
  KeepPassword.s
  HavePassword.i
  UnknownFields.i
EndStructure

Global NewList Entries.Entry()
Global SourceVersion.i, InputBytes.i, *Input, EntryCount.i

Procedure.i B(*P, At.i)
  ProcedureReturn PeekA(*P + At) & $FF
EndProcedure

Procedure.i LE32(*P, At.i)
  ProcedureReturn B(*P,At) | (B(*P,At+1)<<8) | (B(*P,At+2)<<16) | (B(*P,At+3)<<24)
EndProcedure

Procedure.s Decode1251(*P, N.i)
  Protected i.i, x.i, r.s = ""
  For i=0 To N-1
    x=B(*P,i)
    If x >= $C0
      x=$0410+x-$C0
    Else
      Select x
        Case $80 : x=$0402
        Case $81 : x=$0403
        Case $82 : x=$201A
        Case $83 : x=$0453
        Case $84 : x=$201E
        Case $85 : x=$2026
        Case $86 : x=$2020
        Case $87 : x=$2021
        Case $88 : x=$20AC
        Case $89 : x=$2030
        Case $8A : x=$0409
        Case $8B : x=$2039
        Case $8C : x=$040A
        Case $8D : x=$040C
        Case $8E : x=$040B
        Case $8F : x=$040F
        Case $90 : x=$0452
        Case $91 : x=$2018
        Case $92 : x=$2019
        Case $93 : x=$201C
        Case $94 : x=$201D
        Case $95 : x=$2022
        Case $96 : x=$2013
        Case $97 : x=$2014
        Case $99 : x=$2122
        Case $9A : x=$0459
        Case $9B : x=$203A
        Case $9C : x=$045A
        Case $9D : x=$045C
        Case $9E : x=$045B
        Case $9F : x=$045F
        Case $A0 : x=$00A0
        Case $A1 : x=$040E
        Case $A2 : x=$045E
        Case $A3 : x=$0408
        Case $A4 : x=$00A4
        Case $A5 : x=$0490
        Case $A6 : x=$00A6
        Case $A7 : x=$00A7
        Case $A8 : x=$0401
        Case $A9 : x=$00A9
        Case $AA : x=$0404
        Case $AB : x=$00AB
        Case $AC : x=$00AC
        Case $AD : x=$00AD
        Case $AE : x=$00AE
        Case $AF : x=$0407
        Case $B0 : x=$00B0
        Case $B1 : x=$00B1
        Case $B2 : x=$0406
        Case $B3 : x=$0456
        Case $B4 : x=$0491
        Case $B5 : x=$00B5
        Case $B6 : x=$00B6
        Case $B7 : x=$00B7
        Case $B8 : x=$0451
        Case $B9 : x=$2116
        Case $BA : x=$0454
        Case $BB : x=$00BB
        Case $BC : x=$0458
        Case $BD : x=$0405
        Case $BE : x=$0455
        Case $BF : x=$0457
      EndSelect
    EndIf
    r + Chr(x)
  Next
  ProcedureReturn r
EndProcedure

Procedure.i IsUTF8(*Data, N.i)
  Protected i.i, b0.i, b1.i, b2.i, b3.i, count.i
  i=0
  While i<N
    b0=B(*Data,i)
    If b0<$80
      i+1 : Continue
    EndIf
    If b0>=$C2 And b0<=$DF
      count=2
    ElseIf b0>=$E0 And b0<=$EF
      count=3
    ElseIf b0>=$F0 And b0<=$F4
      count=4
    Else
      ProcedureReturn #False
    EndIf
    If i+count>N : ProcedureReturn #False : EndIf
    b1=B(*Data,i+1)
    If b1<$80 Or b1>$BF : ProcedureReturn #False : EndIf
    If count>=3
      b2=B(*Data,i+2)
      If b2<$80 Or b2>$BF : ProcedureReturn #False : EndIf
      If b0=$E0 And b1<$A0 : ProcedureReturn #False : EndIf
      If b0=$ED And b1>=$A0 : ProcedureReturn #False : EndIf
    EndIf
    If count=4
      b3=B(*Data,i+3)
      If b3<$80 Or b3>$BF : ProcedureReturn #False : EndIf
      If b0=$F0 And b1<$90 : ProcedureReturn #False : EndIf
      If b0=$F4 And b1>$8F : ProcedureReturn #False : EndIf
    EndIf
    i+count
  Wend
  ProcedureReturn #True
EndProcedure

Procedure.s DecodeText(*P, N.i)
  If N=0 : ProcedureReturn "" : EndIf
  ; v3 may contain UTF-8 after conversion, while native v3 uses CP1251.
  ; Select encoding for each textual field, not for the entire file.
  If SourceVersion=4 Or IsUTF8(*P,N)
    Protected *tmp = AllocateMemory(N+1)
    Protected decoded.s
    If *tmp=0 : ProcedureReturn "" : EndIf
    CopyMemory(*P,*tmp,N)
    PokeA(*tmp+N,0)
    decoded=PeekS(*tmp,-1,#PB_UTF8)
    FreeMemory(*tmp)
    ProcedureReturn decoded
  EndIf
  ProcedureReturn Decode1251(*P,N)
EndProcedure

Procedure.i LoadDatabase(FileName.s)
  Protected f.i, length.i, pos.i, n.i, stop.i, k.i, p.i, fid.i, vlen.i, unknown.i
  Protected value.s
  f=ReadFile(#PB_Any,FileName,#PB_File_SharedRead)
  If f=0 : PrintN("ERROR: Cannot open " + FileName) : ProcedureReturn #False : EndIf
  length=Lof(f)
  If length<14
    CloseFile(f) : PrintN("ERROR: File too short") : ProcedureReturn #False
  EndIf
  *Input=AllocateMemory(length)
  If *Input=0
    CloseFile(f) : PrintN("ERROR: Out of memory") : ProcedureReturn #False
  EndIf
  InputBytes=length
  If ReadData(f,*Input,length)<>length
    CloseFile(f) : PrintN("ERROR: Read error") : ProcedureReturn #False
  EndIf
  CloseFile(f)
  If B(*Input,0)<>$0D Or B(*Input,1)<>$F0 Or B(*Input,2)<>$1D Or B(*Input,3)<>$C0
    PrintN("ERROR: Invalid CDB signature") : ProcedureReturn #False
  EndIf
  pos=4
  SourceVersion=0
  ClearList(Entries())
  While pos<length
    If pos+6>length : PrintN("ERROR: Truncated record header") : ProcedureReturn #False : EndIf
    n=LE32(*Input,pos)
    If n<6 Or n>length-pos-4 Or B(*Input,pos+4)<>$4D Or B(*Input,pos+5)<>$32
      PrintN("ERROR: Invalid record at byte " + Str(pos)) : ProcedureReturn #False
    EndIf
    stop=pos+4+n
    k=pos+6
    If k+4>stop
      PrintN("ERROR: Truncated record type at byte "+Str(pos)) : ProcedureReturn #False
    EndIf
    If B(*Input,k)=$01 And B(*Input,k+1)=$00 And B(*Input,k+2)=$FF And B(*Input,k+3)=$88
      If SourceVersion=4
        PrintN("ERROR: Mixed WinBox 3 and 4 records") : ProcedureReturn #False
      EndIf
      SourceVersion=3
    ElseIf (B(*Input,k)=$07 And B(*Input,k+1)=0 And B(*Input,k+2)=0 And B(*Input,k+3)=1) Or (B(*Input,k)=$05 And B(*Input,k+1)=0 And B(*Input,k+2)=0 And B(*Input,k+3)=0)
      If SourceVersion=3
        PrintN("ERROR: Mixed WinBox 3 and 4 records") : ProcedureReturn #False
      EndIf
      SourceVersion=4
    Else
      PrintN("ERROR: Unknown record kind at byte " + Str(pos)) : ProcedureReturn #False
    EndIf
    AddElement(Entries())
    Entries()\Kind=RSet(Hex(B(*Input,k)),2,"0")+RSet(Hex(B(*Input,k+1)),2,"0")+RSet(Hex(B(*Input,k+2)),2,"0")+RSet(Hex(B(*Input,k+3)),2,"0")
    ; Identify strings inside this strictly length-bounded record. WinBox 3 uses
    ; a larger wrapper. Recognize both explicit and implicit name framing.
    p=pos+10
    While p+5<=stop
      fid=-1
      ; The implicit (09 00 FE 21) field represents connection name (id 0).
      If B(*Input,p)=$09 And B(*Input,p+1)=0 And B(*Input,p+2)=$FE And B(*Input,p+3)=$21
        fid=0
      ElseIf B(*Input,p+1)=0 And B(*Input,p+2)=0 And B(*Input,p+3)=$21
        fid=B(*Input,p)
      EndIf
      If fid>=0
        vlen=B(*Input,p+4)
        If p+5+vlen<=stop
          value=DecodeText(*Input+p+5,vlen)
          Select fid
            Case 0 : Entries()\DisplayName=value
            Case 1 : Entries()\Address=value
            Case 2 : Entries()\Login=value
            Case 3 : Entries()\Password=value : If vlen>0 : Entries()\HavePassword=1 : EndIf
            Case 4 : Entries()\Comment=value
            Case 6
              If SourceVersion=4
                Entries()\KeepPassword=value
              Else
                Entries()\Session=value
              EndIf
            Case 8 : Entries()\Group=value
            Case 11 : Entries()\RoMON=value
            Case 12 : Entries()\Workspace=value
            Default : Entries()\UnknownFields+1
          EndSelect
          p+5+vlen
          Continue
        EndIf
      EndIf
      p+1
    Wend
    pos=stop
  Wend
  EntryCount=ListSize(Entries())
  If SourceVersion=0
    PrintN("ERROR: CDB version could not be determined unambiguously")
    ProcedureReturn #False
  EndIf
  ProcedureReturn #True
EndProcedure

Procedure.s JsonQuote(v.s)
  Protected i.i, c.i, s.s=Chr(34), ch.s
  For i=1 To Len(v)
    ch=Mid(v,i,1) : c=Asc(ch)
    Select c
      Case 34 : s+"\"+Chr(34)
      Case 92 : s+"\\"
      Case 10 : s+"\n"
      Case 13 : s+"\r"
      Case 9 : s+"\t"
      Default
        If c<32 : s+"\u"+RSet(Hex(c),4,"0") : Else : s+ch : EndIf
    EndSelect
  Next
  ProcedureReturn s+Chr(34)
EndProcedure

Procedure.s CSVCell(Value.s)
  Protected s.s = ReplaceString(Value, Chr(34), Chr(34)+Chr(34))
  ProcedureReturn Chr(34)+s+Chr(34)
EndProcedure

Procedure.s VersionLabel()
  ProcedureReturn "WinBox " + Str(SourceVersion) + ".x CDB"
EndProcedure

; Preserve original seven-column table and machine-readable export formats.
Procedure.s PadField(Value.s, Width.i)
  If Len(Value)<Width
    ProcedureReturn Value+Space(Width-Len(Value))
  EndIf
  ProcedureReturn Value
EndProcedure

Procedure.s Separator(Width.i)
  ProcedureReturn LSet("",Width+2,"-")
EndProcedure

Procedure.i MaxInt(A.i, B.i)
  If A >= B
    ProcedureReturn A
  EndIf
  ProcedureReturn B
EndProcedure

Procedure PrintOutput(Format.i)
  Protected wName.i=4, wAddress.i=7, wUser.i=4, wGroup.i=5
  Protected wOwner.i=5, wKey.i=3, wNote.i=4
  Protected line.s, name.s, idx.i=0

  ; Do not prepend metadata to CSV or JSON: preserve the original schema.
  If Format=#FmtTable Or Format=#FmtTree
    PrintN("CDB format: " + VersionLabel() + " | Records: " + Str(EntryCount))
    PrintN("")
  EndIf

  Select Format
    Case #FmtTable
      ForEach Entries()
        wName=MaxInt(wName,Len(Entries()\Comment))
        wAddress=MaxInt(wAddress,Len(Entries()\Address))
        wUser=MaxInt(wUser,Len(Entries()\Login))
        wGroup=MaxInt(wGroup,Len(Entries()\Group))
        wOwner=MaxInt(wOwner,Len(Entries()\Session))
        wKey=MaxInt(wKey,Len(Entries()\Password))
        wNote=MaxInt(wNote,Len(Entries()\RoMON))
      Next
      line="+"+Separator(wName)+"+"+Separator(wAddress)+"+"+Separator(wUser)+"+"+Separator(wGroup)+"+"+Separator(wOwner)+"+"+Separator(wKey)+"+"+Separator(wNote)+"+"
      PrintN(line)
      PrintN("| "+PadField("Name",wName)+" | "+PadField("Address",wAddress)+" | "+PadField("User",wUser)+" | "+PadField("Group",wGroup)+" | "+PadField("Owner",wOwner)+" | "+PadField("Key",wKey)+" | "+PadField("Note",wNote)+" |")
      PrintN(line)
      ForEach Entries()
        PrintN("| "+PadField(Entries()\Comment,wName)+" | "+PadField(Entries()\Address,wAddress)+" | "+PadField(Entries()\Login,wUser)+" | "+PadField(Entries()\Group,wGroup)+" | "+PadField(Entries()\Session,wOwner)+" | "+PadField(Entries()\Password,wKey)+" | "+PadField(Entries()\RoMON,wNote)+" |")
      Next
      PrintN(line)
    Case #FmtCSV
      PrintN(CSVCell("Name")+","+CSVCell("Address")+","+CSVCell("User")+","+CSVCell("Group")+","+CSVCell("Owner")+","+CSVCell("Key")+","+CSVCell("Note"))
      ForEach Entries()
        PrintN(CSVCell(Entries()\Comment)+","+CSVCell(Entries()\Address)+","+CSVCell(Entries()\Login)+","+CSVCell(Entries()\Group)+","+CSVCell(Entries()\Session)+","+CSVCell(Entries()\Password)+","+CSVCell(Entries()\RoMON))
      Next
    Case #FmtJSON
      PrintN("[")
      ForEach Entries()
        line="  {"+JsonQuote("Name")+": "+JsonQuote(Entries()\Comment)+", "+JsonQuote("Address")+": "+JsonQuote(Entries()\Address)+", "+JsonQuote("User")+": "+JsonQuote(Entries()\Login)+", "+JsonQuote("Group")+": "+JsonQuote(Entries()\Group)+", "+JsonQuote("Owner")+": "+JsonQuote(Entries()\Session)+", "+JsonQuote("Key")+": "+JsonQuote(Entries()\Password)+", "+JsonQuote("Note")+": "+JsonQuote(Entries()\RoMON)+"}"
        If idx<EntryCount-1 : line+"," : EndIf
        PrintN(line)
        idx+1
      Next
      PrintN("]")
    Case #FmtTree
      ; Tree remains explicitly selected; simple grouping is retained.
      NewList Groups.s()
      NewMap Seen.i()
      ForEach Entries()
        If FindMapElement(Seen(),Entries()\Group)=0
          AddMapElement(Seen(),Entries()\Group)
          Seen()=1
          AddElement(Groups())
          Groups()=Entries()\Group
        EndIf
      Next
      ForEach Groups()
        name=Groups()
        If name="" : name="(no group)" : EndIf
        PrintN(name)
        ForEach Entries()
          If Entries()\Group=Groups()
            PrintN("|-- "+Entries()\Comment)
            PrintN("|   Address: "+Entries()\Address+" | User: "+Entries()\Login+" | Owner: "+Entries()\Session+" | Key: "+Entries()\Password)
            If Entries()\RoMON<>"" : PrintN("|   Note: "+Entries()\RoMON) : EndIf
          EndIf
        Next
        PrintN("")
      Next
  EndSelect
EndProcedure

Procedure.i UTF8Size(v.s)
  ProcedureReturn StringByteLength(v,#PB_UTF8)
EndProcedure

Procedure.i CheckField(v.s, label.s, index.i)
  If UTF8Size(v)>254
    PrintN("ERROR: record " + Str(index) + ", field " + label + ": UTF-8 exceeds 254 bytes")
    ProcedureReturn #False
  EndIf
  ProcedureReturn #True
EndProcedure

Procedure WriteField(f.i, id.i, v.s, implicit.i=#False)
  Protected n.i=UTF8Size(v), *buf
  If implicit
    WriteAsciiCharacter(f,$09) : WriteAsciiCharacter(f,$00)
    WriteAsciiCharacter(f,$FE) : WriteAsciiCharacter(f,$21)
  Else
    WriteAsciiCharacter(f,id) : WriteAsciiCharacter(f,0)
    WriteAsciiCharacter(f,0) : WriteAsciiCharacter(f,$21)
  EndIf
  WriteAsciiCharacter(f,n)
  If n>0
    *buf=AllocateMemory(n+1)
    If *buf
      PokeS(*buf,v,-1,#PB_UTF8)
      WriteData(f,*buf,n)
      FreeMemory(*buf)
    EndIf
  EndIf
EndProcedure

Procedure.i ConvertFile(Src.s,Dst.s)
  Protected f.i, pos.i, recordLen.i, recordEnd.i, start.i, p.i, cursor.i
  Protected field.i, fieldLen.i, nextField.i, delta.i, recordNewLen.i
  Protected newLen.i, *utf8, value.s, changed.i, total.i, recNo.i
  Protected *out, outLen.i, capacity.i, outPos.i, recordStart.i, checkPos.i, checkLen.i

  If LCase(Src)=LCase(Dst)
    PrintN("ERROR: source and destination must differ")
    ProcedureReturn #False
  EndIf
  If FileSize(Dst)>=0
    PrintN("ERROR: destination already exists: "+Dst)
    ProcedureReturn #False
  EndIf
  If LoadDatabase(Src)=0 : ProcedureReturn #False : EndIf
  PrintN("Source format: WinBox "+Str(SourceVersion)+".x; records: "+Str(EntryCount))
  If SourceVersion<>3
    PrintN("ERROR: this test mode accepts WinBox 3.x CDB only")
    ProcedureReturn #False
  EndIf

  ; Preserve the v3 record wrapper, all binary fields and passwords. Only
  ; rewrite selected text values. Allocate a separate output memory buffer.
  capacity=InputBytes*3+1024
  *out=AllocateMemory(capacity)
  If *out=0 : PrintN("ERROR: out of memory") : ProcedureReturn #False : EndIf
  CopyMemory(*Input,*out,4)
  outPos=4
  pos=4
  While pos<InputBytes
    recordLen=LE32(*Input,pos)
    recordEnd=pos+4+recordLen
    If recordLen<10 Or recordEnd>InputBytes Or recordEnd<=pos
      PrintN("ERROR: invalid record length at "+Str(pos))
      FreeMemory(*out)
      ProcedureReturn #False
    EndIf
    recNo+1
    recordStart=outPos
    CopyMemory(*Input+pos,*out+outPos,4)
    outPos+4
    cursor=pos+4
    p=pos+10
    While p+5<=recordEnd
      field=-1
      If B(*Input,p+1)=0 And B(*Input,p+2)=0 And B(*Input,p+3)=$21
        field=B(*Input,p)
      EndIf
      If field>=0
        fieldLen=B(*Input,p+4)
        nextField=p+5+fieldLen
        If nextField<=recordEnd
          ; Copy header and non-text payload bytes unchanged. Scan every
          ; length-framed field to avoid false hits inside its payload.
          Select field
            Case 4,6,8,11 ; Display comment, owner/session, group, note. Never password (3).
              ; Only convert high-bit strings. ASCII strings are byte-identical.
              changed=0
              For start=p+5 To nextField-1
                If B(*Input,start)>127 : changed=1 : Break : EndIf
              Next
              If changed And IsUTF8(*Input+p+5,fieldLen)
                ; Already valid UTF-8, preserve bytes exactly.
                changed=0
              EndIf
              If changed
                value=Decode1251(*Input+p+5,fieldLen)
                newLen=StringByteLength(value,#PB_UTF8)
                If newLen>255
                  PrintN("ERROR: record "+Str(recNo)+", field "+Str(field)+" exceeds 255 bytes after UTF-8 conversion")
                  FreeMemory(*out)
                  ProcedureReturn #False
                EndIf
                If outPos+(p+5-cursor)+newLen>capacity
                  PrintN("ERROR: output buffer limit exceeded")
                  FreeMemory(*out)
                  ProcedureReturn #False
                EndIf
                CopyMemory(*Input+cursor,*out+outPos,p+5-cursor)
                outPos+p+5-cursor
                PokeA(*out+outPos-1,newLen)
                *utf8=AllocateMemory(newLen+1)
                If *utf8=0
                  FreeMemory(*out) : ProcedureReturn #False
                EndIf
                PokeS(*utf8,value,-1,#PB_UTF8)
                CopyMemory(*utf8,*out+outPos,newLen)
                FreeMemory(*utf8)
                outPos+newLen
                cursor=nextField
                total+1
              EndIf
          EndSelect
          p=nextField
          Continue
        EndIf
      EndIf
      p+1
    Wend
    If outPos+(recordEnd-cursor)>capacity
      PrintN("ERROR: output buffer limit exceeded")
      FreeMemory(*out)
      ProcedureReturn #False
    EndIf
    CopyMemory(*Input+cursor,*out+outPos,recordEnd-cursor)
    outPos+recordEnd-cursor
    recordNewLen=outPos-recordStart-4
    PokeL(*out+recordStart,recordNewLen)
    pos=recordEnd
  Wend
  If total=0
    PrintN("NOTE: no CP1251 fields found (ASCII or valid UTF-8 already).")
  EndIf
  If pos<>InputBytes
    PrintN("ERROR: source was not fully parsed")
    FreeMemory(*out)
    ProcedureReturn #False
  EndIf
  f=CreateFile(#PB_Any,Dst)
  If f=0
    PrintN("ERROR: cannot create destination: "+Dst)
    FreeMemory(*out)
    ProcedureReturn #False
  EndIf
  If WriteData(f,*out,outPos)<>outPos
    PrintN("ERROR: incomplete write")
    CloseFile(f)
    DeleteFile(Dst)
    FreeMemory(*out)
    ProcedureReturn #False
  EndIf
  CloseFile(f)
  ; Verify output as records and lengths, before accepting it.
  checkPos=4
  While checkPos<outPos
    If checkPos+10>outPos
      PrintN("ERROR: generated CDB has incomplete record")
      DeleteFile(Dst)
      FreeMemory(*out)
      ProcedureReturn #False
    EndIf
    checkLen=LE32(*out,checkPos)
    If checkLen<6 Or checkLen>outPos-checkPos-4 Or B(*out,checkPos+4)<>$4D Or B(*out,checkPos+5)<>$32
      PrintN("ERROR: generated CDB record validation failed")
      DeleteFile(Dst)
      FreeMemory(*out)
      ProcedureReturn #False
    EndIf
    checkPos+4+checkLen
  Wend
  FreeMemory(*out)
  PrintN("Created: "+Dst+" ("+Str(outPos)+" bytes; converted fields: "+Str(total)+")")
  PrintN("NOTE: keeps WinBox 3 wrapper. Test in WinBox 4.4 with a backup.")
  ProcedureReturn #True
EndProcedure

Procedure Usage()
  PrintN("(C)heshirCa 2026 | WinBox CDB reader / converter V2.0")
  PrintN("Usage: cdb <file.cdb> [TABLE|CSV|JSON|TREE]")
  PrintN("       cdb <file.cdb> /OUTPUT <CSV|JSON|TREE>")
  PrintN("       cdb /convert <src.cdb> <dst.cdb>")
EndProcedure

Define argc.i=CountProgramParameters(), fmt.i=#FmtTable, src.s, option.s, destination.s
If argc=0
  Usage() : End 0
EndIf
If LCase(ProgramParameter(0))="/convert"
  If argc<>3 : Usage() : End 1 : EndIf
  If ConvertFile(ProgramParameter(1),ProgramParameter(2))=0 : End 1 : EndIf
  End 0
EndIf
src=ProgramParameter(0)
If argc>=2
  option=UCase(ProgramParameter(1))
  If option="/OUTPUT" Or option="--FORMAT" Or option="/FORMAT"
    If argc<3 : Usage() : End 1 : EndIf
    option=UCase(ProgramParameter(2))
  EndIf
  Select option
    Case "CSV","/CSV" : fmt=#FmtCSV
    Case "JSON","/JSON" : fmt=#FmtJSON
    Case "TREE","/TREE" : fmt=#FmtTree
    Case "TABLE","/TABLE" : fmt=#FmtTable
    Default : Usage() : End 1
  EndSelect
EndIf
If LoadDatabase(src)=0 : End 1 : EndIf
PrintOutput(fmt)
End 0

; IDE Options = PureBasic 6.41 (Windows - x86)
; ExecutableFormat = Console
; CursorPosition = 582
; FirstLine = 562
; Folding = ----
; Optimizer
; EnableThread
; EnableXP
; DPIAware
; Executable = cdb.exe