#!/usr/bin/env bash  
#
# Automatic updater for any client related to both self-provisioned Openshift and Managed Openshift environments
#
# By Marco Placidi mplacidi@redhat.com
#
# 2022/05/05

# OS Type definition

:; if [ -z 0 ]; then
  @echo off
  goto :WINDOWS
fi

MACORLINUX=$(uname -a|grep Darwin;echo $?)
if [ "${MACORLINUX}" == 0 ];
	then ostype=macos
else
	ostype=linux
fi

# Global Vars section

## ocm requires a latest release idenfity, otherwise curl won't download a frickin' anything

[[ $client == "ocm" || $client == "all" ]] && OCM_VERSION=$(curl https://github.com/openshift-online/ocm-cli/releases/latest -L|grep -Eo Release\ [0-9].[0-9].[0-9]{2}|sed 's/<[^>]*>//g;s/Release\ /v/g'|uniq)

## check if there's any Package Manager 


# Client Array section

declare -A CLIENT_URLS_ARRAY
CLIENT_URLS_ARRAY[oc]="https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz"
CLIENT_URLS_ARRAY[ocm]="https://github.com/openshift-online/ocm-cli/releases/download/${OCM_VERSION}/ocm-linux-amd64"
CLIENT_URLS_ARRAY[tkn]="https://mirror.openshift.com/pub/openshift-v4/clients/pipelines/latest/tkn-linux-amd64.tar.gz"
CLIENT_URLS_ARRAY[kn]="https://mirror.openshift.com/pub/openshift-v4/clients/serverless/latest/kn-linux-amd64.tar.gz"
CLIENT_URLS_ARRAY[rosa]="https://mirror.openshift.com/pub/openshift-v4/clients/rosa/latest/rosa-linux.tar.gz"
CLIENT_URLS_ARRAY[helm]="https://mirror.openshift.com/pub/openshift-v4/clients/helm/latest/helm-linux-amd64.tar.gz"
CLIENT_URLS_ARRAY[az]="https://azurecliprod.blob.core.windows.net/install.py"
CLIENT_URLS_ARRAY[aws]="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"

# Functions definitions
# Cleanup step

clean_up () {

echo -n "cleaning up..." && rm -rf ${TMPDIR} && echo "..done."
echo "Bye!"

}

print_help () {
   # Display Help
   echo "Managed Cloud Client download/update tool"
   echo
   echo "option capability has been implemented for future improvements"
   echo "Syntax: cloud_updater.sh [|-h/--help] -c $client"
   echo "options:"
   echo "-h/--help      Print this Help."
   echo "-d/--debug	Enables set -x, for debug"
   echo "-c $client_name Updates client at your choice between [rosa|ocm|tkn|kn|helm|oc|az|all]."
   echo
}

print_sudo_disclaimer () {
	while true;
	do
		echo "Please verify that you have write permissions on the destination directory"
		read -p "$* [y/n]: " yn
		case $yn in
			[Yy]*) return 0 ;;
			[nN]*) echo "Aborted, exiting..." ; exit 1 ;;
		esac
	done
}

linux_client_check_n_update () {
     
     export CLIENT_URL=${CLIENT_URLS_ARRAY[$client]}
     export CLIENT_FILENAME=$(basename $CLIENT_URL)
     # Client env vars definition based on $client parameter chosen by the user
     echo $CLIENT_URL $CLIENT_FILENAME
     
     # Defines a working directory under /tmp and defines current path
     export TMPDIR=/tmp/${client}_cli_update_$(date +%Y.%m.%d-%H.%M.%S)
     
     # Creates working directory and jumps in it
     mkdir -p ${TMPDIR}
     
     # Determines if $client is already installed and binary location, otherwise it defaults that to /usr/local/bin
     CLIENT_CHECK=$(which ${client} 2>/dev/null)
     if [ -z ${CLIENT_CHECK} ];
     	then read -p "Please enter the full path in which you desire to install the ${client} binary: " CLIENT_CHECK
     fi
     CLIENT_LOC=$(echo ${CLIENT_CHECK}|sed 's/\/'''${client}'''//g')
     
     # Determines if curl and/or wget are installed and then downloads the newest $client client
     
     CURL_CHECK=$(curl --help 2>&1 > /dev/null && echo OK || echo NO)
     
     if [ "$CURL_CHECK" == "OK" ];
     	then 
     		export URL_TOOL="$(which curl) -sO"
     	else 
     		echo "Curl is needed in order to make this script functioning properly"; exit 1
     fi
     	
     		echo -n "Downloading latest $client client..."; 
     		if [ "$client" == "ocm" ];
     			then $URL_TOOL $CLIENT_URL -L --output-dir ${TMPDIR} && echo "..done."
     		else
     			$URL_TOOL $CLIENT_URL --output-dir ${TMPDIR} && echo "..done." 
     		fi
     	       if [ "$?" != "0" ];then echo "Cannot download anything, please verify your network configuration.";
     	       fi
     
     # if $client already exists, check local version vs. downloaded version, exits and cleans up in case of already downloaded latest version
     echo "Checking if $client already installed"
     CLIENT_EXISTS=$(which $client 2>&1 >/dev/null && echo OK || echo NO)
     
     if [ "$CLIENT_EXISTS" == "OK" ];
     	then echo "$client already installed in your system" "now checking downloaded version vs. installed version md5 checksums"; 
     		if [ "$client" == "ocm" ];
     			then export CLIENT_MD5=$(md5sum ${TMPDIR}/${CLIENT_FILENAME} |grep -A1 $client|tail -n1|sed -E 's/\s.+$//g')
		elif [ "$client" == "az" ];
			PKGCHECK=$(rpm -q azure-cli > /dev/null;echo $?)
			[[ -x $PKGMGR && $PKGMGR == *"rpm"* ]] && $PKGMGR -q azure-cli 2>/dev/null >/dev/null ;echo $? || $PKGMGR -l azure-cli 2>/dev/null^C

			then echo "Check cannot be implemented for azure-cli, if you continue with the script you'll overwrite your current installation"
     		else
     			export CLIENT_MD5=$(tar xvfz ${TMPDIR}/${CLIENT_FILENAME} --to-command=md5sum|grep -A1 $client|tail -n1|sed -E 's/\s.+$//g') 
     		fi
     	     export LOCAL_CLIENT_MD5=$(md5sum $CLIENT_CHECK|sed -E 's/\s.+$//g')
     	     if [ "${CLIENT_MD5}" == "${LOCAL_CLIENT_MD5}" ];
     	     then echo "Already downloaded $client client with md5sum ${LOCAL_CLIENT_MD5}";
	     else
		     # Untar and copy/overwrite to CLIENT_LOC
			echo "Now unTar-ing $client client into $CLIENT_LOC" 
			if [[ "$CLIENT_FILENAME" == *".tar.gz" ]];
				then tar xvzf ${TMPDIR}/${CLIENT_FILENAME} -C $CLIENT_LOC --overwrite && echo "$client client installed/updated in $CLIENT_LOC" || echo "Please verify if your user has sufficient permissions for writing in $CLIENT_LOC, otherwise run this script with sudo"
			elif [ "$client" == "az" ];
				then PYTHONCMD=$(which python3)||$(which pyhton)
					if [ -z $PYTHONCMD ];then echo "Python is required to proceed with azure-cli installation, exiting program..";exit 2;fi
					$PYTHONCMD <(curl -s https://azurecliprod.blob.core.windows.net/install.py)
			elif [ "$client" == "aws" ];
			then curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "${TMPDIR}/awscliv2.zip" && unzip -o ${TMPDIR}/awscliv2.zip -d ${TMPDIR}
				[ -z $(which aws) ] && sudo ${TMPDIR}/aws/install || sudo ${TMPDIR}/aws/install --update
			else
				cp ${TMPDIR}/$CLIENT_FILENAME $CLIENT_LOC/$client
	     fi
	fi
fi

}
     
macos_client_check_n_update () {
echo NOT YET
}


# Parameters section
for param in "$@"
	do
		if [ "$param" == "--help" ] || [ "$param" == "-h" ];
			then print_help; exit 2
		elif [ "$param" == "--debug" ] || [ "$param" == "-d" ];
			then set -x;
		fi
done

# Client choice
while getopts c: option
do
	case "${option}"
		in
		c)client=${OPTARG};;
	esac
done

print_sudo_disclaimer



# ALL IN!

if [ "$client" == "all" ];
	then declare -a CLIENT_ARRAY=(oc ocm tkn kn helm rosa aws az)
else CLIENT_ARRAY=$client # makes it works in Singular client update
	declare -a CLIENT_VALUES=(oc ocm tkn kn helm rosa aws az)
	declare -A KEY
	for key in "${!CLIENT_VALUES[@]}"; do KEY[${CLIENT_VALUES[$key]}]="$key";done
	[[ ! -n "${KEY[$client]}" ]] && printf '%s is not a valid client value\n' "$client" && exit 2
fi

for client in "${CLIENT_ARRAY[@]}"
  do
     # Singular client update
     if [ -z "$client" ]
     	then read -p "Please input one of the following [rosa|ocm|tkn|kn|helm|oc|az]: " client	
     fi

     ${ostype}_client_check_n_update
     # Clean up function call
     clean_up
done
exit

:WINDOWS

