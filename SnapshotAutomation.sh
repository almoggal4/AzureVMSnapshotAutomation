# consistence paramters
$RG_NAME = "rg1"
$VM_NAME = "test1"
$DEST_EMAIL = "almoggal11@gmail.com"
$FROM_EMAIL = "ofirgal11@outlook.com"
# scopes moudles of automation account
Enable-AzureRmAlias -Scope Process
# Forces the script to use proper TLS
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12






# Connect to azure with password: az ad sp create-for-rbac --name snap1 --role "Disk Snapshot Contributor" --scopes /subscriptions/<subscription id>/resourceGroups/<resource group name>
$TENANT_ID = "d597d379-d9d9-4ebb-9052-f2d218fabbc1"
$PASSWORD = "GgP8Q~avP4ybYgcV-MhxW2HBSuLnexjo3vGkfa87"
$APP_ID = '1bd7809d-c862-4566-ba36-02cff3caaa92'


$passwd = ConvertTo-SecureString $PASSWORD -AsPlainText -Force
$pscredential = New-Object System.Management.Automation.PSCredential($APP_ID, $passwd)
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $TENANT_ID




# get all disks.
$disk_list = Get-AzureRmResource -ResourceType "Microsoft.Compute/disks"


# get the current time of the snapshot with '_' format
$snapshot_time = Get-Date -Format "_dd_MM_yyyy_HH_mm"


# Contect of summery mail
$content = ""


# create incremental snapshots of VM_NAME disks.
foreach($disk in $disk_list){
    #$tags = $disk.Tags
    if($disk.Tags.Values -eq $VM_NAME){
        $snapshot_name = $disk.name + $snapshot_time
        try{
            $disk_snap = Get-AzDisk -DiskName $disk.name -ResourceGroupName $RG_NAME
            $snapshotConfig = New-AzSnapshotConfig -SourceUri $disk_snap.Id -Location $disk_snap.Location -CreateOption Copy -Incremental -Tag @{vm=$VM_NAME}
            New-AzSnapshot -ResourceGroupName $RG_NAME -SnapshotName $snapshot_name -Snapshot $snapshotConfig | Out-Null
            $s_snap = "SNAPSHOT TAKE OF $snapshot_name SUCCEEDED `n"
            $content += $s_snap
        }
        # if the snapshot take has failed
        catch{
            $err_msg = $($PSItem.Exception.Message.ToString())
            #Write-Output $err_msg
            $f_snap = "SNAPSHOT TAKE OF $snapshot_name FAILED: $err_msg `n"
            $content += $f_snap
        }
    }
}


# Delete snapshots after 24 hours of VM_NAME disks
$snapshots = Get-AzSnapshot
foreach($snapshot in $snapshots){
    # for every snapshot of the vm
    if($snapshot.Tags.values -eq $VM_NAME){
        # if the snapshot exists more then 24 hours
        $snapshot_name = $snapshot.name
        if($snapshot.TimeCreated -lt (Get-Date).AddDays(-1).ToUniversalTime()){
            try{
                Remove-AzSnapshot -ResourceGroupName $RG_NAME -SnapshotName $snapshot_name -ErrorAction Stop -Force;
                $s_snap = "SNAPSHOT DELETION OF $snapshot_name SUCCEEDED `n"
                $content += $s_snap 
            }
            # if deletion has failed
            catch{
                $err_msg = $($PSItem.Exception.Message.ToString())
                $f_snap = "SNAPSHOT DELETION OF $snapshot_name FAILED: $err_msg `n"
                $content += $f_snap
            }
            
        }
    }
}
Write-Output $content
# The send grid key from the send grid account
$SENDGRID_API_KEY = "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"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer " + $SENDGRID_API_KEY)
$headers.Add("Content-Type", "application/json")


# subject of the mail
$subject = "Hourly snapshot of $snapshot_time"


$body = @{
personalizations = @(
    @{
        to = @(
                @{
                    email = $DEST_EMAIL
                }
        )
    }
)
from = @{
    email = $FROM_EMAIL
}
subject = $subject
content = @(
    @{
        type = "text/plain"
        value = $content
    }
)
}


$bodyJson = $body | ConvertTo-Json -Depth 4


$response = Invoke-RestMethod -Uri https://api.sendgrid.com/v3/mail/send -Method Post -Headers $headers -Body $bodyJson
