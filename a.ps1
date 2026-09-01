set-strictmode -v latest
$errorActionPreference = 'stop'
$root = ($pwd,$psscriptroot)[[bool]$psscriptroot]

$path = "$root\tank.xlsx"
$csvPath = "$root\in.csv"
$csvPath2 = "$root\log.csv"

function f {
  param($bk, $shtName)
  $sht = $bk.worksheets[$shtName]
  if ($bk.readonly) {write-error "Book not writable."}

  $csv = import-csv $csvPath -enc default
  $a = @(); $b = @()
  $keyC = 1; $valC = 2
  $xlUp = -4162
  $lastR = $sht.cells($sht.rows.count,$keyC).end($xlUp).row
  foreach ($x in $csv) {
    $m = 0
    for ($r = $lastR; $r -gt 0; $r--) {
      if ($sht.cells($r,$keyC).value() -eq $x.id) {
        if ($null -eq $sht.cells($r,$valC).value()) {
          $sht.cells($r,$valC) = 1; $b += $x; $m = 1; break
        }
      }
    }
    if (-not $m) { $a += $x }
  }

  $b | convertTo-csv -notypeinfo |%{$_ -replace '"'} | select -skip 1 | out-file $csvpath2 -enc default -append
  if ($a.count -eq 0) {
    $csv_hdr = ($csv|member -type noteproperty).name
    ($csv_hdr)-join',' | out-file $csvPath -enc default
  } else {
    $a | convertTo-csv -notypeinfo |%{$_ -replace '"'} | out-file $csvpath -enc default
  }
  if (-not $bk.saved) {$bk.save()}
}

try {
  $xl = new-object -com excel.application
  # $xl.visible = 1
  $bk = $xl.workbooks.open($path)
  f $bk 'Sheet1'
} catch {
  write-error($_)
} finally {
  if ($null -ne $bk) {$bk.close(0)}
  if ($null -ne $xl) {$xl.quit()}
  $bk = $null; $xl = $null
  [gc]::collect()
}
