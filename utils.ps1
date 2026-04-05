set-strictmode -v latest
$errorActionPreference = 'stop'
$base = ((gl),$psscriptroot)[[bool]$psscriptroot]


function obj_hash {
  param($o)
  $o.psobject.properties | %{$h=@{}}{
    $h[$_.name]=$_.value
  }{$h}
}


function ip_int {
  param($s)

  $re = '(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|0?[0-9]?[0-9])'
  if (-not ($mask -match "^$re\.$re\.$re\.$re$")) {throw "Invalid Format"}
  ([uint]$matches.1 -shl 24) + ([uint]$matches.2 -shl 16) + ([uint]$matches.3 -shl 8) + [uint]$matches.4
  # ([net.ipAddress]$s).address
}

function int_ip {
  param($n)

  $a = 0,0,0,0 
  $a[3] = $n -band 0xffu
  $a[2] = ($n -band 0xff00u) -shr 8
  $a[1] = ($n -band 0xff0000u) -shr 16
  $a[0] = ($n -band 0xff000000u) -shr 24
  $a -join '.'
  # ([net.ipaddress]$n).ipaddressToString
}

function mask_len {
  param($mask)

  $ip = ip_int $mask
  $i = 31
  while (($ip -shr $i) -eq 1) {
    $ip = $ip -band (-bnot (1u -shl $i--))
  }
  if ($ip -ne 0) {throw "Invalid Format"}
  31-$i
}

function len_mask {
  param($len)

  $len = 32-$len
  $ip = [uint]0
  for ($i = 0; $i -lt $len; $i++) {
    $ip = ($ip -shl 1) + 1
  }
  $ip = -bnot $ip
  int_ip $ip
}

function gip_ {
  $ipcf = gip
  $ipcf | %{
    [pscustomobject]@{
      InterfaceAlias = $ipcf.interfacealias
      IPv4Address = $ipcf.ipv4Address.ipAddress
      IPv4DefaultGateway = $ipcf.ipv4DefaultGateway.nexthop
      DNSServer = ($ipcf.dnsServer|? AddressFamily -eq 2).serverAddresses
    }
  }
}

function set_ip {
  param($ip, $mask, $gw, $dns1, $dns2)

  netsh int ip delete dnsservers $ifName all >$null
  netsh int ip set addr $ifName static $ip $mask $gw >$null
  netsh int ip add dnsservers $ifName $dns1 index=1 >$null
  netsh int ip add dnsservers $ifName $dns2 index=2 >$null
}

function reset_ip {
  netsh int ip set addr $ifName dhcp >$null
  netsh int ip delete dnsservers $ifName all >$null
  # netsh int ip delete winsservers $ifName all >$null
}


function clean {
  ri (Get-PSReadLineOption).HistorySavePath
  rp "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths" "url*"
  rp "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" "*" -errora silentlyContinue
  ri "$env:APPDATA\Microsoft\Windows\Recent\*" -rec -force 
}

function domainname {
  $sys = get-cimInstance win32_computersystem
  $sys.domain
}

function get_osDesc {
  $os = get-cimInstance win32_operatingsystem
  $os.description
}
function set_osDesc{
  param($s)
  $os = get-cimInstance win32_operatingsystem
  $os.description = $s
  set-ciminstance $os
  # net config server /srvcomment:$s
}

function get_batteryInfo {
  $breport = new-temporaryfile
  powercfg /batteryreport /output $breport >$null
  if (test-path $breport) {
    ($html = new-object -com HTMLFILE).IHTMLDocument2_write((get-content $breport -raw))
    $html.close()
    ri $breport
    $pair = $html.IHTMLDocument2_body.getElementsByTagName("table")[1].children[2].children[4]
    $design = $pair.children[1].innerText
    $pair = $html.IHTMLDocument2_body.getElementsByTagName("table")[1].children[2].children[6]
    $nowFull = $pair.children[1].innerText
    $pair2 = $html.IHTMLDocument2_body.getElementsByTagName("table")[1].children[2].children[7]
    [string][int]([int]$nowFull.trimend(" mWh")*100 / [int]$design.trimend(" mWh")) + " %"
    $pair2.children[1].innerText
  }
}

function installed?_excel {
  $ret = $false
  try {
    $xl = new-object -com Excel.Application
    [void]$xl.Workbooks.Add()
    $xl.Workbooks.Item(1).Close()
    $xl.Quit()
    write-verbose 'Excel is installed.'
    $ret = $true
  } catch {
    write-warning 'Excel is not installed.'
  } finally {
    [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($xl)
    $xl = $null
    sleep 1
    [GC]::Collect()
  }
  $ret
}

function activated?_os {
  ((cscript /nologo $env:systemroot\System32\slmgr.vbs /dli) -join '') -match 'ライセンスされています'
}

#Add-Type -AssemblyName System.Windows.Forms
function Suspend-Computer {
    $state = [System.Windows.Forms.PowerState]::Suspend
    [bool]$force = $true
    [bool]$disableWakeEvent = $false

    [System.Windows.Forms.Application]::SetSuspendState($state, $force, $disableWakeEvent)
}
