# Maps code offsets (from the start of the code segment, as the test switch reports them) to
# routines through a Delphi .map (DCC_MapFile=3), and to source lines where the map has them
# (units built with debug information).
#   .\mapaddr.ps1 -Map devcpp.map -Offset 308CF2,1A2B3C
param([Parameter(Mandatory)] [string]$Map, [Parameter(Mandatory)] [string[]]$Offset)
$syms = New-Object 'System.Collections.Generic.List[Tuple[long,string]]'
$lines = New-Object 'System.Collections.Generic.List[Tuple[long,string]]'
$section = ''; $unit = $null
foreach ($l in [IO.File]::ReadLines($Map)) {
  if ($l -match 'Publics by Value') { $section = 'value'; continue }
  if ($l -match '^Line numbers for [^(]+\(([^)]+)\) segment') { $section = 'lines'; $unit = $matches[1]; continue }
  if ($section -eq 'value' -and $l -match '^ 0001:([0-9A-F]{8})\s+(\S+)\s*$') {
    $syms.Add([Tuple]::Create([Convert]::ToInt64($matches[1], 16), $matches[2])) }
  elseif ($section -eq 'lines' -and $l -match '0001:') {
    foreach ($m in [regex]::Matches($l, '(\d+) 0001:([0-9A-F]{8})')) {
      $lines.Add([Tuple]::Create([Convert]::ToInt64($m.Groups[2].Value, 16), "$unit($($m.Groups[1].Value))")) } }
  elseif ($l -match '^\S' -and $section -ne 'value') { $section = '' }
}
$byOffset = [Comparison[Tuple[long,string]]] { param($a, $b) $a.Item1.CompareTo($b.Item1) }
$syms.Sort($byOffset); $lines.Sort($byOffset)
function Find-Below($list, [long]$x) {
  $lo = 0; $hi = $list.Count - 1; $r = $null
  while ($lo -le $hi) { $mid = [int][math]::Floor(($lo + $hi) / 2); if ($list[$mid].Item1 -le $x) { $r = $list[$mid]; $lo = $mid + 1 } else { $hi = $mid - 1 } }
  $r
}
foreach ($o in $Offset) {
  $x = [Convert]::ToInt64($o.TrimStart('$'), 16)
  $s = Find-Below $syms $x; $ln = Find-Below $lines $x
  $name = if ($s) { '{0} + ${1:X}' -f $s.Item2, ($x - $s.Item1) } else { '?' }
  $src = if ($ln -and $s -and $ln.Item1 -ge $s.Item1) { $ln.Item2 } else { '' }
  '{0,8}  {1}  {2}' -f $o, $name, $src
}
