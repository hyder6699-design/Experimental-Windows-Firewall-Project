# Pester 5 wrapper:  Invoke-Pester .\tests\Firewall.Tests.ps1 -Output Detailed
BeforeDiscovery {
    $script:checks = & (Join-Path $PSScriptRoot '..\scripts\09-Test-FirewallBaseline.ps1') -PassThru 6>$null |
        Where-Object { $_.PSObject.Properties.Name -contains 'Pass' }
}
Describe 'Effective firewall baseline' {
    It '<Id> <Setting> = <Expected>' -ForEach $checks {
        $Actual | Should -Be $Expected
    }
}
