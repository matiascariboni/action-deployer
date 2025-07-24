echo "${{ secrets.EC2_KEY }}" | tr -d '\r' > server_key.pem
          chmod 600 server_key.pem
          mkdir -p ~/.ssh
          ssh-keyscan -H ${{ secrets.EC2_IP }} >> ~/.ssh/known_hosts