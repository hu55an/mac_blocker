# mac_blocker
Script para gerenciar listas de controle de acesso (whitelist/blacklist) baseadas em MAC addresses para interfaces e VLANs específicas usando iptables.

## Detalhes:
  - Permite escolher entre modo whitelist e blacklist.
  - Armazena as listas em arquivos separados no mesmo diretório do script.
  - Permite consultar os MACs armazenados.
  - Possibilita adicionar vários MACs de uma vez.
  - Converte e valida os MACs para o formato correto do IPtables.
  - Aceita MACs com hífen ou dois pontos.
  - Permite adicionar MACs de um arquivo.
  - Analisa as regras existentes do IPtables antes de adicionar novas.
  - Pergunta se deseja aplicar as políticas após adicionar MACs.
  - Evita conflitos com regras existentes no IPtables.
  - Atua apenas na VLAN especificada.

Para usar o script, salve-o com um nome como `mac_blocker.sh` e dê permissão de execução com `chmod +x mac_blocker.sh`.

Deve ser executado como "**sudo**" ou como "**root**".

```
Uso: mac_blocker.sh [opções]
Opções:
  -i, --interface <if>   Especifica a interface de rede (ex: eth0)`
  -v, --vlan <id>        Especifica o ID da VLAN`
  -m, --mode <modo>      Define o modo (whitelist ou blacklist)`
  -a, --add <mac>        Adiciona um ou mais MACs (separados por espaço)`
  -r, --remove <mac>     Remove um ou mais MACs (separados por espaço)`
  -f, --file <arquivo>   Adiciona MACs de um arquivo
  -l, --list             Lista os MACs armazenados
  -p, --apply            Aplica as regras no IPtables
  -e, --existing         Usa configurações existentes ao aplicar (não requer interface ou VLAN)"
  -V, --verify           Verifica as regras sem aplicá-las
  -h, --help             Mostra esta mensagem de ajuda
```

## Exemplos de uso:
```
./mac_blocker.sh --vlan 10 --mode whitelist --add 00:11:22:33:44:55 AA-BB-CC-DD-EE-FF
./mac_blocker.sh --vlan 10 --mode whitelist --file macs.txt
./mac_blocker.sh --vlan 10 --mode whitelist --list
./mac_blocker.sh --vlan 10 --mode whitelist --apply

./mac_blocker.sh -v 10 -m whitelist -a 00:11:22:33:44:55 AA-BB-CC-DD-EE-FF
./mac_blocker.sh -v 10 -m whitelist -f macs.txt
./mac_blocker.sh -v 10 -m whitelist -l
./mac_blocker.sh -v 10 -m whitelist -p
```
