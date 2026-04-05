#Requires -RunAsAdministrator
set-strictmode -v latest
$errorActionPreference = 'stop'
$base = ((gl),$psscriptroot)[[bool]$psscriptroot]
# start powershell "-ex remoteSigned -nol -nop -noe" -verb runas

function init {
  $script:path = @{
    excel = "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE"
    word = "C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE"
    ppt = "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE"
    edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
  }
}
. init

(gip).ipv4address.ipaddress
ipconfig | %{if ($_ -match "IPv4.*: (.*)") {$matches[1]}}
(get-netAdapterBinding -componentID ms_tcpip6).enabled

"$env:programfiles\McAfee\Agent\cmdagent.exe" /i
"$env:programfiles\McAfee\DLP\Agent\hdlpdiag.exe"
(get-cimInstance Win32_Product).name
"HKCU:\Software\7-Zip\Compression\Options\zip"
rp "HKCU:\Software\7-Zip\Compression\ShowPassword"
(gp HKCU:\Software\7-Zip\Compression).Archiver
(gp HKCU:\Software\7-Zip\Compression).showpassword
(gp HKCU:\Software\7-Zip\Compression\Options\zip).EncryptionMethod
gpupdate /force /wait:0
gpresult /r

$info = get-computerInfo
$info.csModel
$info.biosName, $info.biosSeralNumber, $info.biosSMBIOSBIOSVersion, $info.biosSMBIOSMajorVersion, $info.biosSMBIOSMinorVersion
$info.osName, $info.osSerialNumber, $info.osVersion, $info.osBuildNumber

$iccid = $null
$data = @(
  'Effective Capacity', ($null,$cycle = get_batteryInfo)[0],
  'Charge Cycle Count', $cycle,
  'Device ID', (netsh m s i | foreach {if ($_ -match ' +(Device Id|デバイス ID).+: +(\w+)') {$matches[2]}}),
  'Subscriber ID', (($rinfo = netsh m s re *) | foreach {if ($_ -match ' +(Subscriber Id|サブスクライバー Id) +: +(\w+)') {$matches[2]}}),
  'SIM ICC ID', ($rinfo | foreach { if ($_ -match ' +(SIM ICC Id|SIM ICC の ID).+: +(\w+)') {($iccid = $matches[2])}}),
  'Telephone #', ($rinfo | foreach {if ($_ -match ' +(Telephone|電話) #.+: +(\w+)') {$matches[2]}}),
  'SIM ID', (& {if ($iccid -ne $null -and ($ret = get-SIMID $iccid)) {$ret}}),
  'UBR', (get-itemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").UBR
)
& {
  param ($l = $data, $h = [ordered]@{})
  while ($l) {
    $k, $v, $l = $l
    $h[$k] = $v
  }
  [pscustomobject]$h
}
