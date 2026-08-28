# ============================================================
# Bastion HA - Automated Failover / Failback Test
# With Timing Statistics + CSV History
# ============================================================

# ------------------------------------------------------------
# Infrastructure configuration
# ------------------------------------------------------------

$FloatingIP = "188.40.148.152"
$PrimaryIP  = "192.168.100.111"
$BackupIP   = "192.168.100.112"
$VIP        = "192.168.100.113"
$User       = "ubuntu"

$PrimaryHostname = "bastion-nawel-test"
$BackupHostname  = "bastion-nawel-backup"

$MaxRetries = 30
$RetryDelay = 1

# ------------------------------------------------------------
# Statistics / History configuration
# ------------------------------------------------------------

$StatsFolder = "$PSScriptRoot\results"
$CsvFile     = "$StatsFolder\ha-test-history.csv"

if (-not (Test-Path $StatsFolder)) {
    New-Item `
        -ItemType Directory `
        -Path $StatsFolder | Out-Null
}

# ------------------------------------------------------------
# Display functions
# ------------------------------------------------------------

function Write-Step($Title) {

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Cyan

    Write-Host $Title `
        -ForegroundColor Cyan

    Write-Host "============================================================" `
        -ForegroundColor Cyan
}

function Write-Pass($Message) {

    Write-Host "[PASS] $Message" `
        -ForegroundColor Green
}

function Write-Fail($Message) {

    Write-Host "[FAIL] $Message" `
        -ForegroundColor Red
}

function Write-Info($Message) {

    Write-Host "[INFO] $Message" `
        -ForegroundColor Yellow
}

function Write-Warn($Message) {

    Write-Host "[WARN] $Message" `
        -ForegroundColor Yellow
}

# ------------------------------------------------------------
# SSH Functions
# ------------------------------------------------------------

function Get-ActiveBastion {

    try {

        $Result = ssh `
            -o ConnectTimeout=4 `
            -o StrictHostKeyChecking=no `
            -o UserKnownHostsFile=NUL `
            "$User@$FloatingIP" `
            "hostname" 2>$null

        if ($LASTEXITCODE -eq 0 -and $Result) {

            return $Result.Trim()
        }

        return $null
    }
    catch {

        return $null
    }
}

function Test-PublicSSH {

    try {

        $Result = ssh `
            -o ConnectTimeout=4 `
            -o StrictHostKeyChecking=no `
            -o UserKnownHostsFile=NUL `
            "$User@$FloatingIP" `
            "hostname" 2>$null

        if ($LASTEXITCODE -eq 0 -and $Result) {

            return $Result.Trim()
        }

        return $null
    }
    catch {

        return $null
    }
}

# ------------------------------------------------------------
# Test variables
# ------------------------------------------------------------

$FailoverSuccess = $false
$FailbackSuccess = $false

$FailoverDuration = 0
$FailbackDuration = 0

$FinalHost = $null
$FinalResult = "FAIL"

# ============================================================
# TEST START
# ============================================================

$TestStart = Get-Date

Write-Step "BASTION HA AUTOMATED TEST"

Write-Host "Test started      : $TestStart"
Write-Host "Floating IP       : $FloatingIP"
Write-Host "Primary IP        : $PrimaryIP"
Write-Host "Backup IP         : $BackupIP"
Write-Host "VIP               : $VIP"

# ============================================================
# STEP 1 - Initial State
# ============================================================

Write-Step "STEP 1 - CHECK INITIAL STATE"

$InitialHost = Get-ActiveBastion

Write-Host "Active Bastion: $InitialHost"

if ($InitialHost -ne $PrimaryHostname) {

    Write-Fail "PRIMARY is not currently active."
    exit 1
}

Write-Pass "PRIMARY is active."

# Check VIP on PRIMARY

$VipCheck = ssh `
    -o StrictHostKeyChecking=no `
    -o UserKnownHostsFile=NUL `
    "$User@$FloatingIP" `
    "ip -4 addr show | grep '$VIP'" `
    2>$null

if ($VipCheck) {

    Write-Pass "PRIMARY owns VIP $VIP"
}
else {

    Write-Fail "PRIMARY does not own VIP $VIP"
    exit 1
}

# ============================================================
# STEP 2 - Check BACKUP
# ============================================================

Write-Step "STEP 2 - CHECK BACKUP"

try {

    $BackupCheck = ssh `
        -J "$User@$FloatingIP" `
        -o ConnectTimeout=5 `
        -o StrictHostKeyChecking=no `
        "$User@$BackupIP" `
        "hostname" `
        2>$null

}
catch {

    $BackupCheck = $null
}

if (
    $BackupCheck -and
    $BackupCheck.Trim() -eq $BackupHostname
) {

    Write-Pass "BACKUP is reachable through ProxyJump."
}
else {

    Write-Fail "BACKUP is not reachable."
    exit 1
}

# ============================================================
# STEP 3 - Trigger Failover
# ============================================================

Write-Step "STEP 3 - TRIGGER FAILOVER"

Write-Info "Stopping Keepalived on PRIMARY..."

$FailoverStart = Get-Date

ssh `
    -o StrictHostKeyChecking=no `
    -o UserKnownHostsFile=NUL `
    "$User@$FloatingIP" `
    "sudo systemctl stop keepalived"

if ($LASTEXITCODE -ne 0) {

    Write-Fail "Unable to stop Keepalived on PRIMARY."
    exit 1
}

Write-Pass "Keepalived stopped on PRIMARY."

# ============================================================
# STEP 4 - Measure Failover
# ============================================================

Write-Step "STEP 4 - MEASURE FAILOVER"

$FailoverEnd = $null

for ($i = 1; $i -le $MaxRetries; $i++) {

    $CurrentHost = Test-PublicSSH

    $Elapsed = (
        (Get-Date) - $FailoverStart
    ).TotalSeconds

    $DisplayHost = if ($CurrentHost) {
        $CurrentHost
    }
    else {
        "unreachable"
    }

    Write-Host (
        "Attempt {0}/{1} | {2:N2}s | Active: {3}" `
            -f `
            $i,
            $MaxRetries,
            $Elapsed,
            $DisplayHost
    )

    if ($CurrentHost -eq $BackupHostname) {

        $FailoverEnd = Get-Date
        $FailoverSuccess = $true

        break
    }

    Start-Sleep -Seconds $RetryDelay
}

if (-not $FailoverSuccess) {

    Write-Fail "Failover timeout."

    Write-Warn "Attempting to restore PRIMARY Keepalived..."

    # At this point FIP may already be on BACKUP.
    # Try to restart PRIMARY from active Bastion.

    ssh `
        -o StrictHostKeyChecking=no `
        -o UserKnownHostsFile=NUL `
        "$User@$FloatingIP" `
        "ssh -o StrictHostKeyChecking=no ubuntu@$PrimaryIP 'sudo systemctl start keepalived'" `
        2>$null

    exit 1
}

$FailoverDuration = (
    $FailoverEnd - $FailoverStart
).TotalSeconds

Write-Pass (
    "BACKUP became active after {0:N2} seconds." `
        -f $FailoverDuration
)

# ============================================================
# STEP 5 - Verify BACKUP VIP
# ============================================================

Write-Step "STEP 5 - VERIFY BACKUP"

$BackupVip = ssh `
    -o StrictHostKeyChecking=no `
    -o UserKnownHostsFile=NUL `
    "$User@$FloatingIP" `
    "ip -4 addr show | grep '$VIP'" `
    2>$null

if ($BackupVip) {

    Write-Pass "BACKUP owns VIP $VIP"
}
else {

    Write-Fail "BACKUP does not own VIP $VIP"
}

# ============================================================
# STEP 6 - Service availability after Failover
# ============================================================

Write-Step "STEP 6 - CHECK SERVICE AFTER FAILOVER"

$ServiceHost = Test-PublicSSH

if ($ServiceHost -eq $BackupHostname) {

    Write-Pass "Public SSH is available on BACKUP."
}
else {

    Write-Fail "Public SSH is not available after failover."
}

# ============================================================
# STEP 7 - Trigger Failback
# ============================================================

Write-Step "STEP 7 - TRIGGER FAILBACK"

Write-Info "Restarting Keepalived on PRIMARY through BACKUP..."

$FailbackStart = Get-Date

ssh `
    -o StrictHostKeyChecking=no `
    -o UserKnownHostsFile=NUL `
    "$User@$FloatingIP" `
    "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$PrimaryIP 'sudo systemctl start keepalived'"

if ($LASTEXITCODE -ne 0) {

    Write-Fail "Unable to start Keepalived on PRIMARY."
    exit 1
}

Write-Pass "Keepalived started on PRIMARY."

# ============================================================
# STEP 8 - Measure Failback
# ============================================================

Write-Step "STEP 8 - MEASURE FAILBACK"

$FailbackEnd = $null

for ($i = 1; $i -le $MaxRetries; $i++) {

    $CurrentHost = Test-PublicSSH

    $Elapsed = (
        (Get-Date) - $FailbackStart
    ).TotalSeconds

    $DisplayHost = if ($CurrentHost) {
        $CurrentHost
    }
    else {
        "unreachable"
    }

    Write-Host (
        "Attempt {0}/{1} | {2:N2}s | Active: {3}" `
            -f `
            $i,
            $MaxRetries,
            $Elapsed,
            $DisplayHost
    )

    if ($CurrentHost -eq $PrimaryHostname) {

        $FailbackEnd = Get-Date
        $FailbackSuccess = $true

        break
    }

    Start-Sleep -Seconds $RetryDelay
}

if (-not $FailbackSuccess) {

    Write-Fail "Failback timeout."
    exit 1
}

$FailbackDuration = (
    $FailbackEnd - $FailbackStart
).TotalSeconds

Write-Pass (
    "PRIMARY recovered after {0:N2} seconds." `
        -f $FailbackDuration
)

# ============================================================
# STEP 9 - Final Verification
# ============================================================

Write-Step "STEP 9 - FINAL STATE"

$FinalHost = Get-ActiveBastion

$FinalVip = ssh `
    -o StrictHostKeyChecking=no `
    -o UserKnownHostsFile=NUL `
    "$User@$FloatingIP" `
    "ip -4 addr show | grep '$VIP'" `
    2>$null

if ($FinalHost -eq $PrimaryHostname) {

    Write-Pass "PRIMARY is active again."
}
else {

    Write-Fail "PRIMARY is not active."
}

if ($FinalVip) {

    Write-Pass "PRIMARY owns VIP $VIP"
}
else {

    Write-Fail "VIP is not present on PRIMARY."
}

# ============================================================
# Test End
# ============================================================

$TestEnd = Get-Date

$TotalDuration = (
    $TestEnd - $TestStart
).TotalSeconds

# ============================================================
# Current test statistics
# ============================================================

Write-Step "HA PERFORMANCE STATISTICS"

Write-Host ""

Write-Host (
    "Test started        : {0}" `
        -f $TestStart
)

Write-Host (
    "Test finished       : {0}" `
        -f $TestEnd
)

Write-Host ""

Write-Host (
    "Failover time       : {0:N2} seconds" `
        -f $FailoverDuration
) -ForegroundColor Yellow

Write-Host (
    "Failback time       : {0:N2} seconds" `
        -f $FailbackDuration
) -ForegroundColor Yellow

Write-Host (
    "Total test duration : {0:N2} seconds" `
        -f $TotalDuration
) -ForegroundColor Yellow

# ============================================================
# Determine result
# ============================================================

if (
    $FailoverSuccess -and
    $FailbackSuccess -and
    ($FinalHost -eq $PrimaryHostname) -and
    $FinalVip
) {

    $FinalResult = "PASS"
}
else {

    $FinalResult = "FAIL"
}

# ============================================================
# SAVE TEST RESULT TO CSV
# ============================================================

Write-Step "SAVE TEST RESULT"

$CurrentResult = [PSCustomObject]@{

    Date = Get-Date `
        -Format "yyyy-MM-dd HH:mm:ss"

    FailoverSeconds = [math]::Round(
        $FailoverDuration,
        2
    )

    FailbackSeconds = [math]::Round(
        $FailbackDuration,
        2
    )

    TotalSeconds = [math]::Round(
        $TotalDuration,
        2
    )

    Result = $FinalResult
}

if (Test-Path $CsvFile) {

    $CurrentResult |
        Export-Csv `
            -Path $CsvFile `
            -Append `
            -NoTypeInformation
}
else {

    $CurrentResult |
        Export-Csv `
            -Path $CsvFile `
            -NoTypeInformation
}

Write-Pass "Test result saved."

Write-Host "CSV file:"
Write-Host $CsvFile -ForegroundColor Cyan

# ============================================================
# CUMULATIVE STATISTICS
# ============================================================

Write-Step "CUMULATIVE HA STATISTICS"

$History = @(
    Import-Csv $CsvFile
)

$TotalTests = $History.Count

$PassedTests = @(
    $History |
        Where-Object {
            $_.Result -eq "PASS"
        }
).Count

$FailedTests = $TotalTests - $PassedTests

if ($TotalTests -gt 0) {

    $SuccessRate = (
        $PassedTests / $TotalTests
    ) * 100
}
else {

    $SuccessRate = 0
}

# ------------------------------------------------------------
# Failover values
# ------------------------------------------------------------

$FailoverValues = @(
    $History |
        ForEach-Object {
            [double]$_.FailoverSeconds
        }
)

$AverageFailover = (
    $FailoverValues |
        Measure-Object -Average
).Average

$MinFailover = (
    $FailoverValues |
        Measure-Object -Minimum
).Minimum

$MaxFailover = (
    $FailoverValues |
        Measure-Object -Maximum
).Maximum

# ------------------------------------------------------------
# Failback values
# ------------------------------------------------------------

$FailbackValues = @(
    $History |
        ForEach-Object {
            [double]$_.FailbackSeconds
        }
)

$AverageFailback = (
    $FailbackValues |
        Measure-Object -Average
).Average

$MinFailback = (
    $FailbackValues |
        Measure-Object -Minimum
).Minimum

$MaxFailback = (
    $FailbackValues |
        Measure-Object -Maximum
).Maximum

# ------------------------------------------------------------
# Total test duration
# ------------------------------------------------------------

$TotalValues = @(
    $History |
        ForEach-Object {
            [double]$_.TotalSeconds
        }
)

$AverageTotal = (
    $TotalValues |
        Measure-Object -Average
).Average

$MinTotal = (
    $TotalValues |
        Measure-Object -Minimum
).Minimum

$MaxTotal = (
    $TotalValues |
        Measure-Object -Maximum
).Maximum

# ------------------------------------------------------------
# Display statistics
# ------------------------------------------------------------

Write-Host ""

Write-Host "Tests performed   : $TotalTests"

Write-Host `
    "Successful tests  : $PassedTests" `
    -ForegroundColor Green

if ($FailedTests -gt 0) {

    Write-Host `
        "Failed tests      : $FailedTests" `
        -ForegroundColor Red
}
else {

    Write-Host "Failed tests      : 0"
}

Write-Host (
    "Success rate      : {0:N2} %" `
        -f $SuccessRate
) -ForegroundColor Green

Write-Host ""

Write-Host "FAILOVER" `
    -ForegroundColor Cyan

Write-Host (
    "  Average : {0:N2} seconds" `
        -f $AverageFailover
)

Write-Host (
    "  Minimum : {0:N2} seconds" `
        -f $MinFailover
)

Write-Host (
    "  Maximum : {0:N2} seconds" `
        -f $MaxFailover
)

Write-Host ""

Write-Host "FAILBACK" `
    -ForegroundColor Cyan

Write-Host (
    "  Average : {0:N2} seconds" `
        -f $AverageFailback
)

Write-Host (
    "  Minimum : {0:N2} seconds" `
        -f $MinFailback
)

Write-Host (
    "  Maximum : {0:N2} seconds" `
        -f $MaxFailback
)

Write-Host ""

Write-Host "TOTAL TEST DURATION" `
    -ForegroundColor Cyan

Write-Host (
    "  Average : {0:N2} seconds" `
        -f $AverageTotal
)

Write-Host (
    "  Minimum : {0:N2} seconds" `
        -f $MinTotal
)

Write-Host (
    "  Maximum : {0:N2} seconds" `
        -f $MaxTotal
)

# ============================================================
# FINAL RESULT
# ============================================================

Write-Step "FINAL RESULT"

if ($FinalResult -eq "PASS") {

    Write-Host ""
    Write-Host "HA TEST SUCCESSFUL" `
        -ForegroundColor Green

    Write-Host ""

    Write-Pass "PRIMARY -> BACKUP failover"
    Write-Pass "Floating IP remained reachable"
    Write-Pass "BACKUP acquired VIP"
    Write-Pass "BACKUP -> PRIMARY failback"
    Write-Pass "PRIMARY recovered VIP"

}
else {

    Write-Fail "HA TEST FAILED"
}

Write-Host ""

Write-Host "History file:" `
    -ForegroundColor Cyan

Write-Host $CsvFile

Write-Host ""