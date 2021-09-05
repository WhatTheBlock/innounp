unit MyTypes;

interface

uses Windows, MD5, SHA1;

////// in general extraction units these types are given their original
////// names as aliases, e.g. type TSetupHeader = TMySetupHeader
////// in verXXXX units this is not done to avoid conflicts
type
  TMySetupVersionData = packed record // same as in all IS versions
    WinVersion, NTVersion: Cardinal;
    NTServicePack: Word;
  end;

  TMySetupLdrOffsetTable = record // in-memory only
    ID: AnsiString; //array[1..12] of Char;
    TotalSize,
    OffsetEXE, CompressedSizeEXE, UncompressedSizeEXE, CRCEXE,
    Offset0, Offset1: Longint;
    TableCRC: Longint;  { CRC of all prior fields in this record }
    TableCRCUsed: boolean;
  end;

  TSetupCompressMethod = (cmStored, cmZip, cmBzip, cmLZMA, cmLZMA2);
  TSetupSalt = array[0..7] of Byte;
  TMySetupProcessorArchitecture = (paUnknown, paX86, paAMD64, paIA64);
  TMySetupProcessorArchitectures = set of TMySetupProcessorArchitecture;
  TMySetupPrivileges = (prNone, prPowerUser, prAdmin, prLowest);
  TMySetupDisablePage = (dpAuto, dpNo, dpYes);
  TMySetupLanguageDetectionMethod = (ldUILanguage, ldLocale, ldNone);

  TFileHashType = (htAdler, htCRC32, htMD5, htSHA1);

  TSetupHash = record
    HashType: TFileHashType;
    case TFileHashType of
      htMD5:  (MD5: TMD5Digest);
      htSHA1: (SHA1: TSHA1Digest);
  end;

  TMySetupHeaderOption = (shDisableStartupPrompt, shUninstallable, shCreateAppDir,
    shAllowNoIcons, shAlwaysRestart, shAlwaysUsePersonalGroup,
    shWindowVisible, shWindowShowCaption, shWindowResizable,
    shWindowStartMaximized, shEnableDirDoesntExistWarning,
    shPassword, shAllowRootDirectory, shDisableFinishedPage,
    shChangesAssociations, shUsePreviousAppDir,
    shBackColorHorizontal, shUsePreviousGroup, shUpdateUninstallLogAppName,
    shUsePreviousSetupType, shDisableReadyMemo, shAlwaysShowComponentsList,
    shFlatComponentsList, shShowComponentSizes, shUsePreviousTasks,
    shDisableReadyPage, shAlwaysShowDirOnReadyPage, shAlwaysShowGroupOnReadyPage,
    shAllowUNCPath, shUserInfoPage, shUsePreviousUserInfo,
    shUninstallRestartComputer, shRestartIfNeededByRun, shShowTasksTreeLines,
    shAllowCancelDuringInstall, shWizardImageStretch, shAppendDefaultDirName,
    shAppendDefaultGroupName, shEncryptionUsed, shChangesEnvironment,
    shShowUndisplayableLanguages,shSetupLogging,
    shSignedUninstaller, shUsePreviousLanguage, shDisableWelcomePage,
    shCloseApplications, shRestartApplications, shAllowNetworkDrive);
  const MySetupHeaderOptionLast = ord(High(TMySetupHeaderOption));
  type TMySetupHeaderOptions = set of TMySetupHeaderOption;  

  TMySetupHeader = record // in-memory only
    AppName, AppVerName, AppId, AppCopyright, AppPublisher, AppPublisherURL,
      AppSupportPhone, AppSupportURL, AppUpdatesURL, AppVersion, DefaultDirName,
      DefaultGroupName, BaseFileName, UninstallFilesDir, UninstallDisplayName,
      UninstallDisplayIcon, AppMutex, DefaultUserInfoName, DefaultUserInfoOrg,
      AppReadmeFile, AppContact, AppComments,
      AppModifyPath, CreateUninstallRegKey, Uninstallable, CloseApplicationsFilter,
      SetupMutex, ChangesEnvironment, ChangesAssociations: AnsiString;
    LicenseText, InfoBeforeText, InfoAfterText, CompiledCodeText: AnsiString;
    NumLanguageEntries, NumCustomMessageEntries, NumPermissionEntries, NumTypeEntries,
      NumComponentEntries, NumTaskEntries, NumDirEntries, NumFileEntries,
      NumFileLocationEntries, NumIconEntries, NumIniEntries,
      NumRegistryEntries, NumInstallDeleteEntries, NumUninstallDeleteEntries,
      NumRunEntries, NumUninstallRunEntries: Integer;
    MinVersion, OnlyBelowVersion: TMySetupVersionData;
    EncryptionUsed: Boolean;
    PasswordHash: TSetupHash;
    PasswordSalt: TSetupSalt;
    ExtraDiskSpaceRequired: Int64;
    SlicesPerDisk: Integer;
    PrivilegesRequired: TMySetupPrivileges;
    LanguageDetectionMethod: TMySetupLanguageDetectionMethod;
    CompressMethod: TSetupCompressMethod;
    ArchitecturesAllowed, ArchitecturesInstallIn64BitMode: TMySetupProcessorArchitectures;
    DisableDirPage, DisableProgramGroupPage: TMySetupDisablePage;
    UninstallDisplaySize: Int64;
    Options: TMySetupHeaderOptions;
  end;

  ////////// Warning: changes made here must be reflected in StructTemplate.pas !
  TMySetupFileOption = (foConfirmOverwrite, foUninsNeverUninstall, foRestartReplace,
    foDeleteAfterInstall, foRegisterServer, foRegisterTypeLib, foSharedFile,
    foCompareTimeStamp, foFontIsntTrueType,
    foSkipIfSourceDoesntExist, foOverwriteReadOnly, foOverwriteSameVersion,
    foCustomDestName, foOnlyIfDestFileExists, foNoRegError,
    foUninsRestartDelete, foOnlyIfDoesntExist, foIgnoreVersion,
    foPromptIfOlder, foDontCopy, foUninsRemoveReadOnly,
    foRecurseSubDirsExternal, foReplaceSameVersionIfContentsDiffer,
    foDontVerifyChecksum, foUninsNoSharedFilePrompt, foCreateAllSubDirs,
    fo32bit, fo64bit, foExternalSizePreset, foSetNTFSCompression,
    foUnsetNTFSCompression, foGacInstall);
  const MySetupFileOptionLast = ord(High(TMySetupFileOption));
  type TMySetupFileOptions = set of TMySetupFileOption;

  TMySetupFileEntry = record // in-memory only
    SourceFilename, DestName, InstallFontName, StrongAssemblyName: AnsiString;
    Components, Tasks, Languages, Check, AfterInstall, BeforeInstall: AnsiString;
    MinVersion, OnlyBelowVersion: TMySetupVersionData;
    LocationEntry: Integer;
    Attribs: Integer;
    ExternalSize: Int64;
    PermissionsEntry: Smallint;
    FileType: (ftUserFile, ftUninstExe, ftRegSvrExe, ftFakeFile);
    Options: TMySetupFileOptions;
    // Custom fields
    DestDir: AnsiString;
  end;

  TMySetupFileLocationFlag = (foVersionInfoValid, foVersionInfoNotValid, foTimeStampInUTC,
      foIsUninstExe, foCallInstructionOptimized, foTouch, foChunkEncrypted,
      foChunkCompressed, foSolidBreak);
  const MySetupFileLocationFlagLast = Ord(High(TMySetupFileLocationFlag));
  type TMySetupFileLocationFlags = set of TMySetupFileLocationFlag;

  TMySetupFileLocationEntry = record // in-memory only
    FirstSlice, LastSlice: Integer;
    StartOffset: Longint;
    ChunkSuboffset: Int64;
    OriginalSize: Int64;
    ChunkCompressedSize: Int64;
    HashType: TFileHashType;
    CRC: Longint;
    MD5Sum: TMD5Digest;
    SHA1Sum: TSHA1Digest;	// From version 5309
    TimeStamp: TFileTime;
    FileVersionMS, FileVersionLS: DWORD;
    Flags: TMySetupFileLocationFlags;
    Contents: AnsiString; // for fake files
    PrimaryFileEntry:integer; // for duplicate files
  end;

  ////////// Warning: changes made here must be reflected in StructTemplate.pas !
  TMySetupRegistryOption = (roCreateValueIfDoesntExist, roUninsDeleteValue,
      roUninsClearValue, roUninsDeleteEntireKey, roUninsDeleteEntireKeyIfEmpty,
      roPreserveStringType, roDeleteKey, roDeleteValue, roNoError,
      roDontCreateKey, ro32Bit, ro64Bit);
  const MySetupRegistryOptionLast = ord(High(TMySetupRegistryOption));
  type TMySetupRegistryOptions = set of TMySetupRegistryOption;

  TMySetupRegistryEntry = record // in-memory only
    Subkey, ValueName, ValueData: AnsiString;
    Components, Tasks, Languages, Check, AfterInstall, BeforeInstall: AnsiString;
    MinVersion, OnlyBelowVersion: TMySetupVersionData;
    RootKey: HKEY;
//    PermissionsEntry: Smallint;
    Typ: (rtNone, rtString, rtExpandString, rtDWord, rtBinary, rtMultiString, rtQWord);
    Options: TMySetupRegistryOptions;
  end;

  TMySetupRunOption = (roShellExec, roSkipIfDoesntExist,
      roPostInstall, roUnchecked, roSkipIfSilent, roSkipIfNotSilent,
      roHideWizard, roRun32Bit, roRun64Bit, roRunAsOriginalUser);
  const MySetupRunOptionLast = ord(High(TMySetupRunOption));
  type TMySetupRunOptions = set of TMySetupRunOption;

  TMySetupRunEntry = record // in-memory only
    Name, Parameters, WorkingDir, RunOnceId, StatusMsg, Verb: AnsiString;
    Description, Components, Tasks, Languages, Check, AfterInstall, BeforeInstall: AnsiString;
    MinVersion, OnlyBelowVersion: TMySetupVersionData;
    ShowCmd: Integer;
    Wait: (rwWaitUntilTerminated, rwNoWait, rwWaitUntilIdle);
    Options: TMySetupRunOptions;
  end;

  TMySetupIconCloseOnExit = (icNoSetting, icYes, icNo);
  TMySetupIconEntry = record // in-memory only
    IconName, Filename, Parameters, WorkingDir, IconFilename, Comment: AnsiString;
    Components, Tasks, Languages, Check, AfterInstall, BeforeInstall: AnsiString;
    MinVersion, OnlyBelowVersion: TMySetupVersionData;
    IconIndex, ShowCmd: Integer;
    CloseOnExit: TMySetupIconCloseOnExit;
    HotKey: Word;
    Options: set of (ioUninsNeverUninstall, ioCreateOnlyIfFileExists,
      ioUseAppPaths);
  end;

  TMySetupTaskEntry = record // in-memory only
    Name, Description, GroupDescription, Components, Languages, Check: AnsiString;
    Level: Integer;
    Used: Boolean;
    MinVersion, OnlyBelowVersion: TMySetupVersionData;
    Options: set of (toExclusive, toUnchecked, toRestart, toCheckedOnce,
      toDontInheritCheck);
  end;

  TMySetupComponentEntry = record // in-memory only
    Name, Description, Types, Languages, Check: AnsiString;
    ExtraDiskSpaceRequired: Int64;
    Level: Integer;
    Used: Boolean;
    MinVersion, OnlyBelowVersion: TMySetupVersionData;
    Options: set of (coFixed, coRestart, coDisableNoUninstallWarning,
      coExclusive, coDontInheritCheck);
  end;

  TMySetupTypeOption = (toIsCustom);
  TMySetupTypeOptions = set of TMySetupTypeOption;
  TMySetupTypeType = (ttUser, ttDefaultFull, ttDefaultCompact, ttDefaultCustom);
  TMySetupTypeEntry = record
    Name, Description, Languages, Check: AnsiString;
    MinVersion, OnlyBelowVersion: TMySetupVersionData;
    Options: TMySetupTypeOptions;
    Typ: TMySetupTypeType;
  end;

  TMySetupCustomMessageEntry = record
    Name, Value: AnsiString;
    LangIndex: Integer;
  end;

  TMySetupLanguageEntry = record
    { Note: LanguageName is Unicode }
    Name, LanguageName, DialogFontName, TitleFontName, WelcomeFontName,
      CopyrightFontName, Data, LicenseText, InfoBeforeText,
      InfoAfterText: AnsiString;
    LanguageID, LanguageCodePage: Cardinal;
    DialogFontSize: Integer;
    TitleFontSize: Integer;
    WelcomeFontSize: Integer;
    CopyrightFontSize: Integer;
    RightToLeft: Boolean;
  end;

   ////////// Warning: changes made here must be reflected in StructTemplate.pas !
  TMySetupDirOption = (doUninsNeverUninstall, doDeleteAfterInstall,
    doUninsAlwaysUninstall, doSetNTFSCompression, doUnsetNTFSCompression);
  const MySetupDirOptionLast = ord(High(TMySetupDirOption));
  type TMySetupDirOptions = set of TMySetupDirOption;

  TMySetupDirEntry = record
    DirName: AnsiString;
    Components, Tasks: AnsiString;
    Languages, Check, AfterInstall, BeforeInstall: AnsiString;
    Attribs: Integer;
    MinVersion, OnlyBelowVersion: TMySetupVersionData;
    Options: TMySetupDirOptions;
  end;

  TMySetupIniOption = (ioCreateKeyIfDoesntExist, ioUninsDeleteEntry,
    ioUninsDeleteEntireSection, ioUninsDeleteSectionIfEmpty,
    { internally used: }
    ioHasValue);
  const MySetupIniOptionLast = ord(High(TMySetupIniOption));
  type TMySetupIniOptions = set of TMySetupIniOption;

  TMySetupIniEntry = record
    Filename, Section, Entry, Value: AnsiString;
    Components, Tasks, Languages, Check, AfterInstall, BeforeInstall: AnsiString;
    MinVersion, OnlyBelowVersion: TMySetupVersionData;
    Options: TMySetupIniOptions;
  end;

  TMySetupDeleteType = (dfFiles, dfFilesAndOrSubdirs, dfDirIfEmpty);
  TMySetupDeleteEntry = record
    Name: AnsiString;
    Components, Tasks, Languages, Check, AfterInstall, BeforeInstall: AnsiString;
    MinVersion, OnlyBelowVersion: TMySetupVersionData;
    DeleteType: TMySetupDeleteType;
  end;

////////// variables get filled in verXXXX units based on information
////////// in structXXXX
var
  SetupHeaderSize, SetupHeaderStrings, SetupHeaderAnsiStrings: Integer;
  SetupLanguageEntrySize, SetupLanguageEntryStrings, SetupLanguageEntryAnsiStrings: Integer;
  SetupCustomMessageEntrySize, SetupCustomMessageEntryStrings, SetupCustomMessageEntryAnsiStrings: Integer;
  SetupPermissionEntrySize, SetupPermissionEntryStrings, SetupPermissionEntryAnsiStrings: Integer;
  SetupTypeEntrySize, SetupTypeEntryStrings, SetupTypeEntryAnsiStrings: Integer;
  SetupComponentEntrySize, SetupComponentEntryStrings, SetupComponentEntryAnsiStrings: Integer;
  SetupTaskEntrySize, SetupTaskEntryStrings, SetupTaskEntryAnsiStrings: Integer;
  SetupDirEntrySize, SetupDirEntryStrings, SetupDirEntryAnsiStrings: Integer;
  SetupFileEntrySize, SetupFileEntryStrings, SetupFileEntryAnsiStrings: Integer;
  SetupIconEntrySize, SetupIconEntryStrings, SetupIconEntryAnsiStrings: Integer;
  SetupIniEntrySize, SetupIniEntryStrings, SetupIniEntryAnsiStrings: Integer;
  SetupRegistryEntrySize, SetupRegistryEntryStrings, SetupRegistryEntryAnsiStrings: Integer;
  SetupDeleteEntrySize, SetupDeleteEntryStrings, SetupDeleteEntryAnsiStrings: Integer;
  SetupRunEntrySize, SetupRunEntryStrings, SetupRunEntryAnsiStrings: Integer;
  SetupFileLocationEntrySize, SetupFileLocationEntryStrings, SetupFileLocationEntryAnsiStrings: Integer;

const
  UNI_FIRST = 5205; // First Inno Setup version that had Unicode support
  ANSI_LAST = 5602; // From IS version 6.0 there is only Unicode version

//////////  encapsulates the version-specific stuff
type
  TInnoVer = class
  public
    VerSupported:integer;
    IsUnicode:boolean;
    IsRT:boolean;
    SetupID:array[1..12] of AnsiChar; // other units have no access to global data in structXXXX.pas
    OfsTabSize:integer;  // same reason
    constructor Create; virtual; abstract;
    procedure SetupSizes; virtual; abstract;
    procedure UnifySetupLdrOffsetTable(const p; var OffsetTable:TMySetupLdrOffsetTable); virtual; abstract;
    procedure UnifySetupHeader(const p; var SetupHeader:TMySetupHeader); virtual; abstract;
    procedure UnifyFileEntry(const p; var FileEntry:TMySetupFileEntry); virtual; abstract;
    procedure UnifyFileLocationEntry(const p; var FileLocationEntry:TMySetupFileLocationEntry); virtual; abstract;
    procedure UnifyRegistryEntry(const p; var RegistryEntry:TMySetupRegistryEntry); virtual; abstract;
    procedure UnifyRunEntry(const p; var RunEntry:TMySetupRunEntry); virtual; abstract;
    procedure UnifyIconEntry(const p; var IconEntry:TMySetupIconEntry); virtual; abstract;
    procedure UnifyTaskEntry(const p; var TaskEntry:TMySetupTaskEntry); virtual; abstract;
    procedure UnifyComponentEntry(const p; var ComponentEntry:TMySetupComponentEntry); virtual; abstract;
    procedure UnifyTypeEntry(const p; var TypeEntry:TMySetupTypeEntry); virtual; abstract;
    procedure UnifyCustomMessageEntry(const p; var CustomMessageEntry:TMySetupCustomMessageEntry); virtual; abstract;
    procedure UnifyLanguageEntry(const p; var LanguageEntry:TMySetupLanguageEntry); virtual; abstract;
    procedure UnifyDirEntry(const p; var DirEntry: TMySetupDirEntry); virtual; abstract;
    procedure UnifyIniEntry(const p; var IniEntry: TMySetupIniEntry); virtual; abstract;
    procedure UnifyDeleteEntry(const p; var DeleteEntry: TMySetupDeleteEntry); virtual; abstract;
  end;

  TByteArray = array [byte] of byte;
  PByteArray = ^TByteArray;

///////// all objects representing supported versions are stored here
var
  VerList:array of TInnoVer;

procedure TranslateSet(const SourceSet; var DestSet; const XlatTab: TByteArray; MaxElement: integer);

// Delphi's dynamic strings get reallocated on every change (in this case, on every append).
// If a string is at least 100K, operations on it slow down significantly.
type
  TBigString=object // old-style object: no VMT and other stuff unless really necessary
    Capacity, Count, IncrementSize:integer;
    Data: PAnsiChar;
    constructor Init(IncrementBy:integer=10000);
    destructor Destroy;
    procedure SetCapacity(NewCapacity:integer); // new capacity can be greater than requested
    procedure AppendString(s: AnsiString);
    function CopyAsString: AnsiString;
  end;

function NormalizeStringVal(Input: AnsiString) : AnsiString; overload;
function NormalizeStringVal(Input: WideString) : AnsiString; overload;
function CopyStringVal(Input: AnsiString) : AnsiString; overload;
function CopyStringVal(Input: WideString) : AnsiString; overload;

function GetVersionBySetupId(const pSetupId; var VerObject: TInnoVer):boolean;

implementation

constructor TBigString.Init(IncrementBy: integer = 10000);
begin
  Capacity := 0;
  Count := 0;
  IncrementSize := IncrementBy;
  Data := nil;
end;

destructor TBigString.Destroy;
begin
  if Data<>nil then FreeMem(Data);
end;

procedure TBigString.SetCapacity(NewCapacity:integer);
var t:integer;
begin
  t:=NewCapacity mod IncrementSize;
  if t>0 then Inc(NewCapacity,IncrementSize-t);
  ReallocMem(Data,NewCapacity);
  Capacity:=NewCapacity;
end;

procedure TBigString.AppendString(s: AnsiString);
begin
  if Count+length(s) > Capacity then SetCapacity(Count+length(s));
  Move(s[1],Data[Count],length(s));
  Inc(Count,length(s));
end;

function TBigString.CopyAsString: AnsiString;
begin
  SetLength(Result,Count);
  Move(Data^,Result[1],Count);
end;


procedure TranslateSet(const SourceSet; var DestSet; const XlatTab: TByteArray; MaxElement: integer);
var
  SourceArray: TByteArray absolute SourceSet;
  DestArray: TByteArray absolute DestSet;
  i:integer;
begin
  for i:=0 to MaxElement do
    if XlatTab[i]<>255 then
      if (SourceArray[XlatTab[i] shr 3] and (1 shl (XlatTab[i] and 7))) <> 0 then //XlatTab[i] in SourceSet then
        DestArray[i shr 3]:=DestArray[i shr 3] or (1 shl (i and 7));  //Include(DestSet,i);
end;

function NormalizeStringVal(Input: AnsiString) : AnsiString;
begin
  Result := Input;
end;

function NormalizeStringVal(Input: WideString) : AnsiString;
var
  len: integer;
begin
  Result := '';
  len := WideCharToMultiByte(CP_UTF8, 0, PWideChar(Input), Length(Input), nil, 0, nil, nil);
  if (len > 0) then
  begin
    SetLength(Result, len);
    WideCharToMultiByte(CP_UTF8, 0, PWideChar(Input), Length(Input), PAnsiChar(Result), len, nil, nil);
  end;
end;

function CopyStringVal(Input: WideString) : AnsiString;
var
  len: integer;
begin
  len := Length(Input) * sizeof(WideChar);
  SetLength(Result, len);
  CopyMemory(@Result[1], @Input[1], len);
end;

function CopyStringVal(Input: AnsiString) : AnsiString;
begin
  Result := Input;
end;

function GetVersionBySetupId(const pSetupId; var VerObject: TInnoVer):boolean;
var
  i:integer;
  aSetupId: array [1..12] of char absolute pSetupId;
begin
  VerObject := nil;
  for i:=0 to High(VerList) do
    if VerList[i].SetupID=aSetupID then begin VerObject:=VerList[i]; break end;
  Result := VerObject<>nil;
end;

end.
