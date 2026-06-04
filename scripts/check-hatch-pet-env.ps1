param(
    [string]$PetId = "hatch-default",
    [string]$PetPackagePath = ""
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$skillDir = Join-Path $env:USERPROFILE ".codex\skills\hatch-pet"
$imagegenCli = Join-Path $env:USERPROFILE ".codex\skills\.system\imagegen\scripts\image_gen.py"

function Resolve-CodexHome {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        return $env:CODEX_HOME
    }

    return (Join-Path $env:USERPROFILE ".codex")
}

function Resolve-HatchPetCandidate {
    param([string]$CandidatePath)

    if ([string]::IsNullOrWhiteSpace($CandidatePath) -or -not (Test-Path $CandidatePath)) {
        return $null
    }

    $resolved = (Resolve-Path $CandidatePath).Path
    $item = Get-Item -LiteralPath $resolved
    if (-not $item.PSIsContainer) {
        if ([string]::Equals($item.Name, "pet.json", [System.StringComparison]::OrdinalIgnoreCase)) {
            $packageDir = Split-Path -Parent $resolved
            $manifestPath = $resolved
        } else {
            return [pscustomobject]@{
                PackageDir = Split-Path -Parent $resolved
                ManifestPath = ""
                SpritesheetPath = $resolved
                Id = Split-Path -Leaf (Split-Path -Parent $resolved)
                DisplayName = Split-Path -Leaf (Split-Path -Parent $resolved)
            }
        }
    } else {
        $packageDir = $resolved
        $manifestPath = Join-Path $packageDir "pet.json"
    }

    if (Test-Path $manifestPath) {
        try {
            $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $spritesheet = $manifest.spritesheetPath
            if ([string]::IsNullOrWhiteSpace($spritesheet)) {
                $spritesheet = "spritesheet.webp"
            }
            if (-not [System.IO.Path]::IsPathRooted($spritesheet)) {
                $spritesheet = Join-Path $packageDir $spritesheet
            }
            if (Test-Path $spritesheet) {
                return [pscustomobject]@{
                    PackageDir = $packageDir
                    ManifestPath = $manifestPath
                    SpritesheetPath = $spritesheet
                    Id = $manifest.id
                    DisplayName = $manifest.displayName
                }
            }
        } catch {
            Write-Host "Invalid pet.json: $manifestPath" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }

    foreach ($name in @("spritesheet.webp", "spritesheet.png")) {
        $spritesheet = Join-Path $packageDir $name
        if (Test-Path $spritesheet) {
            return [pscustomobject]@{
                PackageDir = $packageDir
                ManifestPath = ""
                SpritesheetPath = $spritesheet
                Id = Split-Path -Leaf $packageDir
                DisplayName = Split-Path -Leaf $packageDir
            }
        }
    }

    return $null
}

function Resolve-HatchPetPackage {
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($PetPackagePath)) {
        $candidates += $PetPackagePath
    }
    $candidates += (Join-Path $projectRoot ("pets\" + $PetId))
    $candidates += (Join-Path (Resolve-CodexHome) ("pets\" + $PetId))

    foreach ($candidate in $candidates) {
        $package = Resolve-HatchPetCandidate $candidate
        if ($null -ne $package) {
            return $package
        }
    }

    return $null
}

function Test-HatchSpritesheetDimensions {
    param([string]$SpritesheetPath)

    $probe = & py -3.14 -c "from PIL import Image; import sys; im = Image.open(sys.argv[1]); print(f'{im.width}x{im.height}')" $SpritesheetPath 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($probe)) {
        Write-Host "Cannot verify spritesheet dimensions with Pillow: $SpritesheetPath" -ForegroundColor Yellow
        return
    }

    $size = ($probe | Select-Object -First 1).Trim()
    if ($size -eq "1536x1872") {
        Write-Host "OK spritesheet size: $size" -ForegroundColor Green
    } else {
        Write-Host "Wrong spritesheet size: $size; expected 1536x1872" -ForegroundColor Red
    }
}

function Write-HatchPetCandidateDiagnostics {
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($PetPackagePath)) {
        $candidates += $PetPackagePath
    }
    $candidates += (Join-Path $projectRoot ("pets\" + $PetId))
    $candidates += (Join-Path (Resolve-CodexHome) ("pets\" + $PetId))

    foreach ($candidate in $candidates) {
        if (-not (Test-Path $candidate)) {
            Write-Host "Not found: $candidate" -ForegroundColor DarkGray
            continue
        }

        $resolved = (Resolve-Path $candidate).Path
        $item = Get-Item -LiteralPath $resolved
        $packageDir = if ($item.PSIsContainer) { $resolved } else { Split-Path -Parent $resolved }
        $manifestPath = if ($item.PSIsContainer) { Join-Path $packageDir "pet.json" } elseif ([string]::Equals($item.Name, "pet.json", [System.StringComparison]::OrdinalIgnoreCase)) { $resolved } else { "" }

        if (-not [string]::IsNullOrWhiteSpace($manifestPath) -and (Test-Path $manifestPath)) {
            try {
                $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
                $spritesheet = $manifest.spritesheetPath
                if ([string]::IsNullOrWhiteSpace($spritesheet)) {
                    $spritesheet = "spritesheet.webp"
                }
                if (-not [System.IO.Path]::IsPathRooted($spritesheet)) {
                    $spritesheet = Join-Path $packageDir $spritesheet
                }
                if (-not (Test-Path $spritesheet)) {
                    Write-Host "Found pet.json but missing spritesheet: $spritesheet" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Found pet.json but it is invalid: $manifestPath" -ForegroundColor Red
            }
        } else {
            Write-Host "Found directory without pet.json or loadable spritesheet: $packageDir" -ForegroundColor Yellow
        }
    }
}

function Test-PythonModule {
    param([string]$ModuleName)

    $result = & py -3.14 -c "import importlib.util; raise SystemExit(0 if importlib.util.find_spec('$ModuleName') else 1)" 2>$null
    return $LASTEXITCODE -eq 0
}

Write-Host "Hatch Pet environment check"
Write-Host "Project: $projectRoot"
Write-Host "Requested pet: $PetId"

& py -3.14 --version

$modules = @("PIL", "numpy", "cv2", "imageio", "openai")
foreach ($module in $modules) {
    if (Test-PythonModule $module) {
        Write-Host "OK module: $module" -ForegroundColor Green
    } else {
        Write-Host "Missing module: $module" -ForegroundColor Red
    }
}

if (Test-Path $skillDir) {
    Write-Host "OK Hatch Pet skill: $skillDir" -ForegroundColor Green
} else {
    Write-Host "Missing Hatch Pet skill: $skillDir" -ForegroundColor Red
}

if (Test-Path $imagegenCli) {
    Write-Host "OK imagegen CLI: $imagegenCli" -ForegroundColor Green
} else {
    Write-Host "Missing imagegen CLI: $imagegenCli" -ForegroundColor Red
}

if ($env:OPENAI_API_KEY) {
    Write-Host "OK OPENAI_API_KEY is set" -ForegroundColor Green
} else {
    Write-Host "Missing OPENAI_API_KEY" -ForegroundColor Yellow
}

$petPackage = Resolve-HatchPetPackage
if ($null -ne $petPackage) {
    Write-Host "OK Hatch Pet package: $($petPackage.PackageDir)" -ForegroundColor Green
    if (-not [string]::IsNullOrWhiteSpace($petPackage.ManifestPath)) {
        Write-Host "OK pet.json: $($petPackage.ManifestPath)" -ForegroundColor Green
    } else {
        Write-Host "No pet.json found; using legacy spritesheet-only package" -ForegroundColor Yellow
    }
    Write-Host "OK spritesheet: $($petPackage.SpritesheetPath)" -ForegroundColor Green
    Test-HatchSpritesheetDimensions $petPackage.SpritesheetPath
    if (-not [string]::IsNullOrWhiteSpace($petPackage.DisplayName)) {
        Write-Host "Display name: $($petPackage.DisplayName)"
    }
} else {
    Write-Host "Missing Hatch Pet package for '$PetId'" -ForegroundColor Yellow
    Write-HatchPetCandidateDiagnostics
}

Write-Host ""
Write-Host "Pet lookup order:"
Write-Host "1. -PetPackagePath, when provided"
Write-Host "2. pets\$PetId\pet.json or spritesheet.webp"
Write-Host "3. %CODEX_HOME%\pets\$PetId\pet.json or spritesheet.webp"
Write-Host "4. %USERPROFILE%\.codex\pets\$PetId\pet.json or spritesheet.webp"
