#!/bin/bash
#########################################################################
##############   UNIFICAÇÃO DOS SCRIPTS DE MIGRAÇÃO  ####################
#########################################################################
#########################################################################
# AUTORES:                                                              #
# <Equipe de inteligêcia Operacional - Automações>                      #
# Ellian Silva   Especialista técnico  <ellian.silva@.com>  #
# Luciano Romao  L2                    <luciano.romao@.com> #
# Renan Souza    L2                    <renan.souza@.com>   #
#########################################################################

#cores
RESET="\e[0m"
BOLD="\e[1m"
RED="\e[31m"
YELLOW="\e[33m"
GREEN="\e[32m"
BLUE="\e[34m"
RED_ALERT="\e[41m"

#VALORES PADRÕES
SETDNS="FALSE"
REVERSE="FALSE"
RSYNC="FALSE"
SKIP_FTP_CONN="FALSE"
HOST_FILE="FALSE"

#Funções

help(){
    echo -e "
    ${GREEN}--- MIGRAR HOSPEDAGEM ---${RESET}
    bash <(curl -sk https://git.hostgator.com.br/advanced-support/migration/raw/master/megazord.sh) --user [USUARIO-CPANEL] [SERVIDOR-DESTINO/ORIGEM] [PORTA-SSH] [ID-TICKET]

    ${GREEN}--- MIGRAR REVENDA (COPIA TAMBEM AS CONFIGURACOES DO USUARIO RESELLER)---${RESET}
    bash <(curl -sk https://git.hostgator.com.br/advanced-support/migration/raw/master/megazord.sh) --reseller [USUARIO-RESELLER] [SERVIDOR-DESTINO/ORIGEM] [PORTA-SSH] [ID-TICKET]

    ${GREEN}--- MIGRAR MULTIPLOS USUARIOS DE HOSPEDAGEM ---${RESET}
    bash <(curl -sk https://git.hostgator.com.br/advanced-support/migration/raw/master/megazord.sh) --file [ARQUIVO-COM-USUARIOS] [SERVIDOR-DESTINO/ORIGEM] [PORTA-SSH] [ID-TICKET]

    ${GREEN}--- MIGRAÇÃO COMPLETA DE SERVIDOR ---${RESET} ${BOLD}DISPONIVEL APENAS PARA VPS/DEDICADOS${RESET}
    bash <(curl -sk https://git.hostgator.com.br/advanced-support/migration/raw/master/megazord.sh) --allserver [SERVIDOR-DESTINO/ORIGEM] [PORTA-SSH] [ID-TICKET]

    ${GREEN}--- MIGRAÇÃO DE ARQUIVOS VIA FTP ---${RESET}
    bash <(curl -sk https://git.hostgator.com.br/advanced-support/migration/raw/master/megazord.sh) --ftp [USUARIO] [SENHA] [SERVIDOR DE ORIGEM DOS ARQUIVOS] [PORTA-FTP] [PROTOCOLO FTP/SFTP] [ID-TICKET]

    ${GREEN}--- MIGRAÇÃO DE ARQUIVOS VIA FTP MULTIPLAS CONTAS ---${RESET}
    bash <(curl -sk https://git.hostgator.com.br/advanced-support/migration/raw/master/megazord.sh) --multiftp [ARQUIVO-COM-DADOS] [ID-TICKET]

    PADRÃO DO ARQUIVO (${RED}AS INFORMAÇÕES DEVEM ESTAR SEPARADAS POR UM UNICO TAB${RESET})
    PROTOCOLO   PORTA   SERVIDOR        USUÁRIO     SENHA
    FTP         21      192.185.223.4   acesso      123mudar123

    ${YELLOW}PARÂMETROS ADICIONAIS${RESET}
    --setdns                                        REALIZA APONTAMENTO NAS ZONAS DE DNS PARA O SERVIDOR DE DESTINO     ${RED_ALERT}UTILIZE COM SABEDORIA.${RESET}
    --reverse                                       REALIZE A MIGRAÇÃO DE FORMA REVERSA
    --rsync                                         REALIZE O RSYNC DE USUÁRIOS JÁ MIGRADOS
    --skip-ftp-conn-validation                      Não REALIZA A VALIDAÇÃO DAS CREDENCIAIS FTP
    bash <(curl -sk https://git.hostgator.com.br/advanced-support/migration/raw/master/megazord.sh) --hostfile          GERA ARQUIVO DE HOSTS PARA TESTE - ${RED_ALERT}VERSÃO BETA${RESET}
    "
    
    exit 0

}

hosts_file(){
    
    for user in $(cut -d : -f2 /etc/trueuserdomains | grep -v \*)
    do 
        ip=$(grep IP= /var/cpanel/users/${user} | cut -d = -f2)
        domains=($(ui -l ${user} 2>/dev/null | grep -v "O. Domain" | egrep -i 'domain|sub|addon' | cut -d : -f2))
        for domain in "${domains[@]}"
        do 
            echo -e "${ip} ${domain}\n${ip} www.${domain}"
        done
    done
}
ssh_check(){

    connected=0
    PORTLIST=("22" "222" "2222" "22022")
    echo -e "${YELLOW}Verificando conectividade com o servidor de destino/origem.${RESET}"

    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no root@${IP} -p ${PORT} "exit" 2>/dev/null
    if [[ $? == 0 ]]
    then
        echo -e "${GREEN}OK!${RESET}\nConexão com a porta ${YELLOW}${PORT}${RESET} feita com sucesso no servidor ${YELLOW}${IP}${RESET}.\n\n"
        
        if [[ -z $(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no root@${IP} -p ${PORT} "hostname"| egrep -i 'prodns|hostgator')  ]]
        then
            ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no root@${IP} -p ${PORT} "iptables -I INPUT -p tcp -s $(hostname -i) -j ACCEPT"
        fi
        return 0
    else
        echo -en "${RED}*${RESET} A conexão com a porta ${YELLOW}${PORT}${RESET} no servidor ${YELLOW}${IP}${RESET} falhou.\nTestando conexão em portas padrões..."
        while [[ ! $connected == 1 ]]
        do
            for a in "${PORTLIST[@]}"
            do
                ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no root@${IP} -p ${a} "exit" 2>/dev/null

                if [[ $? == 0 ]]
                then
                    echo -e "${GREEN} Sucesso!${RESET}\nPorta de SSH localizada. Setando porta para ${YELLOW}${a}${RESET}\n\n"
                    if [[ -z $(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no root@${IP} -p ${PORT} "hostname"| egrep -i 'prodns|hostgator')  ]]
                    then
                        ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o GSSAPIAuthentication=no root@${IP} -p ${PORT} "iptables -I INPUT -p tcp -s $(hostname -i) -j ACCEPT"
                    fi
                    
                    export PORT=${a}
                    return 0
                fi
            done
            echo -e "\n${RED}*${RESET} Não foi possível se conectar no servidor ${YELLOW}${IP}${RESET} com a nenhum das portas cadastras no script.\nPortas testadas: $(for i in "${PORTLIST[@]}"; do echo $i ;done)\n\n"
            exit 1
        done
    fi

}

main_migration(){

    ##########################################
    #$1 - usuário a ser migrado              #
    #$2 - IP do servidor de origem/destino   #
    #$3 - Diretório de backups e logs        #
    #Return com valor de 111 indica erro     #
    ##########################################

    if [[ -z ${1} ]] || [[ -z ${2} ]] || [[ -z ${3} ]]
    then
        echo -e "${RED} Erro na função main_migration.\nEntre em contato com a equipe de inteligêcia operacional.${RESET}"
        exit 1
    fi
    

    if [[ ${REVERSE} == TRUE ]]
    then
        #Migração reversa
        #Criando diretório padrão no servidor de origem
        ssh ${2} -p ${PORT} -o StrictHostKeychecking=no -o GSSAPIAuthentication=no "mkdir -p ${3}/pkg/; mkdir -p ${3}/restore; mkdir -p ${3}/rsync/; touch ${3}/users_nao_migrados.txt"

        #Verificando se o usuário existe no servidor de origem.
        check=$(ssh ${2} -p ${PORT} -o StrictHostKeychecking=no -o GSSAPIAuthentication=no "if [[ -f /var/cpanel/users/${1} ]]; then echo true;else echo false;fi")
        if [[ ${check}  != true ]]
        then
            echo -e "${RED}*${RESET} O usuário ${YELLOW}${1}${RESET} parece não existir no servidor de origem ${2}"
            return 111
        fi

        echo -e "\nIniciando Migração do usuário ${YELLOW}${1}${RESET}"
        echo -en "Gerando backup..."
        #Gerando backup da conta
        ssh root@${2} -p ${PORT} -o StrictHostKeychecking=no -o GSSAPIAuthentication=no "/scripts/pkgacct --skiphomedir ${1} ${TMPDIR}/pkg/" > ${3}/pkg/${1}.log

        #Verificando se o backup foi gerado com sucesso.
        check=$(ssh root@${2} -p ${PORT} -o StrictHostKeychecking=no -o GSSAPIAuthentication=no "if [[ -f ${3}/pkg/cpmove-${1}.tar.gz ]]; then echo true;else echo false;fi")
        if [[ ${check} != true ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo "${RED}*${RESET} O backup do usuário ${YELLOW}${1}${RESET} não foi gerado com sucesso. Por gentileza verifique.\nLog disponível: ${BOLD}${3}/pkg/${1}.log${RESET}"
            return 111
        fi
        echo -e "${GREEN} [OK] ${RESET}"
        #Realizando o download do backup
        rsync -avzr --progress -e "ssh -o GSSAPIAuthentication=no -p ${PORT}" root@${2}:${TMPDIR}/pkg/cpmove-${1}.tar.gz ${3}/pkg/ > ${3}/pkg/${1}-backupsync.log

        echo -en "Fazendo download do backup gerado..."
        #Verificando se o rsync foi feito com sucesso.
        if [[ $? != 0 ]] || [[ ! -f ${3}/pkg/cpmove-${1}.tar.gz ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo -e "${RED}*${RESET} Não foi possível encontrar o backup no diretório ${3}/pkg/\nPor gentileza verificar o log ${3}/pkg/${1}-backupsync.log",
            
            return 111
        fi
        echo -e "${GREEN} [OK] ${RESET}"

        echo -en "Realizando a restuaração do backup..."
        #Restaurando a conta
        /scripts/restorepkg --allow_reseller ${3}/pkg/cpmove-${1}.tar.gz > ${3}/restore/${1}.log

        #Verificando se a conta foi restaurada corretamente.
        if [[ ! -f /var/cpanel/users/${1} ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo -e "${RED}*${RESET} A conta do usuário ${YELLOW}${1}${RESET} não foi restaurada corretamnete.\nPor gentileza verificar o log: ${BOLD}${3}/restore/${1}.log${RESET}"
            return 111
        fi
        echo -e "${GREEN} [OK] ${RESET}"

        home_origem="/$(ssh  ${2} -p ${PORT} -o StrictHostKeychecking=no -o GSSAPIAuthentication=no -o ConnectTimeout=10 "grep -i \": ${1}=\" /etc/userdatadomains |grep -i main |awk -F = '{print $9}' | cut -d\/ -f2| head -n1")"
        home_destino="/$(grep -i ": ${1}=" /etc/userdatadomains | grep -i main |awk -F = '{print $9}' | cut -d\/ -f2| head -n1)"

        echo -en "Iniciando Rsync da home..."
        #Verificando se as homes foram localizadas corretamente.
        if [[ -z ${home_origem} ]] || [[ -z ${home_destino} ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo -e "Não foi possível localizar as homes do usuário em alguns dos servidor, por favor, verifique.\nOrigem:${home_origem:-${RED}Não localizado${RESET}}\nDestino:${home_destino:-${RED}Não localizado${RESET}}"
            return 111
        fi        

        #Realizando rsync
        rsync -avzr --progress -e "ssh -p ${PORT} -o GSSAPIAuthentication=no" root@${2}:${home_origem}/${1}/ ${home_destino}/${1}/ > ${3}/rsync/${1}.log 2> ${3}/rsync/${1}.error
        rsync -avzr --progress -e "ssh -p ${PORT} -o GSSAPIAuthentication=no" root@${2}:${home_origem}/${1}/ ${home_destino}/${1}/ >> ${3}/rsync/${1}.log 2>> ${3}/rsync/${1}.error
        #Verificando se o rsync foi realizado com sucesso
        if [[ $? != 0 ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo -e "${RED}*${RESET} O rsync das homes apresentou erro, por gentileza, verifique.\nLog disponível: ${BOLD}${3}/rsync/${1}.error${RESET}"
            return 111
        fi
        echo -e "${GREEN} [OK] ${RESET}"
        echo -e "Migração do usuário ${YELLOW}${1}${RESET} finalizada com sucesso!"

        if [[ ${SETDNS} == TRUE ]]
        then
        #Configurando dns
        #Obtendo lista de domínios
        for domain in $(ssh root@${IP} -p ${PORT} -o GSSAPIAuthentication=no "grep :\ ${1}= /etc/userdatadomains | egrep -i 'parked|main|addon' | cut -d : -f1")
        do
                echo -e "${YELLOW}*${RESET} SETDNS habilitado"
                setdns ${domain}

                #Verificando se execução foi realizada com sucesso.
                if [[ $? == 111 ]]
                then
                    echo "Erro ao configurar as DNS do domínio ${domain}"
                    continue
                fi
            done
        fi

    else    
        #Migração padrão
        #Criando diretórios padrões no servidor de origem.
        ssh ${2} -p ${PORT} -o StrictHostKeychecking=no -o GSSAPIAuthentication=no "mkdir -p ${3}/pkg/; mkdir -p ${3}/restore; mkdir -p ${3}/rsync/"
        echo -e "\nIniciando Migração do usuário ${YELLOW}${1}${RESET}"

        #Verificando seu o usuário existe no servidor.
        if [[ ! -f /var/cpanel/users/${1} ]]
        then
            echo -e "${RED}*${RESET} O usuário ${YELLOW}${1}${RESET} não existe no servidor."
            return 111
        fi

        echo -en "Gerando backup..."
        #Gerando backup da conta
        if [[ ! -d /etc/skipresbackup/ ]]
        then
            mkdir -p /etc/skipresbackup/
        fi
        touch /etc/skipresbackup/${1}
        /scripts/pkgacct --skiphomedir ${1} ${3}/pkg/ > ${3}/pkg/${1}.log

        #Verificando se o backup foi gerado com sucesso
        if [[ ! -f ${3}/pkg/cpmove-${1}.tar.gz ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo -e "${RED}O backup do usuário ${YELLOW}${1}${RESET} ${RED}não foi gerado corretamente.\nPor gentileza verifique.${RESET}"
            return 111
        fi
        echo -e "${GREEN} [OK] ${RESET}"

        echo -en "Realizando o envio do backup para o servidor de destino..."
        #Enviando o backup ao servidor de destino.
        rsync -avzr --progress -e "ssh -p ${PORT} -o GSSAPIAuthentication=no" ${TMPDIR}/pkg/cpmove-${1}.tar.gz root@${2}:${3}/pkg/ > ${3}/rsync/${1}.log 2> ${3}/rsync/${1}.error

        #Verificando se o Rsync foi realizdao com sucesso
        if [[ $? != 0 ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo -e "${RED}*${RESET} Erro ao enviar backup ao servidor de destino, por favor, verifique.\n Log disponível em ${BOLD}${3}/rsync/${1}.error${RESET}"
            return 111
        fi

        #Verificando se o backup se encontra no diretório correto.
        check=$(ssh ${2} -p ${PORT} -o StrictHostKeychecking=no -o GSSAPIAuthentication=no "if [[ -f ${3}/pkg/cpmove-${1}.tar.gz ]]; then echo true;else echo false;fi")
        if [[ ${check} != true ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo -e "Não foi possível localizar o backup do usuário ${YELLOW}${1}${RESET} no servidor destino.\nO backup deveria estar localizado em ${BOLD}${3}/pkg/cpmove-${1}.tar.gz${RESET}"
            return 111
        fi
        echo -e "${GREEN} [OK] ${RESET}"

        echo -en "Restaurando backup..."
        #Restaurando backup no servidor de destino.
        ssh root@${2} -p ${PORT} -o StrictHostKeychecking=no -o GSSAPIAuthentication=no "/scripts/restorepkg --allow_reseller ${3}/pkg/cpmove-${1}.tar.gz" > ${3}/restore/${1}.log

        #Verificando se a conta foi restaurada com sucesso no servidor de destino
        check=$(ssh ${2} -p ${PORT} -o StrictHostKeychecking=no -o GSSAPIAuthentication=no "if [[ -f /var/cpanel/users/${1} ]]; then echo true;else echo "false";fi")
        if [[ $check != true ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo -e "${RED}*${RESET} O usuário ${YELLOW}${1}${RESET} não foi restaurado corretamente no servidor de destino, por gentileza verifique.\nLog disponível: ${BOLD}${3}/restore/${1}.log${RESET}"
            return 111
        fi
        echo -e "${GREEN} [OK] ${RESET}"

        echo -en "Realizando Rsync da home..."
        #Localizando home do usuário no servidor de origem e destino.
        home_origem="/$(grep -i ": ${1}=" /etc/userdatadomains | grep -i main | awk -F = '{print $9}' | cut -d\/ -f2| head -n1)"
        home_destino="/$(ssh ${2} -p ${PORT} -o StrictHostKeychecking=no -o ConnectTimeout=10 -o GSSAPIAuthentication=no "grep -i \": ${1}=\" /etc/userdatadomains |grep -i main |awk -F = '{print $9}' | cut -d\/ -f2| head -n1")"

        #Verificando se as homes foram localizadas corretamente.
        if [[ -z ${home_origem} ]] || [[ -z ${home_destino} ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo -e "Não foi possível localizar as homes do usuário em alguns dos servidor, por favor, verifique.\nOrigem:${home_origem:-${RED}Não localizado${RESET}}\nDestino:${home_destino:-${RED}Não localizado${RESET}}"
            return 111
        fi

        #Realizando rsync das homes
        rsync -avzr --progress -e "ssh -p ${PORT} -o GSSAPIAuthentication=no" ${home_origem}/${1}/ root@${2}:${home_destino}/${1}/ > ${3}/rsync/${1}.log 2> ${3}/rsync/${1}.error
        rsync -avzr --progress -e "ssh -p ${PORT} -o GSSAPIAuthentication=no" ${home_origem}/${1}/ root@${2}:${home_destino}/${1}/ >> ${3}/rsync/${1}.log 2>> ${3}/rsync/${1}.error
        
        #Verificando se o rsync foi realizado com sucesso
        if [[ $? != 0 ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo -e "${RED}*${RESET} O rsync das homes apresentou erro, por gentileza, verifique.\nLog disponível: ${BOLD}${3}/rsync/${1}.error${RESET}"
            return 111
        fi

        echo -e "${GREEN} [OK] ${RESET}"
        echo -e "Migração do usuário ${YELLOW}${1}${RESET} finalizada com sucesso!"

        #Configurando zone de DNS
        if [[ ${SETDNS} == TRUE ]]
        then
            for domain in $(grep ": ${1}="  /etc/userdatadomains | egrep -i 'parked|main|addon' | cut -d : -f1)
            do
                echo -e "${YELLOW}*${RESET} SETDNS habilitado"
                setdns ${domain}

                #Verificando se execução foi realizada com sucesso.
                if [[ $? == 111 ]]
                then
                    echo "Erro ao configurar as DNS do domínio ${domain}"
                    continue
                fi
            done
        fi

    fi

}

reseller_migration(){

    #Verificando se o usuário informado é de fato um revendedor.
    if [[ ${REVERSE} == TRUE ]]
    then
        if [[ -z $(ssh root@${IP} -p ${PORT} -o GSSAPIAuthentication=no "egrep -i \"\<^${USER}\>\" /var/cpanel/resellers" ) ]]
        then
            echo -e "${RED}*${RESET} O usuário ${YELLOW}${USER}${RESET} não é um revendedor válido no servidor de origem ${YELLOW}${IP}${RESET}"
            exit 1
        fi
    elif [[ -z $(egrep -i "\<^${USER}\>" /var/cpanel/resellers) ]]
    then
        echo -e "${RED}*${RESET} O usuário ${YELLOW}${USER}${RESET} não é um revendedor válido."
        exit 1
    fi

    #Verificando usuários a serem migrados e quais usuários já existem no servidor.
    current_users=() #Array com usuários já existentes.

    if [[ ${REVERSE} == TRUE ]]
    then
        #Array com usuários a serem migrados na origem
        reseller_users=($(ssh ${IP} -p ${PORT} -o GSSAPIAuthentication=no -o StrictHostKeychecking=no -o ConnectTimeout=10 "grep -lri owner=${USER} /var/cpanel/users/ | cut -d \/ -f5 | grep -iv ${USER}$"))

        #Informações sobre usuários já existentes no servidor de destino.
        for r_user in "${reseller_users[@]}"
        do
            if [[ ! -z $(egrep -i "\<${r_user}\>" /etc/trueuserdomains | cut -d : -f2) ]] #Verificação local, pois o servidor local irá receber as contas.
            then
                echo -e "\nUsuário ${r_user} ${RED}NÃO será migrado${RESET} pois o mesmo já existe no servidor."
                egrep -i "\<${r_user}\>" /etc/trueuserdomains | cut -d: -f2 >> ${TMPDIR}/users_nao_migrados.txt
                current_users+=("${r_user}")
            fi
        done
    else
        reseller_users=($(grep -lri owner=${USER} /var/cpanel/users/ | cut -d \/ -f5 | grep -iv ${USER}$))

        #Informações sobre usuários já existentes no servidor de destino.
        for r_user in "${reseller_users[@]}"
        do

            if [[ ! -z $(ssh root@${IP} -p ${PORT} -o GSSAPIAuthentication=no "egrep -i \"\<${r_user}\>\" /etc/trueuserdomains") ]] #Verificação remota, pois o servidor remoto irá receber os usuários.
            then
                echo -e "\nUsuário ${YELLOW}${r_user}${RESET} ${RED}NÃO será migrado${RESET} pois o mesmo já existe no servidor de destino."
                ssh root@${IP} -p ${PORT} "egrep -i \"\<${r_user}\>\" /etc/trueuserdomains | cut -d : -f2" >> ${TMPDIR}/users_nao_migrados.txt
                current_users+=("${r_user}")
            fi
        done
    fi
    
    if [[ $(wc -l ${TMPDIR}/users_nao_migrados.txt | awk '{print $1}') != 0 ]]
    then
        while [[ ${opt} != "n" ]] && [[ ${opt} != "s" ]]
        do
            echo -e "${BOLD}Deseja prosseguir com a migração mesmo com os erros citados acima? (s/n)${RESET}"
            read opt
        done

        if [[ ${opt} == n ]]
        then
            exit 1
        fi
    fi

    #Limpando array principal para evitar que usuários já existente sejam migrados.
    if [[ "${#current_users[@]}" != 0 ]]
    then
        for a_user in "${current_users[@]}"
        do
            reseller_users=($(echo "${reseller_users[@]/${a_user}}")) #Excluindo usuários duplicados.
        done
    fi

    #Verificando se existem contas a serem migradas
    if [[ "${#reseller_users[@]}" == 0 ]]
    then
        echo -e "${RED}*${RESET} Não foram localizados usuários para serem migrados."
        exit 1
    fi

    #Realizando a migração do revendedor para garantir a integridade do restante de migração
    echo -e "${RED}Informação importante.${RESET}\nMigrando revendedor antes das demais contas para garantir a integridade das demais migrações.\n"
    main_migration ${USER} ${IP} ${TMPDIR}

    #Verifivando se a migração foi realizada com sucesso
    if [[ $? == 111 ]]
    then
        echo -e "${RED}*${RESET} A migração do revendedor apresentou erros.\nVerifique logs disponíveis em ${BOLD}${TMPDIR}${RESET}\n"
        exit 1
    fi

    #Iniciando a migração
    for migrate_user in "${reseller_users[@]}"
    do
        #chamando função principal de migração.
        main_migration ${migrate_user} ${IP} ${TMPDIR}
        if [[ $? == 111 ]]
        then
            continue #Caso a função retorne condição 111,  continuar o loop para o proximo usuário.
        fi
    done

    #Migrando pacotes/planos
    if [[ ${REVERSE} == TRUE ]]
    then
        rsync -avzr --progress -e "ssh -p ${PORT} -o GSSAPIAuthentication=no" root@${IP}:/var/cpanel/packages/${USER}_* /var/cpanel/packages/ > ${TMPDIR}/packages-rsync.log 2> ${TMPDIR}/packages-rsync.log
        if [[ ! -z $(ssh root@${IP} -p ${PORT} "ls /var/cpanel/webtemplates/${USER} 2>/dev/null") ]]
        then
            rsync -avzr --progress "ssh -p ${PORT} -o GSSAPIAuthentication=no" root@${IP}:/var/cpanel/webtemplates/${USER} /var/cpanel/webtemplates/${USER} > ${TMPDIR}/packages-rsync.log 2> ${TMPDIR}/packages-rsync.log
        fi

    else
        rsync -avzr --progress "ssh -p ${PORT} -o GSSAPIAuthentication=no" /var/cpanel/packages/${USER}_* root@${IP}:/var/cpanel/packages/ > ${TMPDIR}/packages-rsync.log 2> ${TMPDIR}/packages-rsync.log
        if [ -d /var/cpanel/webtemplates/${USER} ]
        then
            rsync -avzr --progress "ssh -p ${PORT} -o GSSAPIAuthentication=no" /var/cpanel/webtemplates/${USER} root@${IP}:/var/cpanel/webtemplates/${USER}/ ${TMPDIR}/packages-rsync.log 2> ${TMPDIR}/packages-rsync.log
        fi
    fi
}

allserver_migration(){

    #Validando execuação apenas para servidores dedicados VPS.
    if [[ ! -z $(hostname | egrep -i 'hostgator|prodns') ]]
    then
        echo -e "${RED}Shared server, exiting...${RESET}"
        exit 1
    fi

    #Criando array com a lista de usuários a serem migrados.
    if [[ ${REVERSE} == TRUE ]]
    then
        users_list=($(ssh ${IP} -p ${PORT} -o GSSAPIAuthentication=no -o StrictHostKeychecking=no -o ConnectTimeout=10 "cut -d : -f2 /etc/trueuserdomains"))
        external_user=($(awk '{print $2}' /etc/trueuserdomains))
    else
        users_list=($(awk '{print $2}' /etc/trueuserdomains))
        external_user=($(ssh ${IP} -p ${PORT} -o GSSAPIAuthentication=no -o StrictHostKeyChecking=no "cut -d : -f2 /etc/trueuserdomains"))
    fi

    #Limpando array de usuários finais.
    for e_user in "${external_user[@]}"
    do
        users_list=($(echo "${users_list[@]/${e_user}}"))
    done
    
    if [[ ${REVERSE} == TRUE ]]
    then
        #Logando usuários que existe que não foram migrados.
        echo -e "Os seguintes usuários não existem pois já existem no servidor destino/origem:" >> ${TMPDIR}/users_nao_migrados.txt
        for e_user in "${external_user[@]}"
        do
            if [[ ! -z $(grep -i ${e_user} /etc/trueuserdomains) ]]
            then
                grep -i ${e_user} /etc/trueuserdomains  >> ${TMPDIR}/users_nao_migrados.txt
                echo -e "Usuário ${YELLOW}${e_user}${RESET} ${RED}NÃO será migrado${RESET} pois o mesmo já existe no servidor de destino/origem."
            fi
        done
    else
    
        #Logando usuários que existe que não foram migrados.
        echo -e "Os seguintes usuários não existem pois já existem no servidor destino/origem:" >> ${TMPDIR}/users_nao_migrados.txt
        for e_user in "${external_user[@]}"
        do
            if [[ ! -z $(ssh ${IP} -p ${PORT} -o GSSAPIAuthentication=no -o StrictHostKeychecking=no -o ConnectTimeout=10 "grep -i ${e_user} /etc/trueuserdomains") ]]
            
            then
                grep -i ${e_user} /etc/trueuserdomains  >> ${TMPDIR}/users_nao_migrados.txt
                echo -e "Usuário ${YELLOW}${e_user}${RESET} ${RED}NÃO será migrado${RESET} pois o mesmo já existe no servidor de destino/origem."
            fi
        done
    fi
    
    #Verificando se existem contas a serem migradas
    if [[ "${#users_list[@]}" == 0 ]]
    then
        echo -e "${RED}*${RESET} Não foram localizados usuários para serem migrados."
        exit 1
    fi

    #Iniciando migração
    for migrate_user in "${users_list[@]}"
    do
        main_migration ${migrate_user} ${IP} ${TMPDIR}

        if [[ $? == 111 ]]
        then 
            continue
        fi
    done
    
}

file_migration(){

    #Alterando o nome da variavel para facilitar leitura.
    file=${USER}
    
    #Verificando se o arquivo com os usuários existe.
    if [[ ! -f ${file} ]]
    then
        echo -e "${RED} O arquivo informado ${YELLOW}${file}${RESET} ${RED}não existe, por favor, verifique.${RESET}"
        exit 1
    fi
    

    #Criando array com a lista de usuários a serem migrados.
    if [[ ${REVERSE} == TRUE ]]
    then
        users_list=($(cat ${file}))
        #external_user=($(cut -d : -f2 /etc/trueuserdomains | cut -d : -f2)) #Verificação local já que a lista de usuário será restaurado no mesmo servidor em que o script é executado.
        
        #Verificando se os usuários a serem migrados existem no servidor de destino.
        for e_user in "${users_list[@]}"
        do
            if [[ -f /var/cpanel/users/${e_user} ]] #local devido a ser reverso
            then
                echo -e "\nUsuário ${e_user} ${RED}NÃO será migrado${RESET} pois o mesmo já existe no servidor de destino/origem. $(hostname)"
                
                #limpando o array
                users_list=($(echo "${users_list[@]/${e_user}}"))
                
                #Logando usuários que existe que não foram migrados.
                echo -e "\nUsuário ${e_user} ${RED}NÃO será migrado${RESET} pois o mesmo já existe no servidor de destino/origem. $(hostname)" >> ${TMPDIR}/users_nao_migrados.txt
            fi
        done
        
    else
        users_list=($(cat ${file}))
        #external_user=($(ssh ${IP} -p ${PORT} -o GSSAPIAuthentication=no -o StrictHostKeyChecking=no "cut -d : -f2 /etc/trueuserdomains | cut -d : -f2")) #Externo já que as contas serão restauradas em um servidor externo.
        external_name=$(ssh ${IP} -p ${PORT} -o GSSAPIAuthentication=no -o StrictHostKeyChecking=no "hostname")
        for e_user in "${users_list[@]}"
        do
            if [[ ! -z $(ssh ${IP} -p ${PORT} -o GSSAPIAuthentication=no -o StrictHostKeyChecking=no "egrep \"\<${e_user}\>\" /etc/trueuserdomains") ]]
            then
                echo -e "\nUsuário ${e_user} ${RED}NÃO será migrado${RESET} pois o mesmo já existe no servidor de destino/origem. ${external_name:-NULL}"
                echo -e "\nUsuário ${e_user} ${RED}NÃO será migrado${RESET} pois o mesmo já existe no servidor de destino/origem. ${external_name:-NULL}" >> ${TMPDIR}/users_nao_migrados.txt
                #limpando o array
                users_list=($(echo "${users_list[@]/${e_user}}"))
            fi
        done
    fi

    

    #Realizando a migração das contas.
    for migrate_user in "${users_list[@]}"
    do
        main_migration ${migrate_user} ${IP} ${TMPDIR}

        if [[ $? == 111 ]]
        then 
            continue
        fi
    done
    
}

setdns(){

    ##################
    ## $1 - usuário ##
    ##################
    
    if [[ ${REVERSE} == TRUE ]]
    then

        #Verificando ip atual.
        echo -en "${YELLOW}*${RESET} Configurando DNS do domínio ${1}... "
        IP_ATUAL=$(ssh root@${IP} -p ${PORT} "grep ${1} /etc/userdatadomains | cut -d= -f11 | cut -d : -f1 | head -n 1")
        IP_NOVO=$(grep ${1} /etc/userdatadomains | cut -d= -f11 | cut -d : -f1 | head -n 1)

        if [[ -z ${IP_ATUAL} ]] || [[ -z ${IP_NOVO} ]]
        then
            echo -e "${RED}[ERRO]${RESET}"
            echo -e "${RED}*${RESET} Erro ao obter ips.\nIP ATUAL: ${IP_ATUAL:-${RED}VAZIO${RESET}}\nIP a ser configurado: ${IP_NOVO:-${RED}VAZIO${RESET}}\n"
            return 111
        fi

        #Realziando backup da zona de DNS
        ssh root@${IP} -p ${PORT} -o GSSAPIAuthentication=no "cp -p /var/named/${1}.db{,-bkp}"

        #Alterando zona de DNS
        ssh root@${IP} -p ${PORT} -o GSSAPIAuthentication=no "sed -i \"s/${IP_ATUAL}/${IP_NOVO}/g\" /var/named/${1}.db"

        #ALTERA O MX DO DOMÍNIO PARA REMOTO
        ssh root@${IP} -p ${PORT} -o GSSAPIAuthentication=no "if [[ ! -z \$(egrep -i \"^${1}\" /etc/localdomains) ]];then sed -i \"/^${1:-NULL}$/d\" /etc/localdomains && echo -e \"${1}\" >> /etc/remotedomains;fi"
        
        rndc reload >/dev/null
    else
    
        echo -en "${YELLOW}*${RESET} Configurando DNS do domínio ${1}... "
        IP_ATUAL=$(grep ${1} /etc/userdatadomains | cut -d= -f11 | cut -d : -f1 | head -n 1)
        IP_NOVO=$(ssh root@${IP} -p ${PORT} -o GSSAPIAuthentication=no "grep ${1} /etc/userdatadomains | cut -d= -f11 | cut -d : -f1 | head -n 1")

        if [[ -z ${IP_ATUAL} ]] || [[ -z ${IP_NOVO} ]]
        then
            echo -e "${RED}[ERRO]${RESET}"
            echo -e "${RED}*${RESET} Erro ao obter ips.\nIP ATUAL: ${IP_ATUAL:-${RED}VAZIO${RESET}}\nIP a ser configurado: ${IP_NOVO:-${RED}VAZIO${RESET}}\n"
            return 111
        fi

        #Realziando backup da zona de DNS
        cp -p /var/named/${1}.db{,-bkp}

         #Alterando zona de DNS
         sed -i "s/${IP_ATUAL}/${IP_NOVO}/g" /var/named/${1}.db

        #ALTERA O MX DO DOMÍNIO PARA REMOTO
        if [[ ! -z  $(egrep -w "^${1:-NULL}$" /etc/localdomains) ]] && [[ -z $(egrep -w "^${1:-NULL}$" /etc/remotedomains) ]]
        then

            sed -i "/^${1:-NULL}$/d" /etc/localdomains
            echo -e "${1}" >> /etc/remotedomains
        fi


    fi
    
    rndc reload >/dev/null
    echo -e "${GREEN}[OK]${RESET}"
    
}

ftp_conn_validation(){

    ####################################################
    ## $1 = usuário                                    #
    ## $2 = senha                                      #
    ## $3 = ip                                         #
    ## $4 = porta                                      #
    ## $5 = protocolo                                  #
    # Verificando se os dados fornecidos são válidos   #  
    ####################################################
    
    
    #Verificando se o pacote lftp esta instalado..
    if [[ ${SKIP_FTP_CONN} != TRUE ]]
    then
        if [[ ${lftp_check} != 1 ]]
        then
            if [[ -z $(yum list installed | grep -i lftp) ]]
            then
                if [[ -z $(hostname | egrep -i 'hostgator|prodns') ]]
                then
                    echo -e "\n${RED}*${RESET}O pacote LFTP não se encontra instalado no servidor. Realizando instalação."
                    yum -y install lftp >/dev/null
                    if [[ $? == 0 ]]
                    then
                        export lftp_check=1
                    else
                        echo -e "\n${RED}*${RESET} Erro ao instalar o pacote de FTP, por gentileza, verificar."
                        exit 1
                    fi
                else
                    echo -e "${RED}*${RESET} O pacote LFTP não se encontra instalado no servidor.\nSolicite a instalação do mesmo através do link: https://jira.endurance.com/servicedesk/customer/portal/537/create/5537"
                    echo -e "Servidor: $(hostaname)\nUsuário:$(echo $SYSADMIN)"
                    exit 1
                fi
            fi
        fi
    
    
        echo "lftp -u ${1},${2} -p ${4} ${5}://${3}" >> ${TMPDIR}/ftp-auth.log
        lftp -u ${1},${2} -p ${4} ${5}://${3} -e '
        set ftp:list-options -a ; 
        set ftp:use-fxp true ; 
        set ftp:fxp-passive-source true ; 
        set ftp:ssl-allow no ; 
        set mirror:parallel-directories on ; 
        set mirror:parallel-transfer-count 5 ;
        set ssl:verify-certificate false;
        set net:timeout 5;
        set net:max-retries 2;
        ls;
        quit;' >/dev/null 2>${TMPDIR}/ftp-auth.log
        
        #Verificando se a conexão foi feita com sucesso
        if [[ $? != 0 ]]
        then
             echo -e "${RED}[DADOS INVÁLIDOS]${RESET}"
            echo -e "\n${RED}*${RESET} Os dados fornecidos para acessar o usuário ${YELLOW}${1}${RESET} no servidor ${YELLOW}${3}${RESET} não são válidos.\nVerifique logs em ${BOLD}${TMPDIR}/ftp-auth.log${RESET}\n"
            return 111
        fi
    else
        return 222
    fi
        

}

mainftp(){
    
    ####################################################
    ## $1 = usuário                                    #
    ## $2 = senha                                      #
    ## $3 = ip                                         #
    ## $4 = porta                                      #
    ## $5 = TMPDIR                                     #
    ## $6 = protocolo                                  #
    ####################################################

    #Acessando o diretório do backup
    cd ${5}
    lftp -d -u ${1},${2} -p ${4} -e '\
    set ftp:list-options -a ; 
    set ftp:use-fxp true ; 
    set ftp:fxp-passive-source true ; 
    set ftp:ssl-allow no ; 
    set mirror:parallel-directories on ; 
    set mirror:parallel-transfer-count 5 ; 
    set ssl:verify-certificate false;
    mirror -c . ./ ; 
    quit'\    ${6}://${3} |tee -a ${5}/ftp-migration-${1}.log 2> ${5}/ftp-migration-${1}-error.log
 
    if [[ $? != 0 ]]
    then
        echo -e "${RED}*${RESET} Algo de errado ocorre durante a transferencia dos arquivos, por favor, verifique o log: ${BOLD}${5}/ftp-migration-error.log${RESET}"
        return 111
    fi
}

migra_ftpuser(){ #Migração de um unico usuário via FTP

    echo -en "${YELLOW}*${RESET} Validando dados de acesso do usuário ${USER}... "
    #Validnado conexão
    ftp_conn_validation ${USER} ${PASSWORD} ${IP} ${PORT} ${PROTOCOL}
    
    if [[ $? == 111 ]]
    then
        exit 1
    elif [[ ${SKIP_FTP_CONN} == TRUE ]]
    then
        echo -e "${BOLD}[SKIPPED]${RESET}"
    else
        echo -e "${GREEN}[OK]${RESET}"
    fi
    
    #Criando um diretório apenas para receber a migração FTP do usuario
    TMPDIR="${TMPDIR}/${USER}-FTP-FILES"
    mkdir -p ${TMPDIR}

    #Chamando função para realizar a migração.
    echo -e "Realizando migração dos arquivos - ${YELLOW}${USER}${RESET}"
    mainftp ${USER} ${PASSWORD} ${IP} ${PORT} ${TMPDIR} ${PROTOCOL} > ${TMPDIR}/ftp.log

    if [[ $? == 111 ]]
    then
        echo -e "${RED}*${RESET} ERRO na migração. Verifique os logs."
        exit 1
    else
        echo -e "${GREEN}*${RESET} Migração finalizada com sucesso."
        exit 0
    fi

}

mult_ftp(){ #migrando diversos usuários via FTP
    
    echo -e "${YELLOW}*${RESET} Validando dados de acesso FTP..."
    TMPDIRFTP=${TMPDIR}
    #Verificando se o arquivo repassado é válido
    if [[ ! -f ${FILE} ]] &&  [[ -z ${FILE} ]] &&  [[  $(wc -l ${FILE} | awk '{print $1}') == 0 ]]
    then
        echo -e "${RED}*${RESET} O arquivo ${FILE} não existe ou se encontra vazio"
        exit 1
    fi

    #Exemplo estrutural de arquivos
    #FTP         21      192.185.223.4   acesso      123mudar123
    
    #Array para tratar usuários com erro
    ftp_users=($(awk '{print $4}' ${FILE}))
    ftp_error=()
    for ftp_user in "${ftp_users[@]}"
    do

        #Setando váriaveis padrões
        PASSWORD=$(egrep -i "\<${ftp_user}\>" ${FILE} | awk '{print $5}')
        IP=$(egrep -i "\<${ftp_user}\>" ${FILE} | awk '{print $3}')
        PORT=$(egrep -i "\<${ftp_user}\>" ${FILE}| awk '{print $2}')
        PROTOCOL=$(egrep -i "\<${ftp_user}\>" ${FILE}| awk '{print $1}' | tr '[:upper:]' '[:lower:]')

        echo -ne "Validação do usuário ${YELLOW}${ftp_user}${RESET} em andamento... "
        #Validnado conexão
        ftp_conn_validation ${ftp_user} ${PASSWORD} ${IP} ${PORT} ${PROTOCOL}
        
        if [[ $? == 111 ]]
        then
            ftp_error+=("ftp_user")
            continue
        elif [[ ${SKIP_FTP_CONN} == TRUE ]]
        then
            echo -e "${BOLD}[SKIPPED]${RESET}"
        else
            echo -e "${GREEN}[OK]${RESET}"
        fi
        
    done

    if [[ "${#ftp_error[@]}" != 0 ]]
    then
        while [[ ${opt} != "n" ]] && [[ ${opt} != "s" ]]
        do
            echo -e "${BOLD}Deseja prosseguir com a migração mesmo com os erros citados acima? (s/n)${RESET}"
            read opt
        done

        if [[ ${opt} == n ]]
        then
            exit 1
        fi

        #Limpando array de usuários
        for a_user in "${ftp_error[@]}"
        do
            reseller_users=($(echo "${ftp_users[@]/${a_user}}")) #Excluindo usuários com erro.
        done
    fi
    

    #Realizando a migração dos arquivos via FTP
    for ftp_user in "${ftp_users[@]}"
    do

        #Setando váriaveis padrões
        PASSWORD=$(egrep -i "\<${ftp_user}\>" ${FILE} | awk '{print $5}')
        IP=$(egrep -i "\<${ftp_user}\>" ${FILE} | awk '{print $3}')
        PORT=$(egrep -i "\<${ftp_user}\>" ${FILE}| awk '{print $2}')
        PROTOCOL=$(egrep -i "\<${ftp_user}\>" ${FILE}| awk '{print $1}' | tr '[:upper:]' '[:lower:]')

        #Criando um diretório apenas para receber a migração FTP do usuario
        TMPDIR="${TMPDIRFTP}/${ftp_user}-FTP-FILES"
        mkdir -p ${TMPDIR}

        #Chamando função para realizar a migração.
        echo -e "Iniciando migração dos arquivos do usuário ${YELLOW}${ftp_user}${RESET}"
        sleep 5
        mainftp ${ftp_user} ${PASSWORD} ${IP} ${PORT} ${TMPDIR} ${PROTOCOL} > ${TMPDIR}/ftp.log

        if [[ $? == 111 ]]
        then
            continue
        fi
            
        echo -e "${GREEN}*${RESET} Migração do usuário ${YELLOW}${ftp_user}${RESET} finalizada com sucesso."
    done
}

main_rsync(){ #Realiza o rsync das homes de usuários já existentes no destino.
    

    echo -ne "\n${GREEN}*${RESET} Iniciando rsync do usuário ${YELLOW}${1}${RESET}..."
    if [[ ${REVERSA} == TRUE ]]
    then
        #Verificando se a home do usuário existe no servidor o qual irá receber o rsync.
        if [[ ! -f /var/cpanel/users/${1} ]]
        then
            echo -e "${RED}*${RESET}O usuário ${1} não existe no servidor $(hostname). Faça a migração do usuário antes de solicitar o rsync."
            return 111
        fi

        check=$(ssh ${2} -p ${PORT} -o GSSAPIAuthentication=no -o StrictHostKeychecking=no "if [[ -f /var/cpanel/users/${1} ]]; then echo true;else echo false;fi")
        if [[ ${check} != true ]]
        then
            echo -e "${RED}*${RESET}O usuário ${1} não existe no servidor de origem. Por gentileza, verifique."
            return 111
        fi

        home_origem="/$(ssh ${2} -p ${PORT} -o GSSAPIAuthentication=no -o StrictHostKeychecking=no "grep -i \": ${1}=\" /etc/userdatadomains |grep -i main |awk -F = '{print $9}' | cut -d\/ -f2| head -n1")"
        home_destino="/$(grep -i ": ${1}=" /etc/userdatadomains | grep -i main |awk -F = '{print $9}' | cut -d\/ -f2| head -n1)"

        if [[ -z ${home_origem} ]] || [[ -z ${home_destino} ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo -e "Não foi possível localizar as homes do usuário em alguns dos servidor, por favor, verifique.\nOrigem:${home_origem:-${RED}Não localizado${RESET}}\nDestino:${home_destino:-${RED}Não localizado${RESET}}"
            return 111
        fi

        #Realizando rsync
        rsync -avzr --progress -e "ssh -p ${PORT}" root@${2}:${home_origem}/${1}/ ${home_destino}/${2}/ > ${TMPDIR}/rsync/${1}.log 2> ${TMPDIR}/rsync/${1}.error
        rsync -avzr --progress -e "ssh -p ${PORT}" root@${2}:${home_origem}/${1}/ ${home_destino}/${2}/ >> ${TMPDIR}/rsync/${1}.log 2>> ${TMPDIR}/rsync/${1}.error
        
        #Verificando se o rsync foi realizado com sucesso
        if [[ $? != 0 ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo -e "${RED}*${RESET} O rsync das homes apresentou erro, por gentileza, verifique.\nLog disponível: ${BOLD}${TMPDIR}/rsync/${1}.error${RESET}"
            return 111
        fi

        echo -e "${GREEN} [OK] ${RESET}"
        echo -e "Rsync do usuário ${YELLOW}${1}${RESET} finalizado com sucesso!"

        if [[ $SETDNS == TRUE ]]
        then
            #Obtendo lista de domínios
            for domain in $(ssh root@${IP} -p ${PORT} -o GSSAPIAuthentication=no "grep :\ ${1}= /etc/userdatadomains | egrep -i 'parked|main|addon' | cut -d : -f1")
            do
    
                    echo -e "${YELLOW}*${RESET} SETDNS habilitado"
                    setdns ${domain}
    
                    #Verificando se execução foi realizada com sucesso.
                    if [[ $? == 111 ]]
                    then
                        echo "Erro ao configurar as DNS do domínio ${domain}"
                        continue
                    fi
            done
        fi

    else
        #Verificando se a home do usuário existe no servidor o qual irá receber o rsync.
        check=$(ssh ${2} -p ${PORT} -o GSSAPIAuthentication=no -o StrictHostKeychecking=no "if [[ -f /var/cpanel/users/${1} ]]; then echo true;else echo false;fi")
        if [[ ${check} != true ]]
        then
            echo -e "${RED}*${RESET}O usuário ${1} não existe no servidor de destino. Faça a migração do usuário antes de solicitar o rsync."
            return 111
        fi

        if [[ ! -f /var/cpanel/users/${1} ]]
        then
            echo -e "${RED}*${RESET}O usuário ${1} não existe no servidor $(hostname).Por gentileza, verifique"
            return 111
        fi

        home_origem="/$(grep -i ": ${1}=" /etc/userdatadomains | grep -i main | awk -F = '{print $9}' | cut -d\/ -f2| head -n1)"
        home_destino="/$(ssh ${2} -p ${PORT} -o StrictHostKeychecking=no -o GSSAPIAuthentication=no "grep -i \": ${1}=\" /etc/userdatadomains |grep -i main |awk -F = '{print $9}' | cut -d\/ -f2| head -n1")"

        if [[ -z ${home_origem} ]] || [[ -z ${home_destino} ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo -e "Não foi possível localizar as homes do usuário em alguns dos servidor, por favor, verifique.\nOrigem:${home_origem:-${RED}Não localizado${RESET}}\nDestino:${home_destino:-${RED}Não localizado${RESET}}"
            return 111
        fi

        #Realizando rsync das homes
        rsync -avzr --progress -e "ssh -p ${PORT}" ${home_origem}/${1}/ root@${2}:${home_destino}/${1}/ > ${TMPDIR}/rsync/${1}.log 2> ${TMPDIR}/rsync/${1}.error
        rsync -avzr --progress -e "ssh -p ${PORT}" ${home_origem}/${1}/ root@${2}:${home_destino}/${1}/ >> ${TMPDIR}/rsync/${1}.log 2>> ${TMPDIR}/rsync/${1}.error
        
        #Verificando se o rsync foi realizado com sucesso
        if [[ $? != 0 ]]
        then
            echo -e "${RED} [ERRO] ${RESET}"
            echo -e "${RED}*${RESET} O rsync das homes apresentou erro, por gentileza, verifique.\nLog disponível: ${BOLD}${TMPDIR}/rsync/${1}.error${RESET}"
            return 111
        fi

        echo -e "${GREEN} [OK] ${RESET}"
        echo -e "Rsync do usuário ${YELLOW}${1}${RESET} finalizada com sucesso!"

        if [[ $SETDNS == TRUE ]]
        then
            for domain in $(grep -i ": ${1}=" /etc/userdatadomains | egrep -i 'parked|main|addon' | awk '{print $1}' | cut -d : -f1)
            do
                echo -e "${YELLOW}*${RESET} SETDNS habilitado"
                setdns ${domain}

                #Verificando se execução foi realizada com sucesso.
                if [[ $? == 111 ]]
                then
                    echo "Erro ao configurar as DNS do domínio ${domain}"
                    continue
                fi
            done
        fi      

    fi

}

rsync_migration(){

    if [[ ${TYPE} == --user ]]
    then
       main_rsync ${USER} ${IP}

        if [[ $? == 111 ]]
        then
            exit 1
        fi
    
    elif [[ ${TYPE} == --reseller ]]
    then

        if [[ ${REVERSE} == TRUE ]]
        then

            for r_user in $(ssh root@${IP} -p ${PORT} -o GSSAPIAuthentication=no "grep -lri owner=${USER} /var/cpanel/users/ | cut -d \/ -f5 | grep -iv ${USER}$")
            do
                main_rsync ${r_user} ${IP}

                if [[ $? == 111 ]]
                then
                    continue
                fi
            done

        else

            for r_user in $(grep -lri owner=${USER} /var/cpanel/users/ | cut -d \/ -f5 | grep -iv ${USER}$)
            do
                main_rsync ${r_user} ${IP}

                if [[ $? == 111 ]]
                then
                    continue
                fi
            done
        fi

    elif [[ ${TYPE} == --file ]]
    then
        #Alterando o nome da variavel para facilitar leitura.
        file=${USER}
        
        #Verificando se o arquivo com os usuários existe.
        if [[ ! -f ${file} ]]
        then
            echo -e "${RED} O arquivo informado ${YELLOW}${file}${RESET} ${RED}não existe, por favor, verifique.${RESET}"
            exit 1
        fi

        #realizando for para o rsync
        for f_user in $(cat ${file})
        do
            main_rsync ${f_user} ${IP}

            if [[ $? == 111 ]]
            then
                continue
            fi
        done
    
    elif [[ ${TYPE} == --allserver ]]
    then

        if [[ ${REVERSE} == TRUE ]]
        then

            for a_user in $(ssh root@${IP} -p ${PORT} -o GSSAPIAuthentication=no "cut -d : -f2 /etc/trueuserdomains")
            do
                main_rsync ${a_user} ${IP}

                if [[ $? == 111 ]]
                then
                    continue
                fi
            done

        else

            for a_user in $(cut -d : -f2 /etc/trueuserdomains)
            do
                main_rsync ${a_user} ${IP}

                if [[ $? == 111 ]]
                then
                    continue
                fi
            done

        fi
    fi

}
#Fim de funções


#Inicio da tratvia do ticket.
TYPE=${1}

if [[ ${TYPE} == --allserver ]]
then
    #exemplo: bash <(curl -sk https://git.hostgator.com.br/advanced-support/migration/raw/dev/megazord.sh) --allserver 192.185.223.4 22 /home/hgtransf
    IP=${2}
    PORT=${3}
    TMPDIR="/home/hgtransfer/${4}"
    USER="vazio"
    
elif [[ ${TYPE} == --ftp ]]
then
    #exemplo: bash <(curl -sk https://git.hostgator.com.br/advanced-support/migration/raw/dev/megazord.sh) --ftp usuário senha 192.185.223.4 22 ftp /home/hgtransf
    USER=${2}
    PASSWORD=${3}
    IP=${4}
    PORT=${5}
    PROTOCOL=$(echo ${6} | tr '[:upper:]' '[:lower:]')
    TMPDIR="/home/hgtransfer/${7}"
elif [[ ${TYPE} == --multiftp ]]
then
    #exemplo: bash <(curl -sk https://git.hostgator.com.br/advanced-support/migration/raw/dev/megazord.sh) --multiftp [ARQUIVO-COM-DADOS] [ID-TICKET]
    USER="vazio"
    IP="192.192.192.192"
    PORT="22"
    FILE=${2}
    TMPDIR="/home/hgtransfer/${3}"
else
    USER=${2}
    IP=${3}
    PORT=${4}
    TMPDIR="/home/hgtransfer/${5}"
fi

    

#Exemplo de para validar as opções do menu
for options in "$@"
do
    case ${options} in
        --help|-h|--h|help)
                help
                shift 2
        ;;
        --setdns)
                SETDNS="TRUE"
                shift 2
        ;;
        --reverse)
                REVERSE="TRUE"
        shift 2
        ;;
        --allserver)
                ALLSERVER="TRUE"
                shift 2
        ;;
        --rsync)
                RSYNC="TRUE"
                shift 2
        ;;
        --skip-ftp-conn-validation)
                SKIP_FTP_CONN="TRUE"
                shift 2
        ;;
        --hostfile)
                HOST_FILE="TRUE"
                shift 2
        ;;
        *)

        ;;
    esac
done
#Fim do menu


#######Inicio de válidações básicas
#Verificando se informações básicas estão vazias
if [[ -z ${USER} ]] ||  [[  -z ${IP} ]] || [[ -z ${TMPDIR} ]] || [[ -z ${PORT} ]] && [[ ${HOST_FILE} == FALSE ]]
then
    echo -e "Usuário: ${USER:-${RED}Não informado${RESET}}\nIP: ${IP:-${RED}Não informado${RESET}}\nID do ticket: ${TMPDIR:-${RED}Não informado${RESET}}\nPorta SSH: ${PORT:-${RED}Não informado${RESET}}\n\n"
    help
fi

#Verificando se o tipo de migração repassado é válido.

if [[ ${TYPE} != --user ]] && [[ ${TYPE} != --reseller ]] && [[ ${TYPE} != --file ]] && [[ ${TYPE} != --allserver ]] && [[ ${TYPE} != --ftp ]] && [[ ${TYPE} != --multiftp ]] && [[ ${HOST_FILE} == FALSE ]]
then 
    echo -e "Tipo de migração inválida!\nTipo solicitado: ${RED}${TYPE}${RESET}\n"
    sleep 2
    help
    exit 1
fi

#######Fim de válidações básicas

if [[ ! -d /home/hgtransfer/ ]]
then
    
    mkdir -p /home/hgtransfer/
    
fi

if [[ ${HOST_FILE} == FALSE ]]
then

    #Criando conteúdo padrão
    echo -e "Criando conteúdo padrão para a migração.\n${TMPDIR}/restore/\n${TMPDIR}/restore/\n${TMPDIR}/rsync/\n${BOLD}Todos os logs a respeito da migração estarão disponíveis nos diretórios citados."
    mkdir -p ${TMPDIR}/pkg/
    mkdir -p ${TMPDIR}/restore/
    mkdir -p ${TMPDIR}/rsync/
    touch ${TMPDIR}/users_nao_migrados.txt
    sleep 1
fi

#Chamando função de teste de conexão
if [[ ${TYPE} != --ftp ]] && [[ ${TYPE} != --multiftp ]] && [[ ${TYPE} != --multiftp ]] && [[ ${HOST_FILE} == FALSE ]]
then
    ssh_check
fi

#Chamando funções de acordo com o menu
if [[ ${RSYNC} == TRUE ]] 
then

    if [[ ${TYPE} == "--ftp" ]] && [[ ${TYPE} == "--multiftp" ]]
    then
        echo -e "${RED}*${RESET} O Rsync não é compatível com migrações de FTP."
        exit 1
    fi
    
    rsync_migration

elif [[ ${TYPE} == "--user" ]]
then
    main_migration ${USER} ${IP} ${TMPDIR}

elif [[ ${TYPE} == "--reseller" ]]
then
    reseller_migration

elif [[ ${TYPE} == "--file" ]]
then
    file_migration

elif [[ ${TYPE} == "--allserver" ]]
then
    allserver_migration

elif [[ ${TYPE} == "--ftp" ]]
then
    if [[ ${REVERSE} == TRUE ]]
    then
        echo -e "${YELLOW}*${RESET} Migrações FTP não tem suporte a migração reversa. Continuando... "
    fi
    if [[ ${SETDNS} == TRUE ]]
    then
        echo -e "${YELLOW}*${RESET} Migrações FTP não tem suporte a opção ${BOLD}setdns${RESET}. Continuando... "
    fi

    migra_ftpuser

elif [[ ${TYPE} == "--multiftp" ]]
then
    if [[ ${REVERSE} == TRUE ]]
    then
        echo -e "${YELLOW}*${RESET} Migrações FTP não tem suporte a migração reversa. Continuando... "
    fi

    if [[ ${SETDNS} == TRUE ]]
    then
        echo -e "${YELLOW}*${RESET} Migrações FTP não tem suporte a opção ${BOLD}setdns${RESET}. Continuando... "
    fi

    mult_ftp

elif [[ ${HOST_FILE} == TRUE ]]
then
    hosts_file
fi
