#!/bin/bash

# Install Docker
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose

# Install Go
GO_VERSION="1.21.1" # Change this to the desired version
curl -LO "https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
rm "go${GO_VERSION}.linux-amd64.tar.gz"

# Set up GOPATH and update PATH
echo "export GOPATH=$HOME/go" >> ~/.bashrc
echo "export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin" >> ~/.bashrc
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

# Step 3: Install Reproxy
go install github.com/umputun/reproxy/app@latest
mv -f $GOPATH/bin/app $GOPATH/bin/reproxy

# Step 4: Install Updater
go install github.com/umputun/updater/app@latest
mv -f $GOPATH/bin/app $GOPATH/bin/updater

# Create systemd service files

# Updater systemd service
secret_key=$(openssl rand -hex 16)
echo "Generated secret key for updater: $secret_key"

cp ./updater-example.yml /etc/updater.yml

echo "[Unit]
Description=Updater for Docker containers
After=network.target

[Service]
ExecStart=$GOPATH/bin/updater --listen=:7010 --key=$secret_key --file=/etc/updater.yml
Restart=always
User=$USER
Group=$USER
Environment=PATH=/usr/local/bin:/usr/bin:/bin:$GOPATH/bin

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/updater.service > /dev/null

# Reproxy systemd service
cp ./reproxy-example.yml /etc/reproxy.yml

echo "[Unit]
Description=Reproxy reverse proxy
After=network.target

[Service]
ExecStart=$GOPATH/bin/reproxy --docker.enabled --docker.auto --listen :7000 --file.enabled --file.name=/etc/reproxy.yml
Restart=always
User=$USER
Group=$USER
Environment=PATH=/usr/local/bin:/usr/bin:/bin:$GOPATH/bin

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/reproxy.service > /dev/null

# Reload systemd, enable and start services
sudo systemctl daemon-reload
sudo systemctl enable reproxy updater
sudo systemctl start reproxy updater

echo "Reproxy and Updater are now set up and running!"