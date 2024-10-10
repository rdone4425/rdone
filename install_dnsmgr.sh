#!/bin/bash

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]
  then echo "请以root权限运行此脚本"
  exit
fi

# 设置变量
DOMAIN="dd2.442595.xyz"
DB_PASSWORD="442595622"
INSTALL_DIR="/var/www/dnsmgr"
DOWNLOAD_URL="https://github.com/find-xposed-magisk/dnsmgr_caihong/releases/download/main_1.7.1/dnsmgr_1.7.1.zip"

# 更新系统并安装必要的软件包
apt update
apt install -y nginx mariadb-server php php-fpm php-mysql php-curl php-mbstring php-xml php-zip unzip

# 创建安装目录
mkdir -p $INSTALL_DIR

# 下载并解压项目文件
cd /tmp
wget $DOWNLOAD_URL -O dnsmgr.zip
if [ $? -ne 0 ]; then
    echo "下载失败,请检查 URL 是否正确"
    exit 1
fi
unzip dnsmgr.zip -d $INSTALL_DIR
rm dnsmgr.zip

# 设置目录权限
chown -R www-data:www-data $INSTALL_DIR
chmod -R 755 $INSTALL_DIR

# 自动赋权
find $INSTALL_DIR -type d -exec chmod 755 {} \;
find $INSTALL_DIR -type f -exec chmod 644 {} \;
chmod -R 777 $INSTALL_DIR/runtime
chmod -R 777 $INSTALL_DIR/public

# 配置Nginx
cat > /etc/nginx/sites-available/dnsmgr <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $INSTALL_DIR/public;
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

ln -s /etc/nginx/sites-available/dnsmgr /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx

# 创建数据库并导入初始数据
mysql -e "CREATE DATABASE IF NOT EXISTS dnsmgr;"
mysql -e "CREATE USER IF NOT EXISTS 'dnsmgr'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON dnsmgr.* TO 'dnsmgr'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
mysql dnsmgr < $INSTALL_DIR/app/sql/install.sql

# 配置项目
if [ -f "$INSTALL_DIR/.example.env" ]; then
    cp $INSTALL_DIR/.example.env $INSTALL_DIR/.env
    sed -i "s/{dbhost}/localhost/g" $INSTALL_DIR/.env
    sed -i "s/{dbname}/dnsmgr/g" $INSTALL_DIR/.env
    sed -i "s/{dbuser}/dnsmgr/g" $INSTALL_DIR/.env
    sed -i "s/{dbpwd}/$DB_PASSWORD/g" $INSTALL_DIR/.env
    sed -i "s/{dbport}/3306/g" $INSTALL_DIR/.env
    sed -i "s/{dbprefix}/dnsmgr_/g" $INSTALL_DIR/.env
else
    echo ".example.env 文件不存在"
fi

echo "安装完成，请访问 http://$DOMAIN 完成最后的配置"
