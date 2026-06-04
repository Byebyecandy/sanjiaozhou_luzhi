param(
    [switch]$SelfTest,
    [switch]$SmokeTest,
    [int]$SmokeTestSeconds = 8,
    [int]$UiSmokeTestSeconds = 0,
    [string]$PetId = "hatch-default",
    [string]$PetPackagePath = "",
    [ValidateSet("zh-CN", "en-US")]
    [string]$Language = "zh-CN"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class ReplayHotkeyForm : Form
{
    public event Action<int> HotkeyPressed;

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    protected override void WndProc(ref Message m)
    {
        const int WM_HOTKEY = 0x0312;
        if (m.Msg == WM_HOTKEY && HotkeyPressed != null)
        {
            HotkeyPressed(m.WParam.ToInt32());
        }
        base.WndProc(ref m);
    }
}

public class ReplayPetCanvas : Panel
{
    public bool IsRecording { get; set; }
    public bool PanelExpanded { get; set; }
    public int CacheSeconds { get; set; }

    public ReplayPetCanvas()
    {
        this.DoubleBuffered = true;
        this.ResizeRedraw = true;
        this.Cursor = Cursors.SizeAll;
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);

        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.Clear(this.BackColor);

        int w = this.Width;
        int h = this.Height;
        Rectangle body = new Rectangle(28, 42, Math.Max(100, w - 56), Math.Max(86, h - 78));

        Color bodyTop = IsRecording ? Color.FromArgb(62, 205, 132) : Color.FromArgb(92, 145, 245);
        Color bodyBottom = IsRecording ? Color.FromArgb(13, 122, 76) : Color.FromArgb(38, 72, 150);
        using (LinearGradientBrush brush = new LinearGradientBrush(body, bodyTop, bodyBottom, 90f))
        using (GraphicsPath path = RoundedRect(body, 38))
        {
            g.FillPath(brush, path);
        }

        using (Pen outline = new Pen(Color.FromArgb(55, 25, 36, 58), 2f))
        using (GraphicsPath path = RoundedRect(body, 38))
        {
            g.DrawPath(outline, path);
        }

        using (Pen antenna = new Pen(Color.FromArgb(80, 28, 43, 68), 5f))
        {
            antenna.StartCap = LineCap.Round;
            antenna.EndCap = LineCap.Round;
            g.DrawLine(antenna, w / 2 - 26, 52, w / 2 - 44, 18);
            g.DrawLine(antenna, w / 2 + 26, 52, w / 2 + 44, 18);
        }

        using (SolidBrush dot = new SolidBrush(IsRecording ? Color.FromArgb(255, 80, 86) : Color.FromArgb(245, 205, 72)))
        {
            g.FillEllipse(dot, w / 2 - 52, 10, 20, 20);
            g.FillEllipse(dot, w / 2 + 32, 10, 20, 20);
        }

        DrawEye(g, body.Left + body.Width / 3 - 18, body.Top + 33, IsRecording);
        DrawEye(g, body.Right - body.Width / 3 - 18, body.Top + 33, IsRecording);

        using (Pen mouth = new Pen(Color.White, 4f))
        {
            mouth.StartCap = LineCap.Round;
            mouth.EndCap = LineCap.Round;
            g.DrawArc(mouth, w / 2 - 24, body.Top + 55, 48, 30, 15, 150);
        }

        Rectangle badge = new Rectangle(w - 70, body.Bottom - 36, 52, 24);
        using (GraphicsPath badgePath = RoundedRect(badge, 12))
        using (SolidBrush badgeBrush = new SolidBrush(Color.FromArgb(232, 255, 255, 255)))
        {
            g.FillPath(badgeBrush, badgePath);
        }

        string badgeText = IsRecording ? "REC" : "IDLE";
        using (Font font = new Font("Segoe UI", 8f, FontStyle.Bold))
        using (SolidBrush textBrush = new SolidBrush(IsRecording ? Color.FromArgb(178, 34, 34) : Color.FromArgb(58, 82, 132)))
        {
            StringFormat format = new StringFormat();
            format.Alignment = StringAlignment.Center;
            format.LineAlignment = StringAlignment.Center;
            g.DrawString(badgeText, font, textBrush, badge, format);
        }

        Rectangle bubble = new Rectangle(12, h - 38, w - 24, 26);
        using (GraphicsPath bubblePath = RoundedRect(bubble, 13))
        using (SolidBrush bubbleBrush = new SolidBrush(Color.FromArgb(236, 20, 27, 42)))
        {
            g.FillPath(bubbleBrush, bubblePath);
        }

        string status = CacheSeconds > 0 ? CacheSeconds.ToString() + "s cached" : "ready";
        using (Font font = new Font("Segoe UI", 8.5f, FontStyle.Bold))
        using (SolidBrush textBrush = new SolidBrush(Color.White))
        {
            StringFormat format = new StringFormat();
            format.Alignment = StringAlignment.Center;
            format.LineAlignment = StringAlignment.Center;
            g.DrawString(status, font, textBrush, bubble, format);
        }

        if (PanelExpanded)
        {
            using (Pen chevron = new Pen(Color.FromArgb(210, 255, 255, 255), 3f))
            {
                chevron.StartCap = LineCap.Round;
                chevron.EndCap = LineCap.Round;
                g.DrawLine(chevron, w / 2 - 10, h - 52, w / 2, h - 44);
                g.DrawLine(chevron, w / 2 + 10, h - 52, w / 2, h - 44);
            }
        }
    }

    private void DrawEye(Graphics g, int x, int y, bool active)
    {
        using (SolidBrush white = new SolidBrush(Color.White))
        using (SolidBrush pupil = new SolidBrush(active ? Color.FromArgb(20, 60, 36) : Color.FromArgb(24, 36, 72)))
        {
            g.FillEllipse(white, x, y, 36, 28);
            g.FillEllipse(pupil, x + 12, y + 8, 12, 12);
        }
    }

    private GraphicsPath RoundedRect(Rectangle bounds, int radius)
    {
        int d = radius * 2;
        GraphicsPath path = new GraphicsPath();
        path.AddArc(bounds.X, bounds.Y, d, d, 180, 90);
        path.AddArc(bounds.Right - d, bounds.Y, d, d, 270, 90);
        path.AddArc(bounds.Right - d, bounds.Bottom - d, d, d, 0, 90);
        path.AddArc(bounds.X, bounds.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }
}

public class CuteReplayPetCanvas : Panel
{
    public bool IsRecording { get; set; }
    public bool PanelExpanded { get; set; }
    public int CacheSeconds { get; set; }
    public int AnimationTick { get; set; }
    public int AnimationElapsedMs { get; set; }
    public string HatchState { get; set; }
    public string HatchPetDisplayName { get; set; }
    public string ReadyText { get; set; }
    public string CachedTextFormat { get; set; }
    public string MissingPetText { get; set; }
    public Image HatchSpritesheet { get; set; }
    public bool HasHatchPet { get; set; }
    public bool UsePixelScaling { get; set; }

    private const int HatchCellWidth = 192;
    private const int HatchCellHeight = 208;
    private static readonly string[] HatchStateNames = new string[] {
        "idle", "running-right", "running-left", "waving", "jumping", "failed", "waiting", "running", "review"
    };
    private static readonly int[][] HatchStateDurations = new int[][] {
        new int[] { 280, 110, 110, 140, 140, 320 },
        new int[] { 120, 120, 120, 120, 120, 120, 120, 220 },
        new int[] { 120, 120, 120, 120, 120, 120, 120, 220 },
        new int[] { 140, 140, 140, 280 },
        new int[] { 140, 140, 140, 140, 280 },
        new int[] { 140, 140, 140, 140, 140, 140, 140, 240 },
        new int[] { 150, 150, 150, 150, 150, 260 },
        new int[] { 120, 120, 120, 120, 120, 220 },
        new int[] { 150, 150, 150, 150, 150, 280 }
    };

    public CuteReplayPetCanvas()
    {
        this.DoubleBuffered = true;
        this.ResizeRedraw = true;
        this.Cursor = Cursors.SizeAll;
        this.HatchState = "idle";
        this.HatchPetDisplayName = "Hatch pet";
        this.ReadyText = "ready";
        this.CachedTextFormat = "{0}s cached";
        this.MissingPetText = "Hatch pet missing";
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);

        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = UsePixelScaling ? PixelOffsetMode.Half : PixelOffsetMode.HighQuality;
        g.InterpolationMode = UsePixelScaling ? InterpolationMode.NearestNeighbor : InterpolationMode.HighQualityBicubic;
        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAliasGridFit;
        g.Clear(this.BackColor);

        int w = this.Width;
        int h = this.Height;
        int cx = w / 2;
        int bob = (AnimationElapsedMs / 480) % 2 == 0 ? 0 : 2;

        if (HatchSpritesheet != null && HasHatchPet)
        {
            DrawHatchPetFrame(g, new Rectangle(10, 4 + bob, w - 20, h - 48));
        }
        else
        {
            DrawMissingHatchPet(g, new Rectangle(18, 26, w - 36, h - 86));
        }
        DrawPixelStatusPill(g, new Rectangle(18, h - 38, w - 36, 28));

        if (PanelExpanded)
        {
            FillPx(g, Color.FromArgb(34, 34, 38), cx - 10, h - 52, 20, 4);
            FillPx(g, Color.FromArgb(34, 34, 38), cx - 6, h - 46, 12, 4);
        }
    }

    private void DrawHatchPetFrame(Graphics g, Rectangle bounds)
    {
        int row = ResolveStateRow();
        int[] durations = HatchStateDurations[row];
        int frame = ResolveFrame(AnimationElapsedMs, durations);
        Rectangle source = new Rectangle(frame * HatchCellWidth, row * HatchCellHeight, HatchCellWidth, HatchCellHeight);

        double scaleX = (double)bounds.Width / source.Width;
        double scaleY = (double)bounds.Height / source.Height;
        double scale = Math.Min(scaleX, scaleY);

        double pulse = IsRecording ? Math.Sin(AnimationElapsedMs * 0.0029) * 0.025 : Math.Sin(AnimationElapsedMs * 0.0015) * 0.012;
        scale *= 1.0 + pulse;

        int drawW = Math.Max(1, (int)Math.Round(source.Width * scale));
        int drawH = Math.Max(1, (int)Math.Round(source.Height * scale));
        int drawX = bounds.X + (bounds.Width - drawW) / 2;
        int drawY = bounds.Bottom - drawH;
        Rectangle dest = new Rectangle(drawX, drawY, drawW, drawH);

        using (System.Drawing.Imaging.ImageAttributes attrs = new System.Drawing.Imaging.ImageAttributes())
        {
            g.DrawImage(HatchSpritesheet, dest, source.X, source.Y, source.Width, source.Height, GraphicsUnit.Pixel, attrs);
        }

        if (IsRecording)
        {
            int dotSize = 12 + ((AnimationTick / 4) % 2) * 3;
            FillPx(g, Color.FromArgb(12, 12, 14), dest.Right - 34, dest.Top + 24, dotSize + 4, dotSize + 4);
            FillPx(g, Color.FromArgb(255, 66, 82), dest.Right - 32, dest.Top + 26, dotSize, dotSize);
            FillPx(g, Color.White, dest.Right - 28, dest.Top + 30, 4, 4);
        }
    }

    private int ResolveStateRow()
    {
        string state = HatchState;
        if (String.IsNullOrWhiteSpace(state))
        {
            state = IsRecording ? "running" : "idle";
        }

        for (int i = 0; i < HatchStateNames.Length; i++)
        {
            if (String.Equals(HatchStateNames[i], state, StringComparison.OrdinalIgnoreCase))
            {
                return i;
            }
        }

        return IsRecording ? 7 : 0;
    }

    private int ResolveFrame(int elapsedMs, int[] durations)
    {
        if (durations == null || durations.Length == 0)
        {
            return 0;
        }

        int totalMs = 0;
        for (int i = 0; i < durations.Length; i++)
        {
            totalMs += Math.Max(1, durations[i]);
        }

        int loopMs = totalMs > 0 ? elapsedMs % totalMs : 0;
        int cursor = 0;
        for (int i = 0; i < durations.Length; i++)
        {
            cursor += Math.Max(1, durations[i]);
            if (loopMs < cursor)
            {
                return i;
            }
        }

        return durations.Length - 1;
    }

    private void DrawMissingHatchPet(Graphics g, Rectangle bounds)
    {
        Color outline = Color.FromArgb(24, 24, 28);
        Color fill = Color.FromArgb(248, 248, 250);
        Color muted = Color.FromArgb(120, 124, 132);

        FillPx(g, outline, bounds.X, bounds.Y, bounds.Width, bounds.Height);
        FillPx(g, fill, bounds.X + 4, bounds.Y + 4, bounds.Width - 8, bounds.Height - 8);
        FillPx(g, outline, bounds.X + 28, bounds.Y + 34, bounds.Width - 56, 10);
        FillPx(g, outline, bounds.X + 42, bounds.Y + 58, bounds.Width - 84, 10);
        FillPx(g, muted, bounds.X + 38, bounds.Y + 92, bounds.Width - 76, 8);
        FillPx(g, muted, bounds.X + 54, bounds.Y + 110, bounds.Width - 108, 8);

        using (Font font = new Font("Segoe UI", 8f, FontStyle.Bold))
        using (SolidBrush brush = new SolidBrush(outline))
        {
            StringFormat format = new StringFormat();
            format.Alignment = StringAlignment.Center;
            format.LineAlignment = StringAlignment.Center;
            g.DrawString(MissingPetText, font, brush, bounds, format);
        }
    }

    private void DrawPixelStatusPill(Graphics g, Rectangle rect)
    {
        Color fill = IsRecording ? Color.FromArgb(34, 28, 30) : Color.FromArgb(244, 244, 244);
        Color border = Color.FromArgb(8, 8, 10);
        Color textColor = IsRecording ? Color.FromArgb(255, 238, 240) : Color.FromArgb(24, 24, 26);

        FillPx(g, border, rect.X, rect.Y, rect.Width, rect.Height);
        FillPx(g, fill, rect.X + 3, rect.Y + 3, rect.Width - 6, rect.Height - 6);

        string status = CacheSeconds > 0 ? String.Format(CachedTextFormat, CacheSeconds) : ReadyText;
        if (IsRecording)
        {
            status = "REC - " + status;
        }

        using (Font font = new Font("Segoe UI", 8f, FontStyle.Bold))
        using (SolidBrush brush = new SolidBrush(textColor))
        {
            StringFormat format = new StringFormat();
            format.Alignment = StringAlignment.Center;
            format.LineAlignment = StringAlignment.Center;
            g.DrawString(status, font, brush, rect, format);
        }
    }

    private void FillPx(Graphics g, Color color, int x, int y, int width, int height)
    {
        using (SolidBrush brush = new SolidBrush(color))
        {
            g.FillRectangle(brush, x, y, width, height);
        }
    }

    private void FillPoly(Graphics g, Color color, Point[] points)
    {
        using (SolidBrush brush = new SolidBrush(color))
        {
            g.FillPolygon(brush, points);
        }
    }

    private GraphicsPath RoundedRect(Rectangle bounds, int radius)
    {
        int d = radius * 2;
        GraphicsPath path = new GraphicsPath();
        path.AddArc(bounds.X, bounds.Y, d, d, 180, 90);
        path.AddArc(bounds.Right - d, bounds.Y, d, d, 270, 90);
        path.AddArc(bounds.Right - d, bounds.Bottom - d, d, d, 0, 90);
        path.AddArc(bounds.X, bounds.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }
}
"@

$script:ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:LocalFfmpeg = Join-Path $script:ProjectRoot "tools\ffmpeg\ffmpeg.exe"
$script:AppIconPath = Join-Path $script:ProjectRoot "assets\sanjiaozhou_luzhi.ico"
$script:CacheDir = Join-Path $env:LOCALAPPDATA "sanjiaozhou_luzhi\cache"
$script:OutputDir = Join-Path $env:USERPROFILE "Videos\sanjiaozhou_luzhi"

$script:FrameRate = 60
$script:VideoBitrate = "20M"
$script:SegmentSeconds = 4
$script:SegmentCount = 17
$script:Encoder = "h264_nvenc"
$script:RequestedPetId = $(if ([string]::IsNullOrWhiteSpace($PetId)) { "hatch-default" } else { $PetId })
$script:ExplicitPetPackagePath = $PetPackagePath
$script:HatchAtlasWidth = 1536
$script:HatchAtlasHeight = 1872
$script:HatchCellWidth = 192
$script:HatchCellHeight = 208
$script:HatchPetPackage = $null
$script:HatchSpritesheet = $null
$script:HatchSpritesheetTempPath = $null
$script:AppIcon = $null
$script:PetCollapsedWidth = 196
$script:PetCollapsedHeight = 184
$script:PetExpandedWidth = 338
$script:PetExpandedHeight = 590
$script:EdgePeekSize = 34
$script:EdgeSnapDistance = 18
$script:PetHiddenAtEdge = $false
$script:PetHiddenEdge = ""
$script:TencentGameModeEnabled = $false
$script:TencentDetectedGames = @()
$script:Language = $Language
$script:TencentGameProcessNames = @(
    "League of Legends",
    "LeagueClient",
    "LeagueClientUx",
    "LeagueClientUxRender",
    "LOLClient",
    "DNF",
    "DNFchina",
    "crossfire",
    "CF",
    "QQSpeed",
    "QQSpeedLauncher",
    "TGame"
)

$script:FfmpegProcess = $null
$script:Form = $null
$script:PetCanvas = $null
$script:Panel = $null
$script:StatusLabel = $null
$script:PetLabel = $null
$script:CacheLabel = $null
$script:OutputLabel = $null
$script:StartButton = $null
$script:StopButton = $null
$script:SaveButton = $null
$script:TencentModeButton = $null
$script:TencentModeLabel = $null
$script:LanguageButton = $null
$script:TitleLabel = $null
$script:HotkeyLabel = $null
$script:OpenButton = $null
$script:ClosePanelButton = $null
$script:LogBox = $null
$script:Timer = $null
$script:UiSmokeTimer = $null
$script:ContextMenu = $null
$script:PanelExpanded = $false
$script:Dragging = $false
$script:DragMoved = $false
$script:DragStartMouse = [System.Drawing.Point]::Empty
$script:DragStartForm = [System.Drawing.Point]::Empty
$script:UiSmokeTestSeconds = $UiSmokeTestSeconds
$script:AnimationTick = 0
$script:AnimationElapsedMs = 0
$script:LastProcessPoll = Get-Date

function Resolve-CodexHome {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        return $env:CODEX_HOME
    }

    return (Join-Path $env:USERPROFILE ".codex")
}

function Resolve-Ffmpeg {
    if (Test-Path $script:LocalFfmpeg) {
        return $script:LocalFfmpeg
    }

    $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        return $cmd.Source
    }

    throw "FFmpeg was not found. Put ffmpeg.exe at tools\ffmpeg\ffmpeg.exe."
}

function Load-AppIcon {
    if (-not (Test-Path $script:AppIconPath)) {
        return $null
    }

    try {
        return New-Object System.Drawing.Icon($script:AppIconPath)
    } catch {
        Write-Host "Failed to load app icon: $($_.Exception.Message)"
        return $null
    }
}

function New-HatchPetPackage {
    param(
        [string]$PackageDir,
        [string]$ManifestPath,
        [string]$SpritesheetPath,
        [string]$Id,
        [string]$DisplayName,
        [string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($Id)) {
        $Id = Split-Path -Leaf $PackageDir
    }
    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        $DisplayName = $Id
    }

    return [pscustomobject]@{
        PackageDir = $PackageDir
        ManifestPath = $ManifestPath
        SpritesheetPath = $SpritesheetPath
        Id = $Id
        DisplayName = $DisplayName
        Description = $Description
    }
}

function Resolve-HatchSpritesheetPath {
    param(
        [string]$PackageDir,
        [string]$SpritesheetPath
    )

    if ([string]::IsNullOrWhiteSpace($SpritesheetPath)) {
        $SpritesheetPath = "spritesheet.webp"
    }

    if ([System.IO.Path]::IsPathRooted($SpritesheetPath)) {
        return $SpritesheetPath
    }

    return (Join-Path $PackageDir $SpritesheetPath)
}

function Read-HatchPetManifest {
    param([string]$ManifestPath)

    if (-not (Test-Path $ManifestPath)) {
        return $null
    }

    try {
        $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $packageDir = Split-Path -Parent $ManifestPath
        $spritesheetPath = Resolve-HatchSpritesheetPath $packageDir $manifest.spritesheetPath

        if (-not (Test-Path $spritesheetPath)) {
            return $null
        }

        return New-HatchPetPackage `
            -PackageDir $packageDir `
            -ManifestPath $ManifestPath `
            -SpritesheetPath $spritesheetPath `
            -Id $manifest.id `
            -DisplayName $manifest.displayName `
            -Description $manifest.description
    } catch {
        Write-Host "Failed to read Hatch Pet manifest '$ManifestPath': $($_.Exception.Message)"
        return $null
    }
}

function Read-HatchPetDirectory {
    param([string]$PackageDir)

    if ([string]::IsNullOrWhiteSpace($PackageDir) -or -not (Test-Path $PackageDir)) {
        return $null
    }

    $resolvedDir = (Resolve-Path $PackageDir).Path
    $manifestPath = Join-Path $resolvedDir "pet.json"
    $package = Read-HatchPetManifest $manifestPath
    if ($null -ne $package) {
        return $package
    }

    $spritesheet = @(
        (Join-Path $resolvedDir "spritesheet.webp"),
        (Join-Path $resolvedDir "spritesheet.png")
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($null -eq $spritesheet) {
        return $null
    }

    return New-HatchPetPackage `
        -PackageDir $resolvedDir `
        -ManifestPath "" `
        -SpritesheetPath $spritesheet `
        -Id (Split-Path -Leaf $resolvedDir) `
        -DisplayName (Split-Path -Leaf $resolvedDir) `
        -Description ""
}

function Read-HatchPetPackagePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
        return $null
    }

    $resolvedPath = (Resolve-Path $Path).Path
    $item = Get-Item -LiteralPath $resolvedPath
    if ($item.PSIsContainer) {
        return Read-HatchPetDirectory $resolvedPath
    }

    if ([string]::Equals($item.Name, "pet.json", [System.StringComparison]::OrdinalIgnoreCase)) {
        return Read-HatchPetManifest $resolvedPath
    }

    return New-HatchPetPackage `
        -PackageDir (Split-Path -Parent $resolvedPath) `
        -ManifestPath "" `
        -SpritesheetPath $resolvedPath `
        -Id (Split-Path -Leaf (Split-Path -Parent $resolvedPath)) `
        -DisplayName (Split-Path -Leaf (Split-Path -Parent $resolvedPath)) `
        -Description ""
}

function Resolve-HatchPetPackage {
    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($script:ExplicitPetPackagePath)) {
        $candidates += $script:ExplicitPetPackagePath
    }

    $candidates += (Join-Path $script:ProjectRoot ("pets\" + $script:RequestedPetId))
    $candidates += (Join-Path (Resolve-CodexHome) ("pets\" + $script:RequestedPetId))

    foreach ($candidate in $candidates) {
        $package = Read-HatchPetPackagePath $candidate
        if ($null -ne $package) {
            return $package
        }
    }

    return $null
}

function Convert-HatchSpritesheetForGdi {
    param([string]$SpritesheetPath)

    $ffmpeg = Resolve-Ffmpeg
    $tempRoot = Join-Path $env:TEMP "sanjiaozhou_luzhi\hatch-pets"
    New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

    $hashProvider = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $hashProvider.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($SpritesheetPath))
    } finally {
        $hashProvider.Dispose()
    }
    $hash = ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").Substring(0, 12).ToLowerInvariant()
    $tempPath = Join-Path $tempRoot ("spritesheet-$hash.png")

    $args = Join-ProcessArguments @(
        "-hide_banner",
        "-y",
        "-i", $SpritesheetPath,
        "-frames:v", "1",
        $tempPath
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $ffmpeg
    $startInfo.Arguments = $args
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdOut = $process.StandardOutput.ReadToEnd()
    $stdErr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0 -or -not (Test-Path $tempPath)) {
        $process.Dispose()
        $detail = if (-not [string]::IsNullOrWhiteSpace($stdErr)) { ($stdErr.Trim() -split "`r?`n" | Select-Object -Last 1) } else { $stdOut.Trim() }
        throw "FFmpeg could not convert Hatch Pet spritesheet for display. $detail"
    }

    $process.Dispose()
    $script:HatchSpritesheetTempPath = $tempPath
    return $tempPath
}

function Open-HatchSpritesheetImage {
    param([string]$SpritesheetPath)

    try {
        $bytes = [System.IO.File]::ReadAllBytes($SpritesheetPath)
        $stream = New-Object System.IO.MemoryStream(,$bytes)
        $image = [System.Drawing.Image]::FromStream($stream)
        $bitmap = New-Object System.Drawing.Bitmap($image)
        $image.Dispose()
        $stream.Dispose()
        return $bitmap
    } catch {
        $convertedPath = Convert-HatchSpritesheetForGdi $SpritesheetPath
        $bytes = [System.IO.File]::ReadAllBytes($convertedPath)
        $stream = New-Object System.IO.MemoryStream(,$bytes)
        $image = [System.Drawing.Image]::FromStream($stream)
        $bitmap = New-Object System.Drawing.Bitmap($image)
        $image.Dispose()
        $stream.Dispose()
        return $bitmap
    }
}

function Load-HatchSpritesheet {
    $package = Resolve-HatchPetPackage
    if ($null -eq $package) {
        return $null
    }

    try {
        $bitmap = Open-HatchSpritesheetImage $package.SpritesheetPath
        if ($bitmap.Width -ne $script:HatchAtlasWidth -or $bitmap.Height -ne $script:HatchAtlasHeight) {
            $actual = "{0}x{1}" -f $bitmap.Width, $bitmap.Height
            $bitmap.Dispose()
            Write-Host "Hatch Pet spritesheet has size $actual; expected $script:HatchAtlasWidth x $script:HatchAtlasHeight."
            return $null
        }

        $script:HatchPetPackage = $package
        return $bitmap
    } catch {
        Write-Host "Failed to load Hatch Pet spritesheet: $($_.Exception.Message)"
        return $null
    }
}

function Join-ProcessArguments {
    param([object[]]$Items)

    $quoted = foreach ($item in $Items) {
        $value = [string]$item
        if ($value -match '[\s"]') {
            '"' + $value.Replace('"', '\"') + '"'
        } else {
            $value
        }
    }

    return ($quoted -join " ")
}

function Test-IsRecording {
    return ($null -ne $script:FfmpegProcess -and -not $script:FfmpegProcess.HasExited)
}

function Add-Log {
    param([string]$Message)

    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    if ($null -ne $script:LogBox) {
        $script:LogBox.AppendText($line + [Environment]::NewLine)
    } else {
        Write-Host $line
    }
}

function T {
    param(
        [string]$Key,
        [hashtable]$Values = @{}
    )

    $texts = @{
        "app.title" = @{"zh-CN" = "sanjiaozhou_luzhi"; "en-US" = "sanjiaozhou_luzhi"}
        "status.tencentDetected" = @{"zh-CN" = "检测到腾讯游戏"; "en-US" = "Tencent game detected"}
        "status.recording" = @{"zh-CN" = "录制中"; "en-US" = "Recording"}
        "status.idle" = @{"zh-CN" = "空闲"; "en-US" = "Idle"}
        "cache.ready" = @{"zh-CN" = "就绪"; "en-US" = "ready"}
        "cache.cached" = @{"zh-CN" = "{seconds} 秒缓存"; "en-US" = "{seconds}s cached"}
        "cache.detail" = @{"zh-CN" = "{count} 个片段，约 {seconds} 秒缓存"; "en-US" = "{count} segment(s), about {seconds}s cached"}
        "pet.loaded" = @{"zh-CN" = "桌宠：{name} ({id})"; "en-US" = "Pet: {name} ({id})"}
        "pet.missing" = @{"zh-CN" = "桌宠：缺少 Hatch 包"; "en-US" = "Pet: missing Hatch package"}
        "pet.loading" = @{"zh-CN" = "桌宠：加载中"; "en-US" = "Pet: loading"}
        "pet.missingCanvas" = @{"zh-CN" = "缺少 Hatch 桌宠"; "en-US" = "Hatch pet missing"}
        "panel.title" = @{"zh-CN" = "Hatch 回放控制"; "en-US" = "Hatch Replay controls"}
        "panel.close" = @{"zh-CN" = "x"; "en-US" = "x"}
        "hotkeys" = @{"zh-CN" = "Alt+F9 开关缓存  |  Alt+F10 保存"; "en-US" = "Alt+F9 toggle cache  |  Alt+F10 save"}
        "button.start" = @{"zh-CN" = "开始"; "en-US" = "Start"}
        "button.save" = @{"zh-CN" = "保存"; "en-US" = "Save"}
        "button.stop" = @{"zh-CN" = "停止"; "en-US" = "Stop"}
        "button.openOutput" = @{"zh-CN" = "打开输出文件夹"; "en-US" = "Open output folder"}
        "button.tencentMode" = @{"zh-CN" = "腾讯游戏模式"; "en-US" = "Tencent mode"}
        "button.tencentModeOn" = @{"zh-CN" = "腾讯模式已开"; "en-US" = "Tencent mode on"}
        "button.language.zh" = @{"zh-CN" = "中文"; "en-US" = "中文"}
        "button.language.en" = @{"zh-CN" = "EN"; "en-US" = "EN"}
        "tencent.off" = @{"zh-CN" = "腾讯游戏模式：关闭"; "en-US" = "Tencent mode: off"}
        "tencent.detected" = @{"zh-CN" = "腾讯游戏：{names}"; "en-US" = "Tencent game: {names}"}
        "tencent.watching" = @{"zh-CN" = "腾讯游戏模式：检测本机进程"; "en-US" = "Tencent mode: watching local processes"}
        "menu.startCache" = @{"zh-CN" = "开始缓存"; "en-US" = "Start cache"}
        "menu.stopCache" = @{"zh-CN" = "停止缓存"; "en-US" = "Stop cache"}
        "menu.saveReplay" = @{"zh-CN" = "保存回放"; "en-US" = "Save replay"}
        "menu.showControls" = @{"zh-CN" = "显示控制面板"; "en-US" = "Show controls"}
        "menu.hideControls" = @{"zh-CN" = "隐藏控制面板"; "en-US" = "Hide controls"}
        "menu.hideEdge" = @{"zh-CN" = "隐藏到屏幕边缘"; "en-US" = "Hide to screen edge"}
        "menu.showPet" = @{"zh-CN" = "显示桌宠"; "en-US" = "Show pet"}
        "menu.enableTencent" = @{"zh-CN" = "开启腾讯游戏模式"; "en-US" = "Enable Tencent mode"}
        "menu.disableTencent" = @{"zh-CN" = "关闭腾讯游戏模式"; "en-US" = "Disable Tencent mode"}
        "menu.language" = @{"zh-CN" = "语言：中文"; "en-US" = "Language: English"}
        "menu.openOutput" = @{"zh-CN" = "打开输出目录"; "en-US" = "Open output"}
        "menu.exit" = @{"zh-CN" = "退出"; "en-US" = "Exit"}
        "log.tencentOn" = @{"zh-CN" = "腾讯游戏模式已开启。仅检测本机进程，不收集 QQ 凭据。"; "en-US" = "Tencent game mode enabled. Local process detection only; no QQ credentials are collected."}
        "log.tencentOff" = @{"zh-CN" = "腾讯游戏模式已关闭。"; "en-US" = "Tencent game mode disabled."}
        "log.ready" = @{"zh-CN" = "控制器已就绪。"; "en-US" = "Controller ready."}
        "log.loadedPet" = @{"zh-CN" = "已加载 Hatch 桌宠：{name}。"; "en-US" = "Loaded Hatch Pet: {name}."}
        "log.missingPet" = @{"zh-CN" = "未找到 Hatch 桌宠包：{id}。"; "en-US" = "No Hatch Pet package found for '{id}'."}
        "log.uiSmoke" = @{"zh-CN" = "UI 烟测将自动关闭。"; "en-US" = "UI smoke test will close automatically."}
        "log.hotkeysOk" = @{"zh-CN" = "全局快捷键已注册。"; "en-US" = "Global hotkeys registered."}
        "log.hotkeysFail" = @{"zh-CN" = "一个或多个快捷键注册失败，按钮仍可使用。"; "en-US" = "Could not register one or more hotkeys. Buttons still work."}
        "log.cacheAlreadyRunning" = @{"zh-CN" = "回放缓存已在运行。"; "en-US" = "Replay cache is already running."}
        "log.cacheStarted" = @{"zh-CN" = "已启动回放缓存：{encoder}，{fps} FPS，{bitrate}。"; "en-US" = "Started replay cache with {encoder}, {fps} FPS, {bitrate}."}
        "log.cacheNotRunning" = @{"zh-CN" = "回放缓存未运行。"; "en-US" = "Replay cache is not running."}
        "log.cacheStopping" = @{"zh-CN" = "正在停止回放缓存..."; "en-US" = "Stopping replay cache..."}
        "log.cacheStopped" = @{"zh-CN" = "回放缓存已停止。"; "en-US" = "Replay cache stopped."}
        "log.savePause" = @{"zh-CN" = "暂停缓存以整理回放片段。"; "en-US" = "Pausing cache to finalize replay segments."}
        "log.noSegments" = @{"zh-CN" = "没有可保存的回放缓存片段。"; "en-US" = "No replay cache segments are available."}
        "log.savingReplay" = @{"zh-CN" = "正在保存 {count} 个片段的回放..."; "en-US" = "Saving replay from {count} segment(s)..."}
        "log.replaySaved" = @{"zh-CN" = "回放已保存：{path}"; "en-US" = "Replay saved: {path}"}
        "log.replaySaveFailed" = @{"zh-CN" = "回放保存失败。退出码：{code}"; "en-US" = "Replay save failed. Exit code: {code}"}
        "log.ffmpegExited" = @{"zh-CN" = "FFmpeg 已退出，退出码 {code}。"; "en-US" = "FFmpeg exited with code {code}."}
    }

    if (-not $texts.ContainsKey($Key)) {
        return $Key
    }

    $language = if ($texts[$Key].ContainsKey($script:Language)) { $script:Language } else { "en-US" }
    $text = [string]$texts[$Key][$language]
    foreach ($item in $Values.GetEnumerator()) {
        $text = $text.Replace("{" + $item.Key + "}", [string]$item.Value)
    }
    return $text
}

function Toggle-Language {
    $script:Language = $(if ($script:Language -eq "zh-CN") { "en-US" } else { "zh-CN" })
    Apply-Language
    Update-UiState
}

function Apply-Language {
    if ($null -ne $script:Form) {
        $script:Form.Text = T "app.title"
    }
    if ($null -ne $script:TitleLabel) {
        $script:TitleLabel.Text = T "panel.title"
    }
    if ($null -ne $script:ClosePanelButton) {
        $script:ClosePanelButton.Text = T "panel.close"
    }
    if ($null -ne $script:HotkeyLabel) {
        $script:HotkeyLabel.Text = T "hotkeys"
    }
    if ($null -ne $script:StartButton) {
        $script:StartButton.Text = T "button.start"
    }
    if ($null -ne $script:SaveButton) {
        $script:SaveButton.Text = T "button.save"
    }
    if ($null -ne $script:StopButton) {
        $script:StopButton.Text = T "button.stop"
    }
    if ($null -ne $script:OpenButton) {
        $script:OpenButton.Text = T "button.openOutput"
    }
    if ($null -ne $script:LanguageButton) {
        $script:LanguageButton.Text = $(if ($script:Language -eq "zh-CN") { T "button.language.en" } else { T "button.language.zh" })
    }
    if ($null -ne $script:ContextMenu) {
        $script:ContextMenu.Items["save"].Text = T "menu.saveReplay"
        $script:ContextMenu.Items["open"].Text = T "menu.openOutput"
        $script:ContextMenu.Items["exit"].Text = T "menu.exit"
        $script:ContextMenu.Items["language"].Text = T "menu.language"
    }
}

function Get-CacheSegments {
    if (-not (Test-Path $script:CacheDir)) {
        return @()
    }

    return @(Get-ChildItem -Path $script:CacheDir -Filter "cache_*.ts" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime)
}

function Get-TencentGameProcesses {
    $nameSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $script:TencentGameProcessNames) {
        [void]$nameSet.Add($name)
    }

    $matches = @()
    foreach ($process in @(Get-Process -ErrorAction SilentlyContinue)) {
        if ($nameSet.Contains($process.ProcessName)) {
            $matches += $process
        }
    }

    return @($matches | Sort-Object ProcessName -Unique)
}

function Update-TencentGameMode {
    if (-not $script:TencentGameModeEnabled) {
        $script:TencentDetectedGames = @()
        return
    }

    $script:TencentDetectedGames = @(Get-TencentGameProcesses)
}

function Toggle-TencentGameMode {
    $script:TencentGameModeEnabled = -not $script:TencentGameModeEnabled
    if ($script:TencentGameModeEnabled) {
        Add-Log (T "log.tencentOn")
    } else {
        Add-Log (T "log.tencentOff")
        $script:TencentDetectedGames = @()
    }
    Update-UiState
}

function Update-UiState {
    if ($null -eq $script:Form) {
        return
    }

    Update-TencentGameMode
    $isRecording = Test-IsRecording
    $segments = Get-CacheSegments
    $cacheSeconds = [Math]::Min($segments.Count * $script:SegmentSeconds, $script:SegmentCount * $script:SegmentSeconds)
    $hasTencentGame = $script:TencentGameModeEnabled -and $script:TencentDetectedGames.Count -gt 0

    if ($null -ne $script:PetCanvas) {
        $script:PetCanvas.IsRecording = $isRecording
        $script:PetCanvas.PanelExpanded = $script:PanelExpanded
        $script:PetCanvas.CacheSeconds = $cacheSeconds
        $script:PetCanvas.AnimationTick = $script:AnimationTick
        $script:PetCanvas.AnimationElapsedMs = $script:AnimationElapsedMs
        $script:PetCanvas.HatchState = $(if ($hasTencentGame) { "waiting" } elseif ($isRecording) { "running" } else { "idle" })
        $script:PetCanvas.HatchPetDisplayName = $(if ($null -ne $script:HatchPetPackage) { $script:HatchPetPackage.DisplayName } else { "Hatch pet" })
        $script:PetCanvas.ReadyText = T "cache.ready"
        $script:PetCanvas.CachedTextFormat = $(if ($script:Language -eq "zh-CN") { "{0} 秒缓存" } else { "{0}s cached" })
        $script:PetCanvas.MissingPetText = T "pet.missingCanvas"
        $script:PetCanvas.Invalidate()
    }

    if ($null -ne $script:StatusLabel) {
        if ($hasTencentGame) {
            $script:StatusLabel.Text = T "status.tencentDetected"
            $script:StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(189, 96, 31)
        } elseif ($isRecording) {
            $script:StatusLabel.Text = T "status.recording"
            $script:StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(31, 134, 86)
        } else {
            $script:StatusLabel.Text = T "status.idle"
            $script:StatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(174, 55, 55)
        }
    }

    if ($null -ne $script:CacheLabel) {
        $script:CacheLabel.Text = T "cache.detail" @{count = $segments.Count; seconds = $cacheSeconds}
    }

    if ($null -ne $script:PetLabel) {
        if ($null -ne $script:HatchPetPackage) {
            $script:PetLabel.Text = T "pet.loaded" @{name = $script:HatchPetPackage.DisplayName; id = $script:HatchPetPackage.Id}
            $script:PetLabel.ForeColor = [System.Drawing.Color]::FromArgb(92, 104, 128)
        } else {
            $script:PetLabel.Text = T "pet.missing"
            $script:PetLabel.ForeColor = [System.Drawing.Color]::FromArgb(174, 55, 55)
        }
    }

    if ($null -ne $script:OutputLabel) {
        $script:OutputLabel.Text = $script:OutputDir
    }

    if ($null -ne $script:TencentModeLabel) {
        if (-not $script:TencentGameModeEnabled) {
            $script:TencentModeLabel.Text = T "tencent.off"
            $script:TencentModeLabel.ForeColor = [System.Drawing.Color]::FromArgb(92, 104, 128)
        } elseif ($hasTencentGame) {
            $names = ($script:TencentDetectedGames | Select-Object -ExpandProperty ProcessName) -join ", "
            $script:TencentModeLabel.Text = T "tencent.detected" @{names = $names}
            $script:TencentModeLabel.ForeColor = [System.Drawing.Color]::FromArgb(189, 96, 31)
        } else {
            $script:TencentModeLabel.Text = T "tencent.watching"
            $script:TencentModeLabel.ForeColor = [System.Drawing.Color]::FromArgb(31, 134, 86)
        }
    }

    if ($null -ne $script:StartButton) {
        $script:StartButton.Enabled = -not $isRecording
    }
    if ($null -ne $script:StopButton) {
        $script:StopButton.Enabled = $isRecording
    }
    if ($null -ne $script:SaveButton) {
        $script:SaveButton.Enabled = ($segments.Count -gt 0)
    }
    if ($null -ne $script:TencentModeButton) {
        $script:TencentModeButton.Text = $(if ($script:TencentGameModeEnabled) { T "button.tencentModeOn" } else { T "button.tencentMode" })
        $script:TencentModeButton.BackColor = $(if ($script:TencentGameModeEnabled) { [System.Drawing.Color]::FromArgb(234, 146, 77) } else { [System.Drawing.Color]::FromArgb(236, 242, 250) })
        $script:TencentModeButton.ForeColor = $(if ($script:TencentGameModeEnabled) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::FromArgb(44, 68, 98) })
    }

    if ($null -ne $script:ContextMenu) {
        $script:ContextMenu.Items["toggle"].Text = $(if ($isRecording) { T "menu.stopCache" } else { T "menu.startCache" })
        $script:ContextMenu.Items["save"].Enabled = ($segments.Count -gt 0)
        $script:ContextMenu.Items["panel"].Text = $(if ($script:PanelExpanded) { T "menu.hideControls" } else { T "menu.showControls" })
        $script:ContextMenu.Items["edge"].Text = $(if ($script:PetHiddenAtEdge) { T "menu.showPet" } else { T "menu.hideEdge" })
        $script:ContextMenu.Items["tencent"].Text = $(if ($script:TencentGameModeEnabled) { T "menu.disableTencent" } else { T "menu.enableTencent" })
        $script:ContextMenu.Items["language"].Text = T "menu.language"
    }
}

function Clear-Cache {
    New-Item -ItemType Directory -Force -Path $script:CacheDir | Out-Null

    $resolvedCache = (Resolve-Path $script:CacheDir).Path
    $expectedRoot = Join-Path $env:LOCALAPPDATA "sanjiaozhou_luzhi\cache"
    $resolvedExpected = (Resolve-Path $expectedRoot).Path

    if ($resolvedCache -ne $resolvedExpected) {
        throw "Unexpected cache path: $resolvedCache"
    }

    Get-ChildItem -Path $script:CacheDir -Filter "cache_*.ts" -ErrorAction SilentlyContinue | Remove-Item -Force
    $concatList = Join-Path $script:CacheDir "concat-list.txt"
    if (Test-Path $concatList) {
        Remove-Item -Force $concatList
    }
}

function Start-ReplayCache {
    if (Test-IsRecording) {
        Add-Log (T "log.cacheAlreadyRunning")
        return
    }

    $ffmpeg = Resolve-Ffmpeg
    New-Item -ItemType Directory -Force -Path $script:OutputDir | Out-Null
    Clear-Cache

    $outputPattern = Join-Path $script:CacheDir "cache_%03d.ts"
    $keyframeInterval = $script:FrameRate * 2

    $args = Join-ProcessArguments @(
        "-hide_banner",
        "-y",
        "-f", "gdigrab",
        "-framerate", $script:FrameRate,
        "-i", "desktop",
        "-c:v", $script:Encoder,
        "-preset", "p5",
        "-rc", "vbr",
        "-b:v", $script:VideoBitrate,
        "-g", $keyframeInterval,
        "-an",
        "-f", "segment",
        "-segment_time", $script:SegmentSeconds,
        "-segment_wrap", $script:SegmentCount,
        "-reset_timestamps", "1",
        $outputPattern
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $ffmpeg
    $startInfo.Arguments = $args
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $false
    $startInfo.RedirectStandardError = $false
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    if (-not $process.Start()) {
        throw "Failed to start FFmpeg."
    }

    $script:FfmpegProcess = $process
    Add-Log (T "log.cacheStarted" @{encoder = $script:Encoder; fps = $script:FrameRate; bitrate = $script:VideoBitrate})
    Update-UiState
}

function Stop-ReplayCache {
    if (-not (Test-IsRecording)) {
        Add-Log (T "log.cacheNotRunning")
        $script:FfmpegProcess = $null
        Update-UiState
        return
    }

    Add-Log (T "log.cacheStopping")

    try {
        $script:FfmpegProcess.StandardInput.WriteLine("q")
        $script:FfmpegProcess.StandardInput.Flush()
    } catch {
        Add-Log "Could not send graceful stop, forcing exit if needed."
    }

    if (-not $script:FfmpegProcess.WaitForExit(5000)) {
        try {
            $script:FfmpegProcess.Kill()
        } catch {
            Add-Log "Failed to force-stop FFmpeg: $($_.Exception.Message)"
        }
    }

    try {
        $script:FfmpegProcess.Dispose()
    } catch {
    }

    $script:FfmpegProcess = $null
    Add-Log (T "log.cacheStopped")
    Update-UiState
}

function Save-Replay {
    $ffmpeg = Resolve-Ffmpeg
    New-Item -ItemType Directory -Force -Path $script:OutputDir | Out-Null
    New-Item -ItemType Directory -Force -Path $script:CacheDir | Out-Null

    $restartAfterSave = Test-IsRecording
    if ($restartAfterSave) {
        Add-Log (T "log.savePause")
        Stop-ReplayCache
    }

    try {
        $segments = @(Get-CacheSegments | Select-Object -Last $script:SegmentCount)
        if ($segments.Count -eq 0) {
            Add-Log (T "log.noSegments")
            Update-UiState
            return
        }

        $listPath = Join-Path $script:CacheDir "concat-list.txt"
        $segments | ForEach-Object {
            $safePath = $_.FullName.Replace("'", "''")
            "file '$safePath'"
        } | Set-Content -Encoding ASCII -Path $listPath

        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $outputPath = Join-Path $script:OutputDir "Replay_$timestamp.mp4"

        Add-Log (T "log.savingReplay" @{count = $segments.Count})

        $args = Join-ProcessArguments @(
            "-hide_banner",
            "-y",
            "-f", "concat",
            "-safe", "0",
            "-i", $listPath,
            "-c", "copy",
            $outputPath
        )

        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $ffmpeg
        $startInfo.Arguments = $args
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        [void]$process.Start()
        $stdOut = $process.StandardOutput.ReadToEnd()
        $stdErr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        if ($process.ExitCode -eq 0 -and (Test-Path $outputPath)) {
            Add-Log (T "log.replaySaved" @{path = $outputPath})
        } else {
            Add-Log (T "log.replaySaveFailed" @{code = $process.ExitCode})
            if (-not [string]::IsNullOrWhiteSpace($stdErr)) {
                Add-Log ($stdErr.Trim() -split "`r?`n" | Select-Object -Last 1)
            } elseif (-not [string]::IsNullOrWhiteSpace($stdOut)) {
                Add-Log ($stdOut.Trim() -split "`r?`n" | Select-Object -Last 1)
            }
        }

        $process.Dispose()
        Update-UiState
    } finally {
        if ($restartAfterSave) {
            Start-ReplayCache
        }
    }
}

function Open-OutputFolder {
    New-Item -ItemType Directory -Force -Path $script:OutputDir | Out-Null
    Start-Process explorer.exe $script:OutputDir
}

function Toggle-ReplayCache {
    if (Test-IsRecording) {
        Stop-ReplayCache
    } else {
        Start-ReplayCache
    }
}

function New-Label {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 420,
        [int]$Height = 24
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $label.AutoEllipsis = $true
    return $label
}

function New-Button {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 130,
        [int]$Height = 36
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    return $button
}

function Set-PanelExpanded {
    param([bool]$Expanded)

    if ($Expanded -and $script:PetHiddenAtEdge) {
        Show-PetFromEdge
    }

    $script:PanelExpanded = $Expanded
    if ($null -eq $script:Form -or $null -eq $script:Panel) {
        return
    }

    if ($Expanded) {
        $script:Panel.Visible = $true
        $script:Form.Size = New-Object System.Drawing.Size($script:PetExpandedWidth, $script:PetExpandedHeight)
    } else {
        $script:Panel.Visible = $false
        $script:Form.Size = New-Object System.Drawing.Size($script:PetCollapsedWidth, $script:PetCollapsedHeight)
    }

    Update-UiState
}

function Toggle-Panel {
    Set-PanelExpanded (-not $script:PanelExpanded)
}

function Get-CurrentWorkingArea {
    if ($null -ne $script:Form) {
        return [System.Windows.Forms.Screen]::FromControl($script:Form).WorkingArea
    }

    return [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
}

function Show-PetFromEdge {
    if ($null -eq $script:Form -or -not $script:PetHiddenAtEdge) {
        return
    }

    $area = Get-CurrentWorkingArea
    $x = $script:Form.Location.X
    $y = $script:Form.Location.Y

    switch ($script:PetHiddenEdge) {
        "left" { $x = $area.Left + 4 }
        "right" { $x = $area.Right - $script:Form.Width - 4 }
        "top" { $y = $area.Top + 4 }
        "bottom" { $y = $area.Bottom - $script:Form.Height - 4 }
    }

    $x = [Math]::Max($area.Left, [Math]::Min($area.Right - $script:Form.Width, $x))
    $y = [Math]::Max($area.Top, [Math]::Min($area.Bottom - $script:Form.Height, $y))
    $script:Form.Location = New-Object System.Drawing.Point($x, $y)
    $script:PetHiddenAtEdge = $false
    $script:PetHiddenEdge = ""
    Update-UiState
}

function Hide-PetToEdge {
    param([string]$Edge = "")

    if ($null -eq $script:Form) {
        return
    }

    Set-PanelExpanded $false
    $area = Get-CurrentWorkingArea
    $current = $script:Form.Location
    $distances = @{
        left = [Math]::Abs($current.X - $area.Left)
        right = [Math]::Abs(($area.Right - ($current.X + $script:Form.Width)))
        top = [Math]::Abs($current.Y - $area.Top)
        bottom = [Math]::Abs(($area.Bottom - ($current.Y + $script:Form.Height)))
    }

    if ([string]::IsNullOrWhiteSpace($Edge)) {
        $Edge = ($distances.GetEnumerator() | Sort-Object Value | Select-Object -First 1).Key
    }

    $x = $current.X
    $y = $current.Y
    switch ($Edge) {
        "left" { $x = $area.Left - $script:Form.Width + $script:EdgePeekSize }
        "right" { $x = $area.Right - $script:EdgePeekSize }
        "top" { $y = $area.Top - $script:Form.Height + $script:EdgePeekSize }
        "bottom" { $y = $area.Bottom - $script:EdgePeekSize }
        default { return }
    }

    if ($Edge -eq "left" -or $Edge -eq "right") {
        $y = [Math]::Max($area.Top, [Math]::Min($area.Bottom - $script:Form.Height, $y))
    } else {
        $x = [Math]::Max($area.Left, [Math]::Min($area.Right - $script:Form.Width, $x))
    }

    $script:Form.Location = New-Object System.Drawing.Point($x, $y)
    $script:PetHiddenAtEdge = $true
    $script:PetHiddenEdge = $Edge
    Update-UiState
}

function Toggle-PetEdgeHidden {
    if ($script:PetHiddenAtEdge) {
        Show-PetFromEdge
    } else {
        Hide-PetToEdge
    }
}

function Snap-Or-Hide-PetNearEdge {
    if ($null -eq $script:Form -or $script:PanelExpanded) {
        return
    }

    $area = Get-CurrentWorkingArea
    $location = $script:Form.Location
    if (($location.X - $area.Left) -le $script:EdgeSnapDistance) {
        Hide-PetToEdge "left"
    } elseif (($area.Right - ($location.X + $script:Form.Width)) -le $script:EdgeSnapDistance) {
        Hide-PetToEdge "right"
    } elseif (($location.Y - $area.Top) -le $script:EdgeSnapDistance) {
        Hide-PetToEdge "top"
    } elseif (($area.Bottom - ($location.Y + $script:Form.Height)) -le $script:EdgeSnapDistance) {
        Hide-PetToEdge "bottom"
    }
}

function New-PetButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 136,
        [int]$Height = 34,
        [System.Drawing.Color]$BackColor = [System.Drawing.Color]::FromArgb(47, 92, 196),
        [System.Drawing.Color]$ForeColor = [System.Drawing.Color]::White
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    $button.FlatStyle = "Flat"
    $button.FlatAppearance.BorderSize = 0
    $button.BackColor = $BackColor
    $button.ForeColor = $ForeColor
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    return $button
}

function New-PetInfoLabel {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 284,
        [int]$Height = 20,
        [bool]$Bold = $false
    )

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, $Height)
    $label.AutoEllipsis = $true
    $style = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 9, $style)
    $label.ForeColor = [System.Drawing.Color]::FromArgb(34, 42, 62)
    return $label
}

function New-PetContextMenu {
    $menu = New-Object System.Windows.Forms.ContextMenuStrip

    $toggleItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $toggleItem.Name = "toggle"
    $toggleItem.Text = T "menu.startCache"
    $toggleItem.Add_Click({ Toggle-ReplayCache })
    [void]$menu.Items.Add($toggleItem)

    $saveItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $saveItem.Name = "save"
    $saveItem.Text = T "menu.saveReplay"
    $saveItem.Add_Click({ Save-Replay })
    [void]$menu.Items.Add($saveItem)

    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $panelItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $panelItem.Name = "panel"
    $panelItem.Text = T "menu.showControls"
    $panelItem.Add_Click({ Toggle-Panel })
    [void]$menu.Items.Add($panelItem)

    $edgeItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $edgeItem.Name = "edge"
    $edgeItem.Text = T "menu.hideEdge"
    $edgeItem.Add_Click({ Toggle-PetEdgeHidden })
    [void]$menu.Items.Add($edgeItem)

    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $tencentItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $tencentItem.Name = "tencent"
    $tencentItem.Text = T "menu.enableTencent"
    $tencentItem.Add_Click({ Toggle-TencentGameMode })
    [void]$menu.Items.Add($tencentItem)

    $languageItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $languageItem.Name = "language"
    $languageItem.Text = T "menu.language"
    $languageItem.Add_Click({ Toggle-Language })
    [void]$menu.Items.Add($languageItem)

    $openItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $openItem.Name = "open"
    $openItem.Text = T "menu.openOutput"
    $openItem.Add_Click({ Open-OutputFolder })
    [void]$menu.Items.Add($openItem)

    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $exitItem.Name = "exit"
    $exitItem.Text = T "menu.exit"
    $exitItem.Add_Click({ $script:Form.Close() })
    [void]$menu.Items.Add($exitItem)

    return $menu
}

function Start-PetDrag {
    param([System.Windows.Forms.MouseEventArgs]$EventArgs)

    if ($EventArgs.Button -ne [System.Windows.Forms.MouseButtons]::Left) {
        return
    }

    if ($script:PetHiddenAtEdge) {
        Show-PetFromEdge
    }

    $script:Dragging = $true
    $script:DragMoved = $false
    $script:DragStartMouse = [System.Windows.Forms.Control]::MousePosition
    $script:DragStartForm = $script:Form.Location
}

function Move-PetDrag {
    if (-not $script:Dragging) {
        return
    }

    $current = [System.Windows.Forms.Control]::MousePosition
    $dx = $current.X - $script:DragStartMouse.X
    $dy = $current.Y - $script:DragStartMouse.Y
    if ([Math]::Abs($dx) -gt 4 -or [Math]::Abs($dy) -gt 4) {
        $script:DragMoved = $true
    }
    $script:Form.Location = New-Object System.Drawing.Point(($script:DragStartForm.X + $dx), ($script:DragStartForm.Y + $dy))
}

function Stop-PetDrag {
    $script:Dragging = $false
    if ($script:DragMoved) {
        Snap-Or-Hide-PetNearEdge
    }
}

if ($SelfTest) {
    $ffmpeg = Resolve-Ffmpeg
    $petPackage = Resolve-HatchPetPackage
    Write-Host "Controller self-test passed."
    Write-Host "FFmpeg: $ffmpeg"
    Write-Host "Cache: $script:CacheDir"
    Write-Host "Output: $script:OutputDir"
    if ($null -ne $petPackage) {
        Write-Host "Hatch Pet: $($petPackage.DisplayName) [$($petPackage.Id)]"
        Write-Host "Hatch Pet spritesheet: $($petPackage.SpritesheetPath)"
    } else {
        Write-Host "Hatch Pet: missing"
    }
    exit 0
}

if ($SmokeTest) {
    $script:FrameRate = 30
    $script:VideoBitrate = "8M"
    $script:SegmentSeconds = 2
    $script:SegmentCount = 5

    Write-Host "Controller smoke test started."
    Start-ReplayCache
    Start-Sleep -Seconds $SmokeTestSeconds
    Save-Replay
    Stop-ReplayCache
    Write-Host "Controller smoke test finished."
    exit 0
}

$script:HatchSpritesheet = Load-HatchSpritesheet
$script:AppIcon = Load-AppIcon

$script:Form = New-Object ReplayHotkeyForm
$script:Form.Text = T "app.title"
$script:Form.Size = New-Object System.Drawing.Size($script:PetCollapsedWidth, $script:PetCollapsedHeight)
$script:Form.StartPosition = "Manual"
$script:Form.FormBorderStyle = "None"
$script:Form.MaximizeBox = $false
$script:Form.MinimizeBox = $false
$script:Form.ShowInTaskbar = $true
$script:Form.TopMost = $true
if ($null -ne $script:AppIcon) {
    $script:Form.Icon = $script:AppIcon
}
$transparentKey = [System.Drawing.Color]::FromArgb(255, 0, 254)
$script:Form.BackColor = $transparentKey
$script:Form.TransparencyKey = $transparentKey
$script:Form.Padding = New-Object System.Windows.Forms.Padding(0)

$workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$script:Form.Location = New-Object System.Drawing.Point(($workingArea.Right - $script:PetCollapsedWidth - 22), ($workingArea.Bottom - $script:PetCollapsedHeight - 42))

$script:ContextMenu = New-PetContextMenu
$script:Form.ContextMenuStrip = $script:ContextMenu

$script:PetCanvas = New-Object CuteReplayPetCanvas
$script:PetCanvas.Location = New-Object System.Drawing.Point(0, 0)
$script:PetCanvas.Size = New-Object System.Drawing.Size($script:PetCollapsedWidth, $script:PetCollapsedHeight)
$script:PetCanvas.BackColor = $transparentKey
$script:PetCanvas.HatchSpritesheet = $script:HatchSpritesheet
$script:PetCanvas.HasHatchPet = ($null -ne $script:HatchSpritesheet)
$script:PetCanvas.UsePixelScaling = $false
$script:PetCanvas.HatchPetDisplayName = $(if ($null -ne $script:HatchPetPackage) { $script:HatchPetPackage.DisplayName } else { "Hatch pet" })
$script:PetCanvas.ContextMenuStrip = $script:ContextMenu
$script:PetCanvas.Add_MouseDown({ param($sender, $eventArgs) Start-PetDrag $eventArgs })
$script:PetCanvas.Add_MouseMove({ Move-PetDrag })
$script:PetCanvas.Add_MouseUp({ Stop-PetDrag })
$script:PetCanvas.Add_Click({
    if ($script:PetHiddenAtEdge) {
        Show-PetFromEdge
    } elseif (-not $script:DragMoved) {
        Toggle-Panel
    }
    $script:DragMoved = $false
})
$script:Form.Controls.Add($script:PetCanvas)

$script:Panel = New-Object System.Windows.Forms.Panel
$script:Panel.Location = New-Object System.Drawing.Point(12, ($script:PetCollapsedHeight - 6))
$script:Panel.Size = New-Object System.Drawing.Size(314, 378)
$script:Panel.BackColor = [System.Drawing.Color]::FromArgb(255, 253, 250)
$script:Panel.Visible = $false
$script:Panel.ContextMenuStrip = $script:ContextMenu
$script:Form.Controls.Add($script:Panel)

$script:TitleLabel = New-PetInfoLabel (T "panel.title") 14 12 184 24 $true
$script:TitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$script:Panel.Controls.Add($script:TitleLabel)

$script:LanguageButton = New-PetButton (T "button.language.en") 206 12 52 28 ([System.Drawing.Color]::FromArgb(236, 242, 250)) ([System.Drawing.Color]::FromArgb(44, 68, 98))
$script:LanguageButton.Add_Click({ Toggle-Language })
$script:Panel.Controls.Add($script:LanguageButton)

$script:ClosePanelButton = New-PetButton (T "panel.close") 272 12 28 28 ([System.Drawing.Color]::FromArgb(250, 232, 236)) ([System.Drawing.Color]::FromArgb(114, 70, 82))
$script:ClosePanelButton.Add_Click({ Set-PanelExpanded $false })
$script:Panel.Controls.Add($script:ClosePanelButton)

$script:StatusLabel = New-PetInfoLabel (T "status.idle") 14 44 160 22 $true
$script:Panel.Controls.Add($script:StatusLabel)

$script:HotkeyLabel = New-PetInfoLabel (T "hotkeys") 14 68 278 20
$script:HotkeyLabel.ForeColor = [System.Drawing.Color]::FromArgb(92, 104, 128)
$script:Panel.Controls.Add($script:HotkeyLabel)

$script:PetLabel = New-PetInfoLabel (T "pet.loading") 14 94 278 20
$script:Panel.Controls.Add($script:PetLabel)

$script:CacheLabel = New-PetInfoLabel (T "cache.detail" @{count = 0; seconds = 0}) 14 118 278 20
$script:Panel.Controls.Add($script:CacheLabel)

$script:OutputLabel = New-PetInfoLabel $script:OutputDir 14 142 292 20
$script:OutputLabel.ForeColor = [System.Drawing.Color]::FromArgb(92, 104, 128)
$script:Panel.Controls.Add($script:OutputLabel)

$script:StartButton = New-PetButton (T "button.start") 14 172 92 38 ([System.Drawing.Color]::FromArgb(78, 166, 117)) ([System.Drawing.Color]::White)
$script:StartButton.Add_Click({ Start-ReplayCache })
$script:Panel.Controls.Add($script:StartButton)

$script:SaveButton = New-PetButton (T "button.save") 112 172 92 38 ([System.Drawing.Color]::FromArgb(113, 139, 230)) ([System.Drawing.Color]::White)
$script:SaveButton.Add_Click({ Save-Replay })
$script:Panel.Controls.Add($script:SaveButton)

$script:StopButton = New-PetButton (T "button.stop") 210 172 92 38 ([System.Drawing.Color]::FromArgb(228, 101, 120)) ([System.Drawing.Color]::White)
$script:StopButton.Add_Click({ Stop-ReplayCache })
$script:Panel.Controls.Add($script:StopButton)

$script:OpenButton = New-PetButton (T "button.openOutput") 14 222 292 32 ([System.Drawing.Color]::FromArgb(244, 238, 255)) ([System.Drawing.Color]::FromArgb(78, 69, 116))
$script:OpenButton.Add_Click({ Open-OutputFolder })
$script:Panel.Controls.Add($script:OpenButton)

$script:TencentModeLabel = New-PetInfoLabel (T "tencent.off") 14 264 292 20
$script:TencentModeLabel.ForeColor = [System.Drawing.Color]::FromArgb(92, 104, 128)
$script:Panel.Controls.Add($script:TencentModeLabel)

$script:TencentModeButton = New-PetButton (T "button.tencentMode") 14 290 292 32 ([System.Drawing.Color]::FromArgb(236, 242, 250)) ([System.Drawing.Color]::FromArgb(44, 68, 98))
$script:TencentModeButton.Add_Click({ Toggle-TencentGameMode })
$script:Panel.Controls.Add($script:TencentModeButton)

$script:LogBox = New-Object System.Windows.Forms.TextBox
$script:LogBox.Location = New-Object System.Drawing.Point(14, 330)
$script:LogBox.Size = New-Object System.Drawing.Size(292, 36)
$script:LogBox.Multiline = $true
$script:LogBox.ScrollBars = "Vertical"
$script:LogBox.ReadOnly = $true
$script:LogBox.BorderStyle = "FixedSingle"
$script:LogBox.Font = New-Object System.Drawing.Font("Consolas", 8)
$script:Panel.Controls.Add($script:LogBox)

$script:Timer = New-Object System.Windows.Forms.Timer
$script:Timer.Interval = 120
$script:Timer.Add_Tick({
    $script:AnimationTick += 1
    $script:AnimationElapsedMs += $script:Timer.Interval
    $now = Get-Date
    if (($now - $script:LastProcessPoll).TotalMilliseconds -ge 1000) {
        $script:LastProcessPoll = $now
        if ($null -ne $script:FfmpegProcess -and $script:FfmpegProcess.HasExited) {
            Add-Log (T "log.ffmpegExited" @{code = $script:FfmpegProcess.ExitCode})
            $script:FfmpegProcess.Dispose()
            $script:FfmpegProcess = $null
        }
    }
    Update-UiState
})

$script:Form.add_HotkeyPressed({
    param([int]$Id)

    if ($Id -eq 1) {
        Toggle-ReplayCache
    } elseif ($Id -eq 2) {
        Save-Replay
    }
})

$script:Form.Add_Shown({
    $script:Timer.Start()
    Update-UiState
    Add-Log (T "log.ready")
    if ($null -ne $script:HatchPetPackage) {
        Add-Log (T "log.loadedPet" @{name = $script:HatchPetPackage.DisplayName})
    } else {
        Add-Log (T "log.missingPet" @{id = $script:RequestedPetId})
    }
    if ($script:UiSmokeTestSeconds -gt 0) {
        Set-PanelExpanded $true
        Add-Log (T "log.uiSmoke")
        $script:UiSmokeTimer = New-Object System.Windows.Forms.Timer
        $script:UiSmokeTimer.Interval = [Math]::Max(1, $script:UiSmokeTestSeconds) * 1000
        $script:UiSmokeTimer.Add_Tick({
            $script:UiSmokeTimer.Stop()
            $script:Form.Close()
        })
        $script:UiSmokeTimer.Start()
    }

    $modAlt = 0x0001
    $vkF9 = 0x78
    $vkF10 = 0x79

    if ($script:UiSmokeTestSeconds -eq 0) {
        $registeredF9 = [ReplayHotkeyForm]::RegisterHotKey($script:Form.Handle, 1, $modAlt, $vkF9)
        $registeredF10 = [ReplayHotkeyForm]::RegisterHotKey($script:Form.Handle, 2, $modAlt, $vkF10)

        if ($registeredF9 -and $registeredF10) {
            Add-Log (T "log.hotkeysOk")
        } else {
            Add-Log (T "log.hotkeysFail")
        }
    }
})

$script:Form.Add_FormClosing({
    if ($script:UiSmokeTestSeconds -eq 0) {
        [ReplayHotkeyForm]::UnregisterHotKey($script:Form.Handle, 1) | Out-Null
        [ReplayHotkeyForm]::UnregisterHotKey($script:Form.Handle, 2) | Out-Null
    }
    if ($null -ne $script:UiSmokeTimer) {
        $script:UiSmokeTimer.Stop()
        $script:UiSmokeTimer.Dispose()
    }
    if ($null -ne $script:HatchSpritesheet) {
        $script:HatchSpritesheet.Dispose()
        $script:HatchSpritesheet = $null
    }
    if ($null -ne $script:AppIcon) {
        $script:AppIcon.Dispose()
        $script:AppIcon = $null
    }
    if (-not [string]::IsNullOrWhiteSpace($script:HatchSpritesheetTempPath) -and (Test-Path $script:HatchSpritesheetTempPath)) {
        Remove-Item -LiteralPath $script:HatchSpritesheetTempPath -Force -ErrorAction SilentlyContinue
    }
    $script:Timer.Stop()
    if (Test-IsRecording) {
        Stop-ReplayCache
    }
})

[void][System.Windows.Forms.Application]::Run($script:Form)
