#!/usr/bin/env bash  
#
# Automatic updater for any client related to both self-provisioned Openshift and Managed Openshift environments
#
# By Marco Placidi mplacidi@redhat.com
#
# 2022/05/05

# Functions definitions
# Cleanup step

clean_up () {

echo -n "cleaning up..." && rm -rf ${TMPDIR} && echo "..done."
echo "Bye!"

}

print_help () {
   # Display Help
   echo "Openshift Client download/update tool"
   echo
   echo "option capability has been implemented for future improvements"
   echo "Syntax: cloud_updater.sh [|-h/--help] -c $client"
   echo "options:"
   echo "-h/--help      Print this Help."
   echo "-d/--debug	Enables set -x, for debug"
   echo "-c $client_name Updates client at your choice between [rosa|ocm|tkn|kn|helm|oc|az]."
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

if [ -z "$client" ];
	then read -p "Please input one of the following [rosa|ocm|tkn|kn|helm|oc|az]: " client	
fi
if [ "$client" == "oc" ]; 
	  then CLIENT_URL="https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz"
		#client=${client:-oc}
	elif [ "$client" == "ocm" ];
	then export OCM_VERSION=$(curl https://github.com/openshift-online/ocm-cli/releases/latest -sL|grep openshift-online|grep -Eo v'[0-9]{1,2}.[0-9]{1,2}.[0-9]{1,3}'|uniq)
		export CLIENT_URL="https://github.com/openshift-online/ocm-cli/releases/download/${OCM_VERSION}/ocm-linux-amd64"
	elif [ "$client" == "tkn" ];
	  then export CLIENT_URL="https://mirror.openshift.com/pub/openshift-v4/clients/pipelines/latest/tkn-linux-amd64.tar.gz"
	elif [ "$client" == "kn" ];
	  then export CLIENT_URL="https://mirror.openshift.com/pub/openshift-v4/clients/serverless/latest/kn-linux-amd64.tar.gz"
	elif [ "$client" == "rosa" ];
	  then export CLIENT_URL="https://mirror.openshift.com/pub/openshift-v4/clients/rosa/latest/rosa-linux.tar.gz"
	elif [ "$client" == "helm" ];
	  then export CLIENT_URL="https://mirror.openshift.com/pub/openshift-v4/clients/helm/latest/helm-linux-amd64.tar.gz"
	elif [ "$client" == "az" ];
	  then curl -L https://aka.ms/InstallAzureCli | bash
	  exit 0
	elif [ "$client" == "aws" ];
	  then curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip -o awscliv2.zip
	       if [ -z $(which aws) ];then
	       sudo aws/install
	       else sudo aws/install --update
               fi
	  exit 0
	else echo "Please, select a valid client between oc, rosa, ocm, tkn, kn, helm, az";exit 2
fi

export CLIENT_FILENAME=$(basename $CLIENT_URL)
# Client env vars definition based on $client parameter chosen by the user
echo $CLIENT_URL $CLIENT_FILENAME

# debug exit
#exit 1

# Defines a working directory under /tmp and defines current path
export TMPDIR=/tmp/${client}_cli_update_$(date +%Y.%m.%d-%H.%M.%S)
#export LAUNCHDIR=$PWD

# Creates working directory and jumps in it
mkdir -p ${TMPDIR}
#cd ${TMPDIR}

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
			then $URL_TOOL $CLIENT_URL -LO --output-dir ${TMPDIR} && echo "..done."
		else
			$URL_TOOL $CLIENT_URL -O --output-dir ${TMPDIR} && echo "..done." 
		fi
	       if [ "$?" != "0" ];then echo "Cannot download anything, please verify your network configuration.";
	       fi

# if $client already exists, check local version vs. downloaded version, exits and cleans up in case of already downloaded latest version
echo "Checking if $client already installed"
CLIENT_EXISTS=$(which $client 2>&1 >/dev/null && echo OK || echo NO)

if [ "$CLIENT_EXISTS" == "OK" ];
	then echo "$client already client exists, now checking downloaded version vs. installed version md5 checksums"; 
		if [ "$client" == "ocm" ];
			then export CLIENT_MD5=$(md5sum ${TMPDIR}/${CLIENT_FILENAME} |grep -A1 $client|tail -n1|sed -E 's/\s.+$//g')
		else
			export CLIENT_MD5=$(tar xvfz ${TMPDIR}/${CLIENT_FILENAME} --to-command=md5sum|grep -A1 $client|tail -n1|sed -E 's/\s.+$//g') 
		fi
	     export LOCAL_CLIENT_MD5=$(md5sum $CLIENT_CHECK|sed -E 's/\s.+$//g')
	     if [ "${CLIENT_MD5}" == "${LOCAL_CLIENT_MD5}" ];
	     then echo "Already downloaded $client client with md5sum ${LOCAL_CLIENT_MD5}"; clean_up; exit 2
fi

fi
# Untar and copy/overwrite to CLIENT_LOC
echo "Now unTar-ing $client client into $CLIENT_LOC"
if [[ "$CLIENT_FILENAME" == *".tar.gz" ]];
	then tar xvzf ${TMPDIR}/${CLIENT_FILENAME} -C $CLIENT_LOC --overwrite && echo "$client client installed/updated in $CLIENT_LOC" || echo "Please verify if your user has sufficient permissions for writing in $CLIENT_LOC, otherwise run this script with sudo"
else
	cp ${TMPDIR}/$CLIENT_FILENAME $CLIENT_LOC/$client
fi
# Clean up function call
clean_up
