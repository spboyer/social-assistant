metadata description = 'Creates an Azure Static Web Apps instance.'
param name string
param location string = resourceGroup().location
param tags object = {}
param sku object = {
  name: 'Free'
  tier: 'Free'
}

resource web 'Microsoft.Web/staticSites@2022-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {}
  sku: sku
  
}

output name string = web.name
output uri string = 'https://${web.properties.defaultHostname}'
