program innounp;
{$APPTYPE CONSOLE}
uses
{$IFDEF EUREKALOG}
  ExceptionLog,
{$ENDIF}
  Windows, SysUtils, Classes, StrUtils,
  MyTypes in 'MyTypes.pas',
  Struct in 'Struct.pas',
  StructJoin in 'StructJoin.pas',  
  Msgs in 'Msgs.pas',
  MsgIds in 'MsgIds.pas',
  PathFunc in 'PathFunc.pas',
  CmnFunc2 in 'CmnFunc2.pas',
  SetupEnt in 'SetupEnt.pas',
  Extract in 'Extract.pas',
  Extract4000 in 'Extract4000.pas',
  Main in 'Main.pas',
  Int64Em in 'Int64Em.pas',
  InstFunc in 'InstFunc.pas',
  ZLib in 'zlib.pas',
  BZlib in 'bzlib.pas',
  LZMADecomp in 'LZMADecomp.pas',
  LZMADecompSmall in 'LZMADecompSmall.pas',
  Compress in 'Compress.pas',
  RebuildScript in 'RebuildScript.pas',
  FileClass in 'FileClass.pas',
  CallOptimizer in 'CallOptimizer.pas',
  FileNull in 'FileNull.pas',
  SetupLdr in 'SetupLdr.pas',
  CustomVersions in 'CustomVersions.pas',
{$I CompressList.inc}
  ;

{$R version.res}

const
{$I VersionInfo.inc}

type
  TCompressedBlockReaderClass = class of TAbstractBlockReader;
  TOverwriteAction = (oaOverwrite, oaSkip, oaAsk, oaAbort);
var
  WarnOnMod:boolean=false;
  IsUnknownVersion:boolean=false;
  OverwriteAction: TOverwriteAction;

// Run parameters
  SetupFileName: string;
  FileMasks: array of string;
  Password: string;
  CommandAction: TCommandAction;
  StripPaths:boolean=false;
  OutDir:string='';
  BaseDirToStrip:string='';
  AttemptUnpackUnknown:boolean=true;
  ExtractAllCopies:boolean=false;
  AutoYes: Boolean = false;
  ExtractTestOnly: Boolean = false;
  QuietExtract: Boolean = false;
  ExtractEmbedded: Boolean = false;
  InteractiveMode: Boolean = true;

function FindVerObject(var IsUnknown: boolean) : TInnoVer;
var
  tmpVer: integer;
  i: integer;
begin
  Result := nil;
  IsUnknown := true;

  // ISX versions currently are not supported
  if (VerIsISX) then Exit;

  // First try to find direct match
  for i := 0 to High(VerList) do
    if (VerList[i].VerSupported = Ver) and (VerList[i].IsUnicode = VerIsUnicode) and (VerList[i].IsRT = VerIsRT) then
    begin
      Result := VerList[i];
      IsUnknown := false;
      break;
    end;

  if (Result = nil) and AttemptUnpackUnknown then
  begin
    // Try to find closest match (version higher or equal)
    tmpVer := 0;
    for i:=0 to High(VerList) do with VerList[i] do
      if (Ver >= VerSupported) and (VerSupported >= tmpVer) and (IsUnicode=VerIsUnicode) then
      begin
        Result := VerList[i];
        tmpVer := VerSupported;
      end;
  end;
end;

function IsCompatibleVersion(const TestID: TSetupID; var VerObject: TInnoVer):boolean;
const
  SignBegin='Inno Setup Setup Data (';
  SignBeginIsx='My Inno Setup Extensions Setup Data (';
  Digits=['0'..'9'];
var
  s:string;
  i,j:integer;
  Ver1,Ver2,Ver3:integer;
  FileVersion: String;
begin
  s:=TestID; Result:=false;
  if pos(SignBegin,s)=1 then i:=length(SignBegin)+1
  else if pos(SignBeginIsx,s)=1 then i:=length(SignBeginIsx)+1
  else exit;
  if not (s[i] in ['1','2','3','4','5','6']) or (s[i+1]<>'.') then exit;
  j:=i; while (j<=sizeof(TSetupID)) and (s[j]<>')') do inc(j);
  if (j>sizeof(TSetupID)) then exit;
  FileVersion:=copy(s,i,j-i);
  if FileVersion='3.0.6.1' then FileVersion:='3.0.8'; // ugly hack to support ISX 3.0.6.1 at low cost
  if not ((FileVersion[1] in Digits) and (FileVersion[2]='.')) then exit;
  Val(copy(FileVersion,1,1),Ver1,i); if i<>0 then exit;
  Val(copy(FileVersion,3,1),Ver2,i); if i<>0 then exit;
  if FileVersion[4]<>'.' then exit;
  j:=5; while (j<=length(FileVersion)) and (FileVersion[j] in Digits) do inc(j);
  Val(copy(FileVersion,5,j-5),Ver3,i); if i<>0 then exit;
  if (j<=length(FileVersion)) then WarnOnMod:=true;
  Ver:=Ver1*1000+Ver2*100+Ver3;

  VerIsUnicode := (PosEx('(u)', s, Length(SignBegin)) > 0) or (PosEx('(U)', s, Length(SignBegin)) > 0);
  VerIsRT := CheckResToolsVersion(SetupFileName);
  VerIsISX := PosEx('with ISX', s, Length(SignBegin)) > 0;

  VerObject := FindVerObject(IsUnknownVersion);
  Result := VerObject <> nil;
end;

function GetBlockReaderClass(InnoVer: integer) : TCompressedBlockReaderClass;
begin
  Result := nil;

  if (InnoVer <= 4008) then Result := TZlibBlockReader4008
  else if (InnoVer >= 4009) and (InnoVer <= 4105) then Result := TZlibBlockReader4107
  // version mismatch (4105 vs. 4107) is ok
  else if (InnoVer > 4105) then Result := Compress.TCompressedBlockReader;
end;

procedure CreateEntryLists;
var
  I: TEntryType;
begin
  for I := Low(I) to High(I) do
    Entries[I] := TList.Create;

  WizardImages := TStringList.Create;
  WizardSmallImages := TStringList.Create;  
end;

procedure SetupLdr;
var
  SourceF: TFile;
  OffsetTable: TSetupLdrOffsetTable;
  IsCompatible: boolean;
  TestID: TSetupID;
  VerObject: TInnoVer;
begin
  SetupLdrOriginalFilename:=SetupFileName;
  try
    SourceF := TFile.Create(SetupFileName, fdOpenExisting, faRead, fsRead);
    try
      if not (GetSetupLdrOffsetTableFromFile(SourceF, OffsetTable) or
        GetSetupLdrOffsetTableFromResource(SetupFileName, SourceF, OffsetTable)) then
      begin
        if SourceF.CappedSize<sizeof(TestID) then SetupCorruptError;
        OffsetTable.Offset0:=0;
        OffsetTable.Offset1:=0;
        SetupLdrMode:=false;
      end;
      SourceF.Seek(OffsetTable.Offset0);
      SourceF.ReadBuffer(TestID, SizeOf(TestID));

      IsCompatible:=IsCompatibleVersion(TestID, VerObject);
      if AttemptUnpackUnknown and IsUnknownVersion and IsCompatible then begin
        writeln('Signature detected: '+TestID);
        writeln('This is not directly supported, but i''ll try to unpack it as version '+IntToStr(VerObject.VerSupported));
      end;
      if not IsCompatible then begin
        if not SetupLdrMode then SetupCorruptError;
        writeln('Signature detected: '+TestID+'. This is not a supported version.');
        raise EFatalError.Create('1');
      end else if IsVersionSuspicious(Ver) then
        writeln('; Version specified: '+IntToStr(Ver))
      else begin
        write('; Version detected: '+IntToStr(Ver));
        if (VerIsUnicode) then write(' (Unicode)');
        if (VerIsRT) then write(' (Custom)');
        writeln('');
      end;
      if WarnOnMod then writeln('Signature: '+TestID);

// Extract the embedded setup exe      // causes problems. disabled for now.
      {if ExtractEmbedded then begin
        SourceF.Seek(OffsetTable.OffsetEXE);
        P := nil;

        try
          GetMem(P, OffsetTable.UncompressedSizeEXE);
          FillChar(P^, OffsetTable.UncompressedSizeEXE, 0);
          try
            Reader := TCompressedBlockReader.Create(SourceF, TLZMADecompressor);
            try
              Reader.Read(P^, OffsetTable.UncompressedSizeEXE);
            finally
              Reader.Free;
            end;
          except
            on ECompressDataError do
              SetupCorruptError;
          end;
          TransformCallInstructions(P^, OffsetTable.UncompressedSizeEXE, False);
          if GetCRC32(P^, OffsetTable.UncompressedSizeEXE) <> OffsetTable.CRCEXE then
            SetupCorruptError;
        finally
          SetLength(s,OffsetTable.UncompressedSizeEXE);
          Move(p^,s[1],OffsetTable.UncompressedSizeEXE);
          FreeMem(P);
          AddFakeFile('embedded\setup.exe',s);
        end;
      end;}
    finally
      FreeAndNil(SourceF);
    end;
    SetupLdrOffset0 := OffsetTable.Offset0;
    SetupLdrOffset1 := OffsetTable.Offset1;
  except
    on E:Exception do begin
      if E is EMessage then raise;
      if E is EFatalError then raise;

      write('Can not open or read the specified file: "'+SetupFileName+'"');
      if (E is EInOutError) then
        writeln(' : '+SysErrorMessage(EInOutError(E).ErrorCode))
      else if (E is EFileError) then
        writeln(' : '+SysErrorMessage(EFileError(E).ErrorCode))
      else begin
        writeln('');
        writeln('Exception class '+E.ClassName+' with message: '+E.Message);
      end;  
      raise EFatalError.Create('1');
    end;
  end;
end;

procedure AbortInit(const Msg: TSetupMessageID);
begin
  writeln('Critical error: '+SetupMessages[Msg]);
//  MsgBox(SetupMessages[Msg], '', mbCriticalError, MB_OK);
  Abort;
end;

procedure InitializeSetup;
var
  SetupFile: TFile;
  pFileEntry: PSetupFileEntry;
  pFileLocationEntry: PSetupFileLocationEntry;
  pRegistryEntry: PSetupRegistryEntry;
  pRunEntry: PSetupRunEntry;
  pIconEntry: PSetupIconEntry;
  pTaskEntry: PSetupTaskEntry;
  pComponentEntry: PSetupComponentEntry;
  pTypeEntry: PSetupTypeEntry;
  pCustomMessageEntry: PSetupCustomMessageEntry;
  pLanguageEntry: PSetupLanguageEntry;
  pDirEntry: PSetupDirEntry;
  pIniEntry: PSetupIniEntry;
  pDeleteEntry: PSetupDeleteEntry;
  RealReader: TAbstractBlockReader;
  Reader: TCacheReader;
  p:pointer;
  i:integer;

  procedure ReadString(const R: TAbstractBlockReader; var Str: AnsiString);
  var
    Len: Longint;
  begin
    R.Read(Len, SizeOf(Len));
    SetLength(Str, Len);
    R.Read((@Str[1])^, Len);
  end;

  procedure SkipEntries(const Count, Size, Strings, AnsiStrings: Integer);
  var
    i: integer;
  begin
    for i:=0 to Count-1 do
      SECompressedBlockSkip(Reader, Size, Strings, AnsiStrings);
  end;

  procedure ReadImageList(const R: TAbstractBlockReader; DestList: TStrings);
  var
    i, Len: Longint;
    Img: String;
  begin
    // In version 5.6.0 IS changed single wizard image to multiple images
    // but version signature was not changed (still 5.5.7)
    // Bacause of this (BAD decision) we have to rely on this heuristics to
    // distinguish if with have one image of several ones
    R.Read(Len, SizeOf(Len));
    if (Len < 20) then // this is probably an image counter
      for i := 0 to Len - 1 do
      begin
        ReadString(R, Img);
        DestList.Add(Img);
      end
    else begin
      // It looks like we have single image and we've already read its length
      SetLength(Img, Len);
      R.Read((@Img[1])^, Len);
      DestList.Add(Img);
    end;
  end;

  procedure ReadWizardAndBzipDll;
  begin
    { Wizard image }
    ReadImageList(Reader, WizardImages);

    if (Ver >= 2001) then
    begin
      ReadImageList(Reader, WizardSmallImages);
    end;
    
    { Decompressor DLL }
    DecompDll:='';
    if (SetupHeader.CompressMethod = cmBzip) or
       ((SetupHeader.CompressMethod = cmLZMA) and (Ver=4105)) or
       ((SetupHeader.CompressMethod = cmZip) and (Ver>=4206)) then
    begin
      ReadString(Reader, DecompDll);
    end;
  end;
var
  VerObject: TInnoVer;
  TestID: TSetupID;
  TheBlockReader: TCompressedBlockReaderClass;
begin
  { Read SETUP.0, or from EXE }

  // If SetupLdrMode=false, we're running on setup.0 (whatever the actual name is}
  // because the 'real' setup.exe (i.e. not the SetupLdr exe) would not pass the check
  // in SetupLdr proc
  // As a bonus, since 4.1.7 setup.0 must have the same base name as setup.exe
//  SetupFilename := SetupLdrOriginalFilename;

  SetupFile := TFile.Create(SetupFilename, fdOpenExisting, faRead, fsRead);
  try
    SetupFile.Seek(SetupLdrOffset0);
    if SetupFile.Read(TestID, SizeOf(TestID)) <> SizeOf(TestID) then
      AbortInit(msgSetupFileCorruptOrWrongVer);
    try
      TheBlockReader := GetBlockReaderClass(Ver);

      RealReader := TheBlockReader.Create(SetupFile, TLZMA1SmallDecompressor);
      Reader := TCacheReader.CreateCache(RealReader);
      
      if IsVersionSuspicious(Ver) then begin
        HeuristicVersionFinder(Reader, Ver);
        write('; Version detected: '+IntToStr(Ver));
        if (VerIsUnicode) then writeln(' (Unicode)') else writeln('');
      end;
      VerObject := FindVerObject(IsUnknownVersion);
//      if VerObject=nil then exit; // that should not happen

      VerObject.SetupSizes;
      try
        { Header }
        p:=AllocMem(SetupHeaderSize);
        SECompressedBlockRead(Reader, p^, SetupHeaderSize, SetupHeaderStrings, SetupHeaderAnsiStrings);
        VerObject.UnifySetupHeader(p^, SetupHeader);
        FreeMem(p);
        if Ver<4000 then begin // language options, wizard images and compressor dll are stored here in 3.x
          SECompressedBlockSkip(Reader, SetupLanguageEntrySize, SetupLanguageEntryStrings, SetupLanguageEntryAnsiStrings);
          ReadWizardAndBzipDll;
        end;
        
        { Language entries }
        if Ver>=4000 then
        begin
          p:=AllocMem(SetupLanguageEntrySize);
          for i:=0 to SetupHeader.NumLanguageEntries-1 do begin
            SECompressedBlockRead(Reader, p^, SetupLanguageEntrySize, SetupLanguageEntryStrings, SetupLanguageEntryAnsiStrings);
            pLanguageEntry:=AllocMem(sizeof(TSetupLanguageEntry));
            VerObject.UnifyLanguageEntry(p^, pLanguageEntry^);
            Entries[seLanguage].Add(pLanguageEntry);
          end;
          FreeMem(p);
        end;

        { CustomMessage entries }
        if Ver>=4201 then
        begin
          p:=AllocMem(SetupCustomMessageEntrySize);
          for i:=0 to SetupHeader.NumCustomMessageEntries-1 do begin
            SECompressedBlockRead(Reader, p^, SetupCustomMessageEntrySize,
              SetupCustomMessageEntryStrings, SetupCustomMessageEntryAnsiStrings);
            pCustomMessageEntry:=AllocMem(sizeof(TSetupCustomMessageEntry));
            VerObject.UnifyCustomMessageEntry(p^, pCustomMessageEntry^);
            Entries[seCustomMessage].Add(pCustomMessageEntry);
          end;
          FreeMem(p);
        end;
        
        { Permission entries }
        if Ver>=4100 then
          SkipEntries(SetupHeader.NumPermissionEntries, SetupPermissionEntrySize,
            SetupPermissionEntryStrings, SetupPermissionEntryAnsiStrings);
            
        { Type entries }
        if (SetupTypeEntrySize > 0) then
        begin
          p:=AllocMem(SetupTypeEntrySize);
          for i:=0 to SetupHeader.NumTypeEntries-1 do begin
            SECompressedBlockRead(Reader, p^, SetupTypeEntrySize, SetupTypeEntryStrings, SetupTypeEntryAnsiStrings);
            pTypeEntry:=AllocMem(sizeof(TSetupTypeEntry));
            VerObject.UnifyTypeEntry(p^, pTypeEntry^);
            Entries[seType].Add(pTypeEntry);
          end;
          FreeMem(p);
        end;

        { Component entries }
        if (SetupComponentEntrySize > 0) then
        begin
          p:=AllocMem(SetupComponentEntrySize);
          for i:=0 to SetupHeader.NumComponentEntries-1 do begin
            SECompressedBlockRead(Reader, p^, SetupComponentEntrySize, SetupComponentEntryStrings, SetupComponentEntryAnsiStrings);
            pComponentEntry:=AllocMem(sizeof(TSetupComponentEntry));
            VerObject.UnifyComponentEntry(p^, pComponentEntry^);
            Entries[seComponent].Add(pComponentEntry);
          end;
          FreeMem(p);
        end;

        { Task entries }
        if (SetupTaskEntrySize > 0) then
        begin
          p:=AllocMem(SetupTaskEntrySize);
          for i:=0 to SetupHeader.NumTaskEntries-1 do begin
            SECompressedBlockRead(Reader, p^, SetupTaskEntrySize, SetupTaskEntryStrings, SetupTaskEntryAnsiStrings);
            pTaskEntry:=AllocMem(sizeof(TSetupTaskEntry));
            VerObject.UnifyTaskEntry(p^,pTaskEntry^);
            Entries[seTask].Add(pTaskEntry);
          end;
          FreeMem(p);
        end;

        { Dir entries }
        p:=AllocMem(SetupDirEntrySize);
        for i:=0 to SetupHeader.NumDirEntries-1 do begin
          SECompressedBlockRead(Reader, p^, SetupDirEntrySize, SetupDirEntryStrings, SetupDirEntryAnsiStrings);
          pDirEntry:=AllocMem(sizeof(TSetupDirEntry));
          VerObject.UnifyDirEntry(p^,pDirEntry^);
          Entries[seDir].Add(pDirEntry);
        end;
        FreeMem(p);

        { File entries }
        p:=AllocMem(SetupFileEntrySize);
        for i:=0 to SetupHeader.NumFileEntries-1 do begin
          SECompressedBlockRead(Reader, p^, SetupFileEntrySize, SetupFileEntryStrings, SetupFileEntryAnsiStrings);
          pFileEntry:=AllocMem(sizeof(TSetupFileEntry));
          VerObject.UnifyFileEntry(p^,pFileEntry^);
          Entries[seFile].Add(pFileEntry);
        end;
        FreeMem(p);

        { Icon entries }
        p:=AllocMem(SetupIconEntrySize);
        for i:=0 to SetupHeader.NumIconEntries-1 do begin
          SECompressedBlockRead(Reader, p^, SetupIconEntrySize, SetupIconEntryStrings, SetupIconEntryAnsiStrings);
          pIconEntry:=AllocMem(sizeof(TSetupIconEntry));
          VerObject.UnifyIconEntry(p^,pIconEntry^);
          Entries[seIcon].Add(pIconEntry);
        end;
        FreeMem(p);

        { INI entries }
        p:=AllocMem(SetupIniEntrySize);
        for i:=0 to SetupHeader.NumIniEntries-1 do begin
          SECompressedBlockRead(Reader, p^, SetupIniEntrySize, SetupIniEntryStrings, SetupIniEntryAnsiStrings);
          pIniEntry:=AllocMem(sizeof(TSetupIniEntry));
          VerObject.UnifyIniEntry(p^,pIniEntry^);
          Entries[seIni].Add(pIniEntry);
        end;
        FreeMem(p);

        { Registry entries }
        p:=AllocMem(SetupRegistryEntrySize);
        for i:=0 to SetupHeader.NumRegistryEntries-1 do begin
          SECompressedBlockRead(Reader, p^, SetupRegistryEntrySize, SetupRegistryEntryStrings, SetupRegistryEntryAnsiStrings);
          pRegistryEntry:=AllocMem(sizeof(TSetupRegistryEntry));
          VerObject.UnifyRegistryEntry(p^,pRegistryEntry^);
          Entries[seRegistry].Add(pRegistryEntry);
        end;
        FreeMem(p);

        { InstallDelete entries }
        p:=AllocMem(SetupDeleteEntrySize);
        for i:=0 to SetupHeader.NumInstallDeleteEntries-1 do begin
          SECompressedBlockRead(Reader, p^, SetupDeleteEntrySize, SetupDeleteEntryStrings, SetupDeleteEntryAnsiStrings);
          pDeleteEntry:=AllocMem(sizeof(TSetupDeleteEntry));
          VerObject.UnifyDeleteEntry(p^, pDeleteEntry^);
          Entries[seInstallDelete].Add(pDeleteEntry);
        end;
        FreeMem(p);

        { UninstallDelete entries }
        p:=AllocMem(SetupDeleteEntrySize);
        for i:=0 to SetupHeader.NumUninstallDeleteEntries-1 do begin
          SECompressedBlockRead(Reader, p^, SetupDeleteEntrySize, SetupDeleteEntryStrings, SetupDeleteEntryAnsiStrings);
          pDeleteEntry:=AllocMem(sizeof(TSetupDeleteEntry));
          VerObject.UnifyDeleteEntry(p^, pDeleteEntry^);
          Entries[seUninstallDelete].Add(pDeleteEntry);
        end;
        FreeMem(p);

        { Run entries }
        p:=AllocMem(SetupRunEntrySize);
        for i:=0 to SetupHeader.NumRunEntries-1 do begin
          SECompressedBlockRead(Reader, p^, SetupRunEntrySize, SetupRunEntryStrings, SetupRunEntryAnsiStrings);
          pRunEntry:=AllocMem(sizeof(TSetupRunEntry));
          VerObject.UnifyRunEntry(p^,pRunEntry^);
          Entries[seRun].Add(pRunEntry);
        end;
        FreeMem(p);
        
        { UninstallRun entries }
        p:=AllocMem(SetupRunEntrySize);
        for i:=0 to SetupHeader.NumUninstallRunEntries-1 do begin
          SECompressedBlockRead(Reader, p^, SetupRunEntrySize, SetupRunEntryStrings, SetupRunEntryAnsiStrings);
          pRunEntry:=AllocMem(sizeof(TSetupRunEntry));
          VerObject.UnifyRunEntry(p^,pRunEntry^);
          Entries[seUninstallRun].Add(pRunEntry);
        end;
        FreeMem(p);

        if Ver>=4000 then ReadWizardAndBzipDll;

        RealReader.Free; Reader.Free;

        RealReader := TheBlockReader.Create(SetupFile, TLZMA1Decompressor);
        Reader:=TCacheReader.CreateCache(RealReader);

        { File location entries }
        p:=AllocMem(SetupFileLocationEntrySize);
        for i:=0 to SetupHeader.NumFileLocationEntries-1 do begin
          SECompressedBlockRead(Reader, p^, SetupFileLocationEntrySize,
            SetupFileLocationEntryStrings, SetupFileLocationEntryAnsiStrings);
          pFileLocationEntry:=AllocMem(sizeof(TSetupFileLocationEntry));
          VerObject.UnifyFileLocationEntry(p^,pFileLocationEntry^);
          if Ver<4000 then with pFileLocationEntry^ do begin
            Dec(FirstSlice);
            Dec(LastSlice);
          end;
          Entries[seFileLocation].Add(pFileLocationEntry);
        end;
        FreeMem(p);

        for i:=0 to Entries[seFileLocation].Count-1 do
          if foTimeStampInUTC in PSetupFileLocationEntry(Entries[seFileLocation][i])^.Flags then begin
            TimeStampsInUTC:=true;
            break;
          end;

      finally
        Reader.Free; RealReader.Free;
      end;
    except
      on ECompressDataError do
        AbortInit(msgSetupFileCorrupt);
    end;
  finally
    FreeAndNil(SetupFile);
  end;
end;

function AskFileOverwrite(DestFile: string) : boolean;
var
  Resp: string;
begin
  Result := (OverwriteAction = oaOverwrite);
  if (OverwriteAction <> oaAsk) then Exit;

  Writeln('File "' + DestFile + '" already exists. Overwrite?');
  repeat
    Write('(Y)es / (N)o / (A)lways / (S)kip all / (Q)uit ?');
    Readln(Resp);
    if (Resp = '') then continue;

    case UpCase(Resp[1]) of
      'Y': begin Result := True; break; end;
      'N': break;
      'A': begin Result := True; OverwriteAction := oaOverwrite; break; end;
      'S': begin OverwriteAction := oaSkip; break; end;
      'Q': begin OverwriteAction := oaAbort; break; end;
    end;
  until False;
end;

procedure ExtractorProgressProc(Bytes: Cardinal);
begin
end;

procedure ProcessFileEntry(const FileExtractor: TFileExtractor;
  const CurFile: PSetupFileEntry);
var
  CurFileLocation: PSetupFileLocationEntry;
  DestFile, TempFile: String;
  DestF: TFile;
  CurFileDate: TFileTime;
  PasswdStr: String; 
begin
  if CurFile^.LocationEntry = -1 then Exit;

  CurFileLocation := PSetupFileLocationEntry(Entries[seFileLocation][CurFile^.LocationEntry]);
  DestFile:=CurFile^.SourceFileName;

  if length(BaseDirToStrip)>0 then delete(DestFile,1,length(BaseDirToStrip));
  if StripPaths then DestFile:=ExtractFileName(DestFile);

  // Check if file already exists and ask if necessary
  if (InteractiveMode) and (OverwriteAction = oaAsk) and FileExists(DestFile) then
    if not AskFileOverwrite(DestFile) then Exit;

  // Ask password if file is encrypted
  if (InteractiveMode) and (foChunkEncrypted in CurFileLocation^.Flags) and (FileExtractor.CryptKey = '') then
    repeat
      writeln('Type in a password (empty string to quit)');
      readln(PasswdStr);
      if (PasswdStr = '') then break;
      PasswdStr := FixPasswordEncoding(PasswdStr); // For proper Unicode/Ansi support
      if TestPassword(PasswdStr) then
      begin
        FileExtractor.CryptKey := PasswdStr;
        break;
      end;
      writeln('Wrong password');
    until false;

  if (ExtractTestOnly) then
    DestF := TNullFile.Create()
  else begin
    TempFile := GenerateUniqueName(ExtractFilePath(ExpandFilename(DestFile)), '.tmp');
    MakeDir(ExtractFilePath(TempFile));
    DestF := TFile.Create(TempFile, fdCreateAlways, faWrite, fsNone);
  end;

  try
    try
      if CurFile^.FileType<>ftFakeFile then begin
        { Decompress a file }
        FileExtractor.SeekTo(CurFileLocation^);
        FileExtractor.DecompressFile(CurFileLocation^, DestF, ExtractorProgressProc);
      end else begin
        DestF.WriteBuffer(CurFileLocation^.Contents[1],length(CurFileLocation^.Contents));
      end;

      { Set time/date stamp }
      CurFileDate:=CurFileLocation^.TimeStamp;
      if not TimeStampsInUTC then LocalFileTimeToFileTime(CurFileLocation^.TimeStamp, CurFileDate);
      SetFileTime(DestF.Handle, @CurFileDate, nil, @CurFileDate);
    finally
      FreeAndNil(DestF);
    end;

    if (not ExtractTestOnly) then
    begin
      DeleteFile(DestFile);

      if not MoveFile(PChar(TempFile), PChar(DestFile)) then
        Win32ErrorMsg('MoveFile');
    end;
  finally
    DeleteFile(TempFile);
  end;
end;

function ShouldProcessFileEntry(AFile: PSetupFileEntry):boolean;
var
  i:integer;
  FilePath,MaskPath,FileName,MaskName:string;
begin
  Result:=false;
  if not ExtractEmbedded and (AFile^.FileType in [ftUninstExe, ftRegSvrExe]) then exit;
  if (AFile^.LocationEntry=-1) then exit;
  if length(BaseDirToStrip)>0 then
    if pos(BaseDirToStrip, AnsiLowercase(AFile^.SourceFileName))<>1 then exit;
  if length(FileMasks)>0 then begin
    for i:=0 to High(FileMasks) do begin
      MaskPath:=AnsiLowercase(PathExtractPath(FileMasks[i]));
      FilePath:=AnsiLowercase(PathExtractPath(AFile^.SourceFileName)); //AFile^.DestDir));
      FileName:=AnsiLowercase(PathExtractName(AFile^.SourceFileName));
//      if AFile^.DestName<>'' then FileName:=AnsiLowercase(PathExtractName(AFile^.DestName));
      MaskName:=AnsiLowercase(PathExtractName(FileMasks[i]));
      if MaskPath ='' then
        Result:=WildcardMatch(PChar(FileName),PChar(AnsiLowercase(FileMasks[i])))
      else if IsWildcard(MaskName) then
        Result := WildcardMatch(PChar(FilePath + FileName), PChar(MaskPath + MaskName))
      else
        Result := WildcardMatch(PChar(FilePath), PChar(MaskPath)) and (FileName = MaskName);
//      else Result:=false;
      if Result then break;
    end;
  end else Result:=true;
end;

procedure ExtractorNotification(MessageText: String);
begin
  if (not QuietExtract) then
    writeln(MessageText);
end;

function CreateFileExtractor() : TFileExtractor;
const
  DecompClasses: array[TSetupCompressMethod] of TCustomDecompressorClass =
    (TStoredDecompressor, TZDecompressor, TBZDecompressor, TLZMA1Decompressor, TLZMA2Decompressor);
begin
  if (Ver <= 4000) then
    Result := TFileExtractor4000.Create(TZDecompressor)
  else
    Result := TFileExtractor.Create(DecompClasses[SetupHeader.CompressMethod]);

  Result.OnNotification := ExtractorNotification;
  Result.Interactive := InteractiveMode;

  Password := FixPasswordEncoding(Password);  // For proper Unicode/Ansi support
  if SetupHeader.EncryptionUsed and (Password <> '') then
  begin
    if TestPassword(Password) then
      Result.CryptKey := Password
    else if (InteractiveMode) then
      writeln('Warning: ' + SetupMessages[msgIncorrectPassword])
    else
      AbortInit(msgIncorrectPassword);
  end;
end;

procedure CopyFiles;
{ Copies all the application's files }
var
  CurFileNumber: Integer;
  CurFile: PSetupFileEntry;
  loc:PSetupFileLocationEntry;
  FileExtractor: TFileExtractor;
begin
  OverwriteAction := oaAsk;
  if (AutoYes) then OverwriteAction := oaOverwrite;

  FileExtractor := CreateFileExtractor;
  try
    for CurFileNumber := 0 to Entries[seFile].Count-1 do begin
      CurFile := PSetupFileEntry(Entries[seFile][CurFileNumber]);
      if not ShouldProcessFileEntry(CurFile) then continue;
      loc:=PSetupFileLocationEntry(Entries[seFileLocation][CurFile^.LocationEntry]);
      if not ExtractAllCopies and (loc^.PrimaryFileEntry<>-1) and (loc^.PrimaryFileEntry<>CurFileNumber) then continue;
      with CurFile^ do
        if not QuietExtract then
          writeln('#'+IntToStr(CurFileNumber)+' '+SourceFilename);

        if CurFile^.LocationEntry <> -1 then begin
          ProcessFileEntry(FileExtractor, CurFile);
        end;

      if (OverwriteAction = oaAbort) then break;  
    end;  //for
  finally
    FileExtractor.Free;
  end;
end;

procedure Usage;
begin
  writeln(Format('innounp, the Inno Setup Unpacker. Version %d.%d', [IUV_MAJOR, IUV_MINOR]));
{$IFDEF EUREKALOG}writeln('Debug release');{$ENDIF}
  writeln('Usage: innounp [command] [options] <setup.exe or setup.0> [@filelist] [filemask ...]');
  writeln('Commands:');
  writeln('  (no)   display general installation info');
  writeln('  -v     verbosely list the files (with sizes and timestamps)');
  writeln('  -x     extract the files from the installation (to the current directory, also see -d)');
  writeln('  -e     extract files without paths');
  writeln('  -t     test files for integrity');  
  writeln('Options:');
  writeln('  -b     batch (non-interactive) mode - will not prompt for password or disk changes');
  writeln('  -q     do not indicate progress while extracting');
  writeln('  -m     extract internal embedded files (such as license and uninstall.exe)');
  writeln('  -pPASS decrypt the installation with a password');
  writeln('  -dDIR  extract the files into DIR (can be absolute or relative path)');
  writeln('  -cDIR  specifies that DIR is the current directory in the installation');
  writeln('  -n     don''t attempt to unpack new versions');
  writeln('  -fFILE same as -p but reads the password from FILE');
  writeln('  -a     extract all copies of duplicate files');
  writeln('  -y     assume Yes on all queries (e.g. overwrite files)');
end;

function ParseCommandLine:boolean;
var
  InstallNameParsed:boolean;
  i:integer;
  f:TextFile;
  s:string;
  PasswordFileName:string;
begin
  Result:=false; CommandAction:=caInstallInfo; InstallNameParsed:=false; SetLength(FileMasks,0);
  PasswordFileName:='';
  ExtractTestOnly := false;
  if (ParamCount<1) then exit;
  for i:=1 to ParamCount do
    if (ParamStr(i)[1]='-') and (length(ParamStr(i))>=2) then
      case UpCase(ParamStr(i)[2]) of
        'V': CommandAction:=caVerboseList;
        'X': CommandAction:=caExtractFiles;
        'E': begin CommandAction:=caExtractFiles; StripPaths:=true; end;
        'T': begin CommandAction:=caExtractFiles; ExtractTestOnly:=true; AutoYes:=true; end;
        'B': begin InteractiveMode:=false; AutoYes:=true; end;
        'Q': QuietExtract:=true;
        'M': ExtractEmbedded:=true;
        'P': Password:=copy(ParamStr(i),3,length(ParamStr(i))-2);
        'D': OutDir:=copy(ParamStr(i),3,length(ParamStr(i))-2);
        'C': BaseDirToStrip:=PathLowercase(AddBackslash(copy(ParamStr(i),3,length(ParamStr(i))-2)));
        'N': AttemptUnpackUnknown:=false;
        'F': PasswordFileName:=copy(ParamStr(i),3,length(ParamStr(i))-2);
        'A': ExtractAllCopies:=true;
        'Y': AutoYes:=true;
        else Exit;
      end
    else if not InstallNameParsed then begin SetupFileName:=ExpandFileName(ParamStr(i)); InstallNameParsed:=true; end
    else if (ParamStr(i)[1]='@') and (length(ParamStr(i))>=2) then begin
      AssignFile(f,copy(ParamStr(i),2,length(ParamStr(i))-1));
      try
        Reset(f);
        while not eof(f) do begin
          readln(f,s); s:=OemToStr(s);
          if s<>'' then begin SetLength(FileMasks,length(FileMasks)+1); FileMasks[High(FileMasks)]:=s; end;
        end;
      except
        on E: Exception do raise EFatalError.Create('2');
      end;
      CloseFile(f);
    end else begin SetLength(FileMasks,length(FileMasks)+1); FileMasks[High(FileMasks)]:=ParamStr(i); end;
  Result:=true;
  if PasswordFileName<>'' then begin
    try
      Password:=FileContents(PasswordFileName);
    except
      writeln('Failed to read "'+PasswordFileName+'". No password will be used');
      Password:='';
    end;
  end;
  for i:=0 to High(FileMasks) do
    if (FileMasks[i,1]='"') and (FileMasks[i,length(FileMasks[i])]='"') then
      FileMasks[i]:=copy(FileMasks[i],2,length(FileMasks[i])-2);
end;

var
  i:integer;
  systime:TSystemTime;
  TimeStamp:TFileTime;
  loc:PSetupFileLocationEntry;
  s:string;
  TotalFileSize: Int64;
  TotalFiles, TotalEncryptedFiles, MaxSlice: Integer;
  ReconstructedScript: AnsiString;
begin
  StdOutputHandle:=GetStdHandle(STD_OUTPUT_HANDLE);
  CreateEntryLists;
  if not ParseCommandLine then begin Usage; halt(1) end;
  try
    if OutDir<>'' then begin MakeDir(OutDir); SetCurrentDir(OutDir) end;
    SetupLdr;
    InitializeSetup;
    if ExtractEmbedded then AddEmbeddedFiles;

    if CommandAction<>caInstallInfo then begin // save some time
      RenameFiles(ExtractAllCopies); // all the fake files must be added before this

      ReconstructedScript := GetInstallScript;
      AddFakeFile('install_script.iss', ReconstructedScript, true);
    end;

    case CommandAction of
    caInstallInfo:
      begin
        writeln('Compression used: '+GetCompressMethodName(SetupHeader.CompressMethod));
        TotalFileSize:=0; TotalFiles:=0; TotalEncryptedFiles:=0; MaxSlice:=0;
        for i:=0 to Entries[seFile].Count-1 do
          with PSetupFileEntry(Entries[seFile][i])^ do begin
            if LocationEntry<>-1 then
            with PSetupFileLocationEntry(Entries[seFileLocation][LocationEntry])^ do begin
              if not ExtractAllCopies and (PrimaryFileEntry<>-1) and (PrimaryFileEntry<>i) then continue;
              TotalFileSize := TotalFileSize + OriginalSize;
              if LastSlice>MaxSlice then MaxSlice:=LastSlice;
              if foChunkEncrypted in Flags then Inc(TotalEncryptedFiles);
            end;
            Inc(TotalFiles);
          end;
        write('Files: '+IntToStr(TotalFiles)+' ; Bytes: '+IntToStr(TotalFileSize));
        if MaxSlice>0 then writeln(' ; Disk slices: '+IntToStr(MaxSlice+1))
        else writeln('');
        if TotalEncryptedFiles>0 then writeln(IntToStr(TotalEncryptedFiles)+' file(s) are encrypted');
        if length(SetupHeader.CompiledCodeText)>0 then
          writeln('Compiled Pascal script: '+IntToStr(length(SetupHeader.CompiledCodeText))+' byte(s)');
      end;
    caVerboseList:
      begin
        writeln('Size        Time              Filename');
        writeln('--------------------------------------');
        for i:=0 to Entries[seFile].Count-1 do
          with PSetupFileEntry(Entries[seFile][i])^ do begin
//            if not (FileType in [ftUserFile,ftFakeFile]) and not ExtractEmbedded then continue;
            if ((FileType in [ftUninstExe, ftRegSvrExe]) or not (FileType in [ftUserFile, ftFakeFile]))
              and not ExtractEmbedded then continue;
            if (LocationEntry=-1) then continue;
            loc:=PSetupFileLocationEntry(Entries[seFileLocation][LocationEntry]);
            if not ExtractAllCopies and (loc^.PrimaryFileEntry<>-1) and (loc^.PrimaryFileEntry<>i) then continue;
            if TimeStampsInUTC then FileTimeToLocalFileTime(loc^.TimeStamp, TimeStamp)
            else TimeStamp:=loc^.TimeStamp;
            FileTimeToSystemTime(TimeStamp, systime);
            str(loc^.OriginalSize:10,s);
            writeln(s+'  '+FormatDateTime('yyyy.mm.dd hh:mm', SystemTimeToDateTime(systime))+
              '  '+SourceFileName);
          end;
        writeln('--------------------------------------');
      end;
    caExtractFiles:
      CopyFiles;
    end;
  except
    on E: EAbort do
      halt(1); //This is a silent exception so just exit with error code
    on E: Exception do
      if IsUnknownVersion then begin
        writeln('Unpacking failed. This version is not supported.'); halt(1);
      end else if E.Message=SSetupFileCorrupt then begin
        writeln('The setup files are corrupted or made by incompatible version. Maybe it''s not an Inno Setup installation at all.');
        writeln('('+inttohex(cardinal(ExceptAddr),8)+')');
{$IFDEF EUREKALOG}raise;{$ELSE}        halt(1);{$ENDIF}
      end else if E.Message='' then begin //SetupMessages[msgSourceIsCorrupted] then
        writeln('Setup files are corrupted.');
        writeln('('+inttohex(cardinal(ExceptAddr),8)+')');
{$IFDEF EUREKALOG}raise;{$ELSE}        halt(1);{$ENDIF}
      end else begin
        if (E.Message <> '1') then // Hide service exceptions
          writeln('Error ('+E.ClassName+') "'+E.Message+'" at address '+inttohex(cardinal(ExceptAddr),8));
{$IFDEF EUREKALOG}raise;{$ELSE}        halt(1);{$ENDIF}
      end;
  end;
end.
