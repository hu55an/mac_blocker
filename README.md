# mac_blocker
Script para gerenciar listas de controle de acesso (whitelist/blacklist) baseadas em MAC addresses para interfaces e VLANs específicas usando iptables.

== Detalhes:
   - Valida e formata MAC addresses antes de adicionar à lista.
   - Permite adicionar múltiplos MACs de uma vez.
   - Suporte para adicionar MACs a partir de um arquivo (um MAC por linha).
   - Aplica as regras de iptables somente na interface ou VLAN especificada.
   - Solicita confirmação antes de aplicar as políticas.
   - Evita conflito com regras existentes no iptables.
   - Permite verificar o que será executado com o iptables antes de aplicar.
