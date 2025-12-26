# Komari监控面板搭建教程

教程参考来源

[Komari 文档](https://komari-document.pages.dev/)

[Komari Github](https://github.com/komari-monitor/komari)

[全国ICMP Ping监控节点地址分享](https://www.nodeseek.com/post-82748-1)

# 第一步（安装依赖文件）
```
apt install -y curl wget sudo unzip
```
```
apt install -y socat
```

# 第二步（安装 Komari面板）
运行以下安装脚本
```
curl -fsSL https://raw.githubusercontent.com/komari-monitor/komari/main/install-komari.sh -o install-komari.sh
chmod +x install-komari.sh
sudo ./install-komari.sh
```
# 第三步（绑定[cloudflare](https://cloudflare.com)可以开启CDN）
# 第四步（利用闲置80端口申请网站证书）

安装 Acme 脚本
```
curl https://get.acme.sh | sh
```
自行更换代码中的域名、邮箱为你解析的域名及邮箱
```
~/.acme.sh/acme.sh --register-account -m xxxx@xxxx.com
```
```
~/.acme.sh/acme.sh  --issue -d xxxxxxx.com   --standalone
```
安装证书到指定文件夹，自行更换代码中的域名为你解析的域名
```
~/.acme.sh/acme.sh --installcert -d xxxxxxx.com --key-file /root/private.key --fullchain-file /root/cert.crt
```

# 第五步（安装nginx）
```
apt install -y nginx
```
# 第六步（编辑nginx文件）
打开nginx.conf文件，清空所有配置，粘贴第二步内容，只需要更改 xxxxxx.com; #填写监控网站域名 填写你自己绑定的域名
```
cd /etc/nginx/nginx.conf
```
```
#user nobody;
worker_processes 1;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;

    sendfile on;
    keepalive_timeout 65;

    client_max_body_size 100M;

    server {
        listen 80;
        listen 443 ssl;
        server_name 2221688.xyz;

        # SSL 配置（优化后）
        ssl_certificate /root/cert.crt;
        ssl_certificate_key /root/private.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;
        add_header Strict-Transport-Security "max-age=31536000";
        error_page 497 https://$host$request_uri;

        # 主反向代理
        location / {
            proxy_pass http://127.0.0.1:8888;
            proxy_set_header Host $host;
            proxy_set_header Origin https://$host;
            proxy_set_header nz-realip $http_CF_Connecting_IP;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
        }
    }
}
```
重启nginx
```
systemctl restart nginx && systemctl status nginx
```
检查配置
```
nginx -t
```
重载生效
```
nginx -s reload
```
