```
export MAASVM_IPMINET_IP='10.100.0.16'
export MAASVM_MGMTNET_IP='10.101.0.16'
export #MAASVM_DEFAULTGW_IP='10.101.0.3'  # assumes the '.1' of the management IP if unset
export MAAS_ADMIN_USER='admin'
export MAAS_ADMIN_EMAIL='admin@example.com'
export MAAS_ADMIN_PASS='admin'

vagrant up
```
