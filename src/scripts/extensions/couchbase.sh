# Function to install libraries required by couchbase
add_couchbase_clibs() {
  ext=$1
  trunk="https://github.com/couchbase/libcouchbase/releases"
  if [[ "$ext" =~ couchbase-2.+ ]]; then
    release="2.10.9"
  else
    release="$(curl -sL $trunk/latest | grep -Eo "libcouchbase-[0-9]+\.[0-9]+\.[0-9]+" | head -n 1 | cut -d'-' -f 2)"
  fi
  [ "$VERSION_ID" = "22.04" ] && vid=20.04 || vid="$VERSION_ID"
  [ "$VERSION_CODENAME" = "jammy" ] && vcn=focal || vcn="$VERSION_CODENAME"
  deb_url="$trunk/download/$release/libcouchbase-${release}_ubuntu${vid/./}_${vcn}_amd64.tar"
  get -q -n /tmp/libcouchbase.tar "$deb_url"
  sudo tar -xf /tmp/libcouchbase.tar -C /tmp
  install_packages libev4 libevent-dev
  sudo dpkg -i /tmp/libcouchbase-*/*.deb
}

add_couchbase_cxxlibs() {
  if [ "$VERSION_ID" = "18.04" ]; then
    if ! command -v gcc-8 >/dev/null || ! command -v g++-8 >/dev/null; then
      install_packages gcc-8 g++-8 -y
    fi
    printf "gcc g++" | xargs -d ' ' -I {} sudo update-alternatives --install /usr/bin/{} {} /usr/bin/{}-8 8
  fi
  if [ "${runner:?}" = "self-hosted" ]; then
    add_list cmake https://apt.kitware.com/ubuntu/ https://apt.kitware.com/keys/kitware-archive-latest.asc "$VERSION_CODENAME" main
  fi
  install_packages cmake ccache
}

get_couchbase_version() {
  if [[ "${version:?}" =~ ${old_versions:?} ]]; then
    echo couchbase-2.2.3
  elif [[ "${version:?}" =~ 5.6|7.[0-1] ]]; then
    echo couchbase-2.6.2
  elif [ "${version:?}" = '7.2' ]; then
    echo couchbase-3.0.4
  elif [ "${version:?}" = '7.3' ]; then
    echo couchbase-3.2.2
  else
    echo couchbase
  fi
}

# Function to add couchbase.
add_couchbase() {
  ext=$1
  if [ "$(uname -s)" = "Linux" ]; then
    if [ "$ext" = "couchbase" ]; then
      ext=$(get_couchbase_version)
    fi
    if [[ "$ext" =~ couchbase-[2-3].+ ]]; then
      add_couchbase_clibs "$ext" >/dev/null 2>&1
    else
      add_couchbase_cxxlibs >/dev/null 2>&1
    fi
    enable_extension "couchbase" "extension"
    if check_extension "couchbase"; then
      add_log "${tick:?}" "couchbase" "Enabled"
    else
      if [ "$ext" = "couchbase" ]; then
        ext="couchbase-$(get_pecl_version "couchbase" "stable")"
        add_extension_from_source couchbase https://pecl.php.net couchbase couchbase "${ext##*-}" extension pecl >/dev/null 2>&1
      else
        pecl_install "${ext}" >/dev/null 2>&1
      fi
      add_extension_log "couchbase" "Installed and enabled"
    fi
  else
    if [ -e "${ext_dir:?}"/libcouchbase_php_core.dylib ]; then
      sudo cp "${ext_dir:?}"/libcouchbase_php_core.dylib ${brew_prefix:?}/lib
    fi
    add_brew_extension couchbase extension
  fi
}
