#!/bin/bash

# 更新系统并安装必要的软件包
apt update && apt upgrade -y
apt install -y nginx mysql-server php php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip unzip wget

# 提示用户输入域名
read -p "请输入您的域名: " domain_name

# 提示用户输入数据库密码
read -sp "请输入数据库密码: " db_password
echo

# 强制删除并重新创建目标目录
rm -rf /var/www/dnsmgr
mkdir -p /var/www/dnsmgr

# 下载最新版本的dnsmgr_caihong
wget https://github.com/find-xposed-magisk/dnsmgr_caihong/archive/refs/tags/main_1.7.1.zip
unzip main_1.7.1.zip
rm -rf /var/www/dnsmgr/*
mv dnsmgr_caihong-main_1.7.1/* /var/www/dnsmgr/
rm -rf dnsmgr_caihong-main_1.7.1 main_1.7.1.zip

# 设置目录权限
chown -R www-data:www-data /var/www/dnsmgr
chmod -R 755 /var/www/dnsmgr

# 检查并启动Nginx
systemctl start nginx
systemctl enable nginx

# 检查并启动MySQL
systemctl start mysql
systemctl enable mysql

# 配置Nginx
cat > /etc/nginx/sites-available/dnsmgr << EOF
server {
    listen 80;
    server_name $domain_name;
    root /var/www/dnsmgr/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
    }
}
EOF

# 强制删除并重新创建符号链接
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/dnsmgr
ln -sf /etc/nginx/sites-available/dnsmgr /etc/nginx/sites-enabled/

# 检查Nginx配置
nginx -t

# 如果配置正确，则重启Nginx
if [ $? -eq 0 ]; then
    systemctl restart nginx
else
    echo "Nginx配置错误，请检查配置文件"
    exit 1
fi

# 删除现有的数据库和用户（如果存在）
mysql -e "DROP DATABASE IF EXISTS dnsmgr;"
mysql -e "DROP USER IF EXISTS 'dnsmgr'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# 创建新的数据库和用户
mysql -e "CREATE DATABASE dnsmgr;"
mysql -e "CREATE USER 'dnsmgr'@'localhost' IDENTIFIED BY '$db_password';"
mysql -e "GRANT ALL PRIVILEGES ON dnsmgr.* TO 'dnsmgr'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# 导入数据库结构
mysql dnsmgr < /var/www/dnsmgr/app/sql/install.sql

# 配置环境变量
cp /var/www/dnsmgr/.example.env /var/www/dnsmgr/.env
sed -i "s/DB_DATABASE=.*/DB_DATABASE=dnsmgr/" /var/www/dnsmgr/.env
sed -i "s/DB_USERNAME=.*/DB_USERNAME=dnsmgr/" /var/www/dnsmgr/.env
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$db_password/" /var/www/dnsmgr/.env

# 安装完成后打印域名
echo "安装完成！请访问 http://$domain_name 来完成最后的配置步骤。"
