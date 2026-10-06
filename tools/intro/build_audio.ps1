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
#
# Only what is out of date is rebuilt. Each scene mix is tagged MIX_HASH: a hash of its voice take (the take's
# SRC_HASH), where its slice of the music starts, its length and fade, the mix filter and the music source. When
# none of those changed the mix is left alone, so editing one scene does not rewrite the rest. A scene's length
# moves the music for every scene after it, so those are rebuilt too, which is correct.
#   -SceneList "10,11"  mix exactly these scenes (a text list: through -File, 10,11 would be flattened into 1011)
#   -Force              mix every scene
#   -Sfx                also regenerate the sound effects (otherwise only when a file is missing)
#   -Stamp              with -SceneList: tag those existing mixes as current without mixing them (a baseline;
#                       use it only for mixes you know are up to date)
# IntroCues.lua is always rewritten: it is text, so git diff shows exactly what moved.
param([string]$SceneList = "", [switch]$Force, [switch]$Sfx, [switch]$Stamp)
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

function Tag([string]$file, [string]$key) {
    if (-not (Test-Path -LiteralPath $file)) { return "" }
    $v = & $ffprobe -v error -show_entries "stream_tags=$key" -of "default=noprint_wrappers=1:nokey=1" $file
    if ($v) { return ("$v").Trim() } else { return "" }
}

function Sha([string]$text) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($text)
    $hash = [Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return (([BitConverter]::ToString($hash) -replace "-", "").ToLower()).Substring(0, 16)
}

function Duration([string]$file) {
    [double]::Parse((& $ffprobe -v error -show_entries format=duration -of csv=p=0 $file), [Globalization.CultureInfo]::InvariantCulture)
}

# ---------------------------------------------------------------- 1. sound effects
# Mono, 44.1 kHz, peak about -9 dBFS. Retro "terminal" blips: rising/falling chirps, a two-tone blip, key clicks.
$fmt = "d=0.2:s=44100"
$sfxSpec = [ordered]@{
    "sfx_chirp_1" = "aevalsrc='0.55*sin(2*PI*(900*t+5357*t*t))*exp(-t*13)':d=0.18:s=44100"
    "sfx_chirp_2" = "aevalsrc='0.55*sin(2*PI*(2200*t-4600*t*t))*exp(-t*12)':d=0.16:s=44100"
    "sfx_chirp_3" = "aevalsrc='0.5*sin(2*PI*if(lt(t,0.045),1500,2100)*t)*exp(-mod(t,0.045)*25)':d=0.12:s=44100"
    "sfx_keys_long" = "aevalsrc='0.55*random(0)*(exp(-mod(t,0.074)*700)*lt(mod(t,0.074),0.012)+0.7*exp(-mod(t,0.113)*650)*lt(mod(t,0.113),0.012))':d=16:s=44100"
    "sfx_pop"     = "aevalsrc='0.6*sin(2*PI*620*t)*exp(-t*26)':d=0.14:s=44100"
}
$sfxMissing = @($sfxSpec.Keys | Where-Object { -not (Test-Path (Join-Path $sfxDir "$_.ogg")) })
if (-not $Stamp -and ($Sfx -or $sfxMissing.Count -gt 0)) {
    foreach ($name in $sfxSpec.Keys) {
        $filter = if ($name -like "sfx_keys*") { "highpass=f=1800,volume=0.7" } else { "volume=0.5" }
        Ffmpeg @("-f", "lavfi", "-i", $sfxSpec[$name], "-af", $filter, "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", (Join-Path $sfxDir "$name.ogg"))
    }
    "sound effects: " + ($sfxSpec.Keys -join ", ")
} else {
    "sound effects: left as they are (-Sfx regenerates them)"
}

# ---------------------------------------------------------------- 2. scene lengths
$sceneCount = (Get-ChildItem (Join-Path $here "narration") -Filter "voice_*.ogg").Count
$voices = 1..$sceneCount | ForEach-Object { Join-Path $here ("narration\voice_{0:00}.ogg" -f $_) }
$pause = 0.6   # keep in step with PAUSE in Intro.lua
$ending = 3.2   # extra seconds after the last scene: the music fades out while the picture fades to black
$chapterEnds = @(10, 12, 14, 16, 18, 20, 22, 24, 26, 29, 32)   # the last scene of each chapter (keep in step with the chapter fields in Intro.lua)
$lengths = $voices | ForEach-Object { Duration $_ }
$starts = @(); $acc = 0.0
for ($k = 0; $k -lt $lengths.Count; $k++) {
    $starts += $acc
    $acc += $lengths[$k] + $pause
    if ($chapterEnds -contains ($k + 1)) { $acc += $ending }
}
$totalSeconds = $acc + $ending + 3

# ---------------------------------------------------------------- 3. music bed
$musicSource = @"
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
$musicHash = Sha $musicSource
$musicWav = Join-Path $work "music.wav"
$musicMade = $false
function EnsureMusic {   # the music is synthesised only when a scene is actually mixed
    if ($script:musicMade) { return }
    Add-Type -TypeDefinition $musicSource
    [MusicGen]::Write($musicWav, $totalSeconds)
    "music bed: {0:N0} s" -f $totalSeconds
    $script:musicMade = $true
}
$only = @($SceneList -split '[,\s]+' | Where-Object { $_ } | ForEach-Object { [int]$_ })
if ($Stamp -and $only.Count -eq 0) { throw "-Stamp needs -SceneList: name the mixes you know are current" }
$mixed = 0; $staleLeft = @(); $stamped = 0

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
    $out = Join-Path $media ("intro_{0}.ogg" -f $n)
    if (-not $Stamp -and (-not (Test-Path $voiceOnly) -or (Get-FileHash $voiceOnly).Hash -ne (Get-FileHash $voices[$i]).Hash)) {
        Copy-Item -LiteralPath $voices[$i] -Destination $voiceOnly -Force
    }
    $filter = ("[0:a]apad=whole_dur={0},asplit=2[v][sc];" +
        "[1:a]atrim=start={1}:duration={0},asetpts=PTS-STARTPTS,afade=t=in:d=0.02,afade=t=out:st={2}:d=0.02,volume=0.22{3}[m];" +
        "[m][sc]sidechaincompress=threshold=0.015:ratio=5:attack=30:release=500:makeup=1[md];" +
        "[v][md]amix=inputs=2:normalize=0:duration=first,alimiter=limit=0.95") -f
        $len.ToString("0.###", [Globalization.CultureInfo]::InvariantCulture),
        $starts[$i].ToString("0.###", [Globalization.CultureInfo]::InvariantCulture),
        ($len - 0.02).ToString("0.###", [Globalization.CultureInfo]::InvariantCulture),
        $musicFade
    $voiceTag = Tag $voices[$i] "SRC_HASH"
    if (-not $voiceTag) { throw ("voice_{0:00}.ogg has no SRC_HASH tag: run tools\intro\check_audio.py (--stamp if you know it is current)" -f $n) }
    $mixHash = Sha ("{0}|{1}|{2}|{3}|{4}|q3" -f $voiceTag, $starts[$i].ToString("0.###", $ci), $len.ToString("0.###", $ci), $filter, $musicHash)
    $current = (Tag $out "MIX_HASH") -eq $mixHash
    if ($Stamp) {
        if ($only -contains $n -and -not (Tag $out "MIX_HASH")) {
            $tmp = "$out.tagging.ogg"
            Ffmpeg @("-i", $out, "-map_metadata", "0", "-c", "copy", "-metadata", "MIX_HASH=$mixHash", $tmp)
            Move-Item -LiteralPath $tmp -Destination $out -Force
            $stamped++
        }
        continue
    }
    $wanted = $Force -or ($only.Count -gt 0 -and $only -contains $n) -or ($only.Count -eq 0 -and -not $current)
    if (-not $wanted) {
        if (-not $current) { $staleLeft += $n }
        continue
    }
    EnsureMusic
    Ffmpeg @("-i", $voices[$i], "-i", $musicWav, "-filter_complex", $filter, "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "3", "-metadata", "MIX_HASH=$mixHash", $out)
    $mixed++
    "intro_{0}.ogg  {1:N2} s  {2:N0} KB (voice only {3:N0} KB)" -f $n, (Duration $out), ((Get-Item $out).Length / 1KB), ((Get-Item $voiceOnly).Length / 1KB)
}
if ($Stamp) { "stamped $stamped mixes" } else { "mixed $mixed scene(s); the rest were up to date" }
if ($staleLeft.Count -gt 0) { Write-Warning ("not mixed (out of date, outside -SceneList): " + ($staleLeft -join ", ")) }

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
    @(8, "every week after that", "EVERY WEEK AFTER THAT"),
    @(8, "Or the last", "OR THE LAST"),
    @(8, "Index is unclear", "THE INDEX IS UNCLEAR"),
    @(9, "earns points", "THE GROUP EARNS POINTS"),
    @(9, "remote, or dangerous", "REMOTE. DANGEROUS. UNREASONABLE."),
    @(9, "ten summons a week", "10 A WEEK. THE REST: ENTHUSIASM."),
    @(9, "secret list", "ZENNIT'S SECRET LIST"),
    @(9, "victory for persistence", "VICTORY FOR PERSISTENCE"),
    @(10, "wins the week", "ZENNIT WINS THE WEEK"),
    @(10, "seven days", "IMMUNE FOR 7 DAYS"),
    @(10, "refuse a summons", "HE MAY REFUSE"),
    @(10, "fifty silver", "50 SILVER. CASH. NO RECEIPT."),
    @(10, "suggest dice", "OR DICE"),
    @(10, "three times a week", "3 DICE A WEEK"),
    @(10, "close the Index", "HE MAY CLOSE THE INDEX"),
    @(10, "accepts most things", "THE INDEX ACCEPTS MOST THINGS"),
    @(11, "the Index counted", "THE INDEX COUNTED"),
    @(11, "Zennit had won", "ZENNIT HAD WON"),
    @(11, "won the dice", "HE WON THE DICE"),
    @(11, "places on his list", "SEVERAL PLACES ON HIS LIST"),
    @(12, "registered letter", "BY REGISTERED LETTER"),
    @(12, "seven days", "SEVEN DAYS. NO RITUAL COULD FIND HIM."),
    @(12, "on leave", "ON LEAVE"),
    @(12, "doing nothing at all", "DOING NOTHING AT ALL"),
    @(13, "the group won", "THE GROUP WON"),
    @(13, "more surprised than the group", "NOBODY MORE SURPRISED"),
    @(13, "head start", "DESPITE THE HEAD START"),
    @(13, "three times", "CHECKED THREE TIMES"),
    @(14, "victory for persistence", "A VICTORY FOR PERSISTENCE"),
    @(14, "small cake", "A SMALL CAKE"),
    @(14, "did not trust", "WHICH HE DID NOT TRUST"),
    @(14, "count the next one", "COUNTING THE NEXT ONE"),
    @(15, "with a parcel", "A PARCEL"),
    @(15, "brass key", "A BRASS KEY"),
    @(15, "Side Door", "SIDE DOOR"),
    @(15, "first item", "THE FIRST ITEM"),
    @(15, "too busy being summoned", "TOO BUSY BEING SUMMONED"),
    @(16, "behind the letter Q", "BEHIND THE LETTER Q"),
    @(16, "Please Do Not", "PLEASE DO NOT"),
    @(16, "very old kettle", "A VERY OLD KETTLE"),
    @(16, "fit him suspiciously well", "A CHAIR THAT FIT HIM"),
    @(16, "cleared his throat", "SOMEONE CLEARED HIS THROAT"),
    @(17, "unexpected receipt", "AN UNEXPECTED RECEIPT"),
    @(17, "carbon paper", "BLUE CARBON PAPER"),
    @(17, "title was smudged", "THE TITLE WAS SMUDGED"),
    @(17, "27B slash 6", "FORM 27B/6"),
    @(18, "form did not exist", "THE FORM DID NOT EXIST"),
    @(18, "in triplicate", "IN TRIPLICATE"),
    @(18, "kept the third", "THE PARTY KEPT THE THIRD"),
    @(18, "think about it", "THEY WILL THINK ABOUT IT"),
    @(19, "second item", "THE SECOND ITEM"),
    @(19, "a pamphlet", "A PAMPHLET"),
    @(19, "Care and Feeding of Ink", "THE CARE AND FEEDING OF INK"),
    @(19, "never been a list of errands", "NOT A LIST OF ERRANDS"),
    @(19, "a syllabus", "A SYLLABUS"),
    @(20, "kettle for company", "THE KETTLE FOR COMPANY"),
    @(20, "promising start", "A PROMISING START"),
    @(20, "considered a gift", "BACKWARDS: A GIFT"),
    @(20, "nameplate was being engraved", "A NAMEPLATE, BEING ENGRAVED"),
    @(20, "decided whose", "NOT YET DECIDED WHOSE"),
    @(21, "without cake", "WITHOUT CAKE"),
    @(21, "answer back", "THE RITUAL ANSWERS BACK"),
    @(21, "glowing in a meaningful manner", "GLOWING IN A MEANINGFUL MANNER"),
    @(21, "unsettling", "UNSETTLING"),
    @(21, "encouraging", "ALSO ENCOURAGING"),
    @(22, "beneath a tavern", "BENEATH A TAVERN"),
    @(22, "chalk circle", "A CHALK CIRCLE"),
    @(22, "27B slash 6", "FORM 27B/6"),
    @(22, "right question", "THE RIGHT QUESTION"),
    @(23, "fourth week", "THE FOURTH WEEK"),
    @(23, "very old and very tired", "VERY OLD. VERY TIRED."),
    @(23, "wrong book", "YOU ARE IN THE WRONG BOOK"),
    @(23, "not a criticism", "NOT A CRITICISM"),
    @(24, "showed him the desk", "THE DESK"),
    @(24, "nine thousand years of unfinished business", "9,000 YEARS OF UNFINISHED BUSINESS"),
    @(24, "about Zennit", "MOSTLY ABOUT ZENNIT"),
    @(24, "hold the pen", "HOLD THE PEN"),
    @(24, "find my hat", "WHILE I FIND MY HAT"),
    @(25, "never wanted gold", "IT NEVER WANTED GOLD"),
    @(25, "proper ending", "A PROPER ENDING"),
    @(25, "followed by closure", "FOLLOWED BY CLOSURE"),
    @(25, "very good about it", "VERY GOOD ABOUT IT"),
    @(26, "Fifty silver", "FIFTY SILVER, IN PERSON"),
    @(26, "third copy of the form", "THE THIRD COPY"),
    @(26, "complete the set", "TO COMPLETE THE SET"),
    @(26, "how that looked", "IT UNDERSTOOD HOW THAT LOOKED"),
    @(27, "found his hat", "THE CLERK FOUND HIS HAT"),
    @(27, "on his head", "ON HIS HEAD"),
    @(27, "shook Zennit's hand", "A HANDSHAKE"),
    @(27, "toward the sea", "WALKING TOWARD THE SEA"),
    @(27, "without his coat", "WITHOUT HIS COAT"),
    @(28, "chair fit", "THE CHAIR FIT"),
    @(28, "from the beginning", "READ FROM THE BEGINNING"),
    @(28, "misfiled by a sneeze", "MISFILED BY A SNEEZE"),
    @(28, "single stroke", "ONE STROKE OF THE PEN"),
    @(28, "went quiet", "THE RITUAL WENT QUIET"),
    @(29, "added entries", "HE ADDED ENTRIES"),
    @(29, "in alphabetical order", "IN ALPHABETICAL ORDER"),
    @(29, "promoted to Clerk", "PROMOTED TO CLERK"),
    @(29, "always accept", "HE WILL ALWAYS ACCEPT"),
    @(29, "wrote that down", "THE INDEX WROTE THAT DOWN"),
    @(30, "fifth win", "THE FIFTH WIN"),
    @(30, "third copy of the form", "THE THIRD COPY"),
    @(30, "reserved for exams", "NERVES RESERVED FOR EXAMS"),
    @(30, "prepared something", "IT HAD PREPARED SOMETHING"),
    @(31, "silver was counted", "THE SILVER WAS COUNTED"),
    @(31, "copy was handed over", "THE COPY WAS HANDED OVER"),
    @(31, "given a receipt", "A RECEIPT, AT LAST"),
    @(31, "complete in triplicate", "COMPLETE IN TRIPLICATE"),
    @(31, "mostly paperwork", "MOSTLY PAPERWORK"),
    @(32, "small click", "A SMALL CLICK"),
    @(32, "summoned by nobody", "SUMMONED BY NOBODY"),
    @(32, "free", "FREE"),
    @(32, "for cake", "FOR CAKE"),
    @(32, "very small cake", "A VERY SMALL CAKE")
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
    @(13, "the group won", 540, 120, 330, 250),
    @(13, "finished ahead of Zennit", 40, 60, 440, 270),
    @(13, "head start", 262, 140, 220, 170),
    @(13, "run of dice", 50, 365, 150, 100),
    @(14, "victory for persistence", 176, 22, 608, 86),
    @(14, "traditional manner", 90, 140, 360, 230),
    @(14, "small cake", 232, 306, 118, 100),
    @(14, "did not trust", 550, 140, 250, 350),
    @(14, "count the next one", 822, 350, 106, 160),
    @(15, "with a parcel", 50, 190, 290, 230),
    @(15, "brass key", 396, 140, 250, 120),
    @(15, "luggage tag", 396, 286, 190, 100),
    @(15, "said, helpfully, nothing", 610, 262, 140, 128),
    @(15, "secret list", 40, 30, 220, 140),
    @(15, "first item", 40, 30, 220, 140),
    @(16, "behind the letter Q", 396, 70, 186, 400),
    @(16, "filing cabinet", 36, 196, 128, 272),
    @(16, "sign that said", 176, 142, 208, 72),
    @(16, "very old kettle", 612, 396, 106, 80),
    @(16, "a desk with a chair", 696, 290, 240, 190),
    @(17, "cake box", 36, 296, 270, 190),
    @(17, "carbon paper", 372, 52, 276, 356),
    @(17, "title was smudged", 396, 86, 228, 70),
    @(17, "27B slash 6", 396, 200, 228, 100),
    @(18, "form did not exist", 50, 50, 760, 150),
    @(18, "in triplicate", 50, 50, 760, 150),
    @(18, "the Index and to the Ritual", 90, 290, 440, 170),
    @(18, "kept the third", 590, 170, 310, 240),
    @(18, "asked for it back", 46, 436, 328, 72),
    @(18, "think about it", 586, 436, 328, 72),
    @(19, "second item", 60, 170, 360, 110),
    @(19, "pamphlet", 460, 160, 280, 200),
    @(19, "Care and Feeding of Ink", 60, 270, 360, 110),
    @(19, "a syllabus", 50, 40, 380, 420),
    @(20, "kettle for company", 70, 400, 130, 90),
    @(20, "alphabet forwards", 70, 24, 400, 70),
    @(20, "backwards", 490, 24, 400, 70),
    @(20, "nameplate was being engraved", 690, 340, 190, 70),
    @(21, "answer back", 320, 120, 320, 350),
    @(21, "carbon copy", 80, 140, 100, 100),
    @(21, "unsettling", 80, 150, 250, 220),
    @(21, "encouraging", 680, 150, 240, 220),
    @(22, "beneath a tavern", 30, 290, 260, 190),
    @(22, "chalk circle", 210, 380, 540, 120),
    @(22, "wedged tight", 436, 350, 100, 90),
    @(22, "27B slash 6", 436, 350, 100, 90),
    @(23, "clerk found", 50, 90, 330, 440),
    @(23, "wrong book", 256, 20, 348, 64),
    @(23, "Zennit replied", 636, 20, 298, 64),
    @(24, "showed him the desk", 40, 210, 880, 220),
    @(24, "hold the pen", 430, 180, 130, 130),
    @(24, "find my hat", 30, 80, 240, 260),
    @(25, "never wanted gold", 290, 16, 388, 64),
    @(25, "gold", 720, 110, 100, 120),
    @(25, "proper ending", 320, 110, 320, 360),
    @(26, "Fifty silver", 50, 60, 280, 270),
    @(26, "third copy of the form", 340, 60, 280, 270),
    @(26, "how that looked", 210, 386, 480, 76),
    @(27, "found his hat", 320, 26, 140, 120),
    @(27, "shook Zennit's hand", 220, 170, 280, 330),
    @(27, "side door", 680, 110, 220, 370),
    @(27, "toward the sea", 690, 300, 210, 130),
    @(28, "chair fit", 100, 240, 110, 210),
    @(28, "read the Index", 240, 200, 470, 260),
    @(28, "letter Z", 480, 200, 230, 250),
    @(28, "single stroke", 620, 180, 140, 140),
    @(28, "went quiet", 30, 390, 130, 140),
    @(29, "added entries", 290, 40, 320, 400),
    @(29, "party went in first", 40, 200, 250, 200),
    @(29, "promoted to Clerk", 600, 320, 300, 90),
    @(29, "always accept", 610, 6, 340, 56),
    @(30, "fifty silver", 60, 310, 90, 90),
    @(30, "third copy", 290, 230, 80, 100),
    @(30, "nerves", 100, 170, 330, 260),
    @(30, "glowed", 600, 190, 320, 340),
    @(30, "prepared something", 556, 76, 388, 66),
    @(31, "silver was counted", 50, 380, 220, 120),
    @(31, "copy was handed over", 250, 150, 480, 230),
    @(31, "given a receipt", 770, 240, 150, 190),
    @(31, "complete in triplicate", 250, 150, 480, 230),
    @(31, "mostly paperwork", 850, 420, 90, 110),
    @(32, "small click", 100, 120, 170, 240),
    @(32, "free", 320, 80, 280, 400),
    @(32, "for cake", 580, 360, 320, 100),
    @(32, "They accepted", 620, 230, 300, 110)
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
        # keep the box inside the 960x540 picture (the self-test checks it)
        $bw = [math]::Min($h[4], 960 - $h[2]); $bh = [math]::Min($h[5], 540 - $h[3])
        $highlights[$s] += , @([math]::Max(0.1, [double]$t - 0.15), $h[2], $h[3], $bw, $bh)
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
