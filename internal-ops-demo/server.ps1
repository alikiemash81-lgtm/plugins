$listener = [System.Net.HttpListener]::new()
$prefix = 'http://localhost:3000/'
$listener.Prefixes.Add($prefix)
$listener.Start()

$reviews = @(
  [pscustomobject]@{ id = 'AUD-1001'; title = 'Quarterly access review'; status = 'in_progress'; owner = 'compliance@company.com'; dueDate = '2026-10-15'; risk = 'medium'; evidence = @('user-access-export.csv','vpn-approval-log.pdf') },
  [pscustomobject]@{ id = 'AUD-1002'; title = 'Vendor onboarding controls'; status = 'pending'; owner = 'risk@company.com'; dueDate = '2026-10-18'; risk = 'high'; evidence = @('contracts-checklist.pdf','screening-summary.xlsx') }
)

$findings = @(
  [pscustomobject]@{ id = 'F-401'; reviewId = 'AUD-1001'; title = 'Duplicate access grants'; severity = 'medium'; status = 'open'; owner = 'security@company.com' },
  [pscustomobject]@{ id = 'F-402'; reviewId = 'AUD-1002'; title = 'Missing policy attestation'; severity = 'high'; status = 'open'; owner = 'legal@company.com' }
)

Write-Host "Internal Audit Workflow demo app listening on $prefix"

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response
    $path = $request.Url.AbsolutePath

    try {
        $response.AppendHeader('Access-Control-Allow-Origin', '*')
        $response.AppendHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        $response.AppendHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')

        if ($request.HttpMethod -eq 'OPTIONS') {
            $response.StatusCode = 200
            $response.OutputStream.Close()
            continue
        }

        if ($request.HttpMethod -eq 'GET' -and $path -eq '/health') {
            $payload = @{ ok = $true; app = 'internal-audit-demo'; time = (Get-Date).ToString('o') } | ConvertTo-Json -Compress
            $data = [System.Text.Encoding]::UTF8.GetBytes($payload)
            $response.StatusCode = 200
            $response.ContentType = 'application/json'
            $response.ContentLength64 = $data.Length
            $response.OutputStream.Write($data, 0, $data.Length)
            $response.OutputStream.Close()
            continue
        }

        if ($request.HttpMethod -eq 'GET' -and $path -eq '/v1/reviews') {
            $payload = @{ items = $reviews } | ConvertTo-Json -Depth 5 -Compress
            $data = [System.Text.Encoding]::UTF8.GetBytes($payload)
            $response.StatusCode = 200
            $response.ContentType = 'application/json'
            $response.ContentLength64 = $data.Length
            $response.OutputStream.Write($data, 0, $data.Length)
            $response.OutputStream.Close()
            continue
        }

        if ($request.HttpMethod -eq 'GET' -and $path -match '^/v1/reviews/') {
            $id = $path.Split('/')[-1]
            $match = $reviews | Where-Object { $_.id -eq $id }
            if (-not $match) {
                $payload = @{ error = 'Review not found' } | ConvertTo-Json -Compress
                $data = [System.Text.Encoding]::UTF8.GetBytes($payload)
                $response.StatusCode = 404
                $response.ContentType = 'application/json'
                $response.ContentLength64 = $data.Length
                $response.OutputStream.Write($data, 0, $data.Length)
                $response.OutputStream.Close()
                continue
            }

            $payload = $match | ConvertTo-Json -Depth 5 -Compress
            $data = [System.Text.Encoding]::UTF8.GetBytes($payload)
            $response.StatusCode = 200
            $response.ContentType = 'application/json'
            $response.ContentLength64 = $data.Length
            $response.OutputStream.Write($data, 0, $data.Length)
            $response.OutputStream.Close()
            continue
        }

        if ($request.HttpMethod -eq 'GET' -and $path -eq '/v1/findings') {
            $payload = @{ items = $findings } | ConvertTo-Json -Depth 5 -Compress
            $data = [System.Text.Encoding]::UTF8.GetBytes($payload)
            $response.StatusCode = 200
            $response.ContentType = 'application/json'
            $response.ContentLength64 = $data.Length
            $response.OutputStream.Write($data, 0, $data.Length)
            $response.OutputStream.Close()
            continue
        }

        if ($request.HttpMethod -eq 'POST' -and $path -eq '/v1/findings') {
            $body = ''
            if ($request.HasEntityBody) {
                $reader = New-Object System.IO.StreamReader($request.InputStream)
                $body = $reader.ReadToEnd()
                $request.InputStream.Close()
            }

            $payload = @{}
            if ($body) {
                $payload = $body | ConvertFrom-Json
            }

            $newFinding = [pscustomobject]@{
                id = "F-$([System.DateTime]::UtcNow.ToString('HHmmss'))"
                reviewId = $payload.reviewId
                title = $payload.title
                severity = if ($payload.severity) { $payload.severity } else { 'medium' }
                status = if ($payload.status) { $payload.status } else { 'open' }
                owner = if ($payload.owner) { $payload.owner } else { 'audit@company.com' }
            }

            $findings += $newFinding
            $json = $newFinding | ConvertTo-Json -Depth 5 -Compress
            $data = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.StatusCode = 201
            $response.ContentType = 'application/json'
            $response.ContentLength64 = $data.Length
            $response.OutputStream.Write($data, 0, $data.Length)
            $response.OutputStream.Close()
            continue
        }

        $payload = @{ error = 'Not found' } | ConvertTo-Json -Compress
        $data = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $response.StatusCode = 404
        $response.ContentType = 'application/json'
        $response.ContentLength64 = $data.Length
        $response.OutputStream.Write($data, 0, $data.Length)
        $response.OutputStream.Close()
    }
    catch {
        $payload = @{ error = $_.Exception.Message } | ConvertTo-Json -Compress
        $data = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $response.StatusCode = 500
        $response.ContentType = 'application/json'
        $response.ContentLength64 = $data.Length
        $response.OutputStream.Write($data, 0, $data.Length)
        $response.OutputStream.Close()
    }
    finally {
        $response.Close()
    }
}

$listener.Stop()
