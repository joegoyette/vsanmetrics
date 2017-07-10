# vsanmetrics.ps1
# Joe Goyette (jgoyette@vmware.com)
# V1.0 June 21, 2017

<#
.SYNOPSIS

Collect vSAN cluster metrics for named vCenter Server system
.DESCRIPTION

Collect vSAN cluster metrics for named vCenter Server system
#>


$vuser = "administrator@vsphere.local"
$vpass = "VMware1!"
$vserver = "vc65.vmguitarlab.com"

connect-viserver $vserver -User $vuser -Password $vpass

# Get vSAN enabled clusters
$vsanclusters = get-cluster | Where-Object  {$_.VsanEnabled -eq $true}

# Query each cluster (Use Out-File -Append -NoClobber when ready)
foreach ($cluster in $vsanclusters) {
    $clustername = $cluster.Name
    $hostcount = (Get-VMHost -Location $cluster).Count 
    $vsanvms = (Get-Datastore -RelatedObject $cluster | Where-Object {$_.Type -eq "vsan"} | Get-VM)
    $vmcount = $vsanvms.Count
    $clusterconfig = Get-VsanClusterConfiguration -Cluster $cluster
    $vsanspaceusage = Get-VsanSpaceUsage -Cluster $cluster
    $vsanview = Get-VsanView -Id "VsanVcClusterConfigSystem-vsan-cluster-config-system"
    $encryptionenabled = $vsanview.VsanClusterGetConfig($cluster.ExtensionData.MoRef).DataEncryptionConfig.EncryptionEnabled
    $faultdomaincount = (Get-VsanFaultDomain -Cluster $cluster).Count
    $diskgroups = Get-VsanDiskGroup -Cluster $cluster
    $diskgroupcount = $diskgroups.Count
    # Calculate the number of cache disks
    $cachediskcount = 0
    foreach ($diskgroup in $diskgroups) {
        $cachediskcount += (Get-VsanDisk -VsanDiskGroup $diskgroup | Where-Object {$_.IsCacheDisk -eq $true}).Count
    }
    # Calculate the number of capacity disks
    $capacitydiskcount = 0
    foreach ($diskgroup in $diskgroups) {
        $capacitydiskcount += (Get-VsanDisk -VsanDiskGroup $diskgroup | Where-Object {$_.IsCacheDisk -eq $false}).Count
    }
    # Get vSAN version 
    $vchs = Get-VsanView -Id "VsanVcClusterHealthSystem-vsan-cluster-health-system"
    $cluster_view = (Get-Cluster -Name $cluster).ExtensionData.MoRef
    $results = $vchs.VsanVcClusterQueryVerifyHealthSystemVersions($cluster_view)
    $vsanversion = $results.VcVersion
    #Get cached vSAN health results
    $hcresults = Test-VsanClusterHealth -UseCache -Cluster $cluster
    #Get vsan space usage
    $usageresults = Get-VsanSpaceUsage -Cluster $cluster

    # Get SPBM Metrics
    $policies = Get-SpbmStoragePolicy -Namespace "VSAN" | Select Name,AnyOfRuleSets
    $vsanspbmcount = $policies.Count
    $vmcomplianceresults = Get-SpbmEntityConfiguration -VM $vsanvms
    $defaultpolicycount = ($vmcomplianceresults | Where-Object {$_.StoragePolicy.Name -eq "Virtual SAN Default Storage Policy" -and $_.ComplianceStatus -ne "notApplicable"}).Count
    $vmdkcomplianceresults = Get-SpbmEntityConfiguration -HardDisk (Get-HardDisk -VM $vsanvms)
    $vmdkcount = $vmdkcomplianceresults.Count
    $vmdksoutofcompliancecount = ($vmdkcomplianceresults | Where-Object {$_.ComplianceStatus -eq "nonCompliant"}).Count
    $pctoutofcompliance = $vmdksoutofcompliancecount / $vmdkcount * 100


Write-Host ""
Write-Host "Cluster Name: $clustername"
Write-Host "vSAN Version: $vsanversion"
Write-Host "Number of hosts in cluster: $hostcount"
Write-Host "Number of VMs on vSAN datastore: $vmcount"
Write-Host "Health check enabled: $($clusterconfig.HealthCheckEnabled)"
Write-Host "iSCSI service enabled: $($clusterconfig.IscsiTargetServiceEnabled)"
Write-Host "Performance service enabled: $($clusterconfig.PerformanceServiceEnabled)"
Write-Host "Space efficiency enabled: $($clusterconfig.SpaceEfficiencyEnabled)"
Write-Host "vSAN encryption enabled: $encryptionenabled"
Write-Host "Streched cluster enabled: $($clusterconfig.StretchedClusterEnabled)"
Write-Host "Time of HCL update: $($clusterconfig.TimeOfHclUpdate)"
Write-Host "Number of named fault domains: $faultdomaincount"
Write-Host "Number of disk groups: $diskgroupcount"
Write-Host "Number of cache disks: $cachediskcount"
Write-Host "Number of capacity disks: $capacitydiskcount"
Write-Host "vSAN Health check:  $($hcresults.OverallHealthStatus) $($hcresults.OverallHealthDescription) [$($hcresults.TimeOfTest)]"
Write-Host "Component Limit Health: $($hcresults.LimitHealth.ComponentLimitHealth)"
Write-Host "vSAN Space Usage - CapacityGB: $($usageresults.CapacityGB)"
Write-Host "vSAN Space Usage - FreeSpaceGB: $($usageresults.FreeSpaceGB)"
Write-Host "vSAN Space Usage - VirtualDiskUsageGB: $($usageresults.VirtualDiskUsageGB)"
Write-Host "vSAN Space Usage - VMHomeUsageGB: $($usageresults.VMHomeUsageGB)"
Write-Host "vSAN Space Usage - FilesystemOverheadGB: $($usageresults.FilesystemOverheadGB)"
Write-Host "vSAN Space Usage - ChecksumOverheadGB: $($usageresults.ChecksumOverheadGB)"
Write-Host "vSAN Space Usage - PrimaryVMDataGB: $($usageresults.PrimaryVMDataGB)"
Write-Host "vSAN Space Usage - VsanOverheadGB: $($usageresults.VsanOverheadGB)"
Write-Host "vSAN Space Usage - IscsiTargetUsageGB: $($usageresults.IscsiTargetUsageGB)"
Write-Host "vSAN Space Usage - IscsiLunUsedGB: $($usageresults.IscsiLunUsedGB)"
Write-Host "vSAN Storage Policy Count: $vsanspbmcount"
Write-Host "vSAN VMs Using Default Policy: $defaultpolicycount"
Write-Host "vSan Virtual Disks Out of Compliance: $pctoutofcompliance%"
Write-Host "vSAN Storage Policies: " $policies


}





