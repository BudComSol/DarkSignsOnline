Attribute VB_Name = "basCommands"
Option Explicit

Public AuthorizePayment As Boolean

Private scrConsole(1 To 4) As ScriptControl
Private scrConsoleContext(1 To 4) As clsScriptFunctions
Private scrConsoleDScript(1 To 4) As Boolean

Private CLIPaths() As String

Public Sub InitBasCommands()
    Dim X As Integer
    For X = 1 To 4
        Set scrConsole(X) = New ScriptControl
        scrConsole(X).AllowUI = False
        scrConsole(X).Timeout = -1
        scrConsole(X).UseSafeSubset = True
        scrConsole(X).Language = "VBScript"

        Dim CLIArguments(0 To 0) As Variant
        CLIArguments(0) = "/dev/tty" & X
        Set scrConsoleContext(X) = New clsScriptFunctions
        scrConsoleContext(X).Configure X, "", True, scrConsole(X), CLIArguments, "", "", 0, False, False, True, "", "", ""

        scrConsole(X).AddObject "DSO", scrConsoleContext(X), True
        LoadBasicFunctions scrConsole(X)

        scrConsoleDScript(X) = True
    Next

    ReDim CLIPaths(0 To 1)
    CLIPaths(0) = "."
    CLIPaths(UBound(CLIPaths)) = "/system/commands"
End Sub

Public Function SafePath(ByVal Path As String, Optional ByVal Prefix As String = "") As String
    Path = Replace(Path, "\", "/")
    If Path = ".." Or Left(Path, 3) = "../" Or Right(Path, 3) = "/.." Or InStr(Path, "/../") > 0 Then
        SafePath = App.Path & "/user/f/a/i/l/s/a/f/e.txt"
        Err.Raise vbObjectError + 9666, , "Invalid character in path"
        Exit Function
    End If

    SafePath = App.Path & "/user/" & Prefix & Path
    While InStr(SafePath, "//") > 0
        SafePath = Replace(SafePath, "//", "/")
    Wend
    If Right(SafePath, 1) = "/" Then
        SafePath = Mid(SafePath, 1, Len(SafePath) - 1)
    End If

    SafePath = Replace(SafePath, "\", "/")
End Function

Public Function ResolvePath(ByVal ConsoleID As Integer, ByVal Path As String) As String
    If ConsoleID = 0 Then
        ResolvePath = ResolvePathRel(".", Path)
        Exit Function
    End If
    ResolvePath = ResolvePathRel(cPath(ConsoleID), Path)
End Function

Public Function ResolvePathRel(ByVal CCPath As String, ByVal Path As String) As String
    If Path = "" Then
        ResolvePathRel = CCPath
        Exit Function
    End If

    If Left(Path, 1) = "/" Or Left(Path, 1) = "\" Then
        ResolvePathRel = Path
    Else
        ResolvePathRel = CCPath & "/" & Path
    End If

    ResolvePathRel = Replace(ResolvePathRel, "\", "/")
    While InStr(ResolvePathRel, "//") > 0
        ResolvePathRel = Replace(ResolvePathRel, "//", "/")
    Wend

    Dim IsRelative As Boolean
    IsRelative = True
    If Left(ResolvePathRel, 1) = "/" Then
        ResolvePathRel = Mid(ResolvePathRel, 2)
        IsRelative = False
    End If

    Dim ResolvePathSplit() As String
    ResolvePathSplit = Split(ResolvePathRel, "/")
    
    Dim ResolvePathSplitCut() As String
    ReDim ResolvePathSplitCut(0 To 0)

    Dim X As Long
    ResolvePathRel = ""
    Dim CurPath As String
    For X = LBound(ResolvePathSplit) To UBound(ResolvePathSplit)
        CurPath = ResolvePathSplit(X)
        If CurPath = "" Or CurPath = "." Then
            ' Don't do anything!
        ElseIf CurPath = ".." Then
            If UBound(ResolvePathSplitCut) > 0 Then
                ReDim Preserve ResolvePathSplitCut(0 To UBound(ResolvePathSplitCut) - 1)
            End If
        Else
            ReDim Preserve ResolvePathSplitCut(0 To UBound(ResolvePathSplitCut) + 1)
            ResolvePathSplitCut(UBound(ResolvePathSplitCut)) = CurPath
        End If
    Next X

    If UBound(ResolvePathSplitCut) = 0 Then
        ResolvePathRel = "/"
        Exit Function
    End If

    If IsRelative Then
        ResolvePathSplitCut(0) = "."
    Else
        ResolvePathSplitCut(0) = ""
    End If
    ResolvePathRel = Join(ResolvePathSplitCut, "/")
End Function

Public Function ResolveCommand(ByVal ConsoleID As Integer, ByVal Command As String) As String
    If InStr(Command, "/") > 0 Or InStr(Command, "\") > 0 Then
        ResolveCommand = ResolvePath(ConsoleID, Command)
        Exit Function
    End If

    If LCase(Right(Command, 3)) <> ".ds" Then
        Command = Command & ".ds"
    End If

    Dim X As Long

    Dim tmpCommand As String
    For X = 0 To UBound(CLIPaths)
        ResolveCommand = ResolvePath(ConsoleID, CLIPaths(X) & "/" & Command)
        If Left(ResolveCommand, 1) <> "/" Then
            GoTo SkipThisPath
        End If

        If basGeneral.FileExists(ResolveCommand) Then
            Exit Function
        End If
SkipThisPath:
    Next

    ResolveCommand = ""
End Function


Public Function VBEscapeSimple(ByVal Str As String) As String
    VBEscapeSimple = Replace(Str, """", """""")
End Function

Public Function VBEscapeSimpleQuoted(ByVal Str As String, Optional ByVal ForceQuotes As Boolean = False) As String
    If Not ForceQuotes Then
        If IsKeyword(Str) Or IsNumeric(Str) Then
            VBEscapeSimpleQuoted = Str
            Exit Function
        End If
    End If
    VBEscapeSimpleQuoted = """" & Replace(Str, """", """""") & """"
End Function


Public Function Run_Command(ByVal tmpS As String, ByVal ConsoleID As Integer, Optional ScriptFrom As String, Optional FromScript As Boolean = True)
    If ConsoleID < 1 Then
        ConsoleID = 1
    End If
    If ConsoleID > 4 Then
        ConsoleID = 4
    End If

    If tmpS = "" Then
        Exit Function
    End If

    CancelScript(ConsoleID) = False

    Dim ErrNumber As Long
    Dim ErrDescription As String

    Dim CodeFaulted As Boolean
    CodeFaulted = False
    On Error GoTo OnCodeFaulted

    scrConsoleContext(ConsoleID).UnAbort
    scrConsole(ConsoleID).Error.Clear

    Dim RunStr As String
    Dim OptionDScript As Boolean
    OptionDScript = scrConsoleDScript(ConsoleID)
    RunStr = ParseCommandLine(tmpS, OptionDScript, False, ConsoleID, True)
    scrConsoleDScript(ConsoleID) = OptionDScript
    scrConsole(ConsoleID).AddCode RunStr
    On Error GoTo 0
    If Not CodeFaulted Then
        GoTo ScriptEnd
    End If

    Dim ObjectErrNumber As Long
    ObjectErrNumber = ErrNumber - vbObjectError
    
    If ObjectErrNumber = 9001 Then
        GoTo ScriptCancelled
    End If
    If ObjectErrNumber = 9002 Then
        GoTo ScriptEnd
    End If
    Dim ErrHelp As String
    ErrHelp = ""
    If ErrNumber = 13 Then
        ErrHelp = "This error might mean the command you tried to use does not exist"
    End If
    
    Dim ErrNumberStr As String
    If ObjectErrNumber >= 0 And ObjectErrNumber <= 65535 Then
        ErrNumberStr = "(O#" & ObjectErrNumber & ")"
    Else
        ErrNumberStr = "(E#" & ErrNumber & ")"
    End If

    SayRaw ConsoleID, "Error processing CLI input: " & ConsoleEscape(ErrDescription) & " " & ErrNumberStr & " " & ErrHelp & "{{red}}"
    GoTo ScriptEnd

ScriptCancelled:
    SayRaw ConsoleID, "Script Stopped by User (CTRL + B){{orange}}"
ScriptEnd:
    scrConsoleContext(ConsoleID).CleanupScriptTasks
    Exit Function

OnCodeFaulted:
    ErrNumber = scrConsole(ConsoleID).Error.Number
    ErrDescription = scrConsole(ConsoleID).Error.Description
    If ErrNumber = 0 Or ErrDescription = "" Then
        ErrNumber = Err.Number
        ErrDescription = Err.Description
    End If

    CodeFaulted = True
    Resume Next
End Function

Public Function ConsoleEscape(ByVal tmpS As String) As String
    tmpS = Replace(tmpS, ConsoleInvisibleChar, "")
    tmpS = Replace(tmpS, "}}", "}" & ConsoleInvisibleChar & "}")
    tmpS = Replace(tmpS, "{{", "{" & ConsoleInvisibleChar & "{")
    ConsoleEscape = tmpS
End Function

Public Function ParseCommandLineOptional(ByVal tmpS As String, ByVal AutoVariablesFrom As Integer, Optional ByVal AllowCommands As Boolean = True) As String
    Dim OptionDScript As Boolean
    OptionDScript = False
    ParseCommandLineOptional = ParseCommandLine(tmpS, OptionDScript, True, AutoVariablesFrom, AllowCommands)
End Function

Public Function ParseCommandLine(ByVal tmpS As String, ByRef OptionDScript As Boolean, ByVal OptionExplicit As Boolean, ByVal AutoVariablesFrom As Integer, ByVal AllowCommands As Boolean) As String
    Dim RestStart As Long
    RestStart = 1
    ParseCommandLine = ""
    While RestStart > 0
        tmpS = Mid(tmpS, RestStart)
        ParseCommandLine = ParseCommandLine & ParseCommandLineInt(tmpS, RestStart, OptionExplicit, OptionDScript, AutoVariablesFrom, AllowCommands)
    Wend

    If OptionExplicit Then
        ParseCommandLine = "Option Explicit : " & ParseCommandLine
    End If
End Function

Public Function IsKeyword(ByVal Candidate As String) As Boolean
    Dim lCandidate As String
    lCandidate = LCase(Candidate)
    IsKeyword = (lCandidate = "true" Or lCandidate = "false" Or lCandidate = "null" Or lCandidate = "nothing")
End Function

Public Function IsValidVarName(ByVal Candidate As String) As Boolean
    If Candidate = "" Then
        IsValidVarName = False
        Exit Function
    End If

    If IsKeyword(Candidate) Then
        IsValidVarName = False
        Exit Function
    End If

    Dim lCandidate As String
    lCandidate = LCase(Candidate)
    If IsNumeric(Candidate) Then
        IsValidVarName = False
        Exit Function
    End If

    Dim X As Long, C As Integer
    For X = 1 To Len(lCandidate)
        C = Asc(Mid(lCandidate, X, 1))
        ' Only check lowercase as we use LCase'd string
        If C >= Asc("a") And C <= Asc("z") Then
            GoTo CIsValid
        End If
        If C >= Asc("0") And C <= Asc("9") Then
            GoTo CIsValid
        End If
        If C = Asc("_") Or C = Asc("(") Or C = Asc(")") Then
            GoTo CIsValid
        End If

        IsValidVarName = False
        Exit Function
CIsValid:
    Next

    IsValidVarName = True
End Function

Private Function ParseCommandLineInt(ByVal tmpS As String, ByRef RestStart As Long, ByRef OptionExplicit As Boolean, ByRef OptionDScript As Boolean, ByVal AutoVariablesFrom As Integer, ByVal AllowCommands As Boolean) As String
    Dim CLIArgs() As String
    Dim CLIArgsQuoted() As Boolean
    ReDim CLIArgs(0 To 0)
    ReDim CLIArgsQuoted(0 To 0)
    Dim curArg As String
    Dim curC As String
    Dim InQuotes As String
    Dim NextInQuotes As String
    Dim InjectYield As Boolean
    Dim IsSimpleCommand As Boolean
    Dim RestSplit As String
    Dim InComment As Boolean

    IsSimpleCommand = True
    RestStart = -1
    NextInQuotes = ""
    InjectYield = False

    Dim X As Long
    For X = 1 To Len(tmpS)
        curC = Mid(tmpS, X, 1)
        If InQuotes <> "" Then
            If curC <> InQuotes Then
                GoTo AddToArg
            End If

            If X < Len(tmpS) And Mid(tmpS, X + 1, 1) = curC Then 'Doubling quotes escapes them
                X = X + 1
                GoTo AddToArg
            End If
           
            GoTo NextArg
        End If
        
        If InComment And curC <> vbLf And curC <> vbCr Then
            GoTo CommandForNext
        End If

        Select Case curC
            Case " ":
                GoTo NextArg
            Case """":
                NextInQuotes = curC
                GoTo NextArg
            Case "'":
                If curArg <> "" Or CLIArgs(0) <> "" Then
                    RestSplit = " "
                    X = X - 1
                    GoTo RestStartSet
                End If
                InComment = True
                curArg = "'"
                GoTo NextArg
            Case ",", ";", "(", ")", "|", "=", "&", "<", ">": ' These mean the user likely intended VBScript and not CLI
                IsSimpleCommand = False
            Case "_":
                If curArg = "" And X < Len(tmpS) Then
                    Dim NextC As String
                    NextC = Mid(tmpS, X + 1, 1)
                    If NextC = vbLf Then
                        IsSimpleCommand = False
                        X = X + 1
                        GoTo CommandForNext
                    ElseIf NextC = vbCr Then
                        IsSimpleCommand = False
                        X = X + 1
                        If X < Len(tmpS) Then
                            NextC = Mid(tmpS, X + 1, 1)
                            If NextC = vbLf Then
                                X = X + 1
                            End If
                        End If
                        GoTo CommandForNext
                    End If
                End If
            Case vbCr:
                If X = Len(tmpS) Then
                    GoTo CommandForNext
                End If
                If Mid(tmpS, X + 1, 1) = vbLf Then
                    X = X + 1
                End If
                RestSplit = vbCrLf
                GoTo RestStartSet
            Case vbLf:
                RestSplit = vbCrLf
                GoTo RestStartSet
            Case ":":
                RestSplit = ":"
RestStartSet:
                RestStart = X + 1
                X = Len(tmpS) + 1
                GoTo NextArg
            'Case Else:
            '   GoTo AddToArg
        End Select
AddToArg:
    curArg = curArg & curC
    If X <> Len(tmpS) Then
        GoTo CommandForNext
    End If
    If InQuotes <> "" Then
        Err.Raise vbObjectError + 9302, , "Unclosed quote in command"
    End If
NextArg:
    If curArg <> "" Or InQuotes <> "" Then
        If CLIArgs(UBound(CLIArgs)) <> "" Then ' Arg 1 and onward
            ReDim Preserve CLIArgs(0 To UBound(CLIArgs) + 1)
            ReDim Preserve CLIArgsQuoted(0 To UBound(CLIArgs))
        Else ' Arg 0
            If Trim(LCase(curArg)) = "rem" Then
                InComment = True
            End If
        End If
        CLIArgs(UBound(CLIArgs)) = curArg
        If InQuotes <> "" Then
            CLIArgsQuoted(UBound(CLIArgs)) = True
        Else
            CLIArgsQuoted(UBound(CLIArgs)) = False
        End If
        curArg = ""
    End If
    InQuotes = NextInQuotes
    NextInQuotes = ""
CommandForNext:
    Next X

    Dim Command As String
    Command = Trim(LCase(CLIArgs(0)))
    If Command = "for" Or Command = "while" Or Command = "do" Then
        InjectYield = True
    End If

    If CLIArgsQuoted(0) Or Not IsSimpleCommand Then
        GoTo NotASimpleCommand
    End If

    If CLIArgs(0) = "" Then
        If RestStart < 0 Then
            Exit Function
        End If

        ParseCommandLineInt = ""
        Exit Function
    End If
    
    Dim ArgStart As Long
    ArgStart = 1
    
    Select Case Command
        Case "next", "wend", "loop", "until", _
                "if", "else", "elseif", "end", _
                "public", "private", "property", "dim", "sub", "function", _
                "const", "enum", "redim", "set", "goto", "type", _
                "throw", "catch", "try", "finally", "on", _
                "for", "while", "do":
            GoTo NotASimpleCommand
        Case "option":
            If UBound(CLIArgs) >= 1 Then
                Command = Trim(LCase(CLIArgs(1)))
                If Command = "dscript" Then
                    OptionDScript = True
                ElseIf Command = "nodscript" Then
                    OptionDScript = False
                Else
                    GoTo NotASimpleCommand
                End If
                ParseCommandLineInt = ""
                GoTo RunSplitCommand
            End If
            GoTo NotASimpleCommand
        Case "rem", "'":
            GoTo NotASimpleCommandButWithOE
        Case "wait":
            If UBound(CLIArgs) >= 1 And Trim(LCase(CLIArgs(1))) = "for" Then
                Command = "waitfor"
                ArgStart = 2
            End If
    End Select
    
    ' We don't want to actually parse anything if we're not opted in
    If Not OptionDScript Then
        GoTo NotASimpleCommand
    End If

    ' First, check if there is a command for it in /system/commands
    Dim CommandNeedFirstComma As Boolean
    If AllowCommands And ((ResolveCommand(AutoVariablesFrom, Command) <> "") Or ((Not IsKeyword(Command)) And (Not IsValidVarName(Command)))) Then
        ParseCommandLineInt = "Call Run(""" & Command & """"
        CommandNeedFirstComma = True
    Else
        ParseCommandLineInt = "PrintVarSingleIfSet " & Command & "("
        CommandNeedFirstComma = False
    End If

    For X = ArgStart To UBound(CLIArgs)
        If X > ArgStart Or CommandNeedFirstComma Then
            ParseCommandLineInt = ParseCommandLineInt & ", "
        End If

        Dim ArgVal As String
        ArgVal = CLIArgs(X)
        If CLIArgsQuoted(X) Then
            GoTo ArgIsNotVar
        End If
        If Left(ArgVal, 1) = "%" And Right(ArgVal, 1) = "%" Then
            Dim ArgValStripped As String
            ArgValStripped = Mid(ArgVal, 2, Len(ArgVal) - 2)
            If Not IsValidVarName(ArgValStripped) Then
                GoTo ArgIsNotVar
            End If
            ParseCommandLineInt = ParseCommandLineInt & ArgValStripped
            GoTo NextCLIFor
        End If
        If Not IsValidVarName(ArgVal) Then
            GoTo ArgIsNotVar
        End If

        If FileExists("/system/commands/help/functions/" & ArgVal & ".ds") Then
            GoTo ArgIsNotVar
        End If

        Dim EvalFaulted As Boolean

        Dim RefFound As Boolean
        RefFound = False
        EvalFaulted = False
        On Error Resume Next
        RefFound = scrConsole(AutoVariablesFrom).Eval("Not (GetRef(" & VBEscapeSimpleQuoted(ArgVal, True) & ") Is Nothing)")
        On Error GoTo 0

        If RefFound Then
            GoTo ArgIsNotVar
        End If

        EvalFaulted = False
        On Error GoTo EvalErrorHandler
        scrConsole(AutoVariablesFrom).AddCode "Option Explicit : VarType " & ArgVal
        On Error GoTo 0

        If EvalFaulted Then
            GoTo ArgIsNotVar
        End If

        ParseCommandLineInt = ParseCommandLineInt & VBEscapeSimple(ArgVal)
        GoTo NextCLIFor
ArgIsNotVar:
        ParseCommandLineInt = ParseCommandLineInt & VBEscapeSimpleQuoted(ArgVal, CLIArgsQuoted(X))
NextCLIFor:
    Next X
    ParseCommandLineInt = ParseCommandLineInt & ")"
    GoTo RunSplitCommand

NotASimpleCommand:
    OptionExplicit = False
NotASimpleCommandButWithOE:
    ParseCommandLineInt = tmpS
    If RestStart > 0 Then
        ParseCommandLineInt = Left(ParseCommandLineInt, RestStart - 2)
    End If

RunSplitCommand:
    If InjectYield Then
        ParseCommandLineInt = ParseCommandLineInt & " : Yield : "
    End If

    If RestStart < 0 Then
        Exit Function
    End If

    ParseCommandLineInt = ParseCommandLineInt & RestSplit
    Exit Function
    
EvalErrorHandler:
    EvalFaulted = True
    Resume Next
End Function

Public Function RGBSplit(ByVal lColor As Long, ByRef R As Long, ByRef G As Long, ByRef b As Long)
    b = lColor And &HFF ' mask the low byte
    G = (lColor And &HFF00&) \ &H100 ' mask the 2nd byte and shift it to the low byte
    R = (lColor And &HFF0000) \ &H10000 ' mask the 3rd byte and shift it to the low byte
End Function

' -y r g b mode
'  SOLID, FLOW, FADEIN, FADEOUT, FADECENTER, FADEINVERSE
Public Sub DrawSimple(ByVal YPos As Long, ByVal RGBVal As Long, ByVal mode As String, ByVal ConsoleID As Integer)
    If YPos >= 0 Then
        Exit Sub
    End If

    mode = i(mode)

    Dim yIndex As Integer, n As Integer
    yIndex = (YPos * -1)

    If mode = "solid" Then
        ReDim Console(ConsoleID, yIndex).Draw(1 To 1)
        Console(ConsoleID, yIndex).Draw(1).Color = RGBVal
        Console(ConsoleID, yIndex).Draw(1).HPos = 0
        Exit Sub
    End If

    Dim R As Long, G As Long, b As Long
    Dim RB As Long, GB As Long, BB As Long
    RGBSplit RGBVal, R, G, b

    ReDim Console(ConsoleID, yIndex).Draw(1 To (DrawDividerWidth + 1))
    For n = 1 To DrawDividerWidth
        Console(ConsoleID, yIndex).Draw(n).HPos = (frmConsole.Width / DrawDividerWidth) * (n - 1)
    Next
    Console(ConsoleID, yIndex).Draw(DrawDividerWidth + 1).Color = -1
    Console(ConsoleID, yIndex).Draw(DrawDividerWidth + 1).HPos = frmConsole.Width

    Select Case mode
    Case "fadecenter":
        RB = R
        GB = G
        BB = b

        For n = ((DrawDividerWidth / 2) + 1) To DrawDividerWidth
            R = R - (DrawDividerWidth / 2)
            G = G - (DrawDividerWidth / 2)
            b = b - (DrawDividerWidth / 2)
            If R < 1 Then R = 0
            If G < 1 Then G = 0
            If b < 1 Then b = 0

            Console(ConsoleID, yIndex).Draw(n).Color = RGB(R, G, b)
        Next n
        
        R = RB
        G = GB
        b = BB

        For n = (DrawDividerWidth / 2) To 1 Step -1
            R = R - (DrawDividerWidth / 2)
            G = G - (DrawDividerWidth / 2)
            b = b - (DrawDividerWidth / 2)
            If R < 1 Then R = 0
            If G < 1 Then G = 0
            If b < 1 Then b = 0
        
            Console(ConsoleID, yIndex).Draw(n).Color = RGB(R, G, b)
        Next n

    Case "fadeinverse":
        RB = R
        GB = G
        BB = b

        For n = DrawDividerWidth To ((DrawDividerWidth / 2) + 1) Step -1
            R = R - (DrawDividerWidth / 2)
            G = G - (DrawDividerWidth / 2)
            b = b - (DrawDividerWidth / 2)
            If R < 1 Then R = 0
            If G < 1 Then G = 0
            If b < 1 Then b = 0
        
            Console(ConsoleID, yIndex).Draw(n).Color = RGB(R, G, b)
        Next n
        
        R = RB
        G = GB
        b = BB

        For n = 1 To (DrawDividerWidth / 2)
            R = R - (DrawDividerWidth / 2)
            G = G - (DrawDividerWidth / 2)
            b = b - (DrawDividerWidth / 2)
            If R < 1 Then R = 0
            If G < 1 Then G = 0
            If b < 1 Then b = 0
        
            Console(ConsoleID, yIndex).Draw(n).Color = RGB(R, G, b)
        Next n

    Case "fadein":
        For n = 1 To DrawDividerWidth
            R = R - 4
            G = G - 4
            b = b - 4
            If R < 1 Then R = 0
            If G < 1 Then G = 0
            If b < 1 Then b = 0
        
            Console(ConsoleID, yIndex).Draw(n).Color = RGB(R, G, b)
        Next n

    Case "fadeout":
        For n = DrawDividerWidth To 1 Step -1
            R = R - 4
            G = G - 4
            b = b - 4
            If R < 1 Then R = 0
            If G < 1 Then G = 0
            If b < 1 Then b = 0
        
            Console(ConsoleID, yIndex).Draw(n).Color = RGB(R, G, b)
        Next n

    Case "flow":
        For n = 1 To ((DrawDividerWidth / 4) * 1)
            R = R - 5
            G = G - 5
            b = b - 5
            If R < 1 Then R = 0
            If G < 1 Then G = 0
            If b < 1 Then b = 0
            Console(ConsoleID, yIndex).Draw(n).Color = RGB(R, G, b)
        Next n
        For n = (((DrawDividerWidth / 4) * 1) + 1) To (((DrawDividerWidth / 4) * 2))
            R = R + 5
            G = G + 5
            b = b + 5
            If R < 1 Then R = 0
            If G < 1 Then G = 0
            If b < 1 Then b = 0
            Console(ConsoleID, yIndex).Draw(n).Color = RGB(R, G, b)
        Next n
        For n = (((DrawDividerWidth / 4) * 2) + 1) To (((DrawDividerWidth / 4) * 3))
            R = R - 5
            G = G - 5
            b = b - 5
            If R < 1 Then R = 0
            If G < 1 Then G = 0
            If b < 1 Then b = 0
            Console(ConsoleID, yIndex).Draw(n).Color = RGB(R, G, b)
        Next n
        For n = (((DrawDividerWidth / 4) * 3) + 1) To (((DrawDividerWidth / 4) * 4))
            R = R + 5
            G = G + 5
            b = b + 5
            If R < 1 Then R = 0
            If G < 1 Then G = 0
            If b < 1 Then b = 0
            Console(ConsoleID, yIndex).Draw(n).Color = RGB(R, G, b)
        Next n

    Case "solid":
        ReDim Console(ConsoleID, yIndex).Draw(1 To 1)
        Console(ConsoleID, yIndex).Draw(1).Color = RGB(R, G, b)
        Console(ConsoleID, yIndex).Draw(1).HPos = 0

    End Select

    frmConsole.QueueConsoleRender
End Sub

Public Sub SetYDiv(ByVal n As Integer)
    If n < 0 Then n = 0
    If n > 720 Then n = 720
    
    yDiv = n

    frmConsole.QueueConsoleRender
End Sub

Public Sub MusicCommand(ByVal s As String)
    Select Case i(s)

    Case "start": RegSave "music", "on"
    Case "on": RegSave "music", "on"

    Case "stop": RegSave "music", "off": basMusic.StopMusic
    Case "off": RegSave "music", "off": basMusic.StopMusic

    Case "next": basMusic.StopMusic

    Case "prev":
        basMusic.PrevMusicIndex
        basMusic.PrevMusicIndex
        basMusic.StopMusic
    End Select
End Sub


Public Sub SetUsername(ByVal s As String, ByVal ConsoleID As Integer)
    If Authorized = True Then
        SayError "You are already logged in.", ConsoleID
        Exit Sub
    End If

    RegSave "myUsernameDev", s
    
    Dim Password As String
    If myPassword = "" Then
        Password = ""
    Else
        Password = "[hidden]"
    End If
    SayRaw ConsoleID, "Your new details are shown below." & "{{orange}}"
    SayRaw ConsoleID, "Username: " & myUsername() & "{{orange 16}}"
    SayRaw ConsoleID, "Password: " & Password & "{{orange 16}}"
End Sub

Public Sub SetPassword(ByVal s As String, ByVal ConsoleID As Integer)
    If Authorized = True Then
        SayError "You are already logged in.", ConsoleID
        Exit Sub
    End If

    RegSave "myPasswordDev", s
    
    Dim Password As String
    If myPassword = "" Then
        Password = ""
    Else
        Password = "[hidden]"
    End If
    SayRaw ConsoleID, "Your new details are shown below." & "{{orange}}"
    SayRaw ConsoleID, "Username: " & myUsername() & "{{orange 16}}"
    SayRaw ConsoleID, "Password: " & Password & "{{orange 16}}"
End Sub

Public Sub ClearConsole(ByVal ConsoleID As Integer)
    Dim n As Integer
    For n = 1 To 299
        Console(ConsoleID, 1) = Console_Line_Defaults
    Next n
End Sub

Public Sub EditFile(ByVal s As String, ByVal ConsoleID As Integer)
    If s = "" Then
        Exit Sub
    End If

    If Not basGeneral.FileExists(s) Then
        SayRaw ConsoleID, "{{green}}File Not Found, Creating: " & s
        WriteFile s, ""
    End If

    Dim ExternalEditor As Boolean
    ExternalEditor = RegLoad("externaleditor", False)

    If ExternalEditor Then
        SayRaw ConsoleID, "{{green}}Opening external editor for " & s
        frmConsole.OpenFileDefault s
        Exit Sub
    End If

    EditorFile_Short = GetShortName(s)
    EditorFile_Long = s

    frmEditor.Show vbModal
    
    If Trim(EditorRunFile) <> "" Then
        Shift_Console_Lines ConsoleID
        Dim EmptyArguments(0 To 0) As Variant
        EmptyArguments(0) = ""
        Run_Script EditorRunFile, ConsoleID, EmptyArguments, "CONSOLE", True, False, False, "", ""
    End If
    
    
    Exit Sub
errorDir:
End Sub

Public Function GetShortName(ByVal s As String) As String
    s = ReverseString(s)
    s = Replace(s, "\", "/")

    If InStr(s, "/") > 0 Then
        s = Mid(s, 1, InStr(s, "/") - 1)
    End If

    GetShortName = Trim(ReverseString(s))
End Function

Public Function SayError(s As String, ByVal ConsoleID As Integer)
    SayRaw ConsoleID, "Error - " & s & " {{orange}}"
End Function

Public Sub PauseConsole(ByVal s As String, ByVal ConsoleID As Integer, Optional ByVal RGBVal As Long = -1)
    ConsolePaused(ConsoleID) = True

    Dim propSpace As String

    Dim strDefault As Boolean
    strDefault = False

    If Not Has_Property_Space(s) Then
        propSpace = "lblue 10 noprespace"
    Else
        propSpace = Get_Property_Space(s)
    End If
    s = Kill_Property_Space(s)

    If Trim(s) = "" Then
        s = "Press any key to continue..."
        strDefault = True
    End If

    s = "{{" & propSpace & "}}" & s
    SayRaw ConsoleID, s
    If RGBVal >= 0 Then
        DrawSimple -1, RGBVal, "solid", ConsoleID
    End If
    Do
        DoEvents: DoEvents: DoEvents: DoEvents: DoEvents: DoEvents: DoEvents: DoEvents
    Loop Until ConsolePaused(ConsoleID) = False
End Sub
