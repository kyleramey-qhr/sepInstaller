#!/bin/sh
# Symantec Installer

# variables
workingDir=$PWD
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'
VER='0.2.0'

displayHelp()
{
    echo "Usage: sepInstall.sh [-z sep_zip][-d sep_directory]"
}

error()
{
    >&2 echo -e "${RED}${1}${NC}"
}

checkDirectory()
{
    # Make sure the directory exists
    if [ ! -d $1 ]
    then
        error "Specified directory ($1) does not exist"
        exit 1
    fi

    # Check for the installer script and src directory
    if [ ! -f "$1/install.sh" ] || [ ! -d "$1/src" ]
    then
        error "Specified directory ($1) does not appear to be a SEP install folder"
        exit 1
    fi

    # Make sure the install script is executable
    if [ ! -x "$1/install.sh" ]
    then
        echo "Making installer executable"
        chmod +x "$1/install.sh"
    fi
}

checkDependencies()
{
    if [[ $(rpm -qa | grep -qw 'kernel-devel') -ne 0 ]] || \
       [[ $(rpm -qa | grep -qw 'gcc') -ne 0 ]]
    then
        sudo yum -y install gcc kernel-devel-$(uname -r) kernel-headers-$(uname -r)
    fi

    # Ask if the user wants UI modules
    echo "Checking for dependencies..."
    if [[ $(rpm -qa | grep -qw 'libX11.*\.i686') -ne 0 ]] || \
       [[ $(rpm -qa | grep -qw 'glibc.*\.i686') -ne 0 ]] || \
       [[ $(rpm -qa | grep -qw 'libgcc.*\.i686') -ne 0 ]]
    then
        read -p "Do you want to install the UI component? (yn):" yn
        case $yn in
            [Yy]* ) sudo yum -y install glibc.i686 libgcc.i686 libX11.i686; break;;
            [Nn]* ) break;;
            * ) echo "Please answer yes or no: "
        esac
    fi
}

buildKernelModules()
{
    cd "$1/src"
    tar -xf "ap-kernelmodule.tar.bz2"
    cd ap-kernelmodule-*
    sudo ./build.sh
    cd ../../
}

checkSavStatus()
{
    status=$(/opt/symantec/symantec_antivirus/sav info -a)
    if [[ $status -eq "Enabled" ]]
    then
        return 0
    else
        return 1
    fi
}

echo -e "${YELLOW}Better(?) SEP Installer ${VER}${NC}"

# Print help if no arguments given
if [[ $# -lt 2 ]] || [[ $# -gt 2 ]]
then
    displayHelp
    exit 1
fi


# Make sure the flag is valid
if [[ -z $1 ]] || [[ ! $1 == @("-z"|"-d") ]]
then
    error "Invalid flag"
    displayHelp
    exit 1
fi



# Handle unzipping
if [[ $1 == "-z" ]] && [[ -f $2 ]] 
then
    echo "Unzipping SEP installer"
    unzip -o -d $PWD/SymantecEndpointProtection $2
    directory="$PWD/SymantecEndpointProtection"
elif [[ $1 == "-d" ]] && [[ -d $2 ]]
then
    checkDirectory $2
    directory=$2
else
    error "Could not find $2"
fi

checkDependencies

# Uninstall existing version
if [ -d "/etc/symantec/sep" ]
then
    echo "Removing old version of SEP..."
    sudo ./install.sh -u
    if [[ ! $? ]]
    then
        error "Could not uninstall SEP"
    fi
fi

# Install SEP
echo "Running SEP Installer"
sudo $directory/install.sh -i
if [[ ! $? ]]
then
    error "Could not install SEP"
else
    echo "The installer is done"
fi

if [[ checkSavStatus ]]
then
    echo "SEP appears to be installed and functioning"
    exit 0
else
    buildKernelModules
    if [[ checkSavStatus ]]
    then
        echo "SEP appears to be installed and functioning"
        exit 0
    else
        error "SEP is not functioning. See above for errors."

fi
