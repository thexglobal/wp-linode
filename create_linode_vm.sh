# Create Nanode VM 
TOKEN='7d9fce46e1f87ff3116c1d381b340af634b85f3c8485b367334de35602d41d24'
curl -H "Content-Type: application/json" \
-H "Authorization: Bearer $TOKEN" \
-X POST -d '{
    "authorized_users": [
        "henry9919"
    ],
    "backups_enabled": false,
    "booted": true,
    "image": "linode/debian12",
    "label": "debian-us-east",
    "private_ip": false,
    "region": "us-east",
    "root_pass": "MARJORAM6mailman.ridicule8atheist",
    "tags": [
        "wordpress"
    ],
    "type": "g6-nanode-1"
}' https://api.linode.com/v4/linode/instances

# create virtual enviroment
venv=linode
python3 -m venv .$venv
source .$venv/bin/activate
python3 -m pip install --upgrade pip
pip3 install linode-cli --upgrade
pip3 install boto3

# Initiate the Linode CLI configuration 
source .linode/bin/activate
export LINODE_CLI_TOKEN=$(op read "op://dev/Linode/admin_token")
linode-cli configure --token



# Create a Linode VM
label=wp_vinalink_net
root_pass=moleskin8quasar_sellout3GERMAN

linode-cli linodes create \
  --authorized_users henry9919 \
  --backups_enabled false \
  --booted true \
  --image linode/debian12 \
  --label $label \
  --private_ip false \
  --region us-east \
  --root_pass $root_pass \
  --tags wordpress \
  --type g6-nanode-1

# Retrieve the Public I
VM_IP=$(linode-cli linodes list \
    --label $label \
    --json | jq -r '.[].ipv4[0]')

echo $VM_IP

ssh root@${VM_IP}

# Upload theme
theme=kava.zip
scp -O $theme root@$VM_IP:/var/www/${label}/wp-content/themes