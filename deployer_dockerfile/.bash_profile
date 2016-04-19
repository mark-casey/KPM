
grep "\.maas" /etc/hosts &>/dev/null
R=$?

if [ ${R} -ne 0 ]
then
    cat /etc/additional_static_hosts >> /etc/hosts
fi
