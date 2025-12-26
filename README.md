# 哪吒监控面板v1搭建教程

教程参考来源

[哪吒wiki](https://github.com/Chasing66)

[JollyRoger blog](https://jollyroger.top/sites/320.html)

[全国ICMP Ping监控节点地址分享](https://www.nodeseek.com/post-82748-1)

# 第一步（安装依赖文件）
```
apt install -y curl wget sudo unzip
```
```
apt install -y socat
```

# 第二步（安装 哪吒Dashboard）
运行以下安装脚本
```
curl -L https://raw.githubusercontent.com/nezhahq/scripts/refs/heads/main/install.sh -o nezha.sh && chmod +x nezha.sh && sudo ./nezha.sh
```
如果你的服务器位于中国大陆，可以使用镜像
```
curl -L https://gitee.com/naibahq/scripts/raw/main/install.sh -o nezha.sh && chmod +x nezha.sh && sudo CN=true ./nezha.sh
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
#user  nobody;
worker_processes  1;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

#pid        logs/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
    #                  '$status $body_bytes_sent "$http_referer" '
    #                  '"$http_user_agent" "$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    # 新增：允许最大的请求体大小为 100M（根据需要可调整）
    client_max_body_size 100M;

    server {
        listen 80;
        listen 443 ssl;
        server_name 88888888.xyz;

        index index.php index.html index.htm default.php default.htm default.html;
        root /home/web/nezha;

        # SSL 配置
        ssl_certificate    /root/cert.crt;
        ssl_certificate_key    /root/private.key;
        ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
        ssl_ciphers EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:EECDH+3DES:RSA+3DES:!MD5;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;
        add_header Strict-Transport-Security "max-age=31536000";
        error_page 497  https://$host$request_uri;

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

        # WebSocket 和特定路径反代
        location ~ ^/(ws|terminal/.+|file/.+)$ {
            proxy_pass http://127.0.0.1:8008;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "Upgrade";
            proxy_set_header Host $host;
        }
    }
}
```
重启nginx
```
systemctl restart nginx && systemctl status nginx
```
# 第七步
直接访问域名，添加你的被控机器，其他哪吒相关操作，参考[哪吒wiki](https://github.com/Chasing66)
