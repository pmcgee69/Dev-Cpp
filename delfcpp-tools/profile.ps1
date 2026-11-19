# Reads a profile the perf test's sampler wrote (one sample per line, innermost frame first: this
# exe's frames as code offsets, other modules' by name) and names the offsets through the .map
# (DCC_MapFile=3), as mapaddr.ps1 does. Prints, as % of samples:
#   self     the innermost frame: where the thread was (a module's name when outside the exe)
#   own      the innermost frame inside the exe: the Delphi routine that was running, or waiting
#            on the system code it called
#   total    every routine of the exe on the stack (each counted once per sample)
#   .\profile.ps1 -Map dev64-Win64\devcpp.map -Profile $env:TEMP\devcpp-profile-style.txt
param([Parameter(Mandatory)] [string]$Map, [Parameter(Mandatory)] [string]$Profile, [int]$Top = 25)
$syms = New-Object 'System.Collections.Generic.List[Tuple[long,string]]'
$section = ''
foreach ($l in [IO.File]::ReadLines($Map)) {
  if ($l -match 'Publics by Value') { $section = 'value'; continue }
  if ($section -eq 'value') {
    if ($l -match '^ 0001:([0-9A-F]{8})\s+(\S+)\s*$') { $syms.Add([Tuple]::Create([Convert]::ToInt64($matches[1], 16), $matches[2])) }
    elseif ($l -match '^\S') { $section = '' }
  }
}
$syms.Sort([Comparison[Tuple[long,string]]] { param($a, $b) $a.Item1.CompareTo($b.Item1) })
$keys = [long[]]($syms | ForEach-Object { $_.Item1 })
$cache = @{}
function Get-Name([string]$frame) {
  if ($frame -notmatch '^[0-9A-F]+$') { return $frame }  # a module's name
  if ($cache.ContainsKey($frame)) { return $cache[$frame] }
  $x = [Convert]::ToInt64($frame, 16)
  $i = [Array]::BinarySearch($keys, $x)
  if ($i -lt 0) { $i = (-bnot $i) - 1 }
  $n = if ($i -ge 0) { $syms[$i].Item2 } else { '?' }
  $cache[$frame] = $n
  $n
}
$self = @{}; $own = @{}; $total = @{}; $count = 0
foreach ($line in [IO.File]::ReadLines($Profile)) {
  $frames = $line.Trim() -split ' ' | Where-Object { $_ }
  if (-not $frames) { continue }
  $count++
  $names = $frames | ForEach-Object { Get-Name $_ }
  $self[$names[0]] = 1 + [int]$self[$names[0]]
  $firstOwn = $null
  for ($k = 0; $k -lt $frames.Count; $k++) { if ($frames[$k] -match '^[0-9A-F]+$') { $firstOwn = $names[$k]; break } }
  if ($firstOwn) { $own[$firstOwn] = 1 + [int]$own[$firstOwn] }
  foreach ($n in ($names | Where-Object { $_ -notmatch '\.(dll|DLL|exe)$|^\?$' } | Select-Object -Unique)) { $total[$n] = 1 + [int]$total[$n] }
}
"$count samples (about 1 ms each)"
foreach ($t in @(@('self', $self), @('own', $own), @('total', $total))) {
  ''
  "== $($t[0])"
  $t[1].GetEnumerator() | Sort-Object Value -Descending | Select-Object -First $Top |
    ForEach-Object { '{0,5:N1}%  {1}' -f (100.0 * $_.Value / $count), $_.Key }
}
