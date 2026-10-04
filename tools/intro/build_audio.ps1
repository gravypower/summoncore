# Builds the intro's audio and key-phrase cues from the narration takes in tools\intro\narration\.
#
#   Media\sfx\sfx_*.ogg        beeps, chirps and key clicks played live as key phrases appear
#   Media\intro_<n>.ogg        narration + quiet synth music bed (music ducks under the voice, swells in pauses)
#   Media\intro_<n>_voice.ogg  narration only (used when Music is switched off)
#   IntroCues.lua              scene lengths and the timed key phrases (generated)
#
# Needs ffmpeg (winget install Gyan.FFmpeg). The music is synthesised here in C#; nothing is sampled
# from any existing recording.
#   powershell -ExecutionPolicy Bypass -File tools\intro\build_audio.ps1
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$root = Split-Path -Parent (Split-Path -Parent $here)
$media = Join-Path $root "Media"
$sfxDir = Join-Path $media "sfx"
$work = Join-Path ([IO.Path]::GetTempPath()) "summoncore_audio"
New-Item -ItemType Directory -Force $media, $sfxDir, $work | Out-Null

$ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $ffmpeg) {
    $ffmpeg = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter ffmpeg.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $ffmpeg) { throw "ffmpeg not found (winget install Gyan.FFmpeg)" }
$ffprobe = Join-Path (Split-Path $ffmpeg) "ffprobe.exe"

function Ffmpeg([string[]]$ffArgs) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & $ffmpeg -hide_banner -loglevel error -y @ffArgs 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) { throw "ffmpeg failed: $($out -join ' ')" }
}

function Duration([string]$file) {
    [double]::Parse((& $ffprobe -v error -show_entries format=duration -of csv=p=0 $file), [Globalization.CultureInfo]::InvariantCulture)
}

# ---------------------------------------------------------------- 1. sound effects
# Mono, 44.1 kHz, peak about -9 dBFS. Retro "terminal" blips: rising/falling chirps, a two-tone blip, key clicks.
$fmt = "d=0.2:s=44100"
$sfx = [ordered]@{
    "sfx_chirp_1" = "aevalsrc='0.55*sin(2*PI*(900*t+5357*t*t))*exp(-t*13)':d=0.18:s=44100"
    "sfx_chirp_2" = "aevalsrc='0.55*sin(2*PI*(2200*t-4600*t*t))*exp(-t*12)':d=0.16:s=44100"
    "sfx_chirp_3" = "aevalsrc='0.5*sin(2*PI*if(lt(t,0.045),1500,2100)*t)*exp(-mod(t,0.045)*25)':d=0.12:s=44100"
    "sfx_keys_long" = "aevalsrc='0.55*random(0)*(exp(-mod(t,0.074)*700)*lt(mod(t,0.074),0.012)+0.7*exp(-mod(t,0.113)*650)*lt(mod(t,0.113),0.012))':d=16:s=44100"
    "sfx_pop"     = "aevalsrc='0.6*sin(2*PI*620*t)*exp(-t*26)':d=0.14:s=44100"
}
foreach ($name in $sfx.Keys) {
    $filter = if ($name -like "sfx_keys*") { "highpass=f=1800,volume=0.7" } else { "volume=0.5" }
    Ffmpeg @("-f", "lavfi", "-i", $sfx[$name], "-af", $filter, "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", (Join-Path $sfxDir "$name.ogg"))
}
"sound effects: " + ($sfx.Keys -join ", ")

# ---------------------------------------------------------------- 2. scene lengths
$sceneCount = (Get-ChildItem (Join-Path $here "narration") -Filter "voice_*.ogg").Count
$voices = 1..$sceneCount | ForEach-Object { Join-Path $here ("narration\voice_{0:00}.ogg" -f $_) }
$pause = 0.6   # keep in step with PAUSE in Intro.lua
$ending = 3.2   # extra seconds after the last scene: the music fades out while the picture fades to black
$chapterEnds = @(10, 12)   # the last scene of each chapter (keep in step with the chapter fields in Intro.lua)
$lengths = $voices | ForEach-Object { Duration $_ }
$starts = @(); $acc = 0.0
for ($k = 0; $k -lt $lengths.Count; $k++) {
    $starts += $acc
    $acc += $lengths[$k] + $pause
    if ($chapterEnds -contains ($k + 1)) { $acc += $ending }
}
$totalSeconds = $acc + $ending + 3

# ---------------------------------------------------------------- 3. music bed
Add-Type -TypeDefinition @"
using System;
using System.IO;

public static class MusicGen {
    static double Midi(int n) { return 440.0 * Math.Pow(2.0, (n - 69) / 12.0); }

    // Light retro-futuristic arpeggios over a steady tempo: bubbly sine plucks with a little pitch drop,
    // a soft triangle pad, a quiet bass note, and a gentle echo. About 96 bpm, eighth-note arpeggios.
    public static void Write(string path, double seconds) {
        const int sr = 44100;
        int n = (int)(seconds * sr);
        var buf = new double[n];
        double step = 60.0 / 96.0 / 2.0;            // one eighth note
        int[][] chords = {
            new[] { 60, 64, 67, 69 },               // C6
            new[] { 57, 60, 64, 67 },               // Am7
            new[] { 53, 57, 60, 64 },               // Fmaj7
            new[] { 55, 59, 62, 64 },               // G / Em colour
        };
        int[] pattern = { 0, 1, 2, 3, 4, 3, 2, 1 }; // 4 = the root an octave up
        int steps = (int)(seconds / step) + 1;
        for (int k = 0; k < steps; k++) {
            var chord = chords[(k / 8) % chords.Length];
            int idx = pattern[k % 8];
            int note = idx < 4 ? chord[idx] : chord[0] + 12;
            double f0 = Midi(note + 12);
            int start = (int)(k * step * sr);
            double phase = 0;
            int len = (int)(0.7 * sr);
            for (int j = 0; j < len && start + j < n; j++) {
                double t = (double)j / sr;
                double env = Math.Exp(-t * 6.0) * (1 - Math.Exp(-t * 500));
                double f = f0 * (1 + 0.04 * Math.Exp(-t * 38));   // the "bloop"
                phase += 2 * Math.PI * f / sr;
                double s = Math.Sin(phase) + 0.30 * Math.Sin(2 * phase) * Math.Exp(-t * 9) + 0.10 * Math.Sin(3 * phase);
                buf[start + j] += 0.20 * env * s * (k % 4 == 0 ? 1.15 : 1.0);
            }
        }
        // pad and bass, one chord per bar
        double bar = step * 8;
        int bars = (int)(seconds / bar) + 1;
        for (int b = 0; b < bars; b++) {
            var chord = chords[b % chords.Length];
            int start = (int)(b * bar * sr);
            int len = (int)((bar + 0.4) * sr);
            foreach (int note in chord) {
                double f = Midi(note - 12);
                double phase = 0;
                for (int j = 0; j < len && start + j < n; j++) {
                    double t = (double)j / sr;
                    double env = (1 - Math.Exp(-t * 6)) * Math.Min(1.0, (bar + 0.4 - t) / 0.4);
                    phase += f / sr;
                    double tri = 4 * Math.Abs(phase - Math.Floor(phase + 0.5)) - 1;
                    buf[start + j] += 0.035 * env * tri;
                }
            }
            for (int h = 0; h < 2; h++) {
                int bs = start + (int)(h * 4 * step * sr);
                double f = Midi(chord[0] - 24);
                for (int j = 0; j < (int)(1.1 * sr) && bs + j < n; j++) {
                    double t = (double)j / sr;
                    buf[bs + j] += 0.10 * Math.Exp(-t * 3.2) * (1 - Math.Exp(-t * 200)) * Math.Sin(2 * Math.PI * f * t);
                }
            }
        }
        // echo (one and a half eighths, 28% feedback), then a one-pole low-pass to soften the top
        int d = (int)(step * 1.5 * sr);
        for (int i = d; i < n; i++) buf[i] += 0.28 * buf[i - d];
        double lp = 0, a = 1 - Math.Exp(-2 * Math.PI * 5200 / sr);
        double peak = 0;
        for (int i = 0; i < n; i++) { lp += a * (buf[i] - lp); buf[i] = lp; peak = Math.Max(peak, Math.Abs(lp)); }
        double gain = peak > 0 ? 0.6 / peak : 1;
        using (var fs = new FileStream(path, FileMode.Create))
        using (var w = new BinaryWriter(fs)) {
            int bytes = n * 2;
            w.Write(new[] { (byte)'R', (byte)'I', (byte)'F', (byte)'F' }); w.Write(36 + bytes);
            w.Write(new[] { (byte)'W', (byte)'A', (byte)'V', (byte)'E', (byte)'f', (byte)'m', (byte)'t', (byte)' ' });
            w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(sr); w.Write(sr * 2); w.Write((short)2); w.Write((short)16);
            w.Write(new[] { (byte)'d', (byte)'a', (byte)'t', (byte)'a' }); w.Write(bytes);
            for (int i = 0; i < n; i++) w.Write((short)Math.Max(-32767, Math.Min(32767, buf[i] * gain * 32767)));
        }
    }
}
"@
$musicWav = Join-Path $work "music.wav"
[MusicGen]::Write($musicWav, $totalSeconds)
"music bed: {0:N0} s" -f $totalSeconds

# ---------------------------------------------------------------- 4. mix each scene
# The music is one continuous track cut at the scene boundaries, so it carries on across scenes. It is
# ducked while the narrator speaks (sidechain compression) and rises in the pauses.
for ($i = 0; $i -lt $sceneCount; $i++) {
    $n = $i + 1
    $len = $lengths[$i] + $pause
    $ci = [Globalization.CultureInfo]::InvariantCulture
    $musicFade = ""
    if ($chapterEnds -contains $n) {
        $len += $ending
        $musicFade = ",afade=t=out:st={0}:d={1}" -f ($len - $ending).ToString("0.###", $ci), $ending.ToString("0.###", $ci)
    }
    $voiceOnly = Join-Path $media ("intro_{0}_voice.ogg" -f $n)
    Copy-Item -LiteralPath $voices[$i] -Destination $voiceOnly -Force
    $out = Join-Path $media ("intro_{0}.ogg" -f $n)
    $filter = ("[0:a]apad=whole_dur={0},asplit=2[v][sc];" +
        "[1:a]atrim=start={1}:duration={0},asetpts=PTS-STARTPTS,afade=t=in:d=0.02,afade=t=out:st={2}:d=0.02,volume=0.22{3}[m];" +
        "[m][sc]sidechaincompress=threshold=0.015:ratio=5:attack=30:release=500:makeup=1[md];" +
        "[v][md]amix=inputs=2:normalize=0:duration=first,alimiter=limit=0.95") -f
        $len.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture),
        $starts[$i].ToString("0.###", [Globalization.CultureInfo]::InvariantCulture),
        ($len - 0.02).ToString("0.###", [Globalization.CultureInfo]::InvariantCulture),
        $musicFade
    Ffmpeg @("-i", $voices[$i], "-i", $musicWav, "-filter_complex", $filter, "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "3", $out)
    "intro_{0}.ogg  {1:N2} s  {2:N0} KB (voice only {3:N0} KB)" -f $n, (Duration $out), ((Get-Item $out).Length / 1KB), ((Get-Item $voiceOnly).Length / 1KB)
}

# ---------------------------------------------------------------- 5. key-phrase cues
# Each cue names a phrase in the narration; its time is found from where the sentence sits in the audio
# (silence detection between sentences) and where the phrase sits in the sentence (by character position).
$cueSpec = @(
    @(1, "cosmic index", "THE COSMIC INDEX OF SUMMONABLE PERSONS"),
    @(1, "nobody has ever read", "NOBODY HAS EVER READ IT"),
    @(1, "single clerk", "ONE CLERK"),
    @(1, "nine thousand years", "9,000 YEARS ON SHIFT"),
    @(2, "the clerk sneezed", "ACHOO."),
    @(2, "origin of the entire problem", "THE ORIGIN OF THE PROBLEM"),
    @(3, "Licensed Summoning Liaison", "LICENSED SUMMONING LIAISON, 3RD CLASS"),
    @(3, "default recipient", "DEFAULT RECIPIENT"),
    @(3, "meant for nobody", "RITUALS MEANT FOR NOBODY"),
    @(3, "intended for a goat", "ONE WAS FOR A GOAT"),
    @(4, "looked for the form", "SEARCHING FOR: THE FORM"),
    @(4, "27B slash 6", "FORM 27B/6"),
    @(4, "never been seen", "NEVER SEEN"),
    @(4, "exactly what a form would say", "EXACTLY WHAT A FORM WOULD SAY"),
    @(5, "fragile sense of self", "A FRAGILE SENSE OF SELF"),
    @(5, "attention and closure", "ATTENTION. CLOSURE."),
    @(5, "fifty silver", "FIFTY SILVER"),
    @(6, "installment on a debt", "INSTALLMENT ON A DEBT"),
    @(6, "never agreed to", "NEVER AGREED TO"),
    @(6, "definite progress", "DEFINITE PROGRESS"),
    @(7, "very easy to summon", "VERY EASY TO SUMMON"),
    @(7, "no objection", "NO OBJECTION"),
    @(7, "never been asked", "NEVER ASKED"),
    @(8, "the week after that", "THE WEEK AFTER THAT"),
    @(8, "Or the last", "OR THE LAST"),
    @(8, "Index is unclear", "THE INDEX IS UNCLEAR"),
    @(9, "earns points", "THE GROUP EARNS POINTS"),
    @(9, "remote, or dangerous", "REMOTE. DANGEROUS. UNREASONABLE."),
    @(9, "secret list", "ZENNIT'S SECRET LIST"),
    @(9, "victory for persistence", "VICTORY FOR PERSISTENCE"),
    @(10, "wins the week", "ZENNIT WINS THE WEEK"),
    @(10, "seven days", "IMMUNE FOR 7 DAYS"),
    @(10, "refuse a summons", "HE MAY REFUSE"),
    @(10, "fifty silver", "50 SILVER. CASH. NO RECEIPT."),
    @(10, "suggest dice", "OR DICE"),
    @(10, "accepts most things", "THE INDEX ACCEPTS MOST THINGS"),
    @(11, "the Index counted", "THE INDEX COUNTED"),
    @(11, "Zennit had won", "ZENNIT HAD WON"),
    @(11, "won the dice", "HE WON THE DICE"),
    @(11, "places on his list", "SEVERAL PLACES ON HIS LIST"),
    @(12, "registered letter", "BY REGISTERED LETTER"),
    @(12, "seven days", "SEVEN DAYS. NO RITUAL COULD FIND HIM."),
    @(12, "on leave", "ON LEAVE"),
    @(12, "doing nothing at all", "DOING NOTHING AT ALL"),
    @(12, "the clerk sneezed", "ACHOO. AGAIN.")
)
$lead = 0.25   # show a cue a little before the words are spoken

# The narration text lives in Intro.lua (one place); read it from there.
$luaText = [IO.File]::ReadAllText((Join-Path $root "Intro.lua"))
$texts = [regex]::Matches($luaText, 'text = \[=\[(.*?)\]=\]', "Singleline") | ForEach-Object { $_.Groups[1].Value.Trim() }
if ($texts.Count -ne $sceneCount) { throw "expected $sceneCount scene texts in Intro.lua, found $($texts.Count)" }

function SpeechSegments([string]$file, [double]$length) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $log = & $ffmpeg -hide_banner -nostats -i $file -af "silencedetect=noise=-38dB:d=0.35" -f null - 2>&1 | ForEach-Object { "$_" }
    $ErrorActionPreference = $prev
    $segs = @(); $cursor = 0.0; $silenceStart = $null
    foreach ($line in $log) {
        if ($line -match "silence_start: ([\d.]+)") { $silenceStart = [double]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture) }
        elseif ($line -match "silence_end: ([\d.]+)") {
            $silenceEnd = [double]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture)
            if ($silenceStart -gt $cursor + 0.05) { $segs += , @($cursor, $silenceStart) }
            $cursor = $silenceEnd; $silenceStart = $null
        }
    }
    if ($length - $cursor -gt 0.05) { $segs += , @($cursor, $length) }
    return , $segs
}

# Seconds into the take at which `phrase` is spoken: from where its sentence sits in the audio and where the
# phrase sits in the sentence (by character position).
function PhraseTime($text, $sentences, $segs, $byCount, $phrase, $scene) {
    $idx = -1
    for ($k = 0; $k -lt $sentences.Count; $k++) {
        if ($sentences[$k].IndexOf($phrase, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $idx = $k; break }
    }
    if ($idx -lt 0) { throw "scene ${scene}: phrase '$phrase' not found in the narration text" }
    $pos = $sentences[$idx].IndexOf($phrase, [StringComparison]::OrdinalIgnoreCase)
    if ($byCount) {
        $before = 0; for ($k = 0; $k -lt $idx; $k++) { $before += $sentences[$k].Length + 1 }
        $first = $segs[0][0]; $last = $segs[$segs.Count - 1][1]
        return $first + (($before + $pos) / [double]$text.Length) * ($last - $first)
    }
    $seg = $segs[$idx]
    return $seg[0] + ($pos / [double]$sentences[$idx].Length) * ($seg[1] - $seg[0])
}

# Highlights: while the narrator mentions something, a glowing box is drawn round that part of the picture.
# Each entry: scene, phrase, then x, y, width, height of the box in the 960x540 picture.
$highlightSpec = @(
    @(1, "cosmic index", 684, 244, 222, 297),
    @(1, "single clerk", 322, 344, 120, 158),
    @(1, "nine thousand years", 322, 344, 120, 158),
    @(2, "letter Z", 612, 192, 216, 156),
    @(2, "the clerk sneezed", 30, 10, 380, 520),
    @(3, "other people", 26, 166, 198, 216),
    @(3, "meant for nobody", 246, 166, 198, 216),
    @(3, "intended for a goat", 466, 166, 198, 216),
    @(3, "named Zennit", 696, 56, 208, 300),
    @(4, "looked for the form", 108, 128, 272, 380),
    @(4, "27B slash 6", 690, 140, 140, 185),
    @(5, "Ritual of Summoning", 250, 20, 460, 500),
    @(5, "attention and closure", 730, 50, 170, 140),
    @(5, "fifty silver", 30, 324, 210, 226),
    @(6, "installment on a debt", 244, 30, 472, 480),
    @(6, "never agreed to", 26, 224, 176, 240),
    @(7, "party of friends", 50, 224, 520, 236),
    @(7, "Zennit is", 754, 124, 212, 290),
    @(7, "no objection", 556, 226, 200, 260),
    @(8, "story of his week", 344, 0, 376, 524),
    @(8, "form is ever found", 640, 50, 150, 200),
    @(8, "Index is unclear", 24, 374, 132, 172),
    @(9, "earns points", 36, 56, 236, 278),
    @(9, "more points for places", 36, 356, 456, 78),
    @(9, "remote, or dangerous", 376, 356, 112, 78),
    @(9, "secret list", 500, 50, 240, 400),
    @(9, "victory for persistence", 36, 56, 448, 278),
    @(10, "wins the week", 36, 96, 272, 380),
    @(10, "refuse a summons", 326, 86, 188, 258),
    @(10, "fifty silver", 516, 86, 188, 258),
    @(10, "suggest dice", 706, 86, 188, 258),
    @(10, "accepts most things", 326, 356, 426, 140),
    @(11, "the Index counted", 40, 60, 440, 270),
    @(11, "Zennit had won", 262, 140, 220, 170),
    @(11, "won the dice", 50, 365, 150, 100),
    @(11, "places on his list", 500, 50, 240, 400),
    @(12, "registered letter", 24, 110, 176, 150),
    @(12, "seven days", 296, 26, 392, 60),
    @(12, "said his name", 340, 140, 170, 66),
    @(12, "on leave", 556, 104, 182, 84),
    @(12, "doing nothing at all", 766, 200, 170, 280),
    @(12, "the clerk sneezed", 16, 330, 200, 210)
)

$cues = @{}
$sentenceTimes = @{}
$highlights = @{}
for ($s = 1; $s -le $sceneCount; $s++) {
    $sentences = [regex]::Split($texts[$s - 1], '(?<=[.!?])\s+')
    $segs = SpeechSegments $voices[$s - 1] $lengths[$s - 1]
    $byCount = $segs.Count -ne $sentences.Count
    if ($byCount) {
        Write-Warning ("scene {0}: {1} sentences but {2} speech segments; spreading cues across the whole take" -f $s, $sentences.Count, $segs.Count)
    }
    $cues[$s] = @()
    foreach ($c in $cueSpec | Where-Object { $_[0] -eq $s }) {
        $t = PhraseTime $texts[$s - 1] $sentences $segs $byCount $c[1] $s
        $cues[$s] += , @([math]::Max(0.1, [double]$t - $lead), $c[2])
    }
    $cues[$s] = @($cues[$s] | Sort-Object { $_[0] })

    $highlights[$s] = @()
    foreach ($h in $highlightSpec | Where-Object { $_[0] -eq $s }) {
        $t = PhraseTime $texts[$s - 1] $sentences $segs $byCount $h[1] $s
        $highlights[$s] += , @([math]::Max(0.1, [double]$t - 0.15), $h[2], $h[3], $h[4], $h[5])
    }
    $highlights[$s] = @($highlights[$s] | Sort-Object { $_[0] })

    # When each sentence starts (for the subtitles): the start of its speech segment, a little early.
    $sentenceTimes[$s] = @()
    $running = 0
    for ($k = 0; $k -lt $sentences.Count; $k++) {
        if ($byCount) {
            $first = $segs[0][0]; $last = $segs[$segs.Count - 1][1]
            $t = $first + ($running / [double]$texts[$s - 1].Length) * ($last - $first)
        } else {
            $t = $segs[$k][0]
        }
        $sentenceTimes[$s] += , @([math]::Max(0.0, [double]$t - 0.1), $sentences[$k])
        $running += $sentences[$k].Length + 1
    }
}

$inv = [Globalization.CultureInfo]::InvariantCulture
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("-- Generated by tools/intro/build_audio.ps1. Do not edit by hand.")
$lines.Add("-- introLength: narration length of each scene in seconds; introCues: when each key phrase appears.")
$lines.Add("local ADDON, ST = ...")
$lines.Add("ST.introEnding = " + $ending.ToString("0.00", $inv))
$lines.Add("ST.introLength = { " + (($lengths | ForEach-Object { $_.ToString("0.00", $inv) }) -join ", ") + " }")
$lines.Add("ST.introCues = {")
for ($s = 1; $s -le $sceneCount; $s++) {
    $lines.Add("    [$s] = {")
    foreach ($c in $cues[$s]) { $lines.Add(("        {{ t = {0}, text = `"{1}`" }}," -f $c[0].ToString("0.00", $inv), $c[1].Replace('"', '\"'))) }
    $lines.Add("    },")
}
$lines.Add("}")
$lines.Add("-- introSentences: when each sentence of the narration starts, for the subtitles.")
$lines.Add("ST.introSentences = {")
for ($s = 1; $s -le $sceneCount; $s++) {
    $lines.Add("    [$s] = {")
    foreach ($c in $sentenceTimes[$s]) { $lines.Add(("        {{ t = {0}, text = [=[{1}]=] }}," -f $c[0].ToString("0.00", $inv), $c[1])) }
    $lines.Add("    },")
}
$lines.Add("}")
$lines.Add("-- introHighlights: while something is mentioned, a box is drawn round it (x, y, w, h in the 960x540 picture).")
$lines.Add("ST.introHighlights = {")
for ($s = 1; $s -le $sceneCount; $s++) {
    if ($highlights[$s].Count -eq 0) { continue }
    $lines.Add("    [$s] = {")
    foreach ($h in $highlights[$s]) { $lines.Add(("        {{ t = {0}, x = {1}, y = {2}, w = {3}, h = {4} }}," -f $h[0].ToString("0.00", $inv), $h[1], $h[2], $h[3], $h[4])) }
    $lines.Add("    },")
}
$lines.Add("}")
[IO.File]::WriteAllText((Join-Path $root "IntroCues.lua"), (($lines -join "`n") + "`n"))
"cues: " + (($cues.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum) + " written to IntroCues.lua"
