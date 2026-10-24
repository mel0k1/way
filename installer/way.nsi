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

!macro RegisterProtocol SCHEME
  WriteRegStr HKCU "Software\Classes\${SCHEME}" "" "URL:Way ${SCHEME}"
  WriteRegStr HKCU "Software\Classes\${SCHEME}" "URL Protocol" ""
  WriteRegStr HKCU "Software\Classes\${SCHEME}\DefaultIcon" "" "$INSTDIR\way.exe,0"
  WriteRegStr HKCU "Software\Classes\${SCHEME}\shell\open\command" "" '"$INSTDIR\way.exe" "%1"'
!macroend

!macro UnregisterProtocol SCHEME
  DeleteRegKey HKCU "Software\Classes\${SCHEME}"
!macroend

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
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Way" "DisplayVersion" "1.5.0"
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Way" "EstimatedSize" 250000
  !insertmacro RegisterProtocol "vless"
  !insertmacro RegisterProtocol "vmess"
  !insertmacro RegisterProtocol "trojan"
  !insertmacro RegisterProtocol "ss"
  !insertmacro RegisterProtocol "hysteria2"
  !insertmacro RegisterProtocol "hy2"
  !insertmacro RegisterProtocol "tuic"
  !insertmacro RegisterProtocol "way"
  !insertmacro RegisterProtocol "clash"
  !insertmacro RegisterProtocol "clashmeta"
  !insertmacro RegisterProtocol "sing-box"
  !insertmacro RegisterProtocol "v2rayng"
  !insertmacro RegisterProtocol "v2rayn"
  !insertmacro RegisterProtocol "sn"
  !insertmacro RegisterProtocol "hiddify"
SectionEnd

Section "Uninstall"
  RMDir /r "$INSTDIR"
  RMDir /r "$SMPROGRAMS\Way"
  Delete "$DESKTOP\Way.lnk"
  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "Way"
  !insertmacro UnregisterProtocol "vless"
  !insertmacro UnregisterProtocol "vmess"
  !insertmacro UnregisterProtocol "trojan"
  !insertmacro UnregisterProtocol "ss"
  !insertmacro UnregisterProtocol "hysteria2"
  !insertmacro UnregisterProtocol "hy2"
  !insertmacro UnregisterProtocol "tuic"
  !insertmacro UnregisterProtocol "way"
  !insertmacro UnregisterProtocol "clash"
  !insertmacro UnregisterProtocol "clashmeta"
  !insertmacro UnregisterProtocol "sing-box"
  !insertmacro UnregisterProtocol "v2rayng"
  !insertmacro UnregisterProtocol "v2rayn"
  !insertmacro UnregisterProtocol "sn"
  !insertmacro UnregisterProtocol "hiddify"
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Way"
SectionEnd
