# Brew wrapper updates brew and (re)install packages
function install_brew(){
    local brew_exists=$(which brew)
    local pkg="${1}";
    local message

    local padding=$(padding $2)

    if [ -z $brew_exists ]; then
        message="$(printf "# Please install Brew (%s) first\n" "https://brew.sh/")"

        message $padding $message
        exit 1;

    else
        if [ -z "${pkg}"  ]; then
            message $padding "$(echo "brew installed")"
            brew upgrade > /dev/null 2>&1
            message $padding "$(echo "brew updating packages")"
            brew update > /dev/null 2>&1

        fi
    fi

    if [ ! -z "${pkg}" ]; then
        message $padding "$(printf "brew reinstalling %s" "${pkg}")"
        brew install $pkg > /dev/null 2>&1
    fi
}


function install_kube(){
    curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
}


# General Setup for .bashrc (which is .bash_profile on mac)
# Adding pathinfo to point back to this repo directory
# And sourcing out .bashrc (as .bash_profile)
function install_bashrc(){
    local URL=https://github.com/butuzov/dots
    local BASHRC=~/.bash_profile

    if [[ ! -f $BASHRC ]]; then
        touch $BASHRC
    fi

    local padding=$(padding 0)
    local bashrc=$(cat ~/.bash_profile | grep "$URL")

    if [[ ! -f $BASHRC || -z $bashrc ]]; then

        printf "\n# Next content added by \`./activate.sh\` from the" >> $BASHRC
        printf "\n# repository %s \n" $URL >> $BASHRC
        printf "\nDOTS_PATH=\"%s\"" $NWD >> $BASHRC
        printf "\nsource \"\${DOTS_PATH}/.bashrc\"\n" >> $BASHRC
        printf "\n# End of the autogenerated record \n" $URL >> $BASHRC

        message="$(echo "changes made to .bashrc")"

    else
        message="$(echo ".bashrc doesn't require change")"
    fi

    message $padding "${message}"
}

# Installs symbolic link to file in out repository
# Used to install multiple dotfiles from out repository
function install_dot(){
    TARGET=$1

    local padding=$(padding $2)
    local message

    local CREATE_LINK=0
    local LINK_MOVED=0

    if [[ -f ~/$TARGET && ! -h ~/$TARGET  ]]; then
        LINK_MOVED=1
        CREATE_LINK=1
    elif [[ -h ~/$TARGET && $(readlink ~/$TARGET) != $(pwd)/$TARGET ]]; then
        LINK_MOVED=1
        CREATE_LINK=1
    elif [[ ! -f ~/$TARGET ]]; then
        CREATE_LINK=1
    else
        message="$(printf "* %s already installed\n" $TARGET)"
        message $padding "${message}"
        return 0
    fi

    # Actually moving files
    if (( $LINK_MOVED == 1)); then
        message="$(printf "* %s : backuped" $TARGET)"
        message $padding "${message}"
        mv ~/$TARGET{,-backup_$(date +%Y-%m-%d)}
    fi

    if (( $CREATE_LINK == 1)); then
        message="$(printf "* %s : link created" $TARGET)"
        message $padding "${message}"
        ln -s "$(pwd)/$TARGET" ~/$TARGET
    fi
}

# Install from git repository
function install_git_repository(){
    local DIRECTORY=$2
    local REPOSITORY=$1
    if [[ ! -d "${NWD}/${DIRECTORY}" ]]; then
      git clone $REPOSITORY "${NWD}/${DIRECTORY}" > /dev/null 2>&1
    fi
}

# installs some tools using brew and standalone install
function install_php_tooling(){

    local padding=$(padding)
    local message

    message $padding "$(echo "PHP: Installing PHP Tools ")"

    local DEV_TOOLS=(
        "phpmd|http://static.phpmd.org/php/latest/phpmd.phar"
    )

    for tool in "${DEV_TOOLS[@]}" ; do
        local TOOL="${tool%%|*}"
        local URL="${tool##*|}"
        local exists="$(which $TOOL)"

        message="$(printf "phar-dl : installing %s \n" "${TOOL}")"
        message $(( $padding + 2 )) "${message}"

        if [[ -z $exists ]]; then

            curl -Ls -o $TOOL $URL
            chmod +x $TOOL
            mv $TOOL /usr/local/bin/
        fi

        message="$(printf "* %s : installed at %s \n" "${TOOL}" "$(which $TOOL)" )"
        message $(( $padding + 2 )) "${message}"

    done

    # rest of packages by brew
    install_brew phpunit 2
    install_brew php-code-sniffer 2
    install_brew composer 2

    # PHP Compatibility Standards
    message="$(printf "code standards: %s"  "PHP_Compatibility" )"
    message $(($padding+4)) "${message}"

    install_git_repository  "https://github.com/wimg/PHPCompatibility" \
                            "programming/php/cs_php_compatibility" \
    && checkout_last_release "programming/php/cs_php_compatibility"


    # WordPress Code Standards
    message="$(printf "code standards: %s"  "WordPress_Code_Standards" )"
    message $(($padding+4)) "${message}"

    install_git_repository  \
    "https://github.com/WordPress-Coding-Standards/WordPress-Coding-Standards" \
    "programming/php/cs_wp_coding-standards" \
    && checkout_last_release "programming/php/cs_wp_coding-standards"

    phpcs --config-set installed_paths "${NWD}/programming/php/cs_wp_coding-standards,${NWD}/programming/php/cs_php_compatibility" > /dev/null 2>&1
}

# installs some tools using pip
function install_python_tooling(){
    message 2 "installing python packages using pip"

    python3.6 -m pip install --upgrade -r "${NWD}/programming/python-pip-requirments.txt" > /dev/null 2>&1
}

# Convert version to number in order to sort it.
# Becouse there are no -V in mac sort
# https://stackoverflow.com/questions/16989598/bash-comparing-version-numbers
function version {
    echo "$@" | awk -F. '{ printf("%03d%03d%03d\n", $1,$2,$3); }';
}

# Obtain last release and checkout it.
function checkout_last_release(){

    local DIRECTORY=$1
    cd "${NWD}/${DIRECTORY}"
    local VERSION=$(git tag -l | \
        git tag -l | \
        grep "\." | \
        awk -F'.' '{printf("%03d%03d%03d:%s\n", $1,$2,$3, $0);}' | \
        sort -nr | \
        head -n 1 | \
        awk -F':' '{print $2}'
    )

    git checkout "tags/${VERSION}" > /dev/null 2>&1

    cd "${NWD}"
}

# prints local header
function header(){
    printf "\n"
    message 0 "$1"
}

# Prints padded message
function message(){
	local initialpadding=$1
	local message=$2
	pad=$(printf '%0.1s' " "{1..80})
	printf "%*.*s%s\n" 0 $initialpadding "$pad" "$message"
}

function padding(){
    if [ -z $1 ]; then
        echo 2;
        return 0;
    fi
    echo $(( 2 + $1 ))
}
