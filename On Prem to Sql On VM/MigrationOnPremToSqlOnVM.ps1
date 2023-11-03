
$SQLPasswordLocal = "VC#net1986@"
$SQLPasswordVM = "VM#net1986@!#"

$migrationInput = @{
    dmsInfo = @{
        subscriptionId = "b1d15854-94e3-416f-b716-fc165ae430a7";
        resourceGroupName = "AzureSqlServerMigration";
        serviceName = "datamigrationservice";
        location = "East US";
    };
    sqlSource = @{
        dataSource = "Viplav-Anand";
        userName = "viplavuser";
        password = $(ConvertTo-SecureString -AsPlainText -Force $SQLPasswordLocal);
        authenticationtype = "SQLAuthentication";
        databaseName = "AdventureWorks2012"
    };
    sqlTarget = @{
        SqlVirtualMachineName = "AzureSqlVm";
        resourceGroupName = "AzureSqlServerMigration";
        authenticationtype = "SQLAuthentication";
        userName = "AzureSqlVMUser"
        password = $(ConvertTo-SecureString -AsPlainText -Force $SQLPasswordVM);
        databaseName = "AdventureWorks2012"
    };
};


# Step 0- Migration (EOF) variables
$shirMsiPath = "C:\Users\vianand\Downloads\IntegrationRuntime_5.33.8649.1.msi";
$sqlPackageDownloadPath = "C:\YY - Projects\TD\sqlpackage-win7-x64-en-162.0.52.1.zip";
$script:sqlPackagePath = $null;


# Step 1- Create an instance of Database Migration Service 
# Main section of the script
function Invoke-Main {
    Connect-AzAccount -Subscription $migrationInput.dmsInfo.subscriptionId;
    Set-AzContext -Subscription $migrationInput.dmsInfo.subscriptionId;
#New-AzResourceGroup -ResourceGroupName $migrationInput.dmsInfo.resourceGroupName -Location EastUS2;

#New-AzDataMigrationSqlService -ResourceGroupName $migrationInput.dmsInfo.resourceGroupName -Name $migrationInput.dmsInfo.serviceName -Location $migrationInput.dmsInfo.location

#$authKeys = Get-AzDataMigrationSqlServiceAuthKey -ResourceGroupName $migrationInput.dmsInfo.resourceGroupName -SqlMigrationServiceName $migrationInput.dmsInfo.serviceName


#Register-AzDataMigrationIntegrationRuntime -AuthKey $authKeys.AuthKey1 -IntegrationRuntimePath $shirMsiPath
#Register-AzDataMigrationIntegrationRuntime -AuthKey $authKeys.AuthKey1


#$sourcePass = ConvertTo-SecureString "password" -AsPlainText -Force
#$sourcrFileSharePass = ConvertTo-SecureString "password" -AsPlainText -Force

#$($migrationInput.dmsInfo.subscriptionId)


####  For Online migration remove the last offline switch

New-AzDataMigrationToSqlVM `
    -ResourceGroupName  $migrationInput.sqlTarget.resourceGroupName `
    -SqlVirtualMachineName  $migrationInput.sqlTarget.SqlVirtualMachineName `
    -TargetDbName $migrationInput.sqlTarget.databaseName `
    -Kind "SqlVM" `
    -Scope "/subscriptions/b1d15854-94e3-416f-b716-fc165ae430a7/resourceGroups/AzureSqlServerMigration/providers/Microsoft.SqlVirtualMachine/sqlVirtualMachines/azuresqlvm" `
    -MigrationService "/subscriptions/b1d15854-94e3-416f-b716-fc165ae430a7/resourceGroups/AzureSqlServerMigration/providers/Microsoft.DataMigration/sqlMigrationServices/datamigrationservice" `
    -AzureBlobStorageAccountResourceId "/subscriptions/b1d15854-94e3-416f-b716-fc165ae430a7/resourceGroups/AzureSqlServerMigration/providers/Microsoft.Storage/storageAccounts/azuresqlstorageforvm" `
    -AzureBlobAccountKey "0qmCmP6ndgYoDORuc8NyViB+uXi4VzM2iwYVIuPWVNYmLBVrsluhdvfHZBAAN8Rwv1Mioz20c5bY+AStLrZUHQ==" `
    -AzureBlobContainerName "backup" `
    -SourceSqlConnectionAuthentication "SqlAuthentication" `
    -SourceSqlConnectionDataSource $migrationInput.sqlSource.dataSource `
    -SourceSqlConnectionUserName $migrationInput.sqlSource.userName `
    -SourceSqlConnectionPassword $migrationInput.sqlSource.password `
    -SourceDatabaseName $migrationInput.sqlSource.databaseName `
    -Offline `
    -OfflineConfigurationLastBackupName "AdventureWorks2022.bak"


function ConvertTo-UnSecureString {
    param( [SecureString]$password )
    if ($password.GetType().Name -eq "SecureString") {
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto($([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)));
    } else { return $password; }
}


# Monitoring Database Migration
    $migDetails = Get-AzDataMigrationToSqlVM -ResourceGroupName $migrationInput.sqlTarget.resourceGroupName -SqlVirtualMachineName $migrationInput.sqlTarget.SqlVirtualMachineName  -TargetDbName $migrationInput.sqlTarget.databaseName -Expand MigrationStatusDetails

    #ProvisioningState should be Creating, Failed or Succeeded
    $migDetails.ProvisioningState | Format-List

    #MigrationStatus should be InProgress, Canceling, Failed or Succeeded
    $migDetails.MigrationStatus | Format-List

    #To view migration details at each backup file level
    $migDetails.MigrationStatusDetail | select *
}


# Calling main function to start end to end database migration workflow
Invoke-Main
