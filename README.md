基于 Ubuntu 的配置说明
====

准备源：
```
sudo apt-get -y install python-software-properties
sudo add-apt-repository ppa:webupd8team/java
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
sudo echo "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen" | sudo tee -a /etc/apt/sources.list.d/10gen.list
sudo apt-get -y update
sudo apt-get -y install git-core
```

安装 MongoDB, Redis ：
`sudo apt-get -y install mongodb-10gen redis-server`

安装 Oracle Java 7 ：
`sudo apt-get -y install oracle-java7-installer`

安装 RVM, JRuby ：
```
curl -L https://get.rvm.io | bash -s stable
rvm install jruby
```

安装 Tengine 依赖包：
`sudo apt-get -y install build-essential libpcre3-dev libssl-dev libgeoip-dev libxslt-dev libgd2-xpm-dev`

编译 Tengine ：
```
git clone git://github.com/taobao/tengine.git

cd tengine

./configure \
--prefix=/etc/nginx \
--sbin-path=/usr/sbin \
--error-log-path=/var/log/nginx/error.log \
--conf-path=/etc/nginx/conf/nginx.conf \
--pid-path=/var/run \
--with-http_addition_module=shared \
--with-http_xslt_module=shared \
--with-http_geoip_module=shared \
--with-http_image_filter_module=shared \
--with-http_sub_module=shared \
--with-http_flv_module=shared \
--with-http_slice_module=shared \
--with-http_mp4_module=shared \
--with-http_concat_module=shared \
--with-http_random_index_module=shared \
--with-http_map_module=shared \
--with-http_split_clients_module=shared \
--with-http_charset_filter_module=shared \
--with-http_access_module=shared \
--with-http_userid_filter_module=shared \
--with-http_footer_filter_module=shared \
--with-http_upstream_least_conn_module=shared \
--with-http_upstream_ip_hash_module=shared \
--with-http_user_agent_module=shared \
--with-http_memcached_module=shared \
--with-http_referer_module=shared \
--with-http_limit_conn_module=shared \
--with-http_limit_req_module=shared \
--with-http_scgi_module=shared \
--with-http_secure_link_module=shared \
--with-http_autoindex_module=shared \
--with-http_sysguard_module=shared \
--with-http_rewrite_module=shared \
--with-http_fastcgi_module=shared \
--with-http_empty_gif_module=shared \
--with-http_browser_module=shared \
--with-http_uwsgi_module=shared

make

sudo make install
echo "启动脚本"
sudo vim /etc/init.d/nginx
sudo chmod +x /etc/init.d/nginx
echo "重写配置文件"
sudo rm -fr /etc/nginx/conf/nginx.conf
sudo vim /etc/nginx/conf/nginx.conf
sudo mkdir /etc/nginx/conf/sites-enabled /etc/nginx/conf/conf.d
echo "注册系统服务"
sudo update-rc.d nginx defaults
sudo service nginx start
```

取出应用，启动服务：
```
git clone https://github.com/mimosa/meta.git

cd meta
echo "Web 服务，占用 9292 端口"
mizuno -D -E production -P /tmp/mizuno_meta.pid
echo "队列服务，执行定时抓取任务"
nohup bundle exec sidekiq-scheduler -e production -C ./config/sidekiq.yml -r ./config/boot.rb >> log/sidekiq.log 2>&1 &
```
