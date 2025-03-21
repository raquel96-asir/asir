#=================
# Raquel Rodriguez
# v1.0 - 2025-03-18
# Descripción: Crea una instancia EC2 basada en Ubuntu en el VPC y subred dadas como parametros
# Powershell version: 5.1
#=================
# paso de parametros:
param (
    [Parameter(Mandatory=$true)]
    [string]$Nombre,
    [Parameter(Mandatory=$true)]
    [string]$VpcId,
    [Parameter(Mandatory=$true)]
    [string]$SubnetId
)

# Configurar la región
$region = "us-east-1"
# Configura tus variables
$instanceType = "t2.micro"  # apto para la capa gratuita
$keyName = "vockey"  # Por Defecto
$Amiid = "ami-04b4f1a9cf54c11d0" # Ubuntu Server 24.04 x64

# Crea el grupo de seguridad
Write-Host "==10: crea el grupo-de-seguridad"
$securityGroupId = aws ec2 create-security-group `
    --group-name "$Nombre-sg" `
    --description "Grupo de seguridad que abre los puertos 22 y 80" `
    --region $region `
    --vpc-id $vpcId `
    --query 'GroupId' `
    --output text

# Configura las reglas del grupo de seguridad
Write-Host "==11: abro el puerto 22"
aws ec2 authorize-security-group-ingress `
    --group-id $securityGroupId `
    --region $region `
    --protocol tcp `
    --port 22 `
    --cidr 0.0.0.0/0 `
    --output text

Write-Host "==12: abro el puerto 80"
aws ec2 authorize-security-group-ingress `
    --group-id $securityGroupId `
    --region $region `
    --protocol tcp `
    --port 80 `
    --cidr 0.0.0.0/0 `
    --output text

# Configuro la preinstalación del EC2 con instalacion de Apache
Write-Host "==20: Instalo apache"
$userData = @"
#!/bin/bash
sudo apt update -y
sudo apt install -y apache2
"@

# Convierte el script en Base64 Se convierte el script en Base64
$userDataBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($userData))
# Crea la instancia EC2
Write-Host "==21: Lanzo la EC2"
$instanceId = aws ec2 run-instances `
    --image-id $amiId `
    --instance-type $instanceType `
    --region $region `
    --key-name $keyName `
    --security-group-ids $securityGroupId `
    --subnet-id $subnetId `
    --user-data $userDataBase64 `
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$Nombre}]" `
    --associate-public-ip-address `
    --count 1 `
    --query 'Instances[0].InstanceId' `
    --output text

# Muestra el ID de la instancia creada
Write-Host "===== IaC: EC2 Ubunut + Apache2 ==========="
Write-Host "secury-group ID: $securityGroupId"
Write-Output "Instancia EC2 ID: $instanceId"
