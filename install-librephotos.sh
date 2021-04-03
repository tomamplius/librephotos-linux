#!/usr/bin/env bash
##### TODO ######
#Apache proxy or Caddy proxy or nginx
#auto configure postgres on local install
#ask parameter like db parameter login admin passord etc..
#Add parameter like --local-postgresql --posgresql-ip --dedicated-install
#Update readme to non interactive installation

function LOG_MANAGEMENT() {
	#TODO: Create verbose mode
	while read -r data; do
                if [[ $data == ---* ]] ; then
			echo $data
		else
			echo $data >$LOG_INSTALL
		fi
	done
}

function installGlobal(){
	# PRE INSTALL
	id -g librephotos > /dev/null || groupadd -r librephotos
	id -u librephotos > /dev/null || useradd --home-dir /usr/lib/librephotos --comment "librephotos user" -g librephotos -mr -s /usr/sbin/nologin librephotos

	mkdir -p $BASE_LOGS
	chown -R librephotos:librephotos $BASE_LOGS
}

# LIBREPHOTOS : BACKEND
function installBackend(){
	echo ---Install system dependency
	apt install --no-install-recommends -y \
		swig libpq-dev postgresql-common curl libopenblas-dev libmagic1 libboost-all-dev libxrender-dev \
		liblapack-dev git bzip2 cmake build-essential libsm6 libglib2.0-0 libgl1-mesa-glx gfortran gunicorn \
		libheif-dev libssl-dev rustc liblzma-dev python3 python3-pip imagemagick

	mkdir -p $BASE_DATA/data_models/{places365,im2txt}
	mkdir -p $BASE_DATA/protected_media/{thumbnails_big,square_thumbnails,square_thumbnails_small,faces}
	mkdir -p $BASE_DATA/data/nextcloud_media
	chown -R librephotos:librephotos $BASE_DATA

	su - -s $(which bash) librephotos <<-EOF
		echo ---Download model
		curl -SL https://s3.eu-central-1.amazonaws.com/ownphotos-deploy/places365_model.tar.gz | tar -zxC $BASE_DATA/data_models/places365/
		curl -SL https://s3.eu-central-1.amazonaws.com/ownphotos-deploy/im2txt_model.tar.gz | tar -zxC $BASE_DATA/data_models/im2txt/
		curl -SL https://s3.eu-central-1.amazonaws.com/ownphotos-deploy/im2txt_data.tar.gz | tar -zxC $BASE_DATA/data_models/im2txt/
		mkdir -p ~/.cache/torch/hub/checkpoints/
		curl -SL https://download.pytorch.org/models/resnet152-b121ed2d.pth -o ~/.cache/torch/hub/checkpoints/resnet152-b121ed2d.pth

		echo ---Install torch and torchvision
		pip3 install torch==1.7.1+cpu torchvision==0.8.2+cpu -f https://download.pytorch.org/whl/torch_stable.html
		echo ---Install dlib
		pip3 install -v --install-option="--no" --install-option="DLIB_USE_CUDA" --install-option="--no" --install-option="USE_AVX_INSTRUCTIONS" --install-option="--no" --install-option="USE_SSE4_INSTRUCTIONS" dlib

		echo ---Install backend
		git clone https://github.com/LibrePhotos/librephotos backend
		cd backend
		pip3 install -r requirements.txt
		python3 -m spacy download en_core_web_sm
EOF

	echo ---register services in systemd
	systemctl enable librephotos-backend
	systemctl enable librephotos-worker.service
	systemctl enable librephotos-image-similarity.service

	[ -d /usr/lib/librephotos/bin ] || mkdir -p /usr/lib/librephotos/bin
	cp ressources/backend/bin/* /usr/lib/librephotos/bin/
	ln -fs /usr/lib/librephotos/bin/librephotos-cli /usr/sbin/librephotos-cli
	chown -R librephotos:librephotos  /usr/lib/librephotos/bin/
	cp -r ressources/backend/etc/librephotos/ /etc/
	cp ressources/backend/systemd/* /etc/systemd/system/
}

# LIBREPHOTOS : FRONTEND
function installFrontend(){
	echo ---Install system dependency
	apt-get install -y curl git xsel nodejs git npm --no-install-recommends

	su - -s $(which bash) librephotos <<-EOF
		echo ---Install frontend
		git clone https://github.com/LibrePhotos/librephotos-frontend frontend
		cd frontend
		echo ---Install npm dependency
		npm install
		echo ---Build frontend
		npm run build
		npm install serve
EOF

	echo ---register services in systemd
	systemctl enable librephotos-frontend

	[ -d /usr/lib/librephotos/bin ] || mkdir -p /usr/lib/librephotos/bin
	cp ressources/frontend/bin/* /usr/lib/librephotos/bin/
	chown -R librephotos:librephotos  /usr/lib/librephotos/bin/
	cp ressources/frontend/systemd/* /etc/systemd/system/
}

# LIBREPHOTOS : PROXY
function installNginx(){
    apt install -y nginx
    cp ressources/nginx/nginx/nginx.conf /etc/nginx/nginx.conf
    systemctl restart nginx
}

function installPostgres(){
	apt install -y postgresql
}
function installRedis(){
	apt install -y redis
}

#Ask information installation
echo "Dedicated host install and configure librephotos, nginx, redis and postgres"
until [[ $LOCAL_FULL =~ ^(Y|N|y|n){1}$ ]]; do
	read -rp "Do you want install librephotos on dedicated host? [y/N]: " -e LOCAL_FULL
done
if [[ $LOCAL_FULL =~ (Y|y) ]] ; then
	LOCAL_BACKEND=y
	LOCAL_FRONTEND=y
	LOCAL_NGINX=y
	LOCAL_POSTGRES=y
	LOCAL_REDIS=y
fi

until [[ $LOCAL_BACKEND =~ ^(Y|N|y|n){1}$ ]]; do
	read -rp "Do you want install librephotos BACKEND on this host? [Y/n]: " -e LOCAL_BACKEND
done

until [[ $LOCAL_FRONTEND =~ ^(Y|N|y|n){1}$ ]]; do
	read -rp "Do you want install librephotos FRONTEND on this host? [Y/n]: " -e LOCAL_FRONTEND
done

if [[ $LOCAL_BACKEND =~ (N|n) && $LOCAL_FRONTEND =~ (N|n) ]] ; then
	echo "Nothing to do"
	exit
fi

if [[ $LOCAL_BACKEND =~ (Y|y) ]] ; then
	until [[ $LOCAL_POSTGRES =~ ^(Y|N|y|n){1}$ ]]; do
		read -rp "Do you want use postgresql on this host? [y/n]: " -e LOCAL_POSTGRES
	done
	until [[ $LOCAL_REDIS =~ ^(Y|N|y|n){1}$ ]]; do
		read -rp "Do you want use redis on this host? [y/n]: " -e LOCAL_REDIS
	done
fi

until [[ $LOCAL_NGINX =~ ^(Y|N|y|n){1}$ ]]; do
	read -rp "Do you want install and configure NGINX on this host? [Y/n]: " -e LOCAL_NGINX
done

# DEPLOYEMENT
set -a

export TS=$(date +%Y%m%d%H%M%S)
export LOG_INSTALL=log/${TS}.log
export BASE_DATA=/var/lib/librephotos
export BASE_LOGS=/var/log/librephotos
echo All log are available in $LOG_INSTALL

cd $(dirname $0)
mkdir -p log

echo "$(date +%H:%M:%S) System configuration"
installGlobal 2>&1 | LOG_MANAGEMENT

if [[ $LOCAL_BACKEND =~ (Y|y) ]] ; then
	echo "$(date +%H:%M:%S) Backend install"
	installBackend 2>&1 | LOG_MANAGEMENT
fi

if [[ $LOCAL_FRONTEND =~ (Y|y) ]] ; then
	echo "$(date +%H:%M:%S) Frontend install"
	installFrontend 2>&1 | LOG_MANAGEMENT
fi

if [[ $LOCAL_NGINX =~ (Y|y) ]] ; then
	echo "$(date +%H:%M:%S) Nginx install"
	installNginx 2>&1 | LOG_MANAGEMENT
fi

if [[ $LOCAL_POSTGRES =~ (Y|y) ]] ; then
	echo "$(date +%H:%M:%S) Postgres install"
	installPostgres 2>&1 | LOG_MANAGEMENT
fi

if [[ $LOCAL_REDIS =~ (Y|y) ]] ; then
 	echo "$(date +%H:%M:%S) Redis install"
	installRedis 2>&1 | LOG_MANAGEMENT
fi

exit
