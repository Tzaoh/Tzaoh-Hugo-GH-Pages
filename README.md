# Hugo-GH-Pages
Hugo Engine AutoCreator for GH Pages.  
This script configures a Hugo installation inside a GitHub personal account.
It will create two repositories to manage Hugo:
* source-blog: 	Where are all the files necessary to compile all the HTML stuff from travis.
* tzaoh.github.io: Where are all the HTML goes.

The "\<user>.github.io" repository will be automatically updated once the user commit a new post to "source-blog".


Requirements to run this script:  
* `apt-get install ruby jq `
* `gem install travis` (rake?) 
* Have a GitHub personal access token with the following privilegues:  
	* ✔ repo:  		Full control of private repositories.  
		* ✔ repo:status		Access commit status.  
		* ✔ repo_deployment:	Access deployment status.  
		* ✔ public_repo:	Access public repositories.  
	* ✔ admin:public_key	Full control of user public keys.  
	  	* ✔ write:public_key	Write user public keys.  
	  	* ✔ read:public_key	Read user public keys.  
	* ✔ delete_repo  		Delete repositories.  
		
It perfoms the following actions:
* Deletes (just in case they exist from previous executions) and recreates:
	* Specific local folder ("source-blog").
	* Specific SSH Keys ("id_rsa" and "travis_key").
	* Specific repositories on your GitHub accout ("source-blog" and "\<user>.github.io").
* Sets the recently created SSH Keys to your GitHub account.
* Installs hugo and creates a local hugo repository.
* Configures a theme of my choice (you are free to fork and change it).
* Creates all the Travis-ci configuration deploy the blog correctly.
* Asks the user to commit a first post or print the necessary commands to do it.s

Please install all the dependencies before execute this script!

-- Tzaoh.
