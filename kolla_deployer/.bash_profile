
grep "\.maas" /etc/hosts &>/dev/null
R=$?

if [ ${R} -ne 0 ]
then
    ### temporary unholy Bash hax to get MAAS's randomized hostnames into deployer container's /etc/hosts - will make a little cleaner later
    #
    # get dynamic inventory output, do some line merging and sed/awk to make it look like HOSTS entries and append onto /etc/hosts
    dynamic_inven_hostnames_and_ips() { /usr/local/share/kolla/ansible/inventory/ansible_maas_dynamic_inventory.py --nodes | grep -E "hostname|ip_address\".+[0-9]{3}[\", ]+$" | sed "N;s/\n//"; } && \
    IFS=$'\n\b'; for hosts_entry in $(dynamic_inven_hostnames_and_ips); do echo "${hosts_entry}" | sed -e 's/hostname":\|ip_address\|[", ]//g' -e 's/:/\t/' | awk '{print $2"\011"$1}' | tee -a /etc/hosts; done; unset IFS
    ###
fi
