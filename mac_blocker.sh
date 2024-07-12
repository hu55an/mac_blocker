#!/bin/bash

# ----------------------------------------------------------------------
# Nome do Script: mac_blocker.sh / mac_blocker
# Descrição:
# Script para gerenciar listas de controle de acesso (whitelist/blacklist)
# baseadas em MAC addresses para interfaces e VLANs específicas usando iptables.
# Versão: 1.2
# Data de Criação: 11-07-2024
# Última Atualização: 11-07-2024
# Autor: Huemmer da Silva Santana
# ----------------------------------------------------------------------
#
# Detalhes:
#   - Requer privilégios de root/sudo para execução.
#   - Usa um diretório de configuração padrão em /etc/mac_block/conf/.
#   - Valida e formata MAC addresses antes de adicionar à lista.
#   - Permite adicionar múltiplos MACs de uma vez.
#   - Suporte para adicionar MACs a partir de um arquivo (um MAC por linha).
#   - Aplica as regras de iptables somente na interface ou VLAN especificada.
#   - Solicita confirmação antes de aplicar as políticas.
#   - Evita conflito com regras existentes no iptables.
#   - Permite verificar o que será executado com o iptables antes de aplicar.
#   - Permite aplicar políticas usando configurações existentes sem especificar interface ou VLAN.
#
# ---------------------------------------------------------------------

# Verifica se o script está sendo executado como root ou com sudo
if [ "$(id -u)" != "0" ]; then
   echo "Este script deve ser executado como root ou com sudo." 1>&2
   exit 1
fi

# Definição de variáveis
CONFIG_DIR="/etc/mac_block/conf"
WHITELIST_FILE="$CONFIG_DIR/whitelist.txt"
BLACKLIST_FILE="$CONFIG_DIR/blacklist.txt"
CONFIG_FILE="$CONFIG_DIR/mac_blocker_config.txt"
VLAN=""
MODE=""
INTERFACE=""
VERIFY=false
USE_EXISTING=false

# Variáveis para o relatório
MACS_INITIAL=0
MACS_ADDED=0
MACS_REMOVED=0
MACS_FAILED=0
FAILED_MACS=()

# Função de ajuda
show_help() {
    echo "Uso: sudo $0 [opções]"
    echo "Este script deve ser executado com privilégios de root/sudo."
    echo "Opções:"
    echo "  -i, --interface <if>   Especifica a interface de rede (ex: eth0)"
    echo "  -v, --vlan <id>        Especifica o ID da VLAN"
    echo "  -m, --mode <modo>      Define o modo (whitelist ou blacklist)"
    echo "  -a, --add <mac>        Adiciona um ou mais MACs (separados por espaço)"
    echo "  -r, --remove <mac>     Remove um ou mais MACs (separados por espaço)"
    echo "  -f, --file <arquivo>   Adiciona MACs de um arquivo"
    echo "  -l, --list             Lista os MACs armazenados"
    echo "  -p, --apply            Aplica as regras no IPtables"
    echo "  -e, --existing         Usa configurações existentes ao aplicar (não requer interface ou VLAN)"
    echo "  -V, --verify           Verifica as regras sem aplicá-las"
    echo "  -h, --help             Mostra esta mensagem de ajuda"
    exit 0
}

# Função para criar o diretório de configuração se não existir
create_config_dir() {
    if [ ! -d "$CONFIG_DIR" ]; then
        echo "Diretório de configuração não encontrado em $CONFIG_DIR."
        echo "Tentando criar o diretório..."
        if mkdir -p "$CONFIG_DIR"; then
            chmod 755 "$CONFIG_DIR"
            echo "Diretório de configuração criado com sucesso em $CONFIG_DIR"
        else
            echo "Falha ao criar o diretório de configuração em $CONFIG_DIR"
            exit 1
        fi
    fi
}

# Cria o diretório de configuração
create_config_dir

# Função para adicionar MAC
add_mac() {
    local mac=$(validate_mac "$1")
    if [ -n "$mac" ]; then
        local file
        if [ "$MODE" == "whitelist" ]; then
            file="$WHITELIST_FILE"
        elif [ "$MODE" == "blacklist" ]; then
            file="$BLACKLIST_FILE"
        else
            echo "Modo inválido. Use 'whitelist' ou 'blacklist'."
            return 1
        fi
        
        if grep -q "^$mac$" "$file"; then
            echo "MAC $mac já está cadastrado na $MODE."
        else
            echo "$mac" >> "$file"
            echo "MAC $mac adicionado à $MODE."
            ((MACS_ADDED++))
        fi
    else
        echo "MAC inválido: $1"
        ((MACS_FAILED++))
        FAILED_MACS+=("$1")
    fi
}

# Função para remover MAC
remove_mac() {
    local mac=$(validate_mac "$1")
    if [ -n "$mac" ]; then
        if [ "$MODE" == "whitelist" ]; then
            if sed -i "/^$mac$/d" "$WHITELIST_FILE"; then
                echo "MAC $mac removido da $MODE."
                ((MACS_REMOVED++))
            fi
        elif [ "$MODE" == "blacklist" ]; then
            if sed -i "/^$mac$/d" "$BLACKLIST_FILE"; then
                echo "MAC $mac removido da $MODE."
                ((MACS_REMOVED++))
            fi
        else
            echo "Modo inválido. Use 'whitelist' ou 'blacklist'."
            return 1
        fi
    else
        echo "MAC inválido: $1"
        ((MACS_FAILED++))
        FAILED_MACS+=("$1")
    fi
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

# Função para gerar relatório
generate_report() {
    local current_macs=$(wc -l < "${MODE}_FILE")
    echo "Relatório de operações:"
    echo "MACs iniciais: $MACS_INITIAL"
    echo "MACs adicionados: $MACS_ADDED"
    echo "MACs removidos: $MACS_REMOVED"
    echo "MACs com falha na operação: $MACS_FAILED"
    echo "Total de MACs atual: $current_macs"
    
    if [ ${#FAILED_MACS[@]} -gt 0 ]; then
        echo "MACs com erro:"
        for mac in "${FAILED_MACS[@]}"; do
            echo "  - $mac"
        done
    fi
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
        else
            echo "Modo inválido. Use 'whitelist' ou 'blacklist'."
            return 1
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
        else
            echo "Modo inválido. Use 'whitelist' ou 'blacklist'."
            return 1
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

# Função para salvar configurações
save_config() {
    echo "INTERFACE=$INTERFACE" > "$CONFIG_FILE"
    echo "VLAN=$VLAN" >> "$CONFIG_FILE"
    echo "MODE=$MODE" >> "$CONFIG_FILE"
    chmod 644 "$CONFIG_FILE"
}

# Função para carregar configurações
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        echo "Arquivo de configuração não encontrado em $CONFIG_FILE. Use -i, -v, e -m para definir as configurações."
        exit 1
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

    # Se estiver usando configurações existentes, carregue-as
    if [ "$USE_EXISTING" = true ]; then
        load_config
    fi

    # Verifica se temos as informações necessárias
    if [ -z "$INTERFACE" ] || [ -z "$MODE" ]; then
        echo "INTERFACE e MODE são obrigatórios. Use -i e -m para defini-los ou --existing para usar configurações salvas."
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
        # Salva as configurações após aplicar com sucesso
        save_config
    else
        echo "Verificação concluída. Nenhuma regra foi aplicada."
    fi
}

# Cria o diretório de configuração
create_config_dir

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
            shift
            ;;
        -e|--existing)
            USE_EXISTING=true
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

# Cria arquivos de lista se não existirem
touch "$WHITELIST_FILE" "$BLACKLIST_FILE"
chmod 644 "$WHITELIST_FILE" "$BLACKLIST_FILE"

# Conta o número inicial de MACs
if [ -n "$MODE" ]; then
    if [ "$MODE" == "whitelist" ] && [ -f "$WHITELIST_FILE" ]; then
        MACS_INITIAL=$(wc -l < "$WHITELIST_FILE")
    elif [ "$MODE" == "blacklist" ] && [ -f "$BLACKLIST_FILE" ]; then
        MACS_INITIAL=$(wc -l < "$BLACKLIST_FILE")
    fi
fi

# Verifica ou aplica as regras com base na opção de verificação
if [ "$VERIFY" = true ]; then
    apply_or_verify_rules true
elif [ "$USE_EXISTING" = true ]; then
    apply_or_verify_rules false
elif [ -n "$INTERFACE" ] && [ -n "$MODE" ]; then
    # Pergunta se deseja aplicar as políticas
    read -p "Deseja aplicar as políticas agora? (s/n): " apply_now
    if [[ $apply_now =~ ^[Ss]$ ]]; then
        apply_or_verify_rules false
    fi
else
    echo "Use -i, -v, e -m para definir as configurações ou --existing para usar configurações salvas."
    show_help
fi

# Adicionar a geração do relatório no final do script
generate_report
