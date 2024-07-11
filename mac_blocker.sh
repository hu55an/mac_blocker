#!/bin/bash

# ----------------------------------------------------------------------
# Nome do Script: mac_blocker.sh / mac_blocker
# Descrição:
# Script para gerenciar listas de controle de acesso (whitelist/blacklist)
# baseadas em MAC addresses para interfaces e VLANs específicas usando iptables.
# Versão: 1.0
# Data de Criação: 11-07-2024
# Autor: Huemmer da Silva Santana
# ----------------------------------------------------------------------
#
# Detalhes:
#   - Valida e formata MAC addresses antes de adicionar à lista.
#   - Permite adicionar múltiplos MACs de uma vez.
#   - Suporte para adicionar MACs a partir de um arquivo (um MAC por linha).
#   - Aplica as regras de iptables somente na interface ou VLAN especificada.
#   - Solicita confirmação antes de aplicar as políticas.
#   - Evita conflito com regras existentes no iptables.
#   - Permite verificar o que será executado com o iptables antes de aplicar.
#
# ---------------------------------------------------------------------

# Definição de variáveis
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
WHITELIST_FILE="$SCRIPT_DIR/whitelist.txt"
BLACKLIST_FILE="$SCRIPT_DIR/blacklist.txt"
VLAN=""
MODE=""
INTERFACE=""
VERIFY=false

# Função de ajuda
show_help() {
    echo "Uso: $0 [opções]"
    echo "Opções:"
    echo "  -i, --interface <if>   Especifica a interface de rede (ex: eth0)"
    echo "  -v, --vlan <id>        Especifica o ID da VLAN"
    echo "  -m, --mode <modo>      Define o modo (whitelist ou blacklist)"
    echo "  -a, --add <mac>        Adiciona um ou mais MACs (separados por espaço)"
    echo "  -r, --remove <mac>     Remove um ou mais MACs (separados por espaço)"
    echo "  -f, --file <arquivo>   Adiciona MACs de um arquivo"
    echo "  -l, --list             Lista os MACs armazenados"
    echo "  -p, --apply            Aplica as regras no IPtables"
    echo "  -V, --verify           Verifica as regras sem aplicá-las"
    echo "  -h, --help             Mostra esta mensagem de ajuda"
    exit 0
}

# Função para validar MAC
validate_mac() {
    local mac=$1
    if [[ $mac =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
        echo "$mac" | tr '[:lower:]' '[:upper:]' | tr -d ':' | sed 's/.\{2\}/&:/g;s/:$//'
    else
        echo ""
    fi
}

# Função para adicionar MAC
add_mac() {
    local mac=$(validate_mac "$1")
    if [ -n "$mac" ]; then
        local file
        if [ "$MODE" == "whitelist" ]; then
            file="$WHITELIST_FILE"
        elif [ "$MODE" == "blacklist" ]; then
            file="$BLACKLIST_FILE"
        fi
        
        if grep -q "^$mac$" "$file"; then
            echo "MAC $mac já está cadastrado na $MODE."
        else
            echo "$mac" >> "$file"
            echo "MAC $mac adicionado à $MODE."
        fi
    else
        echo "MAC inválido: $1"
    fi
}

# Função para remover MAC
remove_mac() {
    local mac=$(validate_mac "$1")
    if [ -n "$mac" ]; then
        if [ "$MODE" == "whitelist" ]; then
            sed -i "/^$mac$/d" "$WHITELIST_FILE"
        elif [ "$MODE" == "blacklist" ]; then
            sed -i "/^$mac$/d" "$BLACKLIST_FILE"
        fi
        echo "MAC $mac removido da $MODE."
    else
        echo "MAC inválido: $1"
    fi
}

# Função para listar MACs
list_macs() {
    echo "Whitelist:"
    cat "$WHITELIST_FILE"
    echo "Blacklist:"
    cat "$BLACKLIST_FILE"
}

# Função para adicionar MACs de um arquivo
add_macs_from_file() {
    local file=$1
    if [ -f "$file" ]; then
        while IFS= read -r line; do
            add_mac "$line"
        done < "$file"
    else
        echo "Arquivo não encontrado: $file"
    fi
}

# Função para aplicar ou verificar regras no IPtables
apply_or_verify_rules() {
    local verify_mode=$1
    local action="Aplicando"
    if [ "$verify_mode" = true ]; then
        action="Verificando"
    fi

    # Verifica se o IPtables está instalado
    if ! command -v iptables &> /dev/null; then
        echo "IPtables não está instalado. Por favor, instale-o primeiro."
        exit 1
    fi

    local in_interface="$INTERFACE"
    if [ -n "$VLAN" ]; then
        in_interface="$INTERFACE.$VLAN"
    fi

    echo "$action regras para interface $in_interface no modo $MODE:"

    if [ "$verify_mode" = false ]; then
        # Limpa regras existentes para a interface especificada
        iptables -D FORWARD -i "$in_interface" -j ACCEPT 2>/dev/null
        iptables -D FORWARD -i "$in_interface" -j DROP 2>/dev/null
    fi

    if [ "$MODE" == "whitelist" ]; then
        # Adiciona regras de whitelist
        while IFS= read -r mac; do
            echo "$action: iptables -I FORWARD -i $in_interface -m mac --mac-source $mac -j ACCEPT"
            if [ "$verify_mode" = false ]; then
                iptables -I FORWARD -i "$in_interface" -m mac --mac-source "$mac" -j ACCEPT
            fi
        done < "$WHITELIST_FILE"
        # Bloqueia todo o resto
        echo "$action: iptables -A FORWARD -i $in_interface -j DROP"
        if [ "$verify_mode" = false ]; then
            iptables -A FORWARD -i "$in_interface" -j DROP
        fi
    elif [ "$MODE" == "blacklist" ]; then
        # Adiciona regras de blacklist
        while IFS= read -r mac; do
            echo "$action: iptables -I FORWARD -i $in_interface -m mac --mac-source $mac -j DROP"
            if [ "$verify_mode" = false ]; then
                iptables -I FORWARD -i "$in_interface" -m mac --mac-source "$mac" -j DROP
            fi
        done < "$BLACKLIST_FILE"
        # Permite todo o resto
        echo "$action: iptables -A FORWARD -i $in_interface -j ACCEPT"
        if [ "$verify_mode" = false ]; then
            iptables -A FORWARD -i "$in_interface" -j ACCEPT
        fi
    fi

    if [ "$verify_mode" = false ]; then
        echo "Regras aplicadas com sucesso para interface $in_interface no modo $MODE."
    else
        echo "Verificação concluída. Nenhuma regra foi aplicada."
    fi
}

# Verifica argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--interface)
            INTERFACE="$2"
            shift 2
            ;;
        -v|--vlan)
            VLAN="$2"
            shift 2
            ;;
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -a|--add)
            shift
            while [[ $# -gt 0 && ! $1 =~ ^- ]]; do
                add_mac "$1"
                shift
            done
            ;;
        -r|--remove)
            shift
            while [[ $# -gt 0 && ! $1 =~ ^- ]]; do
                remove_mac "$1"
                shift
            done
            ;;
        -f|--file)
            add_macs_from_file "$2"
            shift 2
            ;;
        -l|--list)
            list_macs
            shift
            ;;
        -p|--apply)
            apply_or_verify_rules false
            shift
            ;;
        -V|--verify)
            VERIFY=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Opção inválida: $1"
            show_help
            ;;
    esac
done

# Verifica se INTERFACE e MODE foram especificados
if [ -z "$INTERFACE" ] || [ -z "$MODE" ]; then
    echo "INTERFACE e MODE são obrigatórios."
    show_help
fi

# Cria arquivos de lista se não existirem
touch "$WHITELIST_FILE" "$BLACKLIST_FILE"

# Verifica ou aplica as regras com base na opção de verificação
if [ "$VERIFY" = true ]; then
    apply_or_verify_rules true
else
    # Pergunta se deseja aplicar as políticas
    read -p "Deseja aplicar as políticas agora? (s/n): " apply_now
    if [[ $apply_now =~ ^[Ss]$ ]]; then
        apply_or_verify_rules false
    fi
fi
