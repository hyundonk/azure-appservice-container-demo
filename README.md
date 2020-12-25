# azure-appservice-container-demo



본 테라폼 코드는 App Service for Linux container demo를 위한 리소스들을 아래 그림과 같은 구성으로 생성합니다. 

![img](https://documents.lucid.app/documents/b5fd55d6-f54a-4cdd-9bd2-110a9a04cada/pages/mXwzAnnOLpm1?a=594&x=59&y=318&w=1635&h=715&store=1&accept=image%2F*&auth=LCA%2037fd2407bbb1514c115eac1e07d59da159d6a69f-ts%3D1608824497)

아래 문서에 container 이미지를 만들고, 컨테이너 레지스트리에 push하고 App Service에서 해당 이미지를 pull하여 container를 구동하는 방법 등이 기술되어 있습니다. 

[Tutorial: Build and run a custom image in Azure App Service - Azure App Service | Microsoft Docs](https://docs.microsoft.com/en-us/azure/app-service/tutorial-custom-container?pivots=container-linux)



**원격 저장소**

App Services for Linux Container는 다음의 Persistent 저장소 옵션을 제공합니다. 

1. Azure managed storage: WEBSITES_ENABLE_APP_SERVICE_STORAGE App Setting 변수가 true로 설정해야 합니다. Container내에서 /home 경로로 mount됩니다. 
2. Customer storage account: 고객이 생성한 고객 storage account를 mount합니다. blob container (Read only만 지원) 또는 file share (Read/Write 가능)를 mount할 수 있습니다.

본 데모에서는 아래 코드와 같이 customer storage account 옵션을 사용하여 고객 storage account의 file share 를 컨테이너 내의 /mount 경로로 mount합니다.  

``` Terraform
storage_account {
    name       = azurerm_storage_account.example.name
    account_name = azurerm_storage_account.example.name
    type       = "AzureFiles"
    access_key = azurerm_storage_account.example.primary_access_key
    share_name = azurerm_storage_share.example.name
    mount_path = "/mount"
  }
```





**Azure Container Registry**

Application에서 사용할 container image를 가지고 있습니다. App Service의 앱은 시작시 해당 Azure Container Registry에서 지정된 application container image를 pull한 뒤 container를 구동합니다. 본 데모에서는 아래 Azure CLI 명령을 이용하여 ACR에 접근을 위한 password를 할당 받았습니다. 실제 Production 환경에서는 Managed Identity를 생성하여 해당 Identity에 해당 ACR 리소스에 대한 "ACRPull" 권한을 부여하고 App Service에 해당 Identity를 연결하는 방법을 권고합니다. (https://docs.microsoft.com/en-us/azure/container-registry/container-registry-authentication-managed-identity 참조). Container 이미지를 생성하고 ACR에 push한는 방법은 https://docs.microsoft.com/en-us/azure/app-service/configure-custom-container 문서를 참조하시기 바랍니다. 

```
# Login to ACR
az acr login --name {acr-name} 

# Get credential 
az acr credential show --resource-group {resource-group-name} --name {acr-name}
```


**Application Gateway WAF**

Application Gateway의 WAF 기능은 App Service에서 구동되는 앱에 대한 웹 방화벽 기능을 제공하며 또한 SSL offload 기능을 제공합니다. 본 데모에서는 SSL offload 모드로 Application Gateway에서 App Service로 보내는 요청은 plain HTTP로 보내집니다. Application Gateway는 End-to-end로 SSL encryption을 적용하여 연결하는 모드도 지원하며 실제 production 환경에서는 end-to-end SSL 모드를 권고합니다. End-to-end encryption을 위해서는 Root CA certificate를 포함한 전체 certificate chain이 업로드 되어야 합니다.  https://docs.microsoft.com/en-us/azure/application-gateway/ssl-overview 참조



**Key Vault**

SSL certificate를 생성하여 Key Vault로 import하여 관리합니다. Application Gateway는 시작시 해당 Key Vault에서 SSL certificate를 가져와 사용합니다. Application Gateway에서 Key Vault의 Certificate에 접근(Read)할 수 있도록 managed identity를 생성하여 Application Gateway 리소스에 부여하고 해당 Identity에 Key Vault certificate의 access policy에 Read 권한을 부여합니다. 


**Self-Signed 인증서 만드는 방법은 아래 참조.**

https://docs.microsoft.com/en-us/azure/application-gateway/tutorial-ssl-powershell#create-a-self-signed-certificate

 ```

 
참고문서

https://docs.microsoft.com/en-us/azure/app-service/configure-connect-to-azure-storage?pivots=container-linux
https://docs.microsoft.com/en-us/azure/app-service/configure-custom-container?pivots=container-linux#use-persistent-shared-storage
https://docs.microsoft.com/en-us/azure/app-service/troubleshoot-diagnostic-logs
https://docs.microsoft.com/en-us/azure/container-registry/container-registry-authentication


 ```



