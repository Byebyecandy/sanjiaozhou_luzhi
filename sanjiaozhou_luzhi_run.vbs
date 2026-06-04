Option Explicit

Dim shell, fso, scriptDir, command, i, arg
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Quote(scriptDir & "\sanjiaozhou_luzhi.ps1")

For i = 0 To WScript.Arguments.Count - 1
    arg = WScript.Arguments.Item(i)
    command = command & " " & Quote(arg)
Next

shell.Run command, 0, False

Function Quote(value)
    Quote = """" & Replace(value, """", """""") & """"
End Function
