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

# The party's gag (Zennit's tab): tools/gag/gag_party_source.m4a, 8.0 s with about 0.28 s of lead-in, same treatment,
# trimmed 0.2 s and faded out over the last 0.3 s. Gag.lua's PARTY_CLIP duration is its length (7.9 s).
& $ffmpeg -y -hide_banner -loglevel error -ss 0.2 -i (Join-Path $PSScriptRoot "gag_party_source.m4a") `
    -af "highpass=f=80,loudnorm=I=-17:TP=-3:LRA=7,pan=mono|c0=0.5*c0+0.5*c1,aresample=44100,alimiter=limit=0.7:level=disabled,afade=t=out:st=7.5:d=0.3" `
    -c:a libvorbis -q:a 4 (Join-Path $root "Media\gag_party.ogg")
Get-Item (Join-Path $root "Media\gag_party.ogg") | Select-Object Name, Length

# More of the party's gags (one is picked at random each time): tools/gag/party/party_NN_source.m4a, 3 to 6 s each with about
# 0.5 s of lead-in. The silence at each end is cut (below -45 dB), then the same treatment, with a 0.3 s fade out. Gag.lua's
# PARTY_CLIPS durations are the lengths this prints.
foreach ($src in Get-ChildItem (Join-Path $PSScriptRoot "party") -Filter "party_*_source.m4a" | Sort-Object Name) {
    $n = $src.Name -replace '^party_(\d+)_source\.m4a$', '$1'
    $out = Join-Path $root ("Media\gag_party_{0}.ogg" -f $n)
    & $ffmpeg -y -hide_banner -loglevel error -i $src.FullName `
        -af ("silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05,areverse," +
            "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.1,areverse," +
            "highpass=f=80,loudnorm=I=-17:TP=-3:LRA=7,pan=mono|c0=0.5*c0+0.5*c1,aresample=44100," +
            "alimiter=limit=0.7:level=disabled,areverse,afade=t=in:d=0.3,areverse") `
        -c:a libvorbis -q:a 4 $out
    $ffprobe = Join-Path (Split-Path $ffmpeg) "ffprobe.exe"
    "{0}: {1:N1} s" -f (Split-Path $out -Leaf), [double](& $ffprobe -v error -show_entries format=duration -of csv=p=0 $out)
}
