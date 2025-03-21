#=================
# Raquel Rodriguez
# 2025-03-21
# Powershell version: 5.1
# Descripción: Crea un VPC con sus subredes asociadas, igw, igwNAT y rutas
#=================
# Configurar la región
$region = "us-east-1"
#
$bloque_cidr_vpc = "10.10.0.0/16"
$bloque_subred_publica = "10.10.1.0/24"
$bloque_subred_privada = "10.10.2.0/24"

# Crear el VPC
Write-Host "==10: crea vpc"
$vpcId = (aws ec2 create-vpc `
    --cidr-block $bloque_cidr_vpc  `
    --region $region `
    --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=lapolla14}]' `
    --query 'Vpc.VpcId' --output text)
# Habilitar la resolución de DNS
Write-Host "==11: modifica VPC: Habilita DNS"
aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-support --region $region

# Habilitar nombres de host DNS
Write-Host "==12: modifica VPC: Habilita DNS-host"
aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-hostnames --region $region

# Crear la subred pública
Write-Host "==20: crea Subred Publica"
$publicSubnetId = (aws ec2 create-subnet `
    --vpc-id $vpcId `
    --cidr-block $bloque_subred_publica `
    --region $region --availability-zone "us-east-1a" `
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=vpc-fhw-publica}]' `
    --query 'Subnet.SubnetId' --output text)

# Crear la subred privada
Write-Host "==30: crea Subred Privada"
$privateSubnetId = (aws ec2 create-subnet `
    --vpc-id $vpcId `
    --cidr-block $bloque_subred_privada `
    --region $region --availability-zone "us-east-1a" `
    --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=vpc-fhw-privada}]' `
    --query 'Subnet.SubnetId' --output text)

# Crear la gateway de Internet
Write-Host "==40: crea Internet-Gateway"
$internetGatewayId = (aws ec2 create-internet-gateway `
    --region $region --query 'InternetGateway.InternetGatewayId' --output text)

# Asociar la gateway de Internet con el VPC
Write-Host "==50: asocia Internet-Gateway -> VPC"
aws ec2 attach-internet-gateway `
    --vpc-id $vpcId `
    --internet-gateway-id $internetGatewayId `
    --region $region

# Crear una tabla de rutas para la subred pública
Write-Host "==60: crea tabla-rutas publica"
$publicRouteTableId = (aws ec2 create-route-table `
    --vpc-id $vpcId --region $region `
    --query 'RouteTable.RouteTableId' --output text)

# Crear una ruta en la tabla de rutas pública que apunte a la gateway de Internet
aws ec2 create-route --route-table-id $publicRouteTableId --destination-cidr-block 0.0.0.0/0 --gateway-id $internetGatewayId --region $region

# Asociar la tabla de rutas pública con la subred pública
aws ec2 associate-route-table --subnet-id $publicSubnetId --route-table-id $publicRouteTableId --region $region

# Habilitar la asignación automática de IPs públicas en la subred pública
aws ec2 modify-subnet-attribute --subnet-id $publicSubnetId --map-public-ip-on-launch --region $region

# Crear una gateway NAT
Write-Host "==70: crea GatewayNAT"
$natGatewayId = (aws ec2 create-nat-gateway --subnet-id $publicSubnetId --allocation-id $(aws ec2 allocate-address --query 'AllocationId' --output text --region $region) --region $region --query 'NatGateway.NatGatewayId' --output text)

# Esperar a que la gateway NAT esté disponible
aws ec2 wait nat-gateway-available --nat-gateway-ids $natGatewayId --region $region

# Crear una tabla de rutas para la subred privada
Write-Host "==80: crea tabla-rutas privada"
$privateRouteTableId = (aws ec2 create-route-table --vpc-id $vpcId --region $region --query 'RouteTable.RouteTableId' --output text)

# Crear una ruta en la tabla de rutas privada que apunte a la gateway NAT
aws ec2 create-route --route-table-id $privateRouteTableId --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $natGatewayId --region $region

# Asociar la tabla de rutas privada con la subred privada
aws ec2 associate-route-table --subnet-id $privateSubnetId --route-table-id $privateRouteTableId --region $region
Write-Host "===== vpc-fhw ==========="
Write-Host "VPC ID: $vpcId"
Write-Host "Public Subnet ID: $publicSubnetId"
Write-Host "Private Subnet ID: $privateSubnetId"
Write-Host "Internet Gateway ID: $internetGatewayId"
Write-Host "NAT Gateway ID: $natGatewayId"

# Obtener la fecha actual en el formato deseado
$fechaActual = Get-Date -Format "yyyy-MM-dd HH:mm"

# Crear el contenido que deseas guardar en el archivo
$contenido = @"
Fecha: $fechaActual
VPC ID: $vpcId
Public Subnet ID: $publicSubnetId
Private Subnet ID: $privateSubnetId
Internet Gateway ID: $internetGatewayId
NAT Gateway ID: $natGatewayId
"@

# Guardar el contenido en un archivo de texto, sobrescribiendo si ya existe
$contenido | Out-File -FilePath "salida.txt" -Force
