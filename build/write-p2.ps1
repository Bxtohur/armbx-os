Start-Transcript -Path 'C:\Development\armbx-build\p2-write.log' -Force
$diskPath = '\\.\PhysicalDrive1'
$p2Img    = 'C:\Development\armbx-build\p2-raw.img'
$p2Offset = 3153920L * 512
$p2Size   = (Get-Item $p2Img).Length

Write-Host "Writing $p2Img -> $diskPath at offset $p2Offset ($p2Size bytes)"

try {
    $src = [IO.FileStream]::new($p2Img, [IO.FileMode]::Open, [IO.FileAccess]::Read)
    $dst = [IO.FileStream]::new($diskPath, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
    $null = $dst.Seek($p2Offset, [IO.SeekOrigin]::Begin)
    $buf = New-Object byte[] (4MB)
    $copied = 0L
    while (($n = $src.Read($buf, 0, $buf.Length)) -gt 0) {
        $dst.Write($buf, 0, $n)
        $copied += $n
    }
    $dst.Flush()
    $src.Close(); $dst.Close()
    Write-Host ("Written {0} bytes" -f $copied)
} catch {
    Write-Host "ERROR: $_"
}
Stop-Transcript
