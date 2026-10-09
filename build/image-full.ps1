Start-Transcript -Path 'C:\Development\armbx-build\image-full.log' -Force
$imagePath = 'C:\Development\armbx-build\armbx-full.img'
$diskPath  = '\\.\PhysicalDrive1'
$total     = (Get-Disk -Number 1).Size
Write-Host ("Imaging {0} -> {1}" -f $diskPath, $imagePath)
Write-Host ("Started: {0}" -f (Get-Date -Format 'HH:mm:ss'))
Write-Host ("Total: {0} bytes ({1} GB)" -f $total, ([math]::Round($total/1GB,2)))
try {
    $src = [IO.FileStream]::new($diskPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $dst = [IO.FileStream]::new($imagePath, [IO.FileMode]::Create, [IO.FileAccess]::Write)
    $buf = New-Object byte[] (4MB)
    $copied = 0L
    $lastReport = 0L
    $startTime = Get-Date
    while ($copied -lt $total) {
        $n = $src.Read($buf, 0, $buf.Length)
        if ($n -le 0) { break }
        $dst.Write($buf, 0, $n)
        $copied += $n
        if (($copied - $lastReport) -ge 500MB) {
            $lastReport = $copied
            $elapsed = (Get-Date) - $startTime
            $mbps = [math]::Round(($copied/1MB)/$elapsed.TotalSeconds,1)
            $pct  = [math]::Round($copied/$total*100,1)
            Write-Host ("{0}%  {1} GB  {2} MB/s" -f $pct, ([math]::Round($copied/1GB,2)), $mbps)
        }
    }
    $dst.Flush()
    $src.Close()
    $dst.Close()
    $elapsed = (Get-Date) - $startTime
    Write-Host ("DONE in {0} min. Size: {1} GB" -f ([math]::Round($elapsed.TotalMinutes,1)), ([math]::Round($copied/1GB,2)))
} catch {
    Write-Host "ERROR: $_"
}
Stop-Transcript
