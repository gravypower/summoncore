# How tools/gag/gag_zennit_source.m4a became Media/gag_zennit.ogg (ffmpeg, see the ffmpeg-installed note in the
# narrator skill for where it lives on this machine). The recording is quiet (mean about -49 dB) with about 0.45 s
# of lead-in, so it is trimmed, high-passed, loudness-normalised, limited to -3 dB, mono at 44.1 kHz, and faded out.
#   powershell -ExecutionPolicy Bypass -File tools\gag\make_gag_audio.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $ffmpeg) {
    $ffmpeg = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe | Select-Object -First 1).FullName
}
& $ffmpeg -y -hide_banner -loglevel error -ss 0.45 -i (Join-Path $PSScriptRoot "gag_zennit_source.m4a") `
    -af "highpass=f=80,loudnorm=I=-17:TP=-3:LRA=7,pan=mono|c0=0.5*c0+0.5*c1,aresample=44100,alimiter=limit=0.7:level=disabled,afade=t=out:st=2.55:d=0.15" `
    -c:a libvorbis -q:a 4 (Join-Path $root "Media\gag_zennit.ogg")
Get-Item (Join-Path $root "Media\gag_zennit.ogg") | Select-Object Name, Length
