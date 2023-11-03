
$SQLPasswordLocal = "xxxxxxx"
$SQLPasswordDB = "xxxxxxx"

$migrationInput = @{
    dmsInfo = @{
        subscriptionId = "b1d15854-94e3-416f-b716-xxxxxxxx";
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
        instanceName = "sqlmigrationviplav";
        resourceGroupName = "AzureSqlServerMigration";
        dataSource = "tcp:sqlmigrationviplav.database.windows.net,1433";
        authenticationtype = "SQLAuthentication";
        userName = "viplavuser"
        password = $(ConvertTo-SecureString -AsPlainText -Force $SQLPasswordDB);
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
    # Connect to your Azure account and set subscription
    Connect-AzAccount -Subscription $migrationInput.dmsInfo.subscriptionId;

    # Create an instance of Database Migration Service
    ##New-AzDataMigrationSqlService -ResourceGroupName $migrationInput.dmsInfo.resourceGroupName -Name $migrationInput.dmsInfo.serviceName -Location $migrationInput.dmsInfo.location;

# Step 2- Register Database Migration Service with self-hosted Integration Runtime
    # Register Database Migration Service with self-hosted Integration Runtime
    ## $authKeys = Get-AzDataMigrationSqlServiceAuthKey -ResourceGroupName $migrationInput.dmsInfo.resourceGroupName -SqlMigrationServiceName $migrationInput.dmsInfo.serviceName;
    ## Register-AzDataMigrationIntegrationRuntime -AuthKey $authKeys.AuthKey1 -IntegrationRuntimePath $shirMsiPath;


# Step 3- Schema deployment using SqlPackage (DACPAC). Skip step 3 if schema at the target database already exists.

    # (optional)- Invoke a function to perform schema deployment using SqlPackage (DACPAC). 
function Invoke-SqlSchemaDeployment {
    # Download SqlPackage from Microsoft
    Get-SqlPackageBinaries -outputBasePath $PSScriptRoot;

    # Extract schema as from source as dacpac
    $dacpacPath = ("{0}\{1}.dacpac" -f $PSScriptRoot, $migrationInput.sqlSource.databaseName);
    $extractArgs = @(
        "/Action:Extract",
        "/TargetFile:""$dacpacPath""",
        "/p:ExtractAllTableData=false",
        "/p:ExtractReferencedServerScopedElements=false",
        "/p:VerifyExtraction=true",
        "/p:IgnoreUserLoginMappings=true", ###
        "/SourceServerName:$($migrationInput.sqlSource.dataSource)",
        "/SourceDatabaseName:$($migrationInput.sqlSource.databaseName)",
        "/SourceUser:$($migrationInput.sqlSource.userName)",
        "/SourcePassword:$(ConvertTo-UnSecureString -password $migrationInput.sqlSource.password)",
        "/SourceTrustServerCertificate:true");

    # run the cmd
    & "$script:sqlPackagePath" @extractArgs | Out-Null;

    # check exit code
    if ($LastExitCode -eq 0) {
        Write-Host ("Info: Extract of $dacpacPath completed") -ForegroundColor Green;
    } else {
        Write-Error ("Error: Failed to extract schema from source. ExitCode={0}." -f $LastExitCode);
    }

    # Publish schema to target using dacpac from previous step
    $publishArgs = @(
        "/Action:Publish",
        "/SourceFile:""$dacpacPath""",
        "/p:CreateNewDatabase=false",
        "/p:AllowIncompatiblePlatform=true",
        "/p:ExcludeObjectTypes=Users;RoleMembership",
        "/Diagnostics:false",
        "/TargetServerName:$($migrationInput.sqlTarget.dataSource)",
        "/TargetDatabaseName:$($migrationInput.sqlTarget.databaseName)",
        "/TargetUser:$($migrationInput.sqlTarget.userName)",
        "/TargetPassword:$(ConvertTo-UnSecureString -password $migrationInput.sqlTarget.password)",
        "/TargetTrustServerCertificate:true");

    # run the cmd
    & "$script:sqlPackagePath" @publishArgs | Out-Null;
    if ($LastExitCode -eq 0) {
        Write-Host ("Info: Publish of $dacpacPath completed") -ForegroundColor Green;
    } else {
        Write-Error ("Error: Failed to publish schema to target. ExitCode={0}." -f $LastExitCode);
    }
}


function Get-SqlPackageBinaries {
    param(
        [Parameter(Mandatory=$true)]
        [string]$outputBasePath
    )
    # reference : https://docs.microsoft.com/en-us/sql/tools/sqlpackage/sqlpackage?view=sql-server-ver16
    $sqlPackageUri = $sqlPackageDownloadPath;
    $outSqlPackagePath = "$outputBasePath\SqlPackagex64";
    $sqlPackageZipPath = "$outSqlPackagePath.zip";
    $sqlPackageExePath = "$outSqlPackagePath\SqlPackage.exe";

    if (-not(Test-Path -Path $sqlPackageExePath)) {
        Write-Host ("Downloading SqlPackage binaries to '{0}'" -f $outSqlPackagePath);
        # Start-BitsTransfer -Source $sqlPackageUri -Destination $sqlPackageZipPath;
        
        $ProgressPreference = 'SilentlyContinue';
        Invoke-WebRequest -Uri $sqlPackageUri -OutFile $sqlPackageZipPath;

        Expand-Archive -Path $sqlPackageZipPath -DestinationPath $outSqlPackagePath -Force;
    }

    # Ensure SqlPackage.exe exists
    if (-not (Test-Path -Path $sqlPackageExePath)) {
        throw ("Error: Could not find '{0}'" -f $sqlPackageExePath);
    }

    $script:sqlPackagePath = $sqlPackageExePath;
}



function ConvertTo-UnSecureString {
    param( [SecureString]$password )
    if ($password.GetType().Name -eq "SecureString") {
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto($([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)));
    } else { return $password; }
}

    # Call this function to perform schema deployment using SqlPackage (DACPAC). Skip the entire step 3 if schema at the target database already exists.

#Invoke-SqlSchemaDeployment



# Step 4- Start Database Migration (Offline) to Azure SQL Database

    # Call DMS to perform the Database migration to Azure SQL Database (offline)
    $dmsResId = $("/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.DataMigration/SqlMigrationServices/{2}" -f $migrationInput.dmsInfo.subscriptionId, $migrationInput.dmsInfo.resourceGroupName, $migrationInput.dmsInfo.serviceName);
    $sqldbResId = $("/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Sql/servers/{2}" -f $migrationInput.dmsInfo.subscriptionId, $migrationInput.sqlTarget.resourceGroupName, $migrationInput.sqlTarget.instanceName);
    New-AzDataMigrationToSqlDb `
        -ResourceGroupName $migrationInput.sqlTarget.resourceGroupName `
        -SqlDbInstanceName $migrationInput.sqlTarget.instanceName `
        -TargetDbName $migrationInput.sqlTarget.databaseName `
        -MigrationService $dmsResId `
        -Scope $sqldbResId `
        -SourceSqlConnectionAuthentication "SqlAuthentication" `
        -SourceSqlConnectionDataSource $migrationInput.sqlSource.dataSource `
        -SourceSqlConnectionUserName $migrationInput.sqlSource.userName `
        -SourceSqlConnectionPassword $migrationInput.sqlSource.password `
        -SourceDatabaseName $migrationInput.sqlSource.databaseName `
        -TargetSqlConnectionAuthentication "SqlAuthentication" `
        -TargetSqlConnectionDataSource $migrationInput.sqlTarget.dataSource `
        -TargetSqlConnectionPassword $migrationInput.sqlTarget.password `
        -TargetSqlConnectionUserName $migrationInput.sqlTarget.userName `
        -WarningAction SilentlyContinue;

# Step 5- Monitoring Database Migration
    # Monitoring Migration
    Get-AzDataMigrationToSqlDb -ResourceGroupName $migrationInput.sqlTarget.resourceGroupName -SqlDbInstanceName $migrationInput.sqlTarget.instanceName -TargetDbName $migrationInput.sqlTarget.databaseName

}


# Calling main function to start end to end database migration workflow
Invoke-Main
