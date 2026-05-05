#!/bin/bash

#===========================
# VARIABLES GLOBALES
#===========================

FTP_ROOT="/srv/ftp"
PUBLIC="$FTP_ROOT/general"
GRUPOS=("reprobados" "recursadores")

#===========================
# VERIFICAR ROOT
#===========================
verificar_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Ejecuta como root o con sudo"
        exit 1
    fi
}

#===========================
# INSTALAR VSFTPD
#===========================
instalar_ftp() {
    echo "=== Instalando vsftpd ==="

    if dpkg -l | grep -q vsftpd; then
        echo "vsftpd ya instalado"
    else
        apt update -y
        apt install vsftpd -y
    fi
}

#===========================
# CREAR GRUPOS
#===========================
crear_grupos() {
    echo "=== Creando grupos ==="
    for g in "${GRUPOS[@]}"; do
        groupadd $g 2>/dev/null
    done
}

#===========================
# CREAR ESTRUCTURA
#===========================
crear_estructura() {
    echo "=== Creando estructura ==="

    mkdir -p "$PUBLIC"
    for g in "${GRUPOS[@]}"; do
        mkdir -p "$FTP_ROOT/$g"
    done

    chown root:root "$FTP_ROOT"
    chmod 755 "$FTP_ROOT"

    chown root:root "$PUBLIC"
    chmod 755 "$PUBLIC"

    chmod 770 "$FTP_ROOT/reprobados"
    chmod 770 "$FTP_ROOT/recursadores"

    echo "Estructura creada"
}

#===========================
# CONFIGURAR VSFTPD
#===========================
configurar_vsftpd() {
    echo "=== Configurando vsftpd ==="

    cat > /etc/vsftpd.conf <<EOF
listen=YES
listen_ipv6=NO

anonymous_enable=YES
anon_root=/srv/ftp/general

local_enable=YES
write_enable=YES
local_umask=022

chroot_local_user=YES
allow_writeable_chroot=YES

pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000

secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
EOF

    systemctl restart vsftpd
    systemctl enable vsftpd

    echo "vsftpd listo"
}

#===========================
# CREAR USUARIO
#===========================
crear_usuario () {

    read -p "Usuario: " user
    read -s -p "Password: " pass; echo ""
    read -p "Grupo (reprobados/recursadores): " grupo

    if [[ "$grupo" != "reprobados" && "$grupo" != "recursadores" ]]; then
        echo "Grupo inválido"
        return
    fi

    if ! id "$user" &>/dev/null; then
        useradd -m $user
        echo "$user:$pass" | chpasswd
    fi

    usermod -aG $grupo $user

    HOME="/home/$user"

    mkdir -p "$HOME/$user"

    rm -rf "$HOME/general" "$HOME/reprobados" "$HOME/recursadores"

    ln -s "$PUBLIC" "$HOME/general"
    ln -s "$FTP_ROOT/$grupo" "$HOME/$grupo"

    chown -R $user:$grupo $HOME
    chmod 750 "$HOME"

    echo "Usuario $user creado correctamente"
}

#==========================
# CREACION MASIVA
#==========================
crear_usuarios() {
    read -p "Cantidad de usuarios: " n
    for ((i=1; i<=n; i++))
    do
        echo "---- Usuario $i ----"
        crear_usuario
    done
}

#==========================
# CAMBIAR GRUPO
#==========================
cambiar_grupo() {

    read -p "Usuario: " user
    read -p "Nuevo grupo: " grupo

    if [[ "$grupo" != "reprobados" && "$grupo" != "recursadores" ]]; then
        echo "Grupo inválido"
        return
    fi

    usermod -G "$grupo" "$user"

    HOME="/home/$user"

    umount "$HOME/reprobados" 2>/dev/null
    umount "$HOME/recursadores" 2>/dev/null

    rm -rf "$HOME/reprobados" "$HOME/recursadores"

    mkdir -p "$HOME/$grupo"

    mount --bind "$FTP_ROOT/$grupo" "$HOME/$grupo"

    grep -v -E "$HOME/reprobados|$HOME/recursadores" /etc/fstab > /tmp/fstab.tmp && mv /tmp/fstab.tmp /etc/fstab

    echo "$FTP_ROOT/$grupo $HOME/$grupo none bind 0 0" >> /etc/fstab

    chown -R "$user:$grupo" "$HOME"

    echo "Grupo actualizado correctamente"
}

#==========================
# ESTADO
#==========================
estado() {
    systemctl status vsftpd
}

#====================
# MENU PRINCIPAL
#====================
menu()
{
    while true
    do
        echo ""
        echo "===== FTP LINUX ====="
        echo "1. Instalar FTP"
        echo "2. Crear grupos"
        echo "3. Crear estructura"
        echo "4. Configurar FTP"
        echo "5. Crear usuarios"
        echo "6. Cambiar grupo"
        echo "7. Estado"
        echo "0. Salir"

        read -p "Opcion: " op

        case $op in
            1) instalar_ftp ;;
            2) crear_grupos ;;
            3) crear_estructura ;;
            4) configurar_vsftpd ;;
            5) crear_usuarios ;;
            6) cambiar_grupo ;;
            7) estado ;;
            0) exit ;;
            *) echo "Opcion invalida" ;;
        esac
    done
}

#====================
# EJECUCION
#====================
verificar_root
menu