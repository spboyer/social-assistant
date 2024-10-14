targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string
@minLength(1)
@description('Primary location for all resources')
param location string
@description('Id of the user or app to assign application roles')
param principalId string
param keyVaultName string = ''
param storageAccountName string = ''
param functionAppName string = ''
param applicationInsightsName string = ''
param hostingPlanName string = ''
param staticWebAppName string = ''
param logAnalyticsName string = ''
@description('Flag to Use keyvault to store and use keys')
param useKeyVault bool = true
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
var rgName = 'rg-${environmentName}'
param azureOpenAiEndpoint string = ''
param azureOpenAiKey string = ''
param cosmosDbAccountName string = 'socialassistant'

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
  tags: tags
}

module database 'app/database.bicep' = {
  name: 'database'
  scope: rg
  params: {
    accountName: !empty(cosmosDbAccountName) ? cosmosDbAccountName : '${abbrs.documentDBDatabaseAccounts}-${resourceToken}'
    location: location
    tags: tags
  }
}

module data 'app/data.bicep' = {
  name: 'data'
  scope: rg
  params: {
    databaseAccountName: database.outputs.accountName
    tags: tags
  }
}

module keyVault 'core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

module web 'app/staticwebapp.bicep' = {
  name: 'web'
  scope: rg
  params: {
    name: !empty(staticWebAppName) ? staticWebAppName : '${abbrs.webStaticSites}${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'web' })
  }
}

module hostingPlan 'core/host/appserviceplan.bicep' = {
  name: 'hostingPlan'
  scope: rg
  params: {
    tags: tags
    location: location
    name: !empty(hostingPlanName) ? hostingPlanName : '${abbrs.webServerFarms}${resourceToken}'
    sku: {
      name: 'Y1'
      tier: 'Dynamic'
    }
    kind: 'linux'
  }
}

module logAnalytics 'core/monitor/loganalytics.bicep' ={
  name: 'logAnalytics'
  scope: rg
  params: {
    name: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.insightsComponents}${resourceToken}'
    location: location
  }
}

module applicationInsights 'core/monitor/applicationinsights.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

module functionApp 'app/functions.bicep' = {
  name: 'api'
  scope: rg
  params: {
    tags: union(tags, { 'azd-service-name': 'api' })
    location: location
    storageAccountName: storageAccount.outputs.name
    functionAppName: !empty(functionAppName) ? functionAppName : '${abbrs.webSitesFunctions}${resourceToken}'
    hostingPlanId: hostingPlan.outputs.id
    keyVaultName: keyVault.outputs.name
    applicationInsightsConnectionString: applicationInsights.outputs.connectionString
    useKeyVault: useKeyVault
    keyVaultEndpoint: keyVault.outputs.endpoint
    azureOpenAiEndpoint: azureOpenAiEndpoint
    azureOpenAiKey: azureOpenAiKey
    cosmosDatabaseConnectionString: database.outputs.endpoint
  }
}

module storageAccount 'core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    tags: tags
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
  }
}

module funcaccess './core/security/keyvault-access.bicep' = if (useKeyVault) {
  name: 'web-keyvault-access'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: functionApp.outputs.identityPrincipalId
  }
}

output AZURE_FUNCTIONAPP_NAME string = functionApp.outputs.name
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_KEY_VALUT_NAME string = keyVault.outputs.name
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output APPLICATIONINSIGHTS_CONNECTION_STRING string = applicationInsights.outputs.connectionString
output AZURE_STORAGE_NAME string = storageAccount.outputs.name
output AZURE_STATIC_WEB_URL string = web.outputs.uri
output LOG_ANALYTICS_ID string = logAnalytics.outputs.id
output USE_KEY_VAULT bool = useKeyVault

// Database outputs
output AZURE_COSMOS_DB_NOSQL_ENDPOINT string = database.outputs.endpoint
output AZURE_COSMOS_DB_NOSQL_DATABASE_NAME string = data.outputs.database.name
output AZURE_COSMOS_DB_NOSQL_CONTAINER_NAMES array = map(data.outputs.containers, c => c.name)
