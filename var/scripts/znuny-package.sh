## example call 
# PACK="Znuny-Search"
# PACK_SOPM="Znuny-Search.sopm"
# ./znuny-package.sh install $PACK $PACK_SOPM
##

# execute inside container (recommended)
# place znuny git repos inside container (recommended)
# copy this script outside /opt/otrs folder! (/opt/ is fine)
BASE_PATH="/opt/GIT/Znuny" # <- (!) path to znuny git repos - change it for your environment(!)

group="apache"
file_permissions="660"
folder_permissions="775"

cd /opt/otrs
TYPE=$1

if [[ $TYPE != '' ]]; then
  PCKG_NAME=$2
  PCKG_SOPM=$3
  if [[ $PCKG_NAME != '' ]]; then
      # example ./znuny-package.sh link Znuny-Search
      if [[ $TYPE == 'link' ]]; then
        su -c "$BASE_PATH/module-tools/bin/otrs.ModuleTools.pl Module::File::Link $BASE_PATH/$PCKG_NAME/ /opt/otrs" -s /bin/bash otrs
      fi
      # example ./znuny-package.sh sync Znuny-Search
      # use while working on single package at a time!
      # use to sync created/deleted/renamed files as symbolic links
      if [[ $TYPE == 'sync' ]]; then
        su -c "$BASE_PATH/module-tools/bin/otrs.ModuleTools.pl Module::File::Unlink -all /opt/otrs" -s /bin/bash otrs
        su -c "$BASE_PATH/module-tools/bin/otrs.ModuleTools.pl Module::File::Link $BASE_PATH/$PCKG_NAME/ /opt/otrs" -s /bin/bash otrs
      fi
      # example ./znuny-package.sh install Znuny-Search Znuny-Search.sopm
      if [[ $TYPE == 'install' ]]; then
        su -c "$BASE_PATH/module-tools/bin/otrs.ModuleTools.pl Module::File::Link $BASE_PATH/$PCKG_NAME/ /opt/otrs" -s /bin/bash otrs
        su -c "$BASE_PATH/module-tools/bin/otrs.ModuleTools.pl Module::Database::Install '$BASE_PATH/$PCKG_NAME/$PCKG_SOPM'" -s /bin/bash otrs
        su -c "$BASE_PATH/module-tools/bin/otrs.ModuleTools.pl Module::Code::Install '$BASE_PATH/$PCKG_NAME/$PCKG_SOPM'" -s /bin/bash otrs
      fi
      # example ./znuny-package.sh uninstall Znuny-Search Znuny-Search.sopm
      if [[ $TYPE == 'uninstall' ]]; then
        su -c "$BASE_PATH/module-tools/bin/otrs.ModuleTools.pl Module::Database::Uninstall '$BASE_PATH/$PCKG_NAME/$PCKG_SOPM'" -s /bin/bash otrs
        su -c "$BASE_PATH/module-tools/bin/otrs.ModuleTools.pl Module::Code::Uninstall '$BASE_PATH/$PCKG_NAME/$PCKG_SOPM'" -s /bin/bash otrs
        su -c "$BASE_PATH/module-tools/bin/otrs.ModuleTools.pl Module::File::Unlink $BASE_PATH/$PCKG_NAME/ /opt/otrs" -s /bin/bash otrs
      fi
      # example ./znuny-package.sh setpermissions Znuny-Search
      if [[ $TYPE == 'setpermissions' ]]; then
        cd "$BASE_PATH/$PCKG_NAME/"
        if [ $? -eq 0 ]; then
            echo "OK - folder $BASE_PATH/$PCKG_NAME/ found";
            echo "Setting file permissions..";
            echo "group:$group";
            echo "permissions:$file_permissions";
            find . -type f -name *.js -exec chown otrs:$group {} \;
            find . -type f -name *.pm -exec chown otrs:$group {} \;
            find . -type f -name *.css -exec chown otrs:$group {} \;
            find . -type f -name *.tt -exec chown otrs:$group {} \;
            find . -type f -name *.sopm -exec chown otrs:$group {} \;
            find . -type f -name *.gif -exec chown otrs:$group {} \;
            find . -type f -name *.xml -exec chown otrs:$group {} \;
            find . -type f -name *.tmpl -exec chown otrs:$group {} \;

            find . -type f -name *.js -exec chmod $file_permissions {} \;
            find . -type f -name *.pm -exec chmod $file_permissions {} \;
            find . -type f -name *.css -exec chmod $file_permissions {} \;
            find . -type f -name *.tt -exec chmod $file_permissions {} \;
            find . -type f -name *.sopm -exec chmod $file_permissions {} \;
            find . -type f -name *.gif -exec chmod $file_permissions {} \;
            find . -type f -name *.xml -exec chmod $file_permissions {} \;
            find . -type f -name *.tmpl -exec chmod $file_permissions {} \;

            echo "Setting folder permissions.."
            echo "group:$group"
            echo "permissions:$folder_permissions"

            find . -type d -exec chown :$group {} \;
            find . -type d -exec chmod $folder_permissions {} \;
        else
            echo FAIL
        fi
      fi
  fi
  if [[ $TYPE == 'unlink-all' ]]; then
    su -c "$BASE_PATH/module-tools/bin/otrs.ModuleTools.pl Module::File::Unlink -all /opt/otrs" -s /bin/bash otrs
  fi
fi

## search package related
# add this to .bash_history for reverse search 
: '
search-sync
search-link
search-install
search-uninstall
search-setpermissions
znuny-unlink-all
'

# add this to .bash_rc for example aliases:
: '
alias search-sync="/opt/znuny-package.sh sync Znuny-Search && /opt/znuny-package.sh setpermissions Znuny-Search"
alias search-link="/opt/znuny-package.sh link Znuny-Search"
alias search-install="/opt/znuny-package.sh install Znuny-Search Znuny-Search.sopm"
alias search-uninstall="/opt/znuny-package.sh uninstall Znuny-Search Znuny-Search.sopm"
alias search-setpermissions="/opt/znuny-package.sh setpermissions Znuny-Search"
alias znuny-unlink-all="/opt/znuny-package.sh unlink-all"
'
##