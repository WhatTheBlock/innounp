{ $jrsoftware: issrc/Projects/Version.inc,v 1.4 2003/04/14 18:53:12 jr Exp $ }

{ Determine Delphi/C++Builder version }
{$IFNDEF VER80}  { if it's not Delphi 1.0 }
  {$IFNDEF VER90}  { if it's not Delphi 2.0 }
    {$IFNDEF VER93}  { and it's not C++Builder 1.0 }
      {$DEFINE IS_D3}  { then it must be at least Delphi 3 or C++Builder 3 }
      {$DEFINE Delphi3orHigher}
      {$IFNDEF VER100}  { if it's not Delphi 3.0 }
        {$IFNDEF VER110}  { and it's not C++Builder 3.0 }
          {$DEFINE IS_D4}  { then it must be at least Delphi 4 or C++Builder 4 }
          {$IFNDEF VER120} {$IFNDEF VER125}  { if it's not Delphi 4 or C++Builder 4 }
            {$DEFINE IS_D5}  { then it must be at least Delphi 5 or C++Builder 5 }
            {$IFNDEF VER130}  { if it's not Delphi 5 or C++Builder 5 }
              {$DEFINE IS_D6}  { then it must be at least Delphi 6 or C++Builder 6 }
            {$ENDIF}
          {$ENDIF} {$ENDIF}
        {$ENDIF}
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}
