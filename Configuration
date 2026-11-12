# Single source of truth for the Windows Firewall baseline.
# Every deployment method (PowerShell, netsh, GPO) must produce exactly this
# effective state. 09-Test-FirewallBaseline.ps1 checks against this file.
# If you change a value here, change 07-Deploy-Netsh.cmd to match.
@{
    # Admin network allowed to reach RDP. Everything else is explicitly blocked.
    AdminSubnet    = '10.10.10.0/28'
    # Ranges that are NOT the admin subnet (used by the explicit RDP block rule).
    NonAdminRanges = @('0.0.0.1-10.10.9.255', '10.10.10.16-255.255.255.254')

    Profiles = @{
        Domain = @{
            Enabled               = 'True'
            DefaultInboundAction  = 'Block'
            DefaultOutboundAction = 'Allow'
            NotifyOnListen        = 'False'
            LogFileName           = '%SystemRoot%\System32\logfiles\firewall\domainfw.log'
            LogMaxSizeKilobytes   = 16384
            LogBlocked            = 'True'
            LogAllowed            = 'True'
        }
        Private = @{
            Enabled               = 'True'
            DefaultInboundAction  = 'Block'
            DefaultOutboundAction = 'Allow'
            NotifyOnListen        = 'False'
            LogFileName           = '%SystemRoot%\System32\logfiles\firewall\privatefw.log'
            LogMaxSizeKilobytes   = 16384
            LogBlocked            = 'True'
            LogAllowed            = 'True'
        }
        Public = @{
            Enabled                 = 'True'
            DefaultInboundAction    = 'Block'
            DefaultOutboundAction   = 'Allow'
            NotifyOnListen          = 'False'
            LogFileName             = '%SystemRoot%\System32\logfiles\firewall\publicfw.log'
            LogMaxSizeKilobytes     = 16384
            LogBlocked              = 'True'
            LogAllowed              = 'True'
            # Only meaningful in a Group Policy store (see guide: "merge settings").
            AllowLocalFirewallRules = 'False'
            AllowLocalIPsecRules    = 'False'
        }
    }

    Rules = @(
        @{
            Name          = 'LAB-RDP-Allow-Admin'
            DisplayName   = 'LAB - RDP allow from admin subnet'
            Direction     = 'Inbound'
            Action        = 'Allow'
            Protocol      = 'TCP'
            LocalPort     = '3389'
            RemoteAddress = 'ADMIN'      # replaced with AdminSubnet at deploy time
            Profile       = 'Domain'
        }
        @{
            Name          = 'LAB-RDP-Block-NonAdmin'
            DisplayName   = 'LAB - RDP block from non-admin ranges'
            Direction     = 'Inbound'
            Action        = 'Block'
            Protocol      = 'TCP'
            LocalPort     = '3389'
            RemoteAddress = 'NONADMIN'   # replaced with NonAdminRanges at deploy time
            Profile       = 'Any'
        }
        @{
            Name          = 'LAB-Block-Out-4444'
            DisplayName   = 'LAB - block outbound TCP 4444'
            Direction     = 'Outbound'
            Action        = 'Block'
            Protocol      = 'TCP'
            RemotePort    = '4444'
            Profile       = 'Any'
        }
    )

    # Audit subcategories checked (deployed once by the FW-Audit GPO, not by the methods).
    Audit = @(
        @{ Subcategory = 'MPSSVC Rule-Level Policy Change'; Expected = 'Success and Failure' }
        @{ Subcategory = 'Filtering Platform Packet Drop';  Expected = 'Failure' }
        @{ Subcategory = 'Filtering Platform Connection';   Expected = 'Failure' }
    )
}
