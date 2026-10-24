!ifndef XBUILDDIR
  !define XBUILDDIR "..\build\windows\x64\runner\Release"
!endif

Unicode true
ManifestDPIAware true
Name "Way"
OutFile "..\dist\WaySetup.exe"
InstallDir "$PROGRAMFILES64\Way"
RequestExecutionLevel admin
SetCompressor /SOLID lzma
Icon "way.ico"
UninstallIcon "way.ico"

Page license
Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

LicenseData "..\LICENSE"

Section "Install"
  SetOutPath $INSTDIR
  File /r "${XBUILDDIR}\*.*"
  WriteUninstaller "$INSTDIR\uninstall.exe"
  CreateDirectory "$SMPROGRAMS\Way"
  CreateShortcut "$SMPROGRAMS\Way\Way.lnk" "$INSTDIR\way.exe"
  CreateShortcut "$DESKTOP\Way.lnk" "$INSTDIR\way.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Way" "DisplayName" "Way"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Way" "UninstallString" "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Way" "DisplayIcon" "$INSTDIR\way.exe"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Way" "Publisher" "mel0k1"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Way" "DisplayVersion" "1.1.0"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Way" "EstimatedSize" 250000
SectionEnd

Section "Uninstall"
  RMDir /r "$INSTDIR"
  RMDir /r "$SMPROGRAMS\Way"
  Delete "$DESKTOP\Way.lnk"
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "Way"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Way"
SectionEnd
