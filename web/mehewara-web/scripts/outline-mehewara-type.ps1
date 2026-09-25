Add-Type -AssemblyName System.Drawing
$output = Join-Path $PSScriptRoot 'mehewara-type-paths.json'
$result = @{}
foreach ($entry in @(@{ Key='wordmark'; Text='Mehewara'; Size=76; Style=[System.Drawing.FontStyle]::Bold }, @{ Key='tagline'; Text='CLEANER CITIES • STRONGER COMMUNITIES'; Size=10; Style=[System.Drawing.FontStyle]::Bold })) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $family = New-Object System.Drawing.FontFamily('Segoe UI')
  $format = [System.Drawing.StringFormat]::GenericTypographic
  $path.AddString($entry.Text, $family, [int]$entry.Style, [single]$entry.Size, [System.Drawing.PointF]::new(0, 0), $format)
  $points = $path.PathPoints
  $types = $path.PathTypes
  $parts = [System.Collections.Generic.List[string]]::new()
  $culture = [System.Globalization.CultureInfo]::InvariantCulture
  for ($i = 0; $i -lt $points.Count; $i++) {
    $type = $types[$i] -band 7
    $x = $points[$i].X.ToString('0.###', $culture)
    $y = $points[$i].Y.ToString('0.###', $culture)
    if ($type -eq 0) { $parts.Add("M$x $y") }
    elseif ($type -eq 1) { $parts.Add("L$x $y") }
    elseif ($type -eq 3) {
      $x2=$points[$i+1].X.ToString('0.###', $culture); $y2=$points[$i+1].Y.ToString('0.###', $culture)
      $x3=$points[$i+2].X.ToString('0.###', $culture); $y3=$points[$i+2].Y.ToString('0.###', $culture)
      $parts.Add("C$x $y $x2 $y2 $x3 $y3")
      $i += 2
    }
    if (($types[$i] -band 128) -ne 0) { $parts.Add('Z') }
  }
  $bounds=$path.GetBounds()
  $result[$entry.Key]=@{ d=($parts -join ' '); x=$bounds.X; y=$bounds.Y; width=$bounds.Width; height=$bounds.Height }
  $path.Dispose(); $family.Dispose()
}
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $output -Encoding utf8
