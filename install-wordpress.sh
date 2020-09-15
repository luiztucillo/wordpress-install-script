#!/bin/bash

CURDIR=$(pwd)
DOCKER_DATA_FOLDER=~/docker-data
DB_NAME=wordpress
DB_PASSWORD=1234qwer
LOCALIZATION=pt_BR
WP_VERSION=latest

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=linux;;
    Darwin*)    machine=macos;;
    CYGWIN*)    machine=windows;;
    MINGW*)     machine=windows;;
    *)          machine="UNKNOWN:${unameOut}"
esac

while [ $# -gt 0 ]; do
    if [[ $1 == *"--"* ]]; then
        v="${1/--/}"
        declare $v="$2"
    fi
    shift
done

if [ -z $dst ]; then
    echo Argument --dst is required
    echo Usage: 
    echo -e "--dst \t\t\tDestination to install Wordpress"
    echo -e "--db_name \t\tSet database name. If already exists will use it (default: wordpress)"
    echo -e "--db_password \t\tSet database password (default: 1234qwer)"
    echo -e "--wp_version \t\tSet Wordpress version to install (default: latest)"
    echo -e "--docker_data_folder \tSet Docker Data folder (default: ~/docker-data)"
    echo -e "--with_woocommerce \tInstall WooCommerce"
    exit 1
fi

if [ ! -z $docker_data_folder ]; then
    DOCKER_DATA_FOLDER=$docker_data_folder
fi

if [ ! -z $db_name ]; then
    DB_NAME=$db_name
fi

if [ ! -z $db_password ]; then
    DB_PASSWORD=$db_password
fi

if [ ! -z $wp_version ]; then
    WP_VERSION=$wp_version
fi

[ ! -d $dst ] && echo Path $dst does not exists && exit 1

[ ! -d $DOCKER_DATA_FOLDER ] && echo Path $DOCKER_DATA_FOLDER does not exists && exit 1

cd $dst
rm -rf *
rm -rf .docker && mkdir .docker
cd .docker
git clone git@github.com:luiztucillo/docker-php-apps.git ./
echo -e "APPLICATION=wordpress\nPHP_VERSION=7.3\nDOMAIN=wordpress.local\nUSERNAME=$USER\nHOST_APP_PATH=../\nDOCKER_DATA_FOLDER=$DOCKER_DATA_FOLDER\nDB_PASSWORD=$DB_PASSWORD\nHOST_OS=$machine" > .env
docker ps | awk '{print $1}' | xargs docker stop 2> /dev/null
docker-compose up -d --build
cd helpers/wordpress
bash install-wpcli.sh
cd ../../../

while ! mysqladmin ping -uroot -p$DB_PASSWORD -h 127.0.0.1 --silent; do
    sleep 1
done

echo -e "\nCreating database"
docker exec wordpress_mysql mysql -uroot -p$DB_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $DB_NAME"

echo -e "\nDownloading"
docker exec wordpress_php wp core download --locale=$LOCALIZATION --version=$WP_VERSION

echo -e "\nConfiguring wordpress"
docker exec wordpress_php wp config create --dbname=$DB_NAME --dbuser=root --dbpass=$DB_PASSWORD --dbhost=mysql

echo -e "\nInstalling wordpress"
docker exec wordpress_php wp core install --url=wordpress.local --title=Example --admin_user=admin --admin_password=1234qwer --admin_email=info@example.com --admin_password=$DB_PASSWORD


# echo -e "\nInstalling woocommerce"
# docker exec wordpress_php wp plugin install woocommerce --activate
