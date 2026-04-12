Write-Host "===== DNS WINDOWS ====="

# En esta parte se realiza la instalacion DNS si no existe
if(!(Get-WindowsFeature -Name DNS).Installed) {
    Install-WindowsFeature DNS -IncludeManagementTools
} else {
    Write-Host "DNS ya instalado"
}

#introduccion de datos
$ip = Read-Host "IP destino"

#creamos la zona si no existe
if(!(Get-DnsServerZone -Name "reprobados.com" -ErrorAction SilentlyContinue)) {
    Add-DnsServerPrimaryZone -Name "reprobados.com" -ZoneFile "reprobados.com.dns"
    Write-Host "Zona creada"
} else {
    Write-Host "Zona ya existente"
}

#Creacion de registros
Add-DnsServerResourceRecordA -Name "@" -ZoneName "reprobados.com" -IPv4Address $ip -ErrorAction SilentlyContinue
Add-DnsServerResourceRecordA -Name "www" -ZoneName "reprobados.com" -IPv4Address $ip -ErrorAction SilentlyContinue

#Reiniciamos el servicio
Restart-Service DNS

#verificacion
Get-DnsServerZone
Write-Host "DNS configurado"
