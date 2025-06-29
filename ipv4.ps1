Set-StrictMode -v latest
$errorActionPreference = 'stop'

function ip {
  [CmdletBinding()]
  [OutputType([PSCustomObject])]
  param([parameter(ValueFromPipeline = $true)][CimInstance]$intf)

  $ipv4 = $intf | Get-NetIPAddress -AddressFamily ipv4
  $gateway = ($intf | Get-NetIPConfiguration).ipv4DefaultGateway
  if ($null -ne $gateway) {
    $gateway = ($intf | Get-NetIPConfiguration).ipv4DefaultGateway.nexthop
  }
  $dhcp = ($intf | Get-NetIPInterface -addressFam ipv4).dhcp 
  $dns = ($intf | Get-DnsClientServerAddress -AddressFam ipv4).serveraddresses
  $id = ($intf | Get-NetAdapter).interfaceGuid
  $nic = Get-CimInstance -class Win32_NetworkAdapterConfiguration -Filter "settingID = '$id'"
  $wins = $nic.winsPrimaryServer, $nic.winsSecondaryServer | ? {$null -ne $_}
  [PSCustomObject]@{
    Dhcp = $dhcp
    Ipv4 = $ipv4.ipv4Address; PrefixLen = $ipv4.PrefixLength; Gateway = $gateway
    Dns = $dns; Wins = @($wins)
  }
}

function Set-WinsAddress {
  [CmdletBinding()]
  [OutputType()]
  param(
    [parameter(valueFromPipeline = $true)][CimInstance]$intf,
    [object[]]$server = $null
  )

  netsh interface ip delete wins $intf.interfaceAlias all >$null
  $cnt = $server.count
  for ($i = 0; $i -lt $cnt; $i++) {
    netsh interface ip add wins $intf.interfaceAlias $server[$i] >$null
  }
}

function Clear-Ipv4Intf {
  ## remove any existing ip address and gateway
  [CmdletBinding()]
  [OutputType()]
  param(
    [parameter(valueFromPipeline = $true)][CimInstance]$intf,
    [switch]$dns,
    [switch]$wins
  )

  $intf | Set-NetIPInterface -addressFam ipv4 -Dhcp dis
  try {
    $intf | Remove-NetIPAddress -addressFam ipv4 -Confirm:$false
    $intf | Remove-NetRoute -Confirm:$false
  } catch {}
  if ($dns) { $intf | Set-DnsClientServerAddress -reset }
  if ($wins) {
    netsh interface ip delete wins $intf.interfaceAlias all >$null
  }
}

function set-ipv4Intf {
  ## configure the new ipv4 settings
  [CmdletBinding()]
  [OutputType()]
  param(
    [parameter(valueFromPipeline = $true)][CimInstance]$intf,
    [string]$ipv4, 
    [byte]$prefixLen,
    [string]$gateway,
    [string[]]$dns = $null,
    [string[]]$wins = $null
  )

  $intf | New-NetIPAddress -ipAddr $ipv4 -prefixLen $prefixLen -defaultg $gateway >$null
  if ($null -ne $dns) { $intf | Set-DnsClientServerAddress -Server $dns }
  if ($null -ne $wins) { $intf | Set-WinsAddress -Server $wins }
}

function Enable-Dhcp {
  [CmdletBinding()]
  [OutputType()]
  param([parameter(valueFromPipeline = $true)][CimInstance]$intf)

  $intf | Set-NetIPInterface -addressFam ipv4 -Dhcp en
  try { $intf | Remove-NetRoute -DestinationPrefix '0.0.0.0/0' -Confirm:$false } catch {}
  $intf | Set-DnsClientServerAddress -reset
}

function Get-Ipv4IntfEasily {
  # get an typical ipv4 interface
  [CmdletBinding()]
  [OutputType([CimInstance])]
  param()

  $adp = Get-NetAdapter
  if ($null -eq $adp) {
    throw 'Network adapters not found.'
  } elseif ($adp -is [array]) {
    $cnt = $adp.count
    for ($i = 0; $i -lt $cnt; $i++) {
      Write-Host ${i}: $adp[$i].name
    }
    $n = Read-Host "Which adapter do you want to configure?`nEnter the number"
    $adp = $adp[$n]
  }
  $intf = ($adp | Get-NetIPInterface -addressFam ipv4)
  if ($null -eq $intf) {
    throw 'Network Interfaces not found.'
  } elseif ($intf -is [array]) {
    $cnt = $intf.count
    for ($i = 0; $i -lt $cnt; $i++) {
      Write-Host ${i}: $intf[$i].name
    }
    $n = Read-Host "Which interface do you want to configure?`nEnter the number"
    $intf = $intf[$n]
  }
  Write-Verbose "`"$($intf.InterfaceAlias)`" is selected."
  $intf
}

function main {
  $intf = Get-Ipv4IntfEasily -verbose
  ($curInfo = $intf | ip)
  Write-Host "will change to`n"
  [PSCustomObject]@{
    Dhcp = 'Disabled'
    Ipv4 = $ipv4; PrefixLen = $PrefixLen; Gateway = $gateway
    Dns = [string[]]$dns; Wins = [string[]]$wins
  }

  $y = Read-Host 'Continue? (Y)'
  if ($y -ceq 'Y') {
    try {
      $intf | Clear-Ipv4Intf -dns -wins
      #sleep 10
      $intf | set-ipv4Intf -ipv4 $ipv4 -prefixLen $prefixLen -gateway $gateway -dns $dns -wins $wins
      #sleep 10
      $info = $intf | ip
      if (-not (($info.ipv4 -eq $ipv4 -and $info.prefixLen -eq $prefixLen -and $info.gateway -eq $gateway -and
          ($info.dns -join '') -eq ($dns -join '') -and ($info.wins -join '') -eq ($wins -join '')))) {
        throw 'Configuration values not correct.'
      }
    } catch {
      Write-Warning $_
      $intf | Get-NetAdapter | Restart-NetAdapter
      sleep 10
      $intf | Clear-Ipv4Intf -dns -wins
      sleep 10
      $intf | set-ipv4Intf -ipv4 $curInfo.ipv4 -prefixLen $curInfo.prefixLen -gateway $curInfo.gateway -dns $curInfo.dns -wins $curInfo.wins
    } finally {
      #shutdown /s /t 10 /f
    }
  }
}

$ipv4 = '192.168.152.2'
$prefixLen = 24
$gateway = '192.168.152.124'
$dns = '192.168.152.124', '192.168.152.4'
$wins = '192.168.152.124'
# $intf | enable-dhcp
main


## note
$intf = Get-Ipv4IntfEasily -verbose
ip $intf
$intf | fl dhcp
$intf | fl dhcp
$intf | Get-NetIPAddress
$intf | Get-NetIPConfiguration
$intf | Get-NetRoute

$adp = Get-NetAdapter | ? { $_.status -eq 'up' }
$adp | Get-NetAdapterBinding
$adp | Disable-NetAdapterBinding -component ms_tcpip6
$adp | Restart-NetAdapter
