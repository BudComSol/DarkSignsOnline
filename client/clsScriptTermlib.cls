VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "clsScriptTermlib"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit

Private IsConf As Boolean
Private GSF As clsScriptFunctions

Public Sub SetGSF(NewGSF As clsScriptFunctions)
    If IsConf Then
        Exit Sub
    End If
    Set GSF = NewGSF
    IsConf = True
End Sub

Private Sub Class_Initialize()
    IsConf = False
End Sub

Public Function SayWithBGColor(ByVal RGBVal As String, ByVal Str As String)
    GSF.Say Str
    GSF.DRAW -1, RGBVal, "solid"
End Function

Public Function SaySlowWithBGColor(ByVal RGBVal As String, ByVal Delay As Long, ByVal Str As String, ByVal Style As String)
    If GSF.IsOutputDisabled Then
        GSF.Say Str & Style
        Exit Function
    End If

    Dim X As Long
    Style = "{{" & Replace(Replace(Style, "{", ""), "}", "") & "}}"
    GSF.Say Left(Str, 1) & Style
    If RGBVal >= 0 Then
        GSF.DRAW -1, RGBVal, "solid"
    End If
    For X = 2 To Len(Str)
        If Mid(Str, X, 1) = ConsoleInvisibleChar Then
            X = X + 1
        End If
        GSF.Wait Delay
        GSF.SayLine Mid(Str, 1, X), -1, True
    Next
End Function

Public Function SaySlow(ByVal Delay As Long, ByVal Str As String, ByVal Style As String)
    SaySlowWithBGColor -1, Delay, Str, Style
End Function

Public Function GetAsciiWithCPromptBG(ByVal RGBVal As String, ByVal Prompt As String)
    GSF.Say "{{noprespace}}" & Prompt & "> [_]"
    If RGBVal >= 0 Then
        GSF.DRAW -1, RGBVal, "solid"
    End If
    Dim Choice As Long
    Choice = GSF.GetASCII()
    GSF.SayLine "{{noprespace}}" & Prompt & "> [" & Chr(Choice) & "]", -1, True
    GetAsciiWithCPromptBG = Choice
End Function

Public Function GetAsciiWithCPrompt(ByVal Prompt As String)
    GetAsciiWithCPrompt = GetAsciiWithCPromptBG(-1, Prompt)
End Function

Public Function GetAsciiWithPrompt()
    GetAsciiWithPrompt = GetAsciiWithCPrompt("")
End Function

Public Function SetMissionProgress(ByVal MissionID As String, ByVal Key As String, ByVal Value As String)
    GSF.SetMissionData MissionID, "progress", Key, Value
End Function

Public Function GetMissionProgress(ByVal MissionID As String, ByVal Key As String)
    GetMissionProgress = GSF.GetMissionData(MissionID, "progress", Key)
End Function

Public Function IntMissionProgress(ByVal MissionID As String, ByVal Key As String)
    Dim Val
    Val = GetMissionProgress(MissionID, Key)
    If Val = "" Then
        IntMissionProgress = 0
    Else
        IntMissionProgress = CInt(Val)
    End If
End Function

Public Function IncMissionProgress(ByVal MissionID As String, ByVal Key As String)
    Dim Val
    Val = IntMissionProgress(MissionID, Key)
    SetMissionProgress MissionID, Key, (Val + 1)
End Function

Public Function BoolMissionProgress(ByVal MissionID As String, ByVal Key As String)
    BoolMissionProgress = (GetMissionProgress(MissionID, Key) = "1")
End Function

Public Function BoolSetMissionProgress(ByVal MissionID As String, ByVal Key As String)
    SetMissionProgress MissionID, Key, "1"
End Function

Public Function BoolClearMissionProgress(ByVal MissionID As String, ByVal Key As String)
    SetMissionProgress MissionID, Key, "0"
End Function

Public Function QReadLine(ByVal Prompt As String)
    QReadLine = LCase(Trim(GSF.ReadLine(Prompt)))
End Function

Public Function QReadLineBG(ByVal RGBVal As String, ByVal Prompt As String)
    QReadLineBG = LCase(Trim(GSF.ReadLine(Prompt, RGBVal)))
End Function
