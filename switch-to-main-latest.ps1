<#
.SYNOPSIS
  Switch the current repo to 'main' and pull, then ensure all submodules are attached to 'main'
  (not the superproject-pinned commit) and pull them as well. Continues on errors and summarizes at the end.
  No fallback to 'master'.
#>

$ErrorActionPreference = 'Continue'  # keep going

# --- Logging helpers ---
function Log([string]$msg)  { Write-Host $msg -ForegroundColor Cyan }
function Ok([string]$msg)   { Write-Host $msg -ForegroundColor Green }
function Warn([string]$msg) { Write-Warning $msg }
function Err([string]$msg)  { Write-Host $msg -ForegroundColor Red }

$Global:Failures = New-Object System.Collections.Generic.List[string]

function Note-Failure([string]$msg) {
  $Global:Failures.Add($msg)
  Err $msg
}

# --- Git helpers ---
function Get-PrimaryRemote {
  try {
    $remotes = & git remote 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $remotes) { throw "No remotes configured." }
    $names = @($remotes -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    if ($names -contains 'origin') { return 'origin' }
    return $names[0]
  } catch {
    Note-Failure "Top-level: cannot determine primary remote ($($_.Exception.Message))"
    return $null
  }
}

function Run-Git {
  param([Parameter(Mandatory=$true)][string]$Cmd, [string[]]$Args)
  & git $Cmd @Args
  return $LASTEXITCODE
}

function Ensure-LocalMain([string]$remote) {
  # If local 'main' exists, done.
  & git show-ref --verify --quiet "refs/heads/main" *> $null
  if ($LASTEXITCODE -eq 0) { return $true }

  # Else if remote/main exists, create tracking
  & git ls-remote --exit-code --heads $remote main *> $null
  if ($LASTEXITCODE -eq 0) {
    if ((Run-Git 'switch' @('-c','main','--track',"$remote/main")) -ne 0) {
      if ((Run-Git 'checkout' @('-b','main','--track',"$remote/main"))) { }
    }
    # verify we have local main now
    & git show-ref --verify --quiet "refs/heads/main" *> $null
    return ($LASTEXITCODE -eq 0)
  }

  Note-Failure "Top-level: remote '$remote' has no 'main' branch."
  return $false
}

# --- Start ---
$remote = Get-PrimaryRemote

Log "==> Stashing local changes (if any)..."
Run-Git 'stash' @('push','-u','-m','auto: switch-to-main') | Out-Null

if ($remote) {
  Log "==> Fetching from '$remote'..."
  if ((Run-Git 'fetch' @('--prune',$remote)) -ne 0) {
    Warn "Top-level: fetch from '$remote' failed; continuing."
  }
} else {
  Warn "Top-level: skipping fetch (no remote)."
}

$switchedTop = $false
if ($remote -and (Ensure-LocalMain -remote $remote)) {
  Log "==> Switching top-level to 'main'..."
  if ((Run-Git 'switch' @('main')) -ne 0) {
    if ((Run-Git 'checkout' @('main')) -ne 0) {
      Note-Failure "Top-level: failed to switch to 'main'."
    } else { $switchedTop = $true }
  } else { $switchedTop = $true }
} else {
  Warn "Top-level: local 'main' not ensured; will still attempt submodules."
}

if ($switchedTop) {
  Log "==> Pulling top-level (ff-only)..."
  if ((Run-Git 'pull' @('--ff-only',$remote,'main')) -ne 0) {
    Warn "Top-level: pull failed (non-ff or network); continuing."
  }
}

# Ensure submodules are present (may temporarily detach; we'll reattach next)
Log "==> Ensuring submodules are cloned..."
if ((Run-Git 'submodule' @('update','--init','--recursive')) -ne 0) {
  Warn "Submodules: init/update reported issues; continuing."
}

# Submodule foreach snippet: never exit non-zero; always continue.
$subCmd = @'
# BEGIN resilient foreach
remotes=$(git remote 2>/dev/null || true)
if [ -z "$remotes" ]; then
  echo "[WARN] $name ($sm_path): no remotes"; exit 0
fi
remote="origin"
echo "$remotes" | tr -d "\r" | grep -qx "origin" || remote=$(echo "$remotes" | head -n1)

# fetch, but don't fail the foreach if it errors
git fetch --prune "$remote" >/dev/null 2>&1 || echo "[WARN] $name ($sm_path): fetch failed"

# ensure remote has main
if ! git ls-remote --exit-code --heads "$remote" main >/dev/null 2>&1; then
  echo "[WARN] $name ($sm_path): '$remote' has no 'main'"
  exit 0
fi

# local changes might block switching; try to stash
git stash push -u -m "auto: submodule switch-to-main" >/dev/null 2>&1 || true

# create local main if missing
if git show-ref --verify --quiet refs/heads/main; then
  : # exists
else
  git switch -c main --track "$remote/main" >/dev/null 2>&1 || \
  git checkout -b main --track "$remote/main" >/dev/null 2>&1 || \
  echo "[WARN] $name ($sm_path): could not create local 'main'"
fi

# switch (attach) to main
git switch main >/dev/null 2>&1 || git checkout main >/dev/null 2>&1 || \
echo "[WARN] $name ($sm_path): could not switch to 'main'"

# pull latest main explicitly
git pull --ff-only "$remote" main >/dev/null 2>&1 || \
echo "[WARN] $name ($sm_path): pull failed (non-ff or network)"

# try to restore stash (ignore conflicts)
git stash pop >/dev/null 2>&1 || true

# Always exit 0 to continue to the next submodule
exit 0
# END resilient foreach
'@

Log "==> Switching submodules to 'main' and pulling latest (continuing on errors)..."
# foreach stops on non-zero exit code; our snippet always exits 0
& git submodule foreach --recursive $subCmd | Write-Output

Log "==> Attempting to pop top-level stash..."
Run-Git 'stash' @('pop') | Out-Null

Ok "Done: repo and submodules attempted. See summary below."

# --- Summary ---
if ($Global:Failures.Count -gt 0) {
  Write-Host "`n=== Summary of issues ===" -ForegroundColor Yellow
  $Global:Failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
} else {
  Write-Host "`nNo critical top-level issues detected." -ForegroundColor Green
}

Write-Host "`nNOTE: Submodules are now on the latest 'main', which may differ from the superproject-pinned commits." -ForegroundColor Yellow

# SIG # Begin signature block
# MIIu8QYJKoZIhvcNAQcCoIIu4jCCLt4CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCbTclnnrlLLaD2
# nUjXAwygx/BdMxSqvFIZYaQ8BS/+CaCCElYwggVvMIIEV6ADAgECAhBI/JO0YFWU
# jTanyYqJ1pQWMA0GCSqGSIb3DQEBDAUAMHsxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# DBJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcMB1NhbGZvcmQxGjAYBgNVBAoM
# EUNvbW9kbyBDQSBMaW1pdGVkMSEwHwYDVQQDDBhBQUEgQ2VydGlmaWNhdGUgU2Vy
# dmljZXMwHhcNMjEwNTI1MDAwMDAwWhcNMjgxMjMxMjM1OTU5WjBWMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCN55QSIgQkdC7/FiMCkoq2rjaFrEfUI5ErPtx94jGgUW+s
# hJHjUoq14pbe0IdjJImK/+8Skzt9u7aKvb0Ffyeba2XTpQxpsbxJOZrxbW6q5KCD
# J9qaDStQ6Utbs7hkNqR+Sj2pcaths3OzPAsM79szV+W+NDfjlxtd/R8SPYIDdub7
# P2bSlDFp+m2zNKzBenjcklDyZMeqLQSrw2rq4C+np9xu1+j/2iGrQL+57g2extme
# me/G3h+pDHazJyCh1rr9gOcB0u/rgimVcI3/uxXP/tEPNqIuTzKQdEZrRzUTdwUz
# T2MuuC3hv2WnBGsY2HH6zAjybYmZELGt2z4s5KoYsMYHAXVn3m3pY2MeNn9pib6q
# RT5uWl+PoVvLnTCGMOgDs0DGDQ84zWeoU4j6uDBl+m/H5x2xg3RpPqzEaDux5mcz
# mrYI4IAFSEDu9oJkRqj1c7AGlfJsZZ+/VVscnFcax3hGfHCqlBuCF6yH6bbJDoEc
# QNYWFyn8XJwYK+pF9e+91WdPKF4F7pBMeufG9ND8+s0+MkYTIDaKBOq3qgdGnA2T
# OglmmVhcKaO5DKYwODzQRjY1fJy67sPV+Qp2+n4FG0DKkjXp1XrRtX8ArqmQqsV/
# AZwQsRb8zG4Y3G9i/qZQp7h7uJ0VP/4gDHXIIloTlRmQAOka1cKG8eOO7F/05QID
# AQABo4IBEjCCAQ4wHwYDVR0jBBgwFoAUoBEKIz6W8Qfs4q8p74Klf9AwpLQwHQYD
# VR0OBBYEFDLrkpr/NZZILyhAQnAgNpFcF4XmMA4GA1UdDwEB/wQEAwIBhjAPBgNV
# HRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMDMBsGA1UdIAQUMBIwBgYE
# VR0gADAIBgZngQwBBAEwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5jb21v
# ZG9jYS5jb20vQUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNAYIKwYBBQUHAQEE
# KDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wDQYJKoZI
# hvcNAQEMBQADggEBABK/oe+LdJqYRLhpRrWrJAoMpIpnuDqBv0WKfVIHqI0fTiGF
# OaNrXi0ghr8QuK55O1PNtPvYRL4G2VxjZ9RAFodEhnIq1jIV9RKDwvnhXRFAZ/ZC
# J3LFI+ICOBpMIOLbAffNRk8monxmwFE2tokCVMf8WPtsAO7+mKYulaEMUykfb9gZ
# pk+e96wJ6l2CxouvgKe9gUhShDHaMuwV5KZMPWw5c9QLhTkg4IUaaOGnSDip0TYl
# d8GNGRbFiExmfS9jzpjoad+sPKhdnckcW67Y8y90z7h+9teDnRGWYpquRRPaf9xH
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggYcMIIEBKADAgECAhAz1wio
# kUBTGeKlu9M5ua1uMA0GCSqGSIb3DQEBDAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxLTArBgNVBAMTJFNlY3RpZ28gUHVibGljIENv
# ZGUgU2lnbmluZyBSb290IFI0NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5
# NTlaMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAs
# BgNVBAMTJVNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBFViBSMzYwggGi
# MA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQC70f4et0JbePWQp64sg/GNIdMw
# hoV739PN2RZLrIXFuwHP4owoEXIEdiyBxasSekBKxRDogRQ5G19PB/YwMDB/NSXl
# wHM9QAmU6Kj46zkLVdW2DIseJ/jePiLBv+9l7nPuZd0o3bsffZsyf7eZVReqskmo
# PBBqOsMhspmoQ9c7gqgZYbU+alpduLyeE9AKnvVbj2k4aOqlH1vKI+4L7bzQHkND
# brBTjMJzKkQxbr6PuMYC9ruCBBV5DFIg6JgncWHvL+T4AvszWbX0w1Xn3/YIIq62
# 0QlZ7AGfc4m3Q0/V8tm9VlkJ3bcX9sR0gLqHRqwG29sEDdVOuu6MCTQZlRvmcBME
# Jd+PuNeEM4xspgzraLqVT3xE6NRpjSV5wyHxNXf4T7YSVZXQVugYAtXueciGoWnx
# G06UE2oHYvDQa5mll1CeHDOhHu5hiwVoHI717iaQg9b+cYWnmvINFD42tRKtd3V6
# zOdGNmqQU8vGlHHeBzoh+dYyZ+CcblSGoGSgg8sCAwEAAaOCAWMwggFfMB8GA1Ud
# IwQYMBaAFDLrkpr/NZZILyhAQnAgNpFcF4XmMB0GA1UdDgQWBBSBMpJBKyjNRsjE
# osYqORLsSKk/FDAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADAT
# BgNVHSUEDDAKBggrBgEFBQcDAzAaBgNVHSAEEzARMAYGBFUdIAAwBwYFZ4EMAQMw
# SwYDVR0fBEQwQjBAoD6gPIY6aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdv
# UHVibGljQ29kZVNpZ25pbmdSb290UjQ2LmNybDB7BggrBgEFBQcBAQRvMG0wRgYI
# KwYBBQUHMAKGOmh0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0Nv
# ZGVTaWduaW5nUm9vdFI0Ni5wN2MwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNl
# Y3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4ICAQBfNqz7+fZyWhS38Asd3tj9lwHS
# /QHumS2G6Pa38Dn/1oFKWqdCSgotFZ3mlP3FaUqy10vxFhJM9r6QZmWLLXTUqwj3
# ahEDCHd8vmnhsNufJIkD1t5cpOCy1rTP4zjVuW3MJ9bOZBHoEHJ20/ng6SyJ6UnT
# s5eWBgrh9grIQZqRXYHYNneYyoBBl6j4kT9jn6rNVFRLgOr1F2bTlHH9nv1HMePp
# GoYd074g0j+xUl+yk72MlQmYco+VAfSYQ6VK+xQmqp02v3Kw/Ny9hA3s7TSoXpUr
# OBZjBXXZ9jEuFWvilLIq0nQ1tZiao/74Ky+2F0snbFrmuXZe2obdq2TWauqDGIgb
# MYL1iLOUJcAhLwhpAuNMu0wqETDrgXkG4UGVKtQg9guT5Hx2DJ0dJmtfhAH2KpnN
# r97H8OQYok6bLyoMZqaSdSa+2UA1E2+upjcaeuitHFFjBypWBmztfhj24+xkc6Zt
# CDaLrw+ZrnVrFyvCTWrDUUZBVumPwo3/E3Gb2u2e05+r5UWmEsUUWlJBl6MGAAjF
# 5hzqJ4I8O9vmRsTvLQA1E802fZ3lqicIBczOwDYOSxlP0GOabb/FKVMxItt1UHeG
# 0PL4au5rBhs+hSMrl8h+eplBDN1Yfw6owxI9OjWb4J0sjBeBVESoeh2YnZZ/WVim
# VGX/UUIL+Efrz/jlvzCCBr8wggUnoAMCAQICEQDw0/va3GMGRYIBp05lXJ1rMA0G
# CSqGSIb3DQEBCwUAMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExp
# bWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBF
# ViBSMzYwHhcNMjUwMzA0MDAwMDAwWhcNMjgwMzAzMjM1OTU5WjCBlTEQMA4GA1UE
# BRMHMzA4NDg1ZjETMBEGCysGAQQBgjc8AgEDEwJBVDEdMBsGA1UEDxMUUHJpdmF0
# ZSBPcmdhbml6YXRpb24xCzAJBgNVBAYTAkFUMRgwFgYDVQQIDA9PYmVyw7ZzdGVy
# cmVpY2gxEjAQBgNVBAoMCUNBRFMgR21iSDESMBAGA1UEAwwJQ0FEUyBHbWJIMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAmh0Id2KapAoZdCiHZ5W60NFB
# fOXEjDVuySoBJ3idILmPkh0niF7wJ+7IvkBRaMmQasLGHmDZbViJ216FoMYygP53
# QfR7hi1oRDi/zaXBsW4uAZMhYLLI2ERt3USRhq3b07ZfL5Gw6eGduzU87vpK6asB
# Iji3pvxWh45FGgO1TLs8S/J88B9sM2Ikq9m3c3WHmr+Z40IlaZzjliaLcGGzCbzg
# h8ygx212c5zR6kWTAURvbfn4qiM9Ac6GjuTS1bZaiI3Gj8G6fb6Nj9L6i+lfEkIy
# R4kB5HuAsI2+IiT0wOLHT45j+RvZ+KWEJMYX5RXisgFw1n2ZGOXMuYk0r1M6HzWp
# Dzon84gycWsuaHhgFgIGV1ArZxqo+ZYY2crdkd0J+RIIAREzcKuSuXgNCUvZFyAW
# IZ/TGmCJVVsAsFi5b6nY62zqdfknL5nx6EqMNQjzSdpOscnx5wZcYMnFkMoFRkXI
# T+tYiVDUSwV/SBYqnYrDm6A70BVAMwuhBzvDUr5OVxDloPMCmuOFByqadNSoeGYm
# eddGRyX5TzQMYVA/DVSr0tslgbdR/9nIc4wgtWRAPhiwvBOLDHh9rVaucT2c4mbg
# I8mwgme33cji8lFyIkRHPbpZunlmTKOL/umfj8CtdcafBHKBrFlzJRM/DogBipU0
# QYitl0nhkVNpRcDskQ0CAwEAAaOCAcUwggHBMB8GA1UdIwQYMBaAFIEykkErKM1G
# yMSixio5EuxIqT8UMB0GA1UdDgQWBBShM7WFyhUdx9shARtiB2DaNTTK3jAOBgNV
# HQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzBJ
# BgNVHSAEQjBAMDUGDCsGAQQBsjEBAgEGATAlMCMGCCsGAQUFBwIBFhdodHRwczov
# L3NlY3RpZ28uY29tL0NQUzAHBgVngQwBAzBLBgNVHR8ERDBCMECgPqA8hjpodHRw
# Oi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ0NBRVZS
# MzYuY3JsMHsGCCsGAQUFBwEBBG8wbTBGBggrBgEFBQcwAoY6aHR0cDovL2NydC5z
# ZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdDQUVWUjM2LmNydDAj
# BggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wNwYDVR0RBDAwLqAa
# BggrBgEFBQcIA6AOMAwMCkFULTMwODQ4NWaBEGl0LWFkbWluQGNhZHMuYXQwDQYJ
# KoZIhvcNAQELBQADggGBAAfowjmmGsE1iky6ze2zWEpFJRijIZisHBJwxXgrrIan
# iGbmbHCr+9xvn3p+p4WP0J8T4M2cRY+jDtux4cEq7P3MGxvxT33YLIYRZC1s4ve7
# Sn82IDLkAqmMF5NbUkO+Su6CJCHGmEklkQiZmS0G5vW6C/KP1YYYhpawyzMv1KJx
# dlRKZzwPPTrTyDISMv9g/CpwQtBK1Z1PizHSHTSOjE+CyXjDusSkZ/qMOAgkNmHE
# 7Xm3g8yWwNjwRtDYkz8v7EbsOrDM7MMjWzOAl7bzpfoTxTsbQ5T7qYs9PECjeix0
# 6YlvpqOrgW0AdsXBfTMGFQVEY+a/0vQRg307gU8jPDTgwd91Jt3tUg5zD26RxVJ/
# 4pmFgA9f5iXEcKBFrpXdEUBqOZFNTRJTHu3s9N5g1DE5X9DRttlJFeUn3aSRXlPA
# z7nqJsVFNtOsFCSKB/Ut2Dod15Nrtr3eB8dU6MpQUgKMMOsPu19hhXmzFoWtbCsF
# fBtijHmcQLexEX4V4myhRzGCG/EwghvtAgEBMGwwVzELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDEuMCwGA1UEAxMlU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIEVWIFIzNgIRAPDT+9rcYwZFggGnTmVcnWswDQYJYIZI
# AWUDBAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYB
# BAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0B
# CQQxIgQgkaQ3cj0nFdoMhJApcBgxPPlFTR4Huj1UBEIl17tXWLQwDQYJKoZIhvcN
# AQEBBQAEggIAPW7Utx7AzAsrFk8aAc2nv8vgZgVF0yH+mRagVHyjMppZLkke41j1
# O5e1qe6KE0ut881iXSR2MO3rA+cfquw80slWL0BMJmUO9XBFq1jc+//pYF9ZcAYD
# 5n8yz01xQe7110tpGUD+bqio8jzkrizJQ8zIgKhakuoYtNAD2QP7byGa8pJUESRr
# rn7WrJp9PNb489yhDuevannpBIRJMbvC0gXD7byA/bMyYwvL/74t+IXCHxBTC/3q
# 01uEtsCFmYT+c1dKNEEooGbJQwJkXZ5jeAZ9t08NgJkS6P8shRT6mYsZeuFAORqM
# o2BnJT8pQFLEkPUeUzJfhy2aoleopWpO9D9yAdKJJPibaBiYhb3ISaz+F8XvNqaL
# yXsdcAw1KNnHI115/c1lYozUrA/BtecqvyNi36Q7uOQCM8HEoz9IrtiUmEKpljsK
# B9w3QQ0taBbarffDY1TiqLzjj/YXIQyqALA/nPecjR9IZEwQXtGs42P2rZvKb/Q8
# AwzMsglQV5CY/To+2Zs4/NpH3NeNWLGrkUiJz73JO3UQcoVp9q9dMRLV9JGYbzhC
# eIPVqdK3PLTH7hQR4wZz/UGeRU2Br9/WkT5fFk0PK9czHykffYeoWNb3FLCu0wdZ
# 8/aLC3ixzfjDxLVzND7Dsj+M6xt9IVwsFET8e7QK5W17bGYhrlv5lwOhghjYMIIY
# 1AYKKwYBBAGCNwMDATGCGMQwghjABgkqhkiG9w0BBwKgghixMIIYrQIBAzEPMA0G
# CWCGSAFlAwQCAgUAMIH4BgsqhkiG9w0BCRABBKCB6ASB5TCB4gIBAQYKKwYBBAGy
# MQIBATAxMA0GCWCGSAFlAwQCAQUABCBvF3HcTqqLhm+G/8W6OGuVxm//iNkPOovq
# GoZ9WzeEigIVALe7k5tf0Uz6+GPoQWGh/8aeEriVGA8yMDI1MDkwOTEwMTcyOVqg
# dqR0MHIxCzAJBgNVBAYTAkdCMRcwFQYDVQQIEw5XZXN0IFlvcmtzaGlyZTEYMBYG
# A1UEChMPU2VjdGlnbyBMaW1pdGVkMTAwLgYDVQQDEydTZWN0aWdvIFB1YmxpYyBU
# aW1lIFN0YW1waW5nIFNpZ25lciBSMzagghMEMIIGYjCCBMqgAwIBAgIRAKQpO24e
# 3denNAiHrXpOtyQwDQYJKoZIhvcNAQEMBQAwVTELMAkGA1UEBhMCR0IxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQdWJsaWMgVGlt
# ZSBTdGFtcGluZyBDQSBSMzYwHhcNMjUwMzI3MDAwMDAwWhcNMzYwMzIxMjM1OTU5
# WjByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZb3Jrc2hpcmUxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDEwMC4GA1UEAxMnU2VjdGlnbyBQdWJsaWMgVGlt
# ZSBTdGFtcGluZyBTaWduZXIgUjM2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEA04SV9G6kU3jyPRBLeBIHPNyUgVNnYayfsGOyYEXrn3+SkDYTLs1crcw/
# ol2swE1TzB2aR/5JIjKNf75QBha2Ddj+4NEPKDxHEd4dEn7RTWMcTIfm492TW22I
# 8LfH+A7Ehz0/safc6BbsNBzjHTt7FngNfhfJoYOrkugSaT8F0IzUh6VUwoHdYDpi
# ln9dh0n0m545d5A5tJD92iFAIbKHQWGbCQNYplqpAFasHBn77OqW37P9BhOASdmj
# p3IijYiFdcA0WQIe60vzvrk0HG+iVcwVZjz+t5OcXGTcxqOAzk1frDNZ1aw8nFhG
# EvG0ktJQknnJZE3D40GofV7O8WzgaAnZmoUn4PCpvH36vD4XaAF2CjiPsJWiY/j2
# xLsJuqx3JtuI4akH0MmGzlBUylhXvdNVXcjAuIEcEQKtOBR9lU4wXQpISrbOT8ux
# +96GzBq8TdbhoFcmYaOBZKlwPP7pOp5Mzx/UMhyBA93PQhiCdPfIVOCINsUY4U23
# p4KJ3F1HqP3H6Slw3lHACnLilGETXRg5X/Fp8G8qlG5Y+M49ZEGUp2bneRLZoyHT
# yynHvFISpefhBCV0KdRZHPcuSL5OAGWnBjAlRtHvsMBrI3AAA0Tu1oGvPa/4yeei
# Ayu+9y3SLC98gDVbySnXnkujjhIh+oaatsk/oyf5R2vcxHahajMCAwEAAaOCAY4w
# ggGKMB8GA1UdIwQYMBaAFF9Y7UwxeqJhQo1SgLqzYZcZojKbMB0GA1UdDgQWBBSI
# YYyhKjdkgShgoZsx0Iz9LALOTzAOBgNVHQ8BAf8EBAMCBsAwDAYDVR0TAQH/BAIw
# ADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDBKBgNVHSAEQzBBMDUGDCsGAQQBsjEB
# AgEDCDAlMCMGCCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQUzAIBgZn
# gQwBBAIwSgYDVR0fBEMwQTA/oD2gO4Y5aHR0cDovL2NybC5zZWN0aWdvLmNvbS9T
# ZWN0aWdvUHVibGljVGltZVN0YW1waW5nQ0FSMzYuY3JsMHoGCCsGAQUFBwEBBG4w
# bDBFBggrBgEFBQcwAoY5aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVi
# bGljVGltZVN0YW1waW5nQ0FSMzYuY3J0MCMGCCsGAQUFBzABhhdodHRwOi8vb2Nz
# cC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAYEAAoE+pIZyUSH5ZakuPVKK
# 4eWbzEsTRJOEjbIu6r7vmzXXLpJx4FyGmcqnFZoa1dzx3JrUCrdG5b//LfAxOGy9
# Ph9JtrYChJaVHrusDh9NgYwiGDOhyyJ2zRy3+kdqhwtUlLCdNjFjakTSE+hkC9F5
# ty1uxOoQ2ZkfI5WM4WXA3ZHcNHB4V42zi7Jk3ktEnkSdViVxM6rduXW0jmmiu71Z
# pBFZDh7Kdens+PQXPgMqvzodgQJEkxaION5XRCoBxAwWwiMm2thPDuZTzWp/gUFz
# i7izCmEt4pE3Kf0MOt3ccgwn4Kl2FIcQaV55nkjv1gODcHcD9+ZVjYZoyKTVWb4V
# qMQy/j8Q3aaYd/jOQ66Fhk3NWbg2tYl5jhQCuIsE55Vg4N0DUbEWvXJxtxQQaVR5
# xzhEI+BjJKzh3TQ026JxHhr2fuJ0mV68AluFr9qshgwS5SpN5FFtaSEnAwqZv3IS
# +mlG50rK7W3qXbWwi4hmpylUfygtYLEdLQukNEX1jiOKMIIGFDCCA/ygAwIBAgIQ
# eiOu2lNplg+RyD5c9MfjPzANBgkqhkiG9w0BAQwFADBXMQswCQYDVQQGEwJHQjEY
# MBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1Ymxp
# YyBUaW1lIFN0YW1waW5nIFJvb3QgUjQ2MB4XDTIxMDMyMjAwMDAwMFoXDTM2MDMy
# MTIzNTk1OVowVTELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRl
# ZDEsMCoGA1UEAxMjU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBDQSBSMzYw
# ggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQDNmNhDQatugivs9jN+JjTk
# iYzT7yISgFQ+7yavjA6Bg+OiIjPm/N/t3nC7wYUrUlY3mFyI32t2o6Ft3EtxJXCc
# 5MmZQZ8AxCbh5c6WzeJDB9qkQVa46xiYEpc81KnBkAWgsaXnLURoYZzksHIzzCNx
# tIXnb9njZholGw9djnjkTdAA83abEOHQ4ujOGIaBhPXG2NdV8TNgFWZ9BojlAvfl
# xNMCOwkCnzlH4oCw5+4v1nssWeN1y4+RlaOywwRMUi54fr2vFsU5QPrgb6tSjvEU
# h1EC4M29YGy/SIYM8ZpHadmVjbi3Pl8hJiTWw9jiCKv31pcAaeijS9fc6R7DgyyL
# IGflmdQMwrNRxCulVq8ZpysiSYNi79tw5RHWZUEhnRfs/hsp/fwkXsynu1jcsUX+
# HuG8FLa2BNheUPtOcgw+vHJcJ8HnJCrcUWhdFczf8O+pDiyGhVYX+bDDP3GhGS7T
# mKmGnbZ9N+MpEhWmbiAVPbgkqykSkzyYVr15OApZYK8CAwEAAaOCAVwwggFYMB8G
# A1UdIwQYMBaAFPZ3at0//QET/xahbIICL9AKPRQlMB0GA1UdDgQWBBRfWO1MMXqi
# YUKNUoC6s2GXGaIymzAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIB
# ADATBgNVHSUEDDAKBggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAwTAYDVR0f
# BEUwQzBBoD+gPYY7aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGlj
# VGltZVN0YW1waW5nUm9vdFI0Ni5jcmwwfAYIKwYBBQUHAQEEcDBuMEcGCCsGAQUF
# BzAChjtodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1lU3Rh
# bXBpbmdSb290UjQ2LnA3YzAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGln
# by5jb20wDQYJKoZIhvcNAQEMBQADggIBABLXeyCtDjVYDJ6BHSVY/UwtZ3Svx2Im
# IfZVVGnGoUaGdltoX4hDskBMZx5NY5L6SCcwDMZhHOmbyMhyOVJDwm1yrKYqGDHW
# zpwVkFJ+996jKKAXyIIaUf5JVKjccev3w16mNIUlNTkpJEor7edVJZiRJVCAmWAa
# Hcw9zP0hY3gj+fWp8MbOocI9Zn78xvm9XKGBp6rEs9sEiq/pwzvg2/KjXE2yWUQI
# kms6+yslCRqNXPjEnBnxuUB1fm6bPAV+Tsr/Qrd+mOCJemo06ldon4pJFbQd0TQV
# IMLv5koklInHvyaf6vATJP4DfPtKzSBPkKlOtyaFTAjD2Nu+di5hErEVVaMqSVbf
# Pzd6kNXOhYm23EWm6N2s2ZHCHVhlUgHaC4ACMRCgXjYfQEDtYEK54dUwPJXV7icz
# 0rgCzs9VI29DwsjVZFpO4ZIVR33LwXyPDbYFkLqYmgHjR3tKVkhh9qKV2WCmBuC2
# 7pIOx6TYvyqiYbntinmpOqh/QPAnhDgexKG9GX/n1PggkGi9HCapZp8fRwg8Rftw
# S21Ln61euBG0yONM6noD2XQPrFwpm3GcuqJMf0o8LLrFkSLRQNwxPDDkWXhW+gZs
# wbaiie5fd/W2ygcto78XCSPfFWveUOSZ5SqK95tBO8aTHmEa4lpJVD7HrTEn9jb1
# EGvxOb1cnn0CMIIGgjCCBGqgAwIBAgIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG
# 9w0BAQwFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDAS
# BgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdv
# cmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3Jp
# dHkwHhcNMjEwMzIyMDAwMDAwWhcNMzgwMTE4MjM1OTU5WjBXMQswCQYDVQQGEwJH
# QjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1
# YmxpYyBUaW1lIFN0YW1waW5nIFJvb3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEAiJ3YuUVnnR3d6LkmgZpUVMB8SQWbzFoVD9mUEES0QUCBdxSZ
# qdTkdizICFNeINCSJS+lV1ipnW5ihkQyC0cRLWXUJzodqpnMRs46npiJPHrfLBOi
# fjfhpdXJ2aHHsPHggGsCi7uE0awqKggE/LkYw3sqaBia67h/3awoqNvGqiFRJ+OT
# WYmUCO2GAXsePHi+/JUNAax3kpqstbl3vcTdOGhtKShvZIvjwulRH87rbukNyHGW
# X5tNK/WABKf+Gnoi4cmisS7oSimgHUI0Wn/4elNd40BFdSZ1EwpuddZ+Wr7+Dfo0
# lcHflm/FDDrOJ3rWqauUP8hsokDoI7D/yUVI9DAE/WK3Jl3C4LKwIpn1mNzMyptR
# wsXKrop06m7NUNHdlTDEMovXAIDGAvYynPt5lutv8lZeI5w3MOlCybAZDpK3Dy1M
# Ko+6aEtE9vtiTMzz/o2dYfdP0KWZwZIXbYsTIlg1YIetCpi5s14qiXOpRsKqFKqa
# v9R1R5vj3NgevsAsvxsAnI8Oa5s2oy25qhsoBIGo/zi6GpxFj+mOdh35Xn91y72J
# 4RGOJEoqzEIbW3q0b2iPuWLA911cRxgY5SJYubvjay3nSMbBPPFsyl6mY4/WYucm
# yS9lo3l7jk27MAe145GWxK4O3m3gEFEIkv7kRmefDR7Oe2T1HxAnICQvr9sCAwEA
# AaOCARYwggESMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1Ud
# DgQWBBT2d2rdP/0BE/8WoWyCAi/QCj0UJTAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0T
# AQH/BAUwAwEB/zATBgNVHSUEDDAKBggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUd
# IAAwUAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VT
# RVJUcnVzdFJTQUNlcnRpZmljYXRpb25BdXRob3JpdHkuY3JsMDUGCCsGAQUFBwEB
# BCkwJzAlBggrBgEFBQcwAYYZaHR0cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkq
# hkiG9w0BAQwFAAOCAgEADr5lQe1oRLjlocXUEYfktzsljOt+2sgXke3Y8UPEooU5
# y39rAARaAdAxUeiX1ktLJ3+lgxtoLQhn5cFb3GF2SSZRX8ptQ6IvuD3wz/LNHKpQ
# 5nX8hjsDLRhsyeIiJsms9yAWnvdYOdEMq1W61KE9JlBkB20XBee6JaXx4UBErc+Y
# uoSb1SxVf7nkNtUjPfcxuFtrQdRMRi/fInV/AobE8Gw/8yBMQKKaHt5eia8ybT8Y
# /Ffa6HAJyz9gvEOcF1VWXG8OMeM7Vy7Bs6mSIkYeYtddU1ux1dQLbEGur18ut97w
# gGwDiGinCwKPyFO7ApcmVJOtlw9FVJxw/mL1TbyBns4zOgkaXFnnfzg4qbSvnrwy
# j1NiurMp4pmAWjR+Pb/SIduPnmFzbSN/G8reZCL4fvGlvPFk4Uab/JVCSmj59+/m
# B2Gn6G/UYOy8k60mKcmaAZsEVkhOFuoj4we8CYyaR9vd9PGZKSinaZIkvVjbH/3n
# lLb0a7SBIkiRzfPfS9T+JesylbHa1LtRV9U/7m0q7Ma2CQ/t392ioOssXW7oKLdO
# mMBl14suVFBmbzrt5V5cQPnwtd3UOTpS9oCG+ZZheiIvPgkDmA8FzPsnfXW5qHEL
# B43ET7HHFHeRPRYrMBKjkb8/IN7Po0d0hQoF4TeMM+zYAJzoKQnVKOLg8pZVPT8x
# ggSSMIIEjgIBATBqMFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExp
# bWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgQ0Eg
# UjM2AhEApCk7bh7d16c0CIetek63JDANBglghkgBZQMEAgIFAKCCAfkwGgYJKoZI
# hvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTA5MDkxMDE3
# MjlaMD8GCSqGSIb3DQEJBDEyBDCWc4eNIXa2rNVEaE2/3A+1DMZEwcWr36oI/ZcK
# me2Fy0bx+65o8glb6Hlb4DbkY8swggF6BgsqhkiG9w0BCRACDDGCAWkwggFlMIIB
# YTAWBBQ4yRSBEES03GY+k9R0S4FBhqm1sTCBhwQUxq5U5HiG8Xw9VRJIjGnDSnr5
# wt0wbzBbpFkwVzELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRl
# ZDEuMCwGA1UEAxMlU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBSb290IFI0
# NgIQeiOu2lNplg+RyD5c9MfjPzCBvAQUhT1jLZOCgmF80JA1xJHeksFC2scwgaMw
# gY6kgYswgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYD
# VQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3Jr
# MS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0aG9yaXR5
# AhA2wrC9fBs656Oz3TbLyXVoMA0GCSqGSIb3DQEBAQUABIICAMF5CArs1uHTRn06
# KxpXR6BzjrMLAPGZrHYiRJxTVCy0g+1D/++kPUUGS0l50JsXXjrC1jJohx8gaIWE
# B70dnI7L9UjfowSRMoyn65DyBsWjpLbe5s2onnbVF8KLsTHJH9vbndfF/fmy2P+H
# 912nD7SCBSHdbs1Kz4Z7C7hMWLb6jHet78ExBTByTBgoi9gXS3tx6QxcFAUUjDDW
# 42MGcOqrPJ9v+FsbGJUkG1ucPPTbyajwwoMzsx/b8oFav0pxspyDay1M/tYj5JJT
# IE3B6nYQNb98x8ktHNHHrMmVTobrmGuulO7rMy1M4Xt5mGnfxFrEaRcq3ZWfc737
# KbmQvE8Uv4cgToBLJX1lf1GGWd3nRrffL7EthvCGF6V8N417R1pfLl3sRcobCEm2
# /6oZGeKnRMAXvh2lCfS1tPBiqhM+2udRzyvGgPjCJIF3pkd62FJJCNpSYK/UCksg
# KuoEYJDzdWdEgn8zZ3JO/596VOezdut3+xczBH8eEhvQnYOxg1sMPKRGfhu7fCEn
# DCS87UkqHWuIHtb3kagbpHZ0urpdZZKAItJEdLkSos+C0XcbiZnvt6JwLArAQdQI
# WuIa8rYEi57dnEeDuI0mFWGwYac/q3WR3HE10h8XDd+Cs1PLO7rcGzVGa/faeP5P
# 67Q5NOlE/G0rkAGkxwOsZ7tfJmlK
# SIG # End signature block
