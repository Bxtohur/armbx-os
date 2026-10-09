Start-Transcript -Path 'C:\Development\armbx-build\p2-extract.log' -Force
$diskPath = '\\.\PhysicalDrive1'
$p2Img    = 'C:\Development\armbx-build\p2-raw.img'
$p2Offset = 3153920L * 512  # start sector * 512 bytes
$p2Size   = 1347584L * 512  # size in bytes = 689963008

Write-Host "Extracting p2 from $diskPath"
Write-Host ("  offset: {0} bytes" -f $p2Offset)
Write-Host ("  size:   {0} bytes ({1} MB)" -f $p2Size, ($p2Size/1MB))

try {
    $src = [IO.FileStream]::new($diskPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $null = $src.Seek($p2Offset, [IO.SeekOrigin]::Begin)
    $dst = [IO.FileStream]::new($p2Img, [IO.FileMode]::Create, [IO.FileAccess]::Write)
    $buf = New-Object byte[] (4MB)
    $remain = $p2Size
    $copied = 0L
    while ($remain -gt 0) {
        $toRead = [Math]::Min($buf.Length, $remain)
        $n = $src.Read($buf, 0, $toRead)
        if ($n -le 0) { break }
        $dst.Write($buf, 0, $n)
        $copied += $n
        $remain -= $n
    }
    $dst.Flush()
    $src.Close(); $dst.Close()
    Write-Host ("Extracted {0} bytes" -f $copied)
} catch {
    Write-Host "ERROR: $_"
}
Stop-Transcript
