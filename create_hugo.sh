#!/bin/bash
# This script will create two repositories on your GitHub account
# Notes
# 
# apt-get install jq ruby
# gem install travis

# If $HISTCONTROL is not set as "ignoreboth" or "ignorespace" we will not be able to
# Not save PASS variable into .bash_history


if [ "$HISTCONTROL" != "ignoreboth" ] || [ "$HISTCONTROL" != "ignorespace" ]; then
	HISTCONTROL=ignoreboth
fi

GH_USER=''
# The following space is on purpose
 GH_TOKEN=''
 
GH_LUSER="`echo ${GH_USER} | tr '[:upper:]' '[:lower:]'`"
GH_EMAIL="${GH_LUSER}@users.noreply.github.com"
REPO_SOURCE='source-blog'
REPO_WWW="${GH_LUSER}.github.io"

RSA_KEYNAME="id_rsa"
RSA_KEYPATH="${HOME}/.ssh/${RSA_KEYNAME}"
TRAVIS_KEYNAME="travis_key"
TRAVIS_KEYPATH="${HOME}/.ssh/${TRAVIS_KEYNAME}"

HUGO_VERSION=hugo_0.20.7_Linux-64bit.deb

main() {
	echo "======================================================================================="
	echo "This script configures a Hugo installation inside GitHub personal account."
	echo "It will create two repositories to manage Hugo:"
	echo "· ${REPO_SOURCE}: 	Where all the files necessary to compile all the HTML stuff from travis."
	echo "· ${REPO_WWW}: 		Where all the HTML goes."
	echo
	echo "The ${REPO_WWW} repository will be automatically updated once the user commit a "
	echo "new post to ${REPO_SOURCE}."
	echo
	echo "Requirements to run this script:"
	echo "· apt-get install ruby jq"
	echo "· gem install travis"
	echo "· Have a GitHub personal access token with the following privilegues:"
	echo "	✔ repo:  		Full control of private repositories."
	echo "	  ✔ repo:status		Access commit status."
	echo "	  ✔ repo_deployment:	Access deployment status."
	echo "	  ✔ public_repo:	Access public repositories."
	echo "	✔ admin:public_key	Full control of user public keys."
	echo "	  ✔ write:public_key	Write user public keys."
	echo "	  ✔ read:public_key	Read user public keys."
	echo "	✔ delete_repo  		Delete repositories."
	echo		
	echo "It perfoms the following actions:"
	echo "· Deletes (just in case they exist from previous executions) and recreates:"
	echo "	· Specific local folder (${REPO_SOURCE})."
	echo "	· Specific SSH Keys (${RSA_KEYNAME} and ${RSA_KEYPATH})."
	echo "	· Specific repositories on your GitHub accout (${REPO_SOURCE}, ${REPO_WWW})."
	echo "· Sets the recently created SSH Keys to your GitHub account."
	echo "· Installs hugo and creates a local hugo repository."
	echo "· Configures a theme of my choice (you are free to fork and change it)."
	echo "· Creates all the Travis-ci configuration deploy the blog correctly."
	echo "· Asks the user to commit a first post or print the necessary commands to do it.s"
	echo
	echo "Please install all the dependencies before execute this script!"
	echo -e "\t\t\t\t\t\t\t\t\t-- Tzaoh."
	echo "======================================================================================="
	pause
	clear
	
	# Reseting previous installations
	reset_installation
	
	# Installing hugo 
	install_hugo

	# Generating public keys for user
	gen_keypair "${RSA_KEYPATH}" "${GH_EMAIL}"
	gen_keypair "${TRAVIS_KEYPATH}" "${GH_EMAIL}"
	
	# Create repositories on GitHub for source-blog and compiled web pages (html, images, styles ...)
	create_repo "${GH_USER}" "${GH_TOKEN}" "${REPO_SOURCE}"
	create_repo "${GH_USER}" "${GH_TOKEN}" "${REPO_WWW}"
	
	# We set the created public key for contact with GitHub.
	# One for our user and another one to let travis do commits
	gh_set_pbkey "${GH_USER}" "${GH_TOKEN}" "${GH_USER}'s Key" "${RSA_KEYPATH}.pub"
	gh_set_pbkey "${GH_USER}" "${GH_TOKEN}" "Travis-CI's Key" "${TRAVIS_KEYPATH}.pub"
	
	# Create a new site with hugo
	echo "[+] Creating local hugo site..."
	hugo new site "${REPO_SOURCE}" > /dev/null
	cd "${REPO_SOURCE}"
	
	# Configuring our specific theme
	config_mainroad_theme
	
	# Initiating the local repo
	git init > /dev/null
	git remote add origin git@github.com:"${GH_USER}"/"${REPO_SOURCE}".git > /dev/null
	git fetch --quiet
	git checkout -t origin/master --quiet
	echo /public >> .gitignore
	
	# Generating .travis.yml
	gen_travis ${GH_USER} ${GH_TOKEN} ${REPO_SOURCE} ${TRAVIS_KEYPATH}
	echo "- chmod 600 ${TRAVIS_KEYNAME}" >> .travis.yml
	
	# Generating Makefile
	gen_Makefile

	# Commit all
	git add -A > /dev/null
	git commit -m "Commit source-blog" --quiet
	git push --set-upstream origin master --quiet
	
	read -p "	[!] Do you want to build a test post? [y/n] " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		hugo new post/my-first-post.md
		echo My first post >> content/post/my-first-post.md
		git add -A > /dev/null
		git commit -m "a"  --quiet
		git push  --quiet
	else
		echo 'Done!'
		echo 'The following post pushes will build correctly.'
		echo '====================================================='
		echo '$ cd'
		echo '$ hugo new post/my-first-post.md'
		echo '$ echo My first post >> content/post/my-first-post.md'
		echo '$ git add -A && git commit -m "a" && git push'
	fi
}

pause() {
	if [ "$#" -ne 1 ]; then
		str="Press any key to continue...";
	else
		str="$1"
	fi
	read -n1 -r -p "${str}" key
}

reset_installation() {
	echo "[+] Reseting previous installations..."
	# cd
	rm -Rf source-blog/ 2> /dev/null

	# Delete the repos, just in case they do exist
	curl -X DELETE -s -u "${GH_USER}":"${GH_TOKEN}" https://api.github.com/repos/${GH_USER}/${REPO_SOURCE} > /dev/null
	curl -X DELETE -s -u "${GH_USER}":"${GH_TOKEN}" https://api.github.com/repos/${GH_USER}/${REPO_WWW} > /dev/null
	
	# Ask to delete all user's SSH Keys.
	read -p "	[!] Do you want to delete your local and remote SSH keys? [y/n] " -n 1 -r
	echo
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		rm "${HOME}"/.ssh/{"${RSA_KEYNAME}"{,.pub},"${TRAVIS_KEYNAME}"{,.pub}} 2> /dev/null
		ids=`curl -s -u "${GH_USER}":"${GH_TOKEN}" https://api.github.com/user/keys | jq '.[].id' `
		
		for id in $ids; do
			curl -X DELETE -s -u "${GH_USER}":"${GH_TOKEN}" https://api.github.com/user/keys/$id > /dev/null
        done
	fi
}

install_hugo() {
	# Installing hugo 
	# TODO: Check if hugo installed (version too?)
	echo "[+] Installing ${HUGO_VERSION}..."
	wget -q "https://github.com/spf13/hugo/releases/download/v0.20.7/${HUGO_VERSION}"
	# dpkg -l -i "${HUGO_VERSION}"
	dpkg -l -i "${HUGO_VERSION}" 2> /dev/null
	rm "${HUGO_VERSION}"
}

gen_keypair() {
	if [ "$#" -ne 2 ]; then
		echo "[-] Illegal number of parameters at \"gen_keypair()\"."
		exit
	fi
	
	key_path=$1
	mail=$2
	
	# Generating public keys for user
	if [ ! -f "${key_path}" ]; then
		echo "[+] Generating new public & private keys (${key_path})..."
		ssh-keygen -t rsa -b 4096 -f "${key_path}" -q -N "" -C "${mail}"
	fi
}

create_repo() {
	if [ "$#" -ne 3 ]; then
		echo "[-] Illegal number of parameters at \"create_repo()\"."
		exit
	fi
	
	ghuser=$1
	ghtoken=$2
	repo=$3
	
	echo "[+] Generating repository \"${repo}\"..."
	curl -s -u ${ghuser}:${ghtoken} https://api.github.com/user/repos -d \
		"{\"name\":\"${repo}\", \"auto_init\":\"true\"}" > /dev/null
}

gh_set_pbkey() {
	if [ "$#" -ne 4 ]; then
		echo "[-] Illegal number of parameters at \"create_repo()\"."
		exit
	fi
	
	ghuser=$1
	ghtoken=$2
	title=$3
	keyfile=$4
	
	echo "[+] Setting public key \"${title}\" at GitHub..."
	curl -s -u "${ghuser}":"${ghtoken}" https://api.github.com/user/keys -d \
		"{\"title\": \"${title}\", \"key\": \"`cat ${keyfile}`\"}" > /dev/null

}

config_mainroad_theme() {
	# We download the theme for our blog, and configure some stuff for it.
	git clone --quiet https://github.com/vimux/mainroad/ themes/mainroad
	rm -R themes/mainroad/{.git,exampleSite} 2> /dev/null

	# Configure config.toml file
	echo "[+] Configuring theme..."
	sed -i -e "s/http:\\/\\/example.org/https:\\/\\/${GH_LUSER}.github.io/g" config.toml
	echo "theme = \"mainroad\"" >> config.toml
}

gen_travis() {
	if [ "$#" -ne 4 ]; then
		echo "[-] Illegal number of parameters at \"gen_travis()\"."
		exit
	fi
	
	gh_user=$1
	gh_token=$2
	repo_source=$3
	travis_keypath=$4
	
	echo "[+] Generating .travis.yml..."
	
	cat >.travis.yml <<EOL
language: go
go:
- 1.7.1
env:
  global:
  - USER="${GH_USER}"
  - LUSER="${GH_LUSER}"
  - EMAIL="${GH_EMAIL}"
  - REPO="${REPO_WWW}"
  - FILES="public/*"
  - GH_REPO="github.com/\${USER}/\${REPO}.git"
before_script:
  - git clone --branch v2 https://github.com/go-yaml/yaml \$GOPATH/src/gopkg.in/yaml.v2
  - go get -u -v github.com/spf13/hugo
script:
  - mkdir public/
  - hugo --theme=mainroad
after_success:
  - MESSAGE=\$(git log --format=%B -n 1 \$TRAVIS_COMMIT)
  - eval \`ssh-agent -s\`
  - ssh-add ${TRAVIS_KEYNAME}
  - git clone git://\${GH_REPO}
  - mv -f \${FILES} \${REPO}
  - cd \${REPO}
  - git config user.email \${EMAIL}
  - git config user.name \${USER}
  - git add -A
  - git commit -m "Commiting new posts..."
  - git push git@github.com:${GH_USER}/${GH_LUSER}.github.io.git master
EOL
	
	cp ${travis_keypath} ./travis_key
	
	# if gem install travis (?)
	
	travis login --user=${gh_user} --github-token=${gh_token} 
	# echo Waiting 10 seconds for sync
	sleep 5
	# travis sync --check --no-interactive
	travis enable --repo ${gh_user}/${REPO_SOURCE} --no-interactive
	travis settings builds_only_with_travis_yml --enable --no-interactive
	travis encrypt-file travis_key --add --repo ${gh_user}/${repo_source} --debug --explode
	
	rm ./"${TRAVIS_KEYNAME}"
	
	
}

gen_Makefile() {
	echo "[+] Generating Makefile..."
	cat >Makefile <<EOL
dev:
	hugo server --watch
EOL
}

main "$@"