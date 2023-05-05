#!/usr/bin/env bash 
#
#
# Automatic updater for oc client
#
# By Marco Placidi mplacidi@redhat.com
#
# 2022/05/05

# Functions definitions
# Cleanup step

clean_up () {

echo "cleaning up..."

cd ${LAUNCHDIR}
rm -rf ${WORKDIR}

}

print_help () {
   # Display Help
   echo "Openshift Client download/update tool"
   echo
   echo "option capabality has been implemented for future improvements"
   echo "Syntax: oc_updater.sh [|-h/--help]"
   echo "options:"
   echo "-h/--help     Print this Help."
   echo
}

# Parameters section
for param in "$@"
	do
		if [ "$param" == "--help" ] || [ "$param" == "-h" ];
			then print_help; exit 2
		fi
done



# Defines a working directory under /tmp and defines current path
export WORKDIR=/tmp/oc_cli_update_$(date +%Y.%m.%d-%H.%M.%S)
export LAUNCHDIR=$PWD

# Creates working directory and jumps in it
mkdir -p ${WORKDIR}
cd ${WORKDIR}

# Determines if oc is already installed and binary location, otherwise it defaults that to /usr/local/bin
OC_CHECK=$(which oc 2>/dev/null|| echo /usr/bin/local/oc)
OC_LOC=$(echo ${OC_CHECK}|sed 's/\/oc//g')

# Determines if curl and/or wget are installed and then downloads the newest oc client

CURL_CHECK=$(curl --help 2>&1 > /dev/null && echo OK || echo NO)
WGET_CHECK=$(wget --help 2>&1 > /dev/null && echo OK || echo NO)

if [ "$CURL_CHECK" == "OK" ];
	then 
		export URL_TOOL="$(which curl) -sO"
	elif [ "$WGET_CHECK" == "OK" ];
		then
			export URL_TOOL="$(which wget) -q"
	else 
		echo "Please install curl or wget in order to use this script"
fi
	
		echo "Downloading latest oc client..."; 
		$URL_TOOL "https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable/openshift-client-linux.tar.gz" && echo "Done." 
	       if [ "$?" != "0" ];then echo "Cannot download anything, please verify your network configuration.";
	       fi

# if oc already exists, check local version vs. downloaded version, exits and cleans up in case of already downloaded latest version
echo "Checking if oc already installed"
OC_EXISTS=$(file /usr/local/bin/oc 2>&1 >/dev/null && echo OK || NO)

if [ "$OC_EXISTS" == "OK" ];
	then echo "Openshift client exists, now checking downloaded version vs. installed version md5 checksums"; export OC_MD5=$(tar xvfz ${WORKDIR}/openshift-client-linux.tar.gz --to-command=md5sum|grep -A1 oc|tail -n1|sed -E 's/\s.+$//g')
	     export LOCAL_OC_MD5=$(md5sum $OC_CHECK|sed -E 's/\s.+$//g')
	     if [ "${OC_MD5}" == "${LOCAL_OC_MD5}" ];
	     then echo "Already downloaded oc client version $(oc version 2>/dev/null |grep Client|sed -E 's/[A-Z].+\:\s//g') and md5sum ${LOCAL_OC_MD5}"; clean_up; exit 2
fi

fi
# Untar and copy/overwrite to OC_LOC
echo "No unTar openshift client into $OC_LOC"
tar xvzf ./openshift-client-linux.tar.gz oc --overwrite -C $OC_LOC && echo "Openshift client installed/updated in $OC_LOC" || echo "Please verify if your user has sufficient permissions for writing in $OC_LOC, otherwise run this script with sudo"

# Clean up function call
clean_up
