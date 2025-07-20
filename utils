set-strictMode -v latest
$erroractionPreference = 'stop'

class ExcelTable {
  $app
  $book
  $sheet
  $begRI=1; $endRI
  $begCI=1; $endCI
  ExcelTable($bookName, $sheetName) {
    $this.app = new-object -com excel.application
    $this.app.visible=1
    $this.book = $this.app.workbooks.open($bookName)
    $this.sheet = $this.book.worksheets($sheetName)
  }
}
function convert-ExcelTableA2d {
  param($xltable)

  ,$xltable.sheet.range($xltable.sheet.cells($xlTable.begRI,$xlTable.begCI),
                        $xltable.sheet.cells($xlTable.endRI,$xlTable.endCI)).value()
}
function convertFrom-a2d {
  param($a2d)

  $begRI = $a2d.getLowerBound(0)
  $begCI = $a2d.getLowerBound(1)
  $endRI = $a2d.getUpperBound(0)
  $endCI = $a2d.getUpperBound(1)
  for ($ri=$begRI+1; $ri -le $endRI; $ri++) {
    $obj = [pscustomobject]@{}
    for ($ci=$begCI; $ci -le $endCI; $ci++) {
      $obj | add-member -membertype noteProperty -name $a2d[$begRI,$ci] -value $a2d[$ri,$ci]
    }
    $obj
  }
}

$table = [ExcelTable]::new('.\source.xlsx', 'Sheet1')
$table.begRI=3
$table.endRI=8
$table.begCI=1
$table.EndCI=5

$a2d = convert-ExcelTableA2d $table
$os = convertFrom-a2d $a2d
